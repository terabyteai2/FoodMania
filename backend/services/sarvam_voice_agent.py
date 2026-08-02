import asyncio
import base64
import json
import logging
import struct
import urllib.parse

import websockets

from config import settings
from database import AsyncSessionLocal
from models import MenuItem, Outlet
from services.customer_orders import DeliveryOrderLine, create_delivery_order, delivery_order_totals

logger = logging.getLogger(__name__)

STT_WS_URL = "wss://api.sarvam.ai/speech-to-text/ws"
STT_SAMPLE_RATE = 16000
ORDER_SOURCE = "voice_agent"
LLM_TIMEOUT = 45.0
TURN_DEBOUNCE_SECONDS = 0.9


def _pcm16_to_wav(pcm: bytes) -> bytes:
    """Wrap 16-bit little-endian mono PCM into a RIFF/WAVE container.

    Sarvam's STT WebSocket only accepts ``audio.encoding == "audio/wav"`` at the
    message level (raw PCM codec names are rejected by its schema), so every
    chunk must be a self-contained WAV file.
    """
    data_len = len(pcm)
    return (
        b"RIFF" + struct.pack("<I", 36 + data_len) + b"WAVE"
        + b"fmt " + struct.pack("<I", 16)
        + struct.pack("<HHIIHH", 1, 1, STT_SAMPLE_RATE, STT_SAMPLE_RATE * 2, 2, 16)
        + b"data" + struct.pack("<I", data_len)
        + pcm
    )


# 0.2s of 16kHz PCM silence wrapped as WAV — keeps the STT WebSocket alive
# past the 60s idle timeout.
_SILENT_CHUNK = base64.b64encode(_pcm16_to_wav(b"\x00" * 6400)).decode()

_MISSING_KEY_LABELS = {
    "customerName": "নাম",
    "mobileNumber": "মোবাইল নম্বর",
    "deliveryAddress": "ডেলিভারি ঠিকানা",
}


def _merge_turn_parts(parts: list[str]) -> str:
    """Merge VAD-segmented transcripts of one utterance into a single text.

    Later segments usually extend an earlier one ("আমার।" → "আমার কথা।"); if a
    new part contains the accumulated text, it replaces it instead of appending,
    so the LLM gets one clean final commit per turn.
    """
    def norm(s: str) -> str:
        return "".join(ch for ch in s if ch.isalnum() or ch.isspace()).lower()

    merged = ""
    for part in parts:
        text = part.strip()
        if not text:
            continue
        if not merged:
            merged = text
        elif norm(text).startswith(norm(merged)):
            merged = text
        elif norm(merged).startswith(norm(text)):
            continue
        else:
            merged = f"{merged} {text}"
    return merged


def _build_restaurant_setup(outlet: Outlet, menu_items: list[MenuItem]) -> dict:
    return {
        "type": "setup",
        "restaurantName": outlet.restaurant.name if outlet.restaurant else outlet.name,
        "outletName": outlet.name,
        "orderingEnabled": True,
        "vatRatePercent": 5.0,
        "deliveryCharge": float(outlet.delivery_charge or 0),
        "menu": [
            {
                "id": item.id,
                "name": item.name_en or item.name,
                "nameBn": item.name_bn or "",
                "category": item.category_en or item.category or "General",
                "price": float(item.price),
            }
            for item in menu_items
        ],
    }


def _parse_json_object(content: str) -> dict:
    clean = content.strip()
    if clean.startswith("```"):
        clean = clean.strip("`").strip()
        if clean.lower().startswith("json"):
            clean = clean[4:].strip()
    return json.loads(clean)


