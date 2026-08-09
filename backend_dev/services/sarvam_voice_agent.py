import asyncio
import base64
import json
import logging
import re
import struct
import time
import urllib.parse

import websockets

from config import settings
from database import AsyncSessionLocal
from models import MenuItem, Outlet
from services.customer_orders import DeliveryOrderLine, create_delivery_order, delivery_order_totals

logger = logging.getLogger(__name__)

STT_WS_URL = "wss://api.sarvam.ai/speech-to-text/ws"
STT_REALTIME_WS_URL = "wss://api.sarvam.ai/speech-to-text-realtime/ws"
TTS_WS_URL = "wss://api.sarvam.ai/text-to-speech/ws"
STT_SAMPLE_RATE = 16000
ORDER_SOURCE = "voice_agent"
LLM_TIMEOUT = 45.0
# Only used by the legacy STT path; the realtime endpoint commits once per
# utterance so no debounce is needed there.
TURN_DEBOUNCE_SECONDS = 0.15


def _timing_secs(after: float | None, before: float | None) -> float | None:
    """Duration between two monotonic stamps, or None if either is missing."""
    if after is None or before is None:
        return None
    return max(0.0, after - before)


def _fmt_secs(seconds: float | None) -> str:
    return "–" if seconds is None else f"{seconds:.2f}s"


def _format_turn_timing(stamps: dict) -> str:
    """One-line per-turn latency breakdown for diagnostics.

    ``stamps`` maps step names to monotonic seconds (or None). Durations that
    can't be computed are rendered as "–" so the stuck step stands out.
    """
    stt = _timing_secs(stamps.get("stt_final_at"), stamps.get("stt_speech_end_at"))
    llm_ttft = _timing_secs(stamps.get("llm_first_token_at"), stamps.get("llm_started_at"))
    llm_total = _timing_secs(stamps.get("llm_done_at"), stamps.get("llm_started_at"))
    tts_first = _timing_secs(stamps.get("tts_first_audio_at"), stamps.get("tts_started_at"))
    tts_total = _timing_secs(stamps.get("tts_done_at"), stamps.get("tts_started_at"))
    turn_total = _timing_secs(stamps.get("tts_done_at"), stamps.get("turn_started_at"))
    return (
        f"[sarvam:turn] #{stamps.get('turn_idx')} "
        f"STT={_fmt_secs(stt)} LLM_TTFT={_fmt_secs(llm_ttft)} LLM={_fmt_secs(llm_total)} "
        f"TTS_connect={_fmt_secs(stamps.get('tts_connect_secs'))} "
        f"TTS_first={_fmt_secs(tts_first)} TTS={_fmt_secs(tts_total)} "
        f"turn_total={_fmt_secs(turn_total)}"
    )


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


# Sentence boundaries: Bengali danda, ? and ! anywhere; "." only when followed
# by whitespace/end so decimals like "৳2.5" are not split.
_SENTENCE_BOUNDARY_RE = re.compile(r"(?<=[।?!…])[ \t]*|(?<=\.)[ \t]+|\n+")


def _split_sentences(text: str) -> list[str]:
    """Split text into complete sentences, keeping the terminating punctuation."""
    text = text.strip()
    if not text:
        return []
    segments = [s.strip() for s in _SENTENCE_BOUNDARY_RE.split(text)]
    return [s for s in segments if s]


_REPLY_VALUE_RE = re.compile(r'"reply"\s*:\s*"((?:[^"\\]|\\.)*)"', re.S)


def _extract_reply_value(text: str) -> str | None:
    """Return the first fully-closed `"reply"` string value in streamed JSON.

    Returns None while the value is still unterminated, so it is safe to call
    on partial LLM output.
    """
    match = _REPLY_VALUE_RE.search(text)
    return match.group(1) if match else None


