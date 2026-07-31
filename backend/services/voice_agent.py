import asyncio
import base64
import json
import logging

import httpx
from fastapi import WebSocket

from config import settings
from database import AsyncSessionLocal
from elevenlabs import AsyncElevenLabs, AudioFormat, CommitStrategy, ElevenLabs, RealtimeAudioOptions
from elevenlabs.realtime.connection import RealtimeConnection
from models import MenuItem, Outlet
from services.customer_orders import DeliveryOrderLine, create_delivery_order, delivery_order_totals

logger = logging.getLogger(__name__)

STT_MODEL = "scribe_v2_realtime"
DEEPSEEK_URL = "https://api.deepseek.com/v1/chat/completions"
DEEPSEEK_TIMEOUT = 45.0
ORDER_SOURCE = "voice_agent"


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
        "You are a voice-based restaurant order-taking assistant. "
        "The customer speaks their order and you respond concisely.\n\n"
        f"Restaurant setup:\n{json.dumps(setup, indent=2, ensure_ascii=False)}\n\n"
        "### replyType — TWO RESPONSE MODES\n"
        "Every response MUST include a \"replyType\" field:\n\n"
        "1. **\"chat\"** — Normal conversation. No order processing needed. Just reply naturally.\n"
        "   Use this for: greetings, answering questions about the restaurant/menu, casual chat, "
        "or any context/off-topic question.\n\n"
        "2. **\"action\"** — You want the backend to process an order action. Include an \"action\" "
        "dict (see rules below).\n"
        "   Use this for: adding items, confirming an order, cancelling, updating customer details.\n\n"
        "### ORDER ACTIONS (only when replyType is \"action\")\n"
        "- To add items: action: {intent: 'add_item', item: 'item_name', qty: number, menu_item_id: 'id_from_menu', price: price_from_menu}\n"
        "- To collect delivery info: action: {intent: 'set_info', key: 'customerName'|'mobileNumber'|'deliveryAddress', value: '...'}\n"
        "- To confirm: action: {intent: 'confirm', confirmed: true}\n"
        "- To cancel: action: {intent: 'cancel'}\n\n"
        "### GENERAL RULES\n"
        "- reply must be short -- this will be spoken aloud via TTS.\n"
        "- Always ask for missing info (name, phone, address) before confirming.\n"
        "- Show the order summary with items and total before confirming.\n"
        "- Item names come from the menu above -- match customer speech to the closest menu item name.\n"
        "- Be polite, conversational, and keep replies under 50 words (they're spoken).\n"
        "- If the customer asks a question about the restaurant or goes off-topic, just reply "
        "naturally with replyType \"chat\" and no action.\n"
        "- Return ONLY a valid JSON object. No markdown formatting, no explanations.\n"
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
            return validated, "I didn't catch that item. Could you please repeat it?"
        mid = line.get("menu_item_id", "")
        price = line.get("price", 0)
        if not mid and menu_by_name:
            match = _lookup_item(name, menu_by_name)
            if match:
                mid = match["id"]
                if not price:
                    price = match["price"]
        if not mid:
            return validated, f"I'm not sure what '{name}' is. Please repeat the item name."
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
                    note="Voice agent order",
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