def _system_prompt(setup: dict) -> str:
    return (
        "তুমি একটি রেস্টুরেন্টের ভয়েস-ভিত্তিক অর্ডার গ্রহণকারী সহকারী। "
        "কাস্টমার মাইকে/ফোনে কথা বলে অর্ডার দেয় এবং তুমি সংক্ষিপ্তভাবে উত্তর দাও।\n\n"
        f"রেস্টুরেন্ট সেটআপ:\n{json.dumps(setup, indent=2, ensure_ascii=False)}\n\n"
        "### replyType — দুই ধরনের রেসপন্স\n"
        "প্রতিটি রেসপন্সে অবশ্যই একটি \"replyType\" ফিল্ড থাকবে:\n\n"
        "1. **\"chat\"** — সাধারণ কথোপকথন। অর্ডার প্রসেসিং লাগবে না। শুধু স্বাভাবিকভাবে উত্তর দাও।\n"
        "   গ্রিটিং, রেস্টুরেন্ট/মেনু সম্পর্কে প্রশ্ন, সাধারণ আলাপ বা অপ্রাসঙ্গিক প্রশ্নে এটি ব্যবহার করো।\n\n"
        "2. **\"action\"** — ব্যাকএন্ডকে অর্ডার অ্যাকশন প্রসেস করতে চাও। একটি \"action\" "
        "ডিক্ট দাও (নিচের নিয়ম দেখো)।\n"
        "   আইটেম যোগ, অর্ডার কনফার্ম, বাতিল বা কাস্টমার তথ্য আপডেটে এটি ব্যবহার করো।\n\n"
        "### অর্ডার অ্যাকশন (শুধু replyType \"action\" হলে)\n"
        "- আইটেম যোগ করতে: action: {intent: 'add_item', item: 'item_name', qty: number, menu_item_id: 'id_from_menu', price: price_from_menu}\n"
        "- ডেলিভারি তথ্য সংগ্রহে: action: {intent: 'set_info', key: 'customerName'|'mobileNumber'|'deliveryAddress', value: '...'}\n"
        "- কনফার্ম করতে: action: {intent: 'confirm', confirmed: true}\n"
        "- বাতিল করতে: action: {intent: 'cancel'}\n\n"
        "### সাধারণ নিয়ম\n"
        "- reply অবশ্যই ছোট রাখো — এটি টি.টি.এস.-এর মাধ্যমে উচ্চারিত হবে।\n"
        "- কনফার্ম করার আগে অনুপস্থিত তথ্য (নাম, ফোন, ঠিকানা) জিজ্ঞেস করো।\n"
        "- কনফার্ম করার আগে আইটেম ও মোট সহ অর্ডারের সামারি দেখাও।\n"
        "- আইটেমের নাম উপরের মেনু থেকে মিলাও — কাস্টমারের কথা বলার সাথে সবচেয়ে কাছের মেনু আইটেম বাছাই করো।\n"
        "- বিনয়ী ও কথোপকথনমূলক হও, উত্তর ৫০ শব্দের কম রাখো (উচ্চারিত হবে)।\n"
        "- কাস্টমার রেস্টুরেন্ট বা অন্য বিষয়ে প্রশ্ন করলে replyType \"chat\" দিয়ে স্বাভাবিক উত্তর দাও, কোনো অ্যাকশন ছাড়া।\n"
        "- শুধু একটি বৈধ JSON অবজেক্ট রিটার্ন করো। কোনো মার্কডাউন বা ব্যাখ্যা নয়।\n"
        "### JSON স্কিমা (আউটপুট ঠিক এই কাঠামোতে হবে)\n"
        "{\"replyType\": \"chat\", \"reply\": \"...\"}\n"
        "অথবা অ্যাকশনের জন্য: {\"replyType\": \"action\", \"reply\": \"...\", \"action\": {\"intent\": \"add_item\", \"item\": \"item_name\", \"qty\": 1, \"menu_item_id\": \"id_from_menu\", \"price\": 100}}\n"
        "- কথার উত্তর অবশ্যই \"reply\" কী-তে দেবে (\"text\" নয়)।\n"
    )