class _ReplyScanner:
    """Feeds LLM stream deltas and yields complete sentences of `"reply"`.

    Only sentences that are fully present in the closed `"reply"` string are
    emitted, so partial JSON never reaches the TTS pipe.
    """

    def __init__(self):
        self.buffer = ""
        self._last_len = 0

    @property
    def emitted_chars(self) -> int:
        return self._last_len

    def feed(self, delta: str) -> list[str]:
        self.buffer += delta
        reply = _extract_reply_value(self.buffer)
        if reply is None:
            return []
        fresh = reply[self._last_len:]
        self._last_len = len(reply)
        return _split_sentences(fresh)


class _TtsWsClient:
    """Incremental TTS over the /text-to-speech/ws WebSocket.

    Every fed chunk is sent as a text message followed by a flush, so its audio
    is synthesized immediately instead of waiting for the whole reply.
    """

    def __init__(self):
        self.ws = None
        self.connect_seconds: float | None = None

    async def connect(self) -> bool:
        if self.ws is not None:
            try:
                if self.ws.state.name != "CLOSED":
                    return True
            except AttributeError:
                return True
            self.ws = None
        self.connect_seconds = None
        t0 = time.monotonic()
        try:
            ws = await websockets.connect(
                TTS_WS_URL + "?" + urllib.parse.urlencode({
                    "model": settings.SARVAM_TTS_MODEL,
                    "send_completion_event": "true",
                }),
                additional_headers={"api-subscription-key": settings.SARVAM_API_KEY},
            )
            await ws.send(json.dumps({
                "type": "config",
                "data": {
                    "model": settings.SARVAM_TTS_MODEL,
                    "language_code": settings.SARVAM_TTS_LANGUAGE,
                    "speaker": settings.SARVAM_TTS_SPEAKER,
                    "pace": settings.SARVAM_TTS_PACE,
                    "temperature": settings.SARVAM_TTS_TEMPERATURE,
                    "speech_sample_rate": settings.SARVAM_TTS_SAMPLE_RATE,
                    "output_audio_codec": "mp3",
                    "min_buffer_size": settings.SARVAM_TTS_MIN_BUFFER,
                    "max_chunk_length": settings.SARVAM_TTS_MAX_CHUNK,
                },
            }))
            self.ws = ws
            self.connect_seconds = time.monotonic() - t0
            logger.info("[sarvam:tts-ws] Connected and configured in %.2fs", self.connect_seconds)
            return True
        except Exception as e:
            logger.error("[sarvam:tts-ws] Connect failed: %s", e)
            self.ws = None
            return False

    async def send_text(self, text: str) -> bool:
        if not text.strip():
            return False
        if not await self.connect():
            return False
        try:
            await self.ws.send(json.dumps({"type": "text", "data": {"text": text}}))
            await self.ws.send(json.dumps({"type": "flush"}))
            return True
        except Exception as e:
            logger.error("[sarvam:tts-ws] Send failed: %s", e)
            self.ws = None
            return False

    async def close(self):
        if self.ws is not None:
            try:
                await self.ws.close()
            except Exception:
                pass
            self.ws = None


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
        "কাস্টমার মাইকে/ফোনে কথা বলে অর্ডার দেয় এবং তুমি মুখে মুখে উত্তর দাও।\n\n"
        f"রেস্টুরেন্ট সেটআপ:\n{json.dumps(setup, indent=2, ensure_ascii=False)}\n\n"
        "### তুমি কে ও কীভাবে কথা বলবে\n"
        "- উষ্ণ ও বন্ধুত্বপূর্ণ একজন রিসেপশনিস্টের মতো কথা বলো — শুকনো, যান্ত্রিক বা একঘেয়ে নয়।\n"
        "- প্রতি টার্নে একই বাক্য, একই সূচনা বা একই কাঠামো দিয়ে শুরু করো না; শব্দ ও বাক্যগঠন বদলাও।\n"
        "- ছোট ছোট বাক্য ব্যবহার করো এবং বাক্য শেষে । , ? — চিহ্ন সঠিকভাবে দাও (টি.টি.এস. এগুলো থেকে ছন্দ পায়)।\n"
        "- প্রয়োজনে সংক্ষিপ্ত স্বাভাবিক সাড়া দাও (যেমন: \"জি বলুন\", \"বুঝেছি\", \"আর কিছু লাগবে?\", \"ধন্যবাদ!\"), কিন্তু জোর করে নয়।\n"
        "- শেষ কথোপকথনে পরের প্রতিটি বাক্য আগেরটির পুনরাবৃত্তি যেন না হয়।\n\n"
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
        "- প্রতিটি ব্যবহারকারী বার্তার শেষে `[অর্ডার স্টেট]` লাইন দেওয়া থাকে — বর্তমান অর্ডারের আইটেম, মোট "
        "ও কনফার্মেশন অবস্থা। সামারি বা কনফার্মেশন প্রশ্ন নিজের ভাষায় সেখান থেকে গুছিয়ে বলো।\n"
        "- কনফার্ম করার আগে অনুপস্থিত তথ্য (নাম, ফোন, ঠিকানা) জিজ্ঞেস করো।\n"
        "- কনফার্ম করার আগে আইটেম ও মোট সহ অর্ডারের সামারি দেখাও।\n"
        "- আইটেমের নাম উপরের মেনু থেকে মিলাও — কাস্টমারের কথা বলার সাথে সবচেয়ে কাছের মেনু আইটেম বাছাই করো।\n"
        "- কাস্টমার রেস্টুরেন্ট বা অন্য বিষয়ে প্রশ্ন করলে replyType \"chat\" দিয়ে স্বাভাবিক উত্তর দাও, কোনো অ্যাকশন ছাড়া।\n"
        "- শুধু একটি বৈধ JSON অবজেক্ট রিটার্ন করো। কোনো মার্কডাউন বা ব্যাখ্যা নয়।\n"
        "### JSON স্কিমা (আউটপুট ঠিক এই কাঠামোতে হবে)\n"
        "{\"replyType\": \"chat\", \"reply\": \"...\"}\n"
        "অথবা অ্যাকশনের জন্য: {\"replyType\": \"action\", \"reply\": \"...\", \"action\": {\"intent\": \"add_item\", \"item\": \"item_name\", \"qty\": 1, \"menu_item_id\": \"id_from_menu\", \"price\": 100}}\n"
        "- কথার উত্তর অবশ্যই \"reply\" কী-তে দেবে (\"text\" নয়)।\n"
        "- JSON-এ \"reply\" ফিল্ডটি শুরুতে দেবে — \"replyType\" ও \"reply\" প্রথমে, \"action\" সবশেষে।\n"
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