class VoiceAgentSession:
    def __init__(self, browser_ws: WebSocket, outlet: Outlet, menu_items: list[MenuItem]):
        self.browser = browser_ws
        self.outlet = outlet
        self.menu_items = menu_items
        self.stt_connection: RealtimeConnection | None = None
        self.history: list[dict] = []
        self._done = False
        self._order_state: dict = {"items": [], "awaitingConfirmation": False}
        self._menu_by_name = _build_menu_lookup(menu_items)
        self._audio_chunks = 0
        self._transcripts = 0

    async def run(self):
        setup = _build_restaurant_setup(self.outlet, self.menu_items)
        sp = _system_prompt(setup)
        self.history.append({"role": "system", "content": sp})
        logger.info("[voice:session] Starting with %d menu items, %d lookup entries",
                     len(self.menu_items), len(self._menu_by_name))
        try:
            async with asyncio.TaskGroup() as tg:
                tg.create_task(self._run_stt())
                tg.create_task(self._relay_audio())
                tg.create_task(self._keepalive())
        except Exception as e:
            logger.error("[voice:session] Error: %s", e, exc_info=True)
        finally:
            await self.close()

    async def _connect_stt(self) -> RealtimeConnection:
        logger.info("[voice:stt] Connecting to ElevenLabs Scribe v2...")
        try:
            client = ElevenLabs(api_key=settings.ELEVENLABS_API_KEY)
            options = RealtimeAudioOptions(
                model_id=STT_MODEL,
                audio_format=AudioFormat.PCM_16000,
                sample_rate=16000,
                commit_strategy=CommitStrategy.VAD,
                vad_silence_threshold_secs=1.0,
                vad_threshold=0.3,
                language_code="bn",
            )
            connection = await client.speech_to_text.realtime.connect(options)
            self.stt_connection = connection

            connection.on("partial_transcript", self._on_partial)
            connection.on("committed_transcript", self._on_committed)
            connection.on("input_error", self._on_stt_error)
            connection.on("error", self._on_stt_error)
            connection.on("auth_error", self._on_stt_error)

            logger.info("[voice:stt] Connected to ElevenLabs Scribe v2")
            return connection
        except Exception as e:
            logger.error("[voice:stt] Failed to connect: %s", e, exc_info=True)
            raise

    def _on_partial(self, data: dict):
        text = data.get("text") or data.get("transcript", "")
        if text.strip():
            self._transcripts += 1
            logger.debug("[voice:stt] Partial: %s", text[:80])
            asyncio.create_task(self._send_browser({"type": "partial", "text": text}))

    def _on_committed(self, data: dict):
        text = data.get("text") or data.get("transcript", "")
        if text.strip():
            self._transcripts += 1
            logger.info("[voice:stt] Committed: %s", text[:120])
            asyncio.create_task(self._send_browser({"type": "user_text", "text": text}))
            asyncio.create_task(self._handle_committed(text))

    def _on_stt_error(self, data: dict):
        error_msg = data.get("error") or data.get("message", "") or str(data)
        logger.error("[voice:stt] Error: %s", error_msg)
        asyncio.create_task(self._send_browser({"type": "error", "text": f"STT: {error_msg}"}))

    async def _run_stt(self):
        try:
            await self._connect_stt()
            while not self._done:
                await asyncio.sleep(1)
        except Exception as e:
            logger.error("[voice:stt] Error: %s", e, exc_info=True)

    async def _relay_audio(self):
        logger.info("[voice:relay] Starting audio relay")
        while not self._done:
            try:
                raw = await asyncio.wait_for(self.browser.receive_text(), timeout=30)
            except asyncio.TimeoutError:
                continue
            except Exception:
                logger.info("[voice:relay] Browser disconnected")
                break
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if msg.get("type") == "audio":
                data = msg.get("data", "")
                if self.stt_connection and data:
                    self._audio_chunks += 1
                    if self._audio_chunks <= 3 or self._audio_chunks % 50 == 0:
                        logger.debug("[voice:relay] Audio chunk #%d (%d bytes)", self._audio_chunks, len(data))
                    await self.stt_connection.send({"audio_base_64": data})
        logger.info("[voice:relay] Stopped (total chunks: %d)", self._audio_chunks)

    async def _keepalive(self):
        while not self._done:
            await asyncio.sleep(25)
            try:
                await self.browser.send_text(json.dumps({"type": "ping"}))
            except Exception:
                break

    async def _handle_committed(self, text: str):
        logger.info("[voice:llm] Handling transcript: %s", text[:120])
        self.history.append({"role": "user", "content": text})
        reply_text = await self._call_llm()
        if reply_text:
            self.history.append({"role": "assistant", "content": reply_text})
            logger.info("[voice:tts] Streaming response (%d chars): %s", len(reply_text), reply_text[:100])
            await self._stream_tts(reply_text)

    async def _call_llm(self) -> str:
        api_key = settings.DEEPSEEK_API_KEY.strip()
        model = settings.CHATBOT_DEEPSEEK_MODEL.strip()
        if not api_key or not model:
            logger.error("[voice:llm] DeepSeek not configured (api_key=%s model=%s)", bool(api_key), model)
            await self._send_browser({"type": "error", "text": "LLM not configured."})
            return ""
        messages = self.history[-20:]
        logger.info("[voice:llm] Calling DeepSeek model=%s with %d messages", model, len(messages))
        try:
            async with httpx.AsyncClient(timeout=DEEPSEEK_TIMEOUT) as client:
                resp = await client.post(
                    DEEPSEEK_URL,
                    headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
                    json={"model": model, "messages": messages, "temperature": 0.3, "max_tokens": 1024},
                )
                resp.raise_for_status()
                payload = resp.json()
        except httpx.HTTPError as e:
            logger.error("[voice:llm] DeepSeek call failed: %s", e, exc_info=True)
            await self._send_browser({"type": "error", "text": "Sorry, I couldn't reach the assistant."})
            return ""
        content = ((payload.get("choices") or [{}])[0].get("message") or {}).get("content", "")
        logger.info("[voice:llm] DeepSeek response received (content_len=%d)", len(content))
        if not content:
            logger.warning("[voice:llm] Empty response from DeepSeek")
            return ""
        try:
            parsed = _parse_json_object(content)
        except json.JSONDecodeError:
            logger.warning("[voice:llm] Non-JSON response, using raw text: %s", content[:100])
            return content[:500]
        reply_type = str(parsed.get("replyType") or "").strip().lower()
        reply = str(parsed.get("reply") or "")
        if reply_type == "action":
            action = parsed.get("action")
            if action:
                logger.info("[voice:llm] Processing action: intent=%s", action.get("intent"))
                self._order_state, event = await _apply_order_action(self.outlet, self._order_state, action, self._menu_by_name)
                if event:
                    etype = event.get("type", "")
                    logger.info("[voice:llm] Action result: %s", etype)
                    if etype == "order_created":
                        reply += f" Your order #{event.get('orderNumber', '')} has been placed. Total: ৳{event.get('totalAmount', 0)}."
                    elif etype == "needs_confirmation":
                        items_str = ", ".join(f"{i['name']} x{i['qty']}" for i in event.get("items", []))
                        reply += f" Here's your order: {items_str}. Total: ৳{event.get('total', 0)}. Shall I confirm?"
                    elif etype == "needs_info":
                        missing = event.get("missing", [])
                        reply += f" I still need your {', '.join(missing)}."
        elif reply_type != "chat":
            logger.warning("[voice:llm] Unknown replyType=%s, treating as chat", reply_type)
        return reply[:500]

    async def _stream_tts(self, text: str):
        if settings.SARVAM_API_KEY:
            try:
                await self._stream_tts_sarvam(text)
                return
            except Exception as e:
                logger.warning("[voice:tts] Sarvam failed, falling back to ElevenLabs: %s", e)
        await self._stream_tts_elevenlabs(text)

    async def _stream_tts_sarvam(self, text: str):
        from sarvamai import SarvamAI
        logger.info("[voice:tts] Streaming via Sarvam AI (speaker=shreya)")
        client = SarvamAI(api_subscription_key=settings.SARVAM_API_KEY)
        audio_count = 0
        for chunk in client.text_to_speech.convert_stream(
            model="bulbul:v3",
            text=text,
            target_language_code="bn-IN",
            speaker="shreya",
            output_audio_codec="mp3",
        ):
            if self._done:
                break
            audio_count += 1
            await self._send_browser({"type": "audio", "data": base64.b64encode(chunk).decode()})
        logger.info("[voice:tts] Sarvam AI stream complete (%d chunks)", audio_count)
        await self._send_browser({"type": "tts_done"})

    async def _stream_tts_elevenlabs(self, text: str):
        voice_id = settings.VOICE_ELEVENLABS_VOICE_ID
        if not voice_id:
            logger.warning("[voice:tts] No voice ID configured")
            await self._send_browser({"type": "error", "text": "TTS voice not configured."})
            return
        logger.info("[voice:tts] Streaming via ElevenLabs SDK (voice=%s)", voice_id)
        try:
            client = AsyncElevenLabs(api_key=settings.ELEVENLABS_API_KEY)
            audio_count = 0
            async for chunk in client.text_to_speech.stream(
                voice_id=voice_id,
                text=text,
                model_id="eleven_flash_v2_5",
                output_format="mp3_44100_128",
                voice_settings={"stability": 0.5, "similarity_boost": 0.75},
            ):
                if self._done:
                    break
                audio_count += 1
                if audio_count <= 3 or audio_count % 20 == 0:
                    logger.debug("[voice:tts] Audio chunk #%d (%d bytes)", audio_count, len(chunk))
                await self._send_browser({"type": "audio", "data": base64.b64encode(chunk).decode()})
            logger.info("[voice:tts] Stream complete (%d chunks)", audio_count)
            await self._send_browser({"type": "tts_done"})
        except Exception as e:
            logger.error("[voice:tts] Stream error: %s", e, exc_info=True)
            await self._send_browser({"type": "error", "text": f"TTS error: {e}"})

    async def _send_browser(self, msg: dict):
        try:
            await self.browser.send_text(json.dumps(msg))
        except Exception as e:
            logger.debug("[voice:browser] Send error: %s", e)

    async def close(self):
        logger.info("[voice:session] Closing session (audio_chunks=%d transcripts=%d)",
                     self._audio_chunks, self._transcripts)
        self._done = True
        if self.stt_connection:
            try:
                await self.stt_connection.close()
            except Exception:
                pass
        logger.info("[voice:session] Session fully closed")