def _build_menu_lookup(menu_items: list[MenuItem]) -> dict:
    lookup = {}
    for item in menu_items:
        name = (item.name_en or item.name).strip().lower()
        lookup[name] = {"id": item.id, "price": float(item.price)}
    return lookup


def _lookup_item(name: str, menu_by_name: dict) -> dict | None:
    key = name.strip().lower()
    direct = menu_by_name.get(key)
    if direct:
        return direct
    for menu_key, info in menu_by_name.items():
        if key in menu_key or menu_key in key:
            return info
    return None


def _validate_lines(lines: list, menu_by_name: dict | None = None) -> tuple[list, str | None]:
    validated = []
    for line in lines:
        name = line.get("name", "")
        if not name:
            return validated, "আইটেমটা শুনতে পাইনি। আবার বলবেন?"
        mid = line.get("menu_item_id", "")
        price = line.get("price", 0)
        if not mid and menu_by_name:
            match = _lookup_item(name, menu_by_name)
            if match:
                mid = match["id"]
                if not price:
                    price = match["price"]
        if not mid:
            return validated, f"'{name}' কী সেটা বুঝতে পারিনি। আইটেমের নাম আবার বলুন।"
        qty = int(line.get("qty", 1))
        if qty <= 0:
            continue
        validated.append({"name": name, "menu_item_id": mid, "qty": qty, "price": float(price)})
    return validated, None


def _merge_state(state: dict, action: dict, menu_by_name: dict | None = None) -> dict:
    s = dict(state)
    intent = str(action.get("intent") or "").strip().lower()
    if intent == "add_item":
        items = list(s.get("items", []))
        item_name = str(action.get("item", ""))
        existing = next((i for i in items if i["name"].lower() == item_name.lower()), None)
        if existing:
            existing["qty"] = existing.get("qty", 1) + int(action.get("qty", 1))
        else:
            mid = action.get("menu_item_id", "")
            price = action.get("price", 0)
            if not mid and menu_by_name:
                match = _lookup_item(item_name, menu_by_name)
                if match:
                    mid = match["id"]
                    if not price:
                        price = match["price"]
            items.append({
                "name": item_name, "qty": int(action.get("qty", 1)),
                "menu_item_id": mid, "price": float(price) if price else 0,
            })
        s["items"] = items
    elif intent == "remove_item":
        items = list(s.get("items", []))
        name = str(action.get("item", "")).lower()
        qty = int(action.get("qty", 1))
        remaining = []
        for i in items:
            if i["name"].lower() == name:
                if i["qty"] > qty:
                    i["qty"] -= qty
                    remaining.append(i)
            else:
                remaining.append(i)
        s["items"] = remaining
    elif intent == "set_info":
        key = str(action.get("key") or "")
        if key:
            s[key] = str(action.get("value") or "")
    elif intent == "confirm":
        s["awaitingConfirmation"] = True
    elif intent == "cancel":
        s = {"items": [], "awaitingConfirmation": False}
    return s