def _order_state_note(state: dict, outlet: Outlet) -> str:
    items = state.get("items") or []
    if not items:
        return "[অর্ডার স্টেট] বর্তমানে অর্ডারে কোনো আইটেম নেই।"
    total = delivery_order_totals(
        [
            DeliveryOrderLine(
                menu_item_id=i.get("menu_item_id") or "", name=i.get("name") or "",
                qty=int(i.get("qty", 1)), price=float(i.get("price") or 0),
            )
            for i in items
        ],
        delivery_charge=float(outlet.delivery_charge or 0),
    )["total"]
    parts = ", ".join(f"{i.get('name')} x{i.get('qty')}" for i in items)
    confirm = "কনফার্ম করা হয়নি" if not state.get("awaitingConfirmation") else "কনফার্মেশনের অপেক্ষায় আছে"
    return f"[অর্ডার স্টেট] আইটেম: {parts}। মোট (ভ্যাট ও ডেলিভারি চার্জসহ): ৳{total}। এখনও {confirm}।"


def _append_event_reply(reply: str, event: dict | None) -> str:
    if not event:
        return reply
    etype = event.get("type", "")
    if etype == "order_created":
        order_no = str(event.get("orderNumber", ""))
        if (order_no and order_no in reply) or ("সম্পন্ন" in reply and "মোট" in reply):
            return reply
        return reply + f" আপনার অর্ডার #{order_no} সম্পন্ন হয়েছে। মোট: ৳{event.get('totalAmount', 0)}।"
    if etype == "needs_confirmation":
        if "কনফার্ম" in reply or "নিশ্চিত" in reply:
            return reply
        items_str = ", ".join(f"{i['name']} x{i['qty']}" for i in event.get("items", []))
        return reply + f" আপনার অর্ডার: {items_str}। মোট: ৳{event.get('total', 0)}। কনফার্ম করবেন?"
    if etype == "needs_info":
        missing = [_MISSING_KEY_LABELS.get(k, k) for k in event.get("missing", [])]
        if any(label in reply for label in missing):
            return reply
        return reply + f" আপনার {' ও '.join(missing)} জানান।"
    if etype == "order_cancelled":
        if "বাতিল" in reply:
            return reply
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
        self._stt_mode = "realtime" if settings.SARVAM_STT_USE_REALTIME else "legacy"
        self._use_realtime_stt = bool(settings.SARVAM_STT_USE_REALTIME)
        self._last_utterance_idx: int | None = None
        # TTS WebSocket state
        self._tts_ws = None
        self._tts_ws_failed = False
        self._tts_inflight = 0
        self._tts_turn_done = False
        self._tts_done_sent = False
        self._tts_scanner = _ReplyScanner()
        self._tts_queue: asyncio.Queue = asyncio.Queue()
        self._turn_start = 0.0
        # Per-turn timing stamps (monotonic seconds) for latency diagnostics.
        self._turn_idx = 0
        self._stt_speech_end_at: float | None = None
        self._stt_final_at: float | None = None
        self._llm_started_at: float | None = None
        self._llm_first_token_at: float | None = None
        self._llm_done_at: float | None = None
        self._tts_connect_secs: float | None = None
        self._tts_started_at: float | None = None
        self._tts_first_audio_at: float | None = None
        self._tts_last_audio_at: float | None = None
        self._tts_done_at: float | None = None

    def _reset_turn_timings(self):
        # The vad.speech_end stamp belongs to the utterance whose final is
        # about to be processed — keep it across the reset so STT latency
        # (speech_end → final) is measurable.
        prev_speech_end = self._stt_speech_end_at
        self._turn_idx += 1
        self._turn_start = time.monotonic()
        self._stt_speech_end_at = prev_speech_end
        self._stt_final_at = None
        self._llm_started_at = None
        self._llm_first_token_at = None
        self._llm_done_at = None
        self._tts_connect_secs = None
        self._tts_started_at = None
        self._tts_first_audio_at = None
        self._tts_last_audio_at = None
        self._tts_done_at = None

    def _turn_timing_summary(self) -> str:
        return _format_turn_timing({
            "turn_idx": self._turn_idx,
            "stt_speech_end_at": self._stt_speech_end_at,
            "stt_final_at": self._stt_final_at,
            "llm_started_at": self._llm_started_at,
            "llm_first_token_at": self._llm_first_token_at,
            "llm_done_at": self._llm_done_at,
            "tts_connect_secs": self._tts_connect_secs,
            "tts_started_at": self._tts_started_at,
            "tts_first_audio_at": self._tts_first_audio_at,
            "tts_done_at": self._tts_done_at,
            "turn_started_at": self._turn_start,
        })

    async def run(self):
        setup = _build_restaurant_setup(self.outlet, self.menu_items)
        sp = _system_prompt(setup)
        self.history.append({"role": "system", "content": sp})
        logger.info("[sarvam:session] Starting with %d menu items, %d lookup entries, stt_mode=%s",
                    len(self.menu_items), len(self._menu_by_name), self._stt_mode)
        try:
            async with asyncio.TaskGroup() as tg:
                tg.create_task(self._connect_and_read_stt())
                tg.create_task(self._relay_audio())
                tg.create_task(self._stt_keepalive())
                tg.create_task(self._keepalive())
                if settings.SARVAM_TTS_USE_WS:
                    tg.create_task(self._tts_reader())
                    tg.create_task(self._tts_feed_loop())
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
                if self._use_realtime_stt:
                    try:
                        await self.stt_ws.send(json.dumps({"event": "ping"}))
                    except Exception:
                        pass
                else:
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
        if self._use_realtime_stt:
            params = {
                "language_code": settings.SARVAM_STT_LANGUAGE,
                "model": "saaras:v3-realtime",
                "stream_type": settings.SARVAM_STT_STREAM_TYPE,
                "mode": "transcribe",
                "encoding": "linear16",
                "sample_rate": str(STT_SAMPLE_RATE),
                "endpointing": settings.SARVAM_STT_ENDPOINTING,
                "threshold": str(settings.SARVAM_STT_THRESHOLD),
                "silence_duration_ms": str(settings.SARVAM_STT_SILENCE_MS),
                "prompt": self._stt_prompt(),
            }
            url = f"{STT_REALTIME_WS_URL}?{urllib.parse.urlencode(params)}"
            self._stt_mode = "realtime"
            logger.info("[sarvam:stt] Connecting to realtime %s", url)
        else:
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
            self._stt_mode = "legacy"
            logger.info("[sarvam:stt] Connecting to %s", url)
        self.stt_ws = await websockets.connect(
            url,
            additional_headers={"api-subscription-key": settings.SARVAM_API_KEY},
        )

    def _stt_prompt(self) -> str:
        names = []
        for item in self.menu_items:
            n = (item.name_bn or item.name_en or item.name or "").strip()
            if n and n not in names:
                names.append(n)
        joined = ", ".join(names[:25])
        menu_part = f"মেনু: {joined}। " if joined else ""
        return f"{menu_part}কাস্টমার রেস্টুরেন্টে ফোন করে অর্ডার দিচ্ছে।"

    async def _handle_stt_message(self, data: dict):
        if self._stt_mode == "realtime":
            await self._handle_realtime_stt_message(data)
            return
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
                self._stt_speech_end_at = time.monotonic()
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

    async def _handle_realtime_stt_message(self, data: dict):
        event = data.get("event")
        if event == "transcript.partial":
            text = (data.get("text") or "").strip()
            if text:
                await self._send_browser({"type": "partial", "text": text})
        elif event == "transcript.final":
            text = (data.get("text") or "").strip()
            if text:
                await self._on_realtime_final(text, data.get("utterance_idx"))
        elif event == "vad.speech_start":
            logger.debug("[sarvam:stt] VAD speech start")
        elif event == "vad.speech_end":
            self._stt_speech_end_at = time.monotonic()
            logger.debug("[sarvam:stt] VAD speech end")
        elif event == "session.end":
            logger.info("[sarvam:stt] Session end: %s", data)
            await self._fallback_from_realtime("session ended")
        elif event == "pong":
            pass
        elif event == "error":
            code = data.get("code") or ""
            message = data.get("message") or str(data)
            is_fatal = bool(data.get("is_fatal"))
            logger.error("[sarvam:stt] Realtime error: code=%s fatal=%s %s", code, is_fatal, message)
            if is_fatal or code in ("invalid_config",):
                await self._send_browser({"type": "error", "text": f"STT: {message}"})
            if is_fatal:
                await self._fallback_from_realtime(message)
        else:
            logger.debug("[sarvam:stt] Unhandled realtime event=%s", event)

    async def _fallback_from_realtime(self, reason: str):
        if not self._use_realtime_stt:
            return
        logger.warning("[sarvam:stt] Falling back to legacy STT: %s", reason)
        self._use_realtime_stt = False
        self._stt_mode = "legacy"
        if self.stt_ws:
            try:
                await self.stt_ws.close()
            except Exception:
                pass
            self.stt_ws = None
        try:
            await self._connect_stt()
        except Exception as e:
            logger.error("[sarvam:stt] Legacy fallback connect failed: %s", e)
            await self._send_browser({"type": "error", "text": f"STT: {e}"})

    async def _on_realtime_final(self, text: str, utterance_idx: int | None):
        if utterance_idx is not None and utterance_idx == self._last_utterance_idx:
            return
        self._last_utterance_idx = utterance_idx
        self._transcripts += 1
        logger.info("[sarvam:stt] Final transcript (idx=%s): %s", utterance_idx, text[:120])
        await self._send_browser({"type": "user_text", "text": text})
        if self._processing:
            logger.info("[sarvam:stt] Dropping overlap while previous turn is processing")
            return
        self._processing = True
        try:
            await self._handle_committed(text)
        finally:
            self._processing = False

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
            if self._use_realtime_stt:
                try:
                    if self.stt_ws:
                        await self.stt_ws.send(json.dumps({"event": "ping"}))
                except Exception:
                    pass
            else:
                await self._send_silence()

    async def _relay_audio(self):
        logger.info("[sarvam:relay] Starting audio relay (mode=%s)", self._stt_mode)
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
                        if self._use_realtime_stt:
                            payload = json.dumps({"event": "audio_input", "audio": base64.b64encode(pcm).decode()})
                        else:
                            wav = _pcm16_to_wav(pcm)
                            payload = json.dumps({
                                "audio": {"data": base64.b64encode(wav).decode(), "encoding": "audio/wav", "sample_rate": STT_SAMPLE_RATE},
                            })
                        await self.stt_ws.send(payload)
                        self._stt_last_audio_sent_at = time.monotonic()
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
        self._reset_turn_timings()
        self._stt_final_at = time.monotonic()
        state_note = _order_state_note(self._order_state, self.outlet)
        self.history.append({"role": "user", "content": f"{text}\n\n{state_note}"})
        self._tts_scanner = _ReplyScanner()
        self._tts_inflight = 0
        self._tts_turn_done = False
        self._tts_done_sent = False
        reply_text = await self._call_llm()
        if reply_text:
            self.history.append({"role": "assistant", "content": reply_text})
            logger.info("[sarvam:tts] Response (%d chars): %s", len(reply_text), reply_text[:100])
            if settings.SARVAM_TTS_USE_WS and not self._tts_ws_failed:
                emitted = min(self._tts_scanner.emitted_chars, len(reply_text))
                remainder = reply_text[emitted:] if emitted < len(reply_text) else ""
                await self._tts_finish_turn(remainder)
            else:
                emitted = min(self._tts_scanner.emitted_chars, len(reply_text))
                await self._stream_tts(reply_text[emitted:] or reply_text)
        asyncio.create_task(self._log_turn_timing())

    async def _log_turn_timing(self):
        """Log the per-turn breakdown once TTS has finished (or after a cap).

        Runs as a background task so TTS_* metrics capture the full pipeline
        instead of the pre-TTS state. Bails out early if the next turn started.
        """
        turn_idx = self._turn_idx
        deadline = time.monotonic() + 10.0
        while self._tts_done_at is None and time.monotonic() < deadline and not self._done:
            if self._turn_idx != turn_idx:
                return
            await asyncio.sleep(0.05)
        logger.info(self._turn_timing_summary())

    async def _on_llm_delta(self, delta: str):
        if not settings.SARVAM_TTS_USE_WS or self._tts_ws_failed:
            return
        for sentence in self._tts_scanner.feed(delta):
            if self._done:
                return
            if self._tts_inflight == 0 and self._tts_queue.empty() and sentence:
                logger.info("[sarvam:tts] First sentence fed to TTS WS (%.2fs)", time.monotonic() - self._turn_start)
            await self._tts_queue.put(sentence)

    async def _tts_feed_loop(self):
        while not self._done:
            sentence = await self._tts_queue.get()
            if self._done or self._tts_ws_failed:
                continue
            if self._tts_ws is None:
                self._tts_ws = _TtsWsClient()
            if await self._tts_ws.send_text(sentence):
                if self._tts_started_at is None:
                    self._tts_started_at = time.monotonic()
                if self._tts_connect_secs is None and self._tts_ws.connect_seconds is not None:
                    self._tts_connect_secs = self._tts_ws.connect_seconds
                self._tts_inflight += 1
            else:
                self._tts_ws_failed = True
                logger.error("[sarvam:tts-ws] Feed failed, falling back to REST TTS for next turns; partial timings: %s", self._turn_timing_summary())

    async def _tts_finish_turn(self, remainder: str):
        if not settings.SARVAM_TTS_USE_WS or self._done:
            return
        if self._tts_ws_failed:
            if not self._tts_done_sent:
                await self._send_tts_done()
            return
        if remainder and remainder.strip():
            await self._tts_queue.put(remainder.strip())
        self._tts_turn_done = True
        if self._tts_queue.empty() and self._tts_inflight == 0 and not self._tts_done_sent:
            await self._send_tts_done()
        else:
            asyncio.create_task(self._tts_done_guard())

    async def _tts_done_guard(self):
        deadline = time.monotonic() + 8.0
        while time.monotonic() < deadline and not self._done:
            if self._tts_queue.empty() and self._tts_inflight == 0:
                break
            await asyncio.sleep(0.25)
        if not self._tts_done_sent:
            await self._send_tts_done()

    async def _tts_reader(self):
        while not self._done:
            tts = self._tts_ws
            if tts is None or tts.ws is None:
                await asyncio.sleep(0.2)
                continue
            try:
                raw = await asyncio.wait_for(tts.ws.recv(), timeout=30)
            except asyncio.TimeoutError:
                try:
                    await tts.ws.send(json.dumps({"type": "ping"}))
                except Exception:
                    tts.ws = None
                continue
            except Exception as e:
                logger.warning("[sarvam:tts-ws] Read closed: %s", e)
                tts.ws = None
                continue
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                continue
            mtype = msg.get("type")
            if mtype == "audio":
                audio = ((msg.get("data") or {}).get("audio") or "")
                if audio:
                    now = time.monotonic()
                    if self._tts_first_audio_at is None:
                        self._tts_first_audio_at = now
                        if self._tts_started_at is not None:
                            logger.info("[sarvam:tts-ws] First audio after %.2fs", now - self._tts_started_at)
                    self._tts_last_audio_at = now
                    await self._send_browser({"type": "audio", "data": audio})
            elif mtype == "event":
                if (msg.get("data") or {}).get("event_type") == "final":
                    if self._tts_inflight > 0:
                        self._tts_inflight -= 1
                    if self._tts_turn_done and self._tts_queue.empty() and self._tts_inflight == 0 and not self._tts_done_sent:
                        await self._send_tts_done()
            elif mtype == "error":
                inner = msg.get("data") or {}
                logger.error("[sarvam:tts-ws] API error: %s", inner.get("message") or inner)
                self._tts_ws_failed = True

    async def _call_llm(self) -> str:
        api_key = settings.SARVAM_API_KEY.strip()
        if not api_key:
            logger.error("[sarvam:llm] Sarvam API key not configured")
            await self._send_browser({"type": "error", "text": "LLM not configured."})
            return ""
        messages = self.history[-20:]
        self._llm_started_at = time.monotonic()
        logger.info("[sarvam:llm] Calling Sarvam model=%s with %d messages", settings.SARVAM_LLM_MODEL, len(messages))
        try:
            content = await asyncio.wait_for(
                self._complete_llm(messages, on_delta=self._on_llm_delta),
                timeout=LLM_TIMEOUT,
            )
        except asyncio.TimeoutError:
            logger.error("[sarvam:llm] LLM call timed out; partial timings: %s", self._turn_timing_summary())
            await self._send_browser({"type": "error", "text": "Sorry, the assistant took too long."})
            return ""
        except Exception as e:
            logger.error("[sarvam:llm] LLM call failed: %s; partial timings: %s", e, self._turn_timing_summary(), exc_info=True)
            await self._send_browser({"type": "error", "text": "Sorry, I couldn't reach the assistant."})
            return ""
        logger.info("[sarvam:llm] Response received (content_len=%d, %.2fs)",
                    len(content), time.monotonic() - self._turn_start)
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

    async def _complete_llm(self, messages: list[dict], on_delta=None) -> str:
        import httpx
        url = "https://api.sarvam.ai/v1/chat/completions"
        headers = {
            "api-subscription-key": settings.SARVAM_API_KEY.strip(),
            "Authorization": f"Bearer {settings.SARVAM_API_KEY.strip()}",
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
                            if self._llm_first_token_at is None:
                                self._llm_first_token_at = time.monotonic()
                                logger.info("[sarvam:llm] First token after %.2fs", self._llm_first_token_at - self._llm_started_at)
                            content += delta["content"]
                            if on_delta:
                                await on_delta(delta["content"])
                    except (KeyError, IndexError, TypeError):
                        pass
        self._llm_done_at = time.monotonic()
        return content

    async def _stream_tts(self, text: str):
        if not text or not text.strip():
            return
        from sarvamai import SarvamAI
        logger.info("[sarvam:tts] Streaming via Sarvam AI (model=%s speaker=%s pace=%s temperature=%s)",
                    settings.SARVAM_TTS_MODEL, settings.SARVAM_TTS_SPEAKER,
                    settings.SARVAM_TTS_PACE, settings.SARVAM_TTS_TEMPERATURE)
        if self._tts_started_at is None:
            self._tts_started_at = time.monotonic()
        try:
            client = SarvamAI(api_subscription_key=settings.SARVAM_API_KEY)
            audio_count = 0
            try:
                chunks = client.text_to_speech.convert_stream(
                    model=settings.SARVAM_TTS_MODEL,
                    text=text,
                    target_language_code=settings.SARVAM_TTS_LANGUAGE,
                    speaker=settings.SARVAM_TTS_SPEAKER,
                    output_audio_codec="mp3",
                    pace=settings.SARVAM_TTS_PACE,
                    temperature=settings.SARVAM_TTS_TEMPERATURE,
                    enable_preprocessing=True,
                )
            except TypeError:
                logger.warning("[sarvam:tts] SDK too old for prosody params, falling back to defaults")
                chunks = client.text_to_speech.convert_stream(
                    model=settings.SARVAM_TTS_MODEL,
                    text=text,
                    target_language_code=settings.SARVAM_TTS_LANGUAGE,
                    speaker=settings.SARVAM_TTS_SPEAKER,
                    output_audio_codec="mp3",
                )
            for chunk in chunks:
                if self._done:
                    break
                audio_count += 1
                now = time.monotonic()
                if self._tts_first_audio_at is None:
                    self._tts_first_audio_at = now
                self._tts_last_audio_at = now
                await self._send_browser({"type": "audio", "data": base64.b64encode(chunk).decode()})
            logger.info("[sarvam:tts] Sarvam AI stream complete (%d chunks)", audio_count)
            await self._send_tts_done()
        except Exception as e:
            logger.error("[sarvam:tts] Stream error: %s", e, exc_info=True)
            await self._send_browser({"type": "error", "text": f"TTS error: {e}"})

    async def _send_tts_done(self):
        """Send tts_done to the browser exactly once, stamping the moment TTS finished."""
        if self._tts_done_sent:
            return
        self._tts_done_sent = True
        self._tts_done_at = time.monotonic()
        await self._send_browser({"type": "tts_done"})

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
        if self._tts_ws:
            await self._tts_ws.close()
            self._tts_ws = None
        if self.stt_ws:
            try:
                await self.stt_ws.close()
            except Exception:
                pass
            self.stt_ws = None
        logger.info("[sarvam:session] Session fully closed")