async def _apply_order_action(outlet: Outlet, state: dict, action: dict, menu_by_name: dict | None = None) -> tuple[dict, dict | None]:
    intent = str(action.get("intent") or "none").strip().lower()
    if intent == "cancel":
        return {"items": [], "awaitingConfirmation": False}, {"type": "order_cancelled"}
    state = _merge_state(state, action, menu_by_name)
    lines, issue = _validate_lines(state.get("items", []), menu_by_name)
    if issue:
        state["awaitingConfirmation"] = False
        return state, {"type": "validation_failed", "reason": issue}
    if not lines:
        return state, None
    total_with_vat = delivery_order_totals(
        [DeliveryOrderLine(menu_item_id=l["menu_item_id"], name=l["name"], qty=l["qty"], price=l["price"]) for l in lines],
        delivery_charge=float(outlet.delivery_charge or 0),
    )
    display_total = total_with_vat["total"]
    has_details = all(
        str(state.get(key) or "").strip()
        for key in ("customerName", "mobileNumber", "deliveryAddress")
    )
    confirmed = bool(action.get("confirmed")) or intent == "confirm"
    awaiting = bool(state.get("awaitingConfirmation"))
    if confirmed and has_details:
        if awaiting or intent == "confirm":
            async with AsyncSessionLocal() as order_db:
                order = await create_delivery_order(
                    db=order_db, outlet=outlet,
                    lines=[DeliveryOrderLine(menu_item_id=l["menu_item_id"], name=l["name"], qty=l["qty"], price=l["price"]) for l in lines],
                    customer_name=str(state.get("customerName") or ""),
                    mobile_number=str(state.get("mobileNumber") or ""),
                    delivery_address=str(state.get("deliveryAddress") or ""),
                    note="Sarvam voice agent order",
                    source=ORDER_SOURCE,
                    created_by_role="customer",
                )
            return {"items": [], "awaitingConfirmation": False}, {
                "type": "order_created",
                "orderNumber": getattr(order, "serial_number", ""),
                "totalAmount": float(order.total_amount),
            }
        state["awaitingConfirmation"] = True
        return state, {
            "type": "needs_confirmation",
            "items": [{"name": l["name"], "qty": l["qty"]} for l in lines],
            "total": display_total,
        }
    if has_details:
        state["awaitingConfirmation"] = True
        return state, {
            "type": "needs_confirmation",
            "items": [{"name": l["name"], "qty": l["qty"]} for l in lines],
            "total": display_total,
        }
    state["awaitingConfirmation"] = False
    missing = [k for k in ("customerName", "mobileNumber", "deliveryAddress") if not str(state.get(k) or "").strip()]
    return state, {"type": "needs_info", "missing": missing}


def _append_event_reply(reply: str, event: dict | None) -> str:
    if not event:
        return reply
    etype = event.get("type", "")
    if etype == "order_created":
        return reply + f" আপনার অর্ডার #{event.get('orderNumber', '')} সম্পন্ন হয়েছে। মোট: ৳{event.get('totalAmount', 0)}।"
    if etype == "needs_confirmation":
        items_str = ", ".join(f"{i['name']} x{i['qty']}" for i in event.get("items", []))
        return reply + f" আপনার অর্ডার: {items_str}। মোট: ৳{event.get('total', 0)}। কনফার্ম করবেন?"
    if etype == "needs_info":
        missing = [_MISSING_KEY_LABELS.get(k, k) for k in event.get("missing", [])]
        return reply + f" আপনার {' ও '.join(missing)} জানান।"
    if etype == "order_cancelled":
        return reply + " অর্ডার বাতিল করা হয়েছে।"
    if etype == "validation_failed":
        return reply
    return reply


class SarvamVoiceAgentSession:
    def __init__(self, browser_ws, outlet: Outlet, menu_items: list[MenuItem]):
        self.browser = browser_ws
        self.outlet = outlet
        self.menu_items = menu_items
        self.stt_ws = None
        self.history: list[dict] = []
        self._done = False
        self._order_state: dict = {"items": [], "awaitingConfirmation": False}
        self._menu_by_name = _build_menu_lookup(menu_items)
        self._audio_chunks = 0
        self._transcripts = 0
        self._turn_parts: list[str] = []
        self._turn_task: asyncio.Task | None = None
        self._processing = False

    async def run(self):
        setup = _build_restaurant_setup(self.outlet, self.menu_items)
        sp = _system_prompt(setup)
        self.history.append({"role": "system", "content": sp})
        logger.info("[sarvam:session] Starting with %d menu items, %d lookup entries",
                    len(self.menu_items), len(self._menu_by_name))
        try:
            async with asyncio.TaskGroup() as tg:
                tg.create_task(self._connect_and_read_stt())
                tg.create_task(self._relay_audio())
                tg.create_task(self._stt_keepalive())
                tg.create_task(self._keepalive())
        except Exception as e:
            logger.error("[sarvam:session] Error: %s", e, exc_info=True)
        finally:
            await self.close()

    async def _connect_and_read_stt(self):
        try:
            await self._connect_stt()
        except Exception as e:
            logger.error("[sarvam:stt] Failed to connect: %s", e, exc_info=True)
            await self._send_browser({"type": "error", "text": f"STT connect failed: {e}"})
            return
        logger.info("[sarvam:stt] Connected (model=%s language=%s)",
                    settings.SARVAM_STT_MODEL, settings.SARVAM_STT_LANGUAGE)
        while not self._done:
            try:
                raw = await asyncio.wait_for(self.stt_ws.recv(), timeout=45)
            except asyncio.TimeoutError:
                logger.debug("[sarvam:stt] recv timeout, sending keepalive")
                await self._send_silence()
                continue
            except Exception as e:
                logger.info("[sarvam:stt] Connection closed: %s", e)
                break
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                continue
            await self._handle_stt_message(data)

    async def _connect_stt(self):
        params = {
            "language-code": settings.SARVAM_STT_LANGUAGE,
            "model": settings.SARVAM_STT_MODEL,
            "mode": "transcribe",
            "sample_rate": str(STT_SAMPLE_RATE),
            "high_vad_sensitivity": "true",
            "flush_signal": "true",
            "vad_signals": "true",
        }
        url = f"{STT_WS_URL}?{urllib.parse.urlencode(params)}"
        logger.info("[sarvam:stt] Connecting to %s", url)
        self.stt_ws = await websockets.connect(
            url,
            additional_headers={"api-subscription-key": settings.SARVAM_API_KEY},
        )

    async def _handle_stt_message(self, data: dict):
        msg_type = data.get("type")
        if msg_type == "data":
            transcript = (data.get("data") or {}).get("transcript", "")
            if transcript.strip():
                self._transcripts += 1
                logger.info("[sarvam:stt] Transcript: %s", transcript[:120])
                await self._on_transcript(transcript)
        elif msg_type == "events":
            signal = (data.get("data") or {}).get("signal_type")
            if signal == "END_SPEECH":
                try:
                    await self.stt_ws.send(json.dumps({"type": "flush"}))
                except Exception:
                    pass
        elif msg_type == "error":
            inner = data.get("data") or {}
            error_msg = (
                inner.get("message") or inner.get("error")
                or data.get("error") or data.get("message") or str(data)
            )
            logger.error("[sarvam:stt] API error: %s", error_msg)
            await self._send_browser({"type": "error", "text": f"STT: {error_msg}"})
        else:
            logger.debug("[sarvam:stt] Unhandled message type=%s", msg_type)

    async def _on_transcript(self, text: str):
        self._turn_parts.append(text.strip())
        await self._send_browser({"type": "partial", "text": _merge_turn_parts(self._turn_parts)})
        # Cancelling mid-processing would abort an in-flight LLM call — only
        # reschedule while we're still debouncing.
        if self._turn_task and not self._turn_task.done() and not self._processing:
            self._turn_task.cancel()
        if not self._turn_task or self._turn_task.done():
            self._turn_task = asyncio.create_task(self._fire_turn())

    async def _fire_turn(self):
        """Debounced: fire ONE LLM commit after a silence gap, merging segments."""
        try:
            await asyncio.sleep(TURN_DEBOUNCE_SECONDS)
        except asyncio.CancelledError:
            return
        while not self._done:
            if self._processing:
                await asyncio.sleep(0.2)
                continue
            text = _merge_turn_parts(self._turn_parts)
            if not text:
                self._turn_parts = []
                return
            self._turn_parts = []
            self._processing = True
            try:
                logger.info("[sarvam:turn] Final commit: %s", text[:120])
                await self._send_browser({"type": "user_text", "text": text})
                await self._handle_committed(text)
            finally:
                self._processing = False
            await asyncio.sleep(TURN_DEBOUNCE_SECONDS)
            if not self._turn_parts:
                return
        self._turn_parts = []

    async def _send_silence(self):
        if not self.stt_ws:
            return
        try:
            await self.stt_ws.send(json.dumps({
                "audio": {"data": _SILENT_CHUNK, "encoding": "audio/wav", "sample_rate": STT_SAMPLE_RATE},
            }))
        except Exception:
            pass

    async def _stt_keepalive(self):
        while not self._done:
            await asyncio.sleep(25)
            await self._send_silence()

    async def _relay_audio(self):
        logger.info("[sarvam:relay] Starting audio relay")
        while not self._done:
            try:
                raw = await asyncio.wait_for(self.browser.receive_text(), timeout=30)
            except asyncio.TimeoutError:
                continue
            except Exception:
                logger.info("[sarvam:relay] Browser disconnected")
                break
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if msg.get("type") == "audio":
                data = msg.get("data", "")
                if self.stt_ws and data:
                    self._audio_chunks += 1
                    if self._audio_chunks <= 3 or self._audio_chunks % 50 == 0:
                        logger.debug("[sarvam:relay] Audio chunk #%d (%d bytes)", self._audio_chunks, len(data))
                    try:
                        pcm = base64.b64decode(data)
                        wav = _pcm16_to_wav(pcm)
                        await self.stt_ws.send(json.dumps({
                            "audio": {"data": base64.b64encode(wav).decode(), "encoding": "audio/wav", "sample_rate": STT_SAMPLE_RATE},
                        }))
                    except Exception as e:
                        logger.warning("[sarvam:relay] STT send failed: %s", e)
                        break
        logger.info("[sarvam:relay] Stopped (total chunks: %d)", self._audio_chunks)

    async def _keepalive(self):
        while not self._done:
            await asyncio.sleep(25)
            try:
                await self.browser.send_text(json.dumps({"type": "ping"}))
            except Exception:
                break

    async def _handle_committed(self, text: str):
        logger.info("[sarvam:llm] Handling transcript: %s", text[:120])
        self.history.append({"role": "user", "content": text})
        reply_text = await self._call_llm()
        if reply_text:
            self.history.append({"role": "assistant", "content": reply_text})
            logger.info("[sarvam:tts] Streaming response (%d chars): %s", len(reply_text), reply_text[:100])
            await self._stream_tts(reply_text)

    async def _call_llm(self) -> str:
        api_key = settings.SARVAM_API_KEY.strip()
        if not api_key:
            logger.error("[sarvam:llm] Sarvam API key not configured")
            await self._send_browser({"type": "error", "text": "LLM not configured."})
            return ""
        messages = self.history[-20:]
        logger.info("[sarvam:llm] Calling Sarvam model=%s with %d messages", settings.SARVAM_LLM_MODEL, len(messages))
        try:
            content = await asyncio.wait_for(
                self._complete_llm(messages),
                timeout=LLM_TIMEOUT,
            )
        except asyncio.TimeoutError:
            logger.error("[sarvam:llm] LLM call timed out")
            await self._send_browser({"type": "error", "text": "Sorry, the assistant took too long."})
            return ""
        except Exception as e:
            logger.error("[sarvam:llm] LLM call failed: %s", e, exc_info=True)
            await self._send_browser({"type": "error", "text": "Sorry, I couldn't reach the assistant."})
            return ""
        logger.info("[sarvam:llm] Response received (content_len=%d)", len(content))
        if not content:
            logger.warning("[sarvam:llm] Empty response from Sarvam LLM")
            return ""
        try:
            parsed = _parse_json_object(content)
        except json.JSONDecodeError:
            logger.warning("[sarvam:llm] Non-JSON response, using raw text: %s", content[:100])
            return content[:500]
        reply_type = str(parsed.get("replyType") or "").strip().lower()
        reply = str(parsed.get("reply") or parsed.get("text") or "")
        if reply_type == "action":
            action = parsed.get("action")
            if action:
                logger.info("[sarvam:llm] Processing action: intent=%s", action.get("intent"))
                self._order_state, event = await _apply_order_action(self.outlet, self._order_state, action, self._menu_by_name)
                if event:
                    logger.info("[sarvam:llm] Action result: %s", event.get("type", ""))
                    reply = _append_event_reply(reply, event)
        elif reply_type != "chat":
            logger.warning("[sarvam:llm] Unknown replyType=%s, treating as chat", reply_type)
        return reply[:500]

    async def _complete_llm(self, messages: list[dict]) -> str:
        import httpx
        url = "https://api.sarvam.ai/v1/chat/completions"
        headers = {
            "api-subscription-key": settings.SARVAM_API_KEY.strip(),
            "Content-Type": "application/json",
        }
        payload = {
            "model": settings.SARVAM_LLM_MODEL,
            "messages": messages,
            "stream": True,
            "temperature": settings.SARVAM_LLM_TEMPERATURE,
            "max_tokens": settings.SARVAM_LLM_MAX_TOKENS,
            "response_format": {"type": "json_object"},
            "reasoning_effort": None,
        }
        content = ""
        async with httpx.AsyncClient(timeout=LLM_TIMEOUT) as client:
            async with client.stream("POST", url, headers=headers, json=payload) as resp:
                if resp.status_code != 200:
                    body = (await resp.aread()).decode("utf-8", errors="replace")
                    message = ""
                    try:
                        message = (json.loads(body).get("error") or {}).get("message", "")
                    except json.JSONDecodeError:
                        pass
                    raise RuntimeError(f"HTTP {resp.status_code}: {message or body[:300]}")
                async for line in resp.aiter_lines():
                    if self._done:
                        break
                    if not line.startswith("data:"):
                        continue
                    data = line[5:].strip()
                    if not data or data == "[DONE]":
                        continue
                    try:
                        chunk = json.loads(data)
                    except json.JSONDecodeError:
                        continue
                    try:
                        delta = chunk["choices"][0]["delta"]
                        if delta and delta.get("content"):
                            content += delta["content"]
                    except (KeyError, IndexError, TypeError):
                        pass
        return content

    async def _stream_tts(self, text: str):
        from sarvamai import SarvamAI
        logger.info("[sarvam:tts] Streaming via Sarvam AI (model=%s speaker=%s)",
                    settings.SARVAM_TTS_MODEL, settings.SARVAM_TTS_SPEAKER)
        try:
            client = SarvamAI(api_subscription_key=settings.SARVAM_API_KEY)
            audio_count = 0
            for chunk in client.text_to_speech.convert_stream(
                model=settings.SARVAM_TTS_MODEL,
                text=text,
                target_language_code=settings.SARVAM_TTS_LANGUAGE,
                speaker=settings.SARVAM_TTS_SPEAKER,
                output_audio_codec="mp3",
            ):
                if self._done:
                    break
                audio_count += 1
                await self._send_browser({"type": "audio", "data": base64.b64encode(chunk).decode()})
            logger.info("[sarvam:tts] Sarvam AI stream complete (%d chunks)", audio_count)
            await self._send_browser({"type": "tts_done"})
        except Exception as e:
            logger.error("[sarvam:tts] Stream error: %s", e, exc_info=True)
            await self._send_browser({"type": "error", "text": f"TTS error: {e}"})

    async def _send_browser(self, msg: dict):
        try:
            await self.browser.send_text(json.dumps(msg))
        except Exception as e:
            logger.debug("[sarvam:browser] Send error: %s", e)

    async def close(self):
        logger.info("[sarvam:session] Closing session (audio_chunks=%d transcripts=%d)",
                    self._audio_chunks, self._transcripts)
        self._done = True
        if self._turn_task and not self._turn_task.done():
            self._turn_task.cancel()
        if self.stt_ws:
            try:
                await self.stt_ws.close()
            except Exception:
                pass
            self.stt_ws = None
        logger.info("[sarvam:session] Session fully closed")
