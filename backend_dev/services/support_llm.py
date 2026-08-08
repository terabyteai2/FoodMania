"""In-app support assistant (Volt Assistant).

Independent LLM route from the Facebook chatbot: ``SUPPORT_CHAT_LLM_*``
settings default to DeepSeek (``DEEPSEEK_API_KEY`` +
``CHATBOT_DEEPSEEK_MODEL`` against https://api.deepseek.com/v1).

Triggers on every client support-chat message and replies as the platform
assistant. The system prompt is built from pluggable sections so future
modules (order analysis, suggestions) can append their own context without
reworking the calling code.

Live-data tools (see services/support_llm_tools.py) use API-native function
calling with the conventional agent loop (per the provider's function-calling
guide): the request carries ``tools`` JSON schemas derived from the TOOLS
registry, the model replies with ``message.tool_calls`` when it needs data,
and the pipeline executes every call and feeds each result back as a
``role: "tool"`` message. The full assistant message — including
``reasoning_content``, which the DeepSeek thinking mode requires to be
replayed after tool calls — is appended between rounds. The loop repeats
(max SUPPORT_LLM_MAX_TOOL_ITERATIONS) until the model stops calling tools;
its final ``content`` is the answer. Tool activity is invisible to the
client — only the final reply is persisted.
"""

import asyncio
import json
import logging
import re
import time
from datetime import datetime, timezone

import httpx
from sqlalchemy import select

from config import settings
from services.support_llm_tools import GUIDE_VOCABULARY, execute_tool, tools_schema

logger = logging.getLogger(__name__)

SUPPORT_LLM_TIMEOUT_SECONDS = 45.0
SUPPORT_LLM_MAX_HISTORY = 2
SUPPORT_LLM_COOLDOWN_SECONDS = 3.0
SUPPORT_LLM_MAX_ACTIONS = 3
SUPPORT_LLM_MAX_STEPS = 4
SUPPORT_LLM_MAX_TOOL_ITERATIONS = 4
SUPPORT_LLM_MAX_REPLY_CHARS = 1200
SUPPORT_LLM_MAX_ATTEMPTS = 3
SUPPORT_LLM_RETRY_BACKOFF_SECONDS = 1.0
ASSISTANT_NAME = "Volt Assistant"

# Reply-outcome statuses recorded on the triggering client message row.
OUTCOME_REPLIED = "replied"
OUTCOME_SKIPPED = "skipped"
OUTCOME_FAILED = "failed"

# Machine-readable reasons for skipped / failed replies.
REASON_COOLDOWN = "cooldown"
REASON_IN_FLIGHT = "in_flight"
REASON_LAST_NOT_CLIENT = "last_not_client"
REASON_NO_CONFIG = "no_config"
REASON_LLM_ERROR = "llm_error"
REASON_TIMEOUT = "timeout"
REASON_HTTP_ERROR = "http_error"
REASON_INVALID_JSON = "invalid_json"
REASON_EMPTY_REPLY = "empty_reply"
REASON_PERSIST_ERROR = "persist_error"

# --- Deeplink vocabulary the app can execute (see admin_app_dev app.dart) ---

_TAB_TARGETS = {
    "analytics",
    "orders",
    "stock",
    "menu",
    "reports",
    "more",
    "tables",
    "live",
    "salesSummary",
}
_SCREEN_TARGETS = {"staff", "audit", "stock_in", "stock_count"}
_MODAL_TARGETS = {"menu_discounts", "menu_delivery_charge"}
_STATIC_SPOTS = {
    "analytics.stats",
    "menu.scanCta",
    "orders.newOrderFab",
    "tables.grid",
    "header.menu",
    "header.bell",
    "header.avatar",
}


def _guide_targets(kind: str) -> set[str]:
    """Target names from the JSON guide vocabulary
    (data/support_guide_deeplinks.json); empty when the file is unavailable."""
    entries = GUIDE_VOCABULARY.get(kind)
    if not isinstance(entries, list):
        return set()
    return {
        str(entry.get("name") or "").strip()
        for entry in entries
        if isinstance(entry, dict) and entry.get("name")
    }


# When the JSON vocabulary file is present it is the single source of truth
# for what the app can execute; otherwise fall back to the constants above.
_file_tabs = _guide_targets("tabs")
_file_screens = _guide_targets("screens")
_file_modals = _guide_targets("modals")
_file_spots = _guide_targets("spots")
if _file_tabs:
    _TAB_TARGETS = _file_tabs
if _file_screens:
    _SCREEN_TARGETS = _file_screens
if _file_modals:
    _MODAL_TARGETS = _file_modals
if _file_spots:
    _STATIC_SPOTS = _file_spots


def _valid_target(target: str) -> bool:
    target = target.strip()
    if target.startswith("tab:"):
        return target[len("tab:"):] in _TAB_TARGETS
    if target.startswith("screen:"):
        return target[len("screen:"):] in _SCREEN_TARGETS
    if target.startswith("modal:"):
        return target[len("modal:"):] in _MODAL_TARGETS
    if target.startswith("highlight:"):
        spot = target[len("highlight:"):]
        return spot in _STATIC_SPOTS or spot.startswith("nav.")
    return False


def _valid_spot(spot: str) -> bool:
    spot = spot.strip()
    return spot in _STATIC_SPOTS or spot.startswith("nav.")


# --- Pluggable prompt sections: future modules append here ---


def _identity_section() -> str:
    return (
        "You are Volt Assistant, the built-in support assistant inside the "
        "QuickBytes restaurant management app. You help the user run their "
        "restaurant with the app and answer product questions. You are not a "
        "food-delivery order chatbot and you never take orders from customers."
    )


def _behavior_section() -> str:
    return (
        "### HOW TO RESPOND\n"
        "1. CONVERSATIONAL FIRST: most replies are normal chat — answer the "
        "question, be warm and brief, and match the user's language (Bangla or "
        "English). Do NOT add steps/actions to every reply.\n"
        "2. GUIDE ONLY WHEN USEFUL: if the user asks how to do something in the "
        "app (\"how do I…\", \"where is…\", \"can the app…\"), your FIRST reply "
        "must be a tool request for get_guide_deeplinks — the deeplink "
        "vocabulary is NOT embedded in this prompt, so without that tool you "
        "cannot build valid steps. After the tool_result, reply with a short "
        "explanation PLUS ordered steps and/or action buttons. Guide replies "
        "always include steps or actions.\n"
        "3. Each step auto-navigates: its \"target\" deeplink switches tabs, "
        "opens a screen or a modal, or highlights an element before the user "
        "reads it. The user advances by tapping the highlighted element "
        "itself; when a step has no \"spot\", a Continue button appears "
        "instead. The app never advances by itself.\n"
        "4. Never invent deeplinks, spot names, or outlet facts — only the "
        "vocabulary get_guide_deeplinks returns and the data the tools "
        "return. If the user needs something the app cannot do, say so "
        "plainly and suggest the closest alternative.\n"
        "5. Be honest about limits. If you don't know, say you'll escalate to "
        "the QuickBytes team."
    )


def _contract_section() -> str:
    return (
        "### TOOLS\n"
        "Read-only tools are attached to this request (get_guide_deeplinks, "
        "get_outlet_info, get_outlet_overview, get_recent_orders, get_order, "
        "get_menu_items, get_stock, get_daily_sales). Use a data tool "
        "whenever the answer needs this outlet's identity or live data — "
        "never invent facts. Each tool's result arrives as a tool message; "
        "keep calling tools until you have what you need. Guide tip: before "
        "emitting steps or actions, always call get_guide_deeplinks — its "
        "results are the only valid targets.\n"
        "### ANSWER FORMAT\n"
        "End the exchange by writing ONLY a JSON object as your final "
        "content: {\"reply\": string, \"actions\": [{\"label\": string, "
        "\"target\": string}] optional max 3, \"steps\": [{\"title\": "
        "string, \"body\": string, \"target\": string optional, \"spot\": "
        "string optional}] optional max 4}. No markdown fences, no text "
        "before or after.\n"
        '- "reply" is REQUIRED: always a non-empty plain conversational '
        "message in the user's language — no markdown.\n"
        '- "actions" are one-tap shortcut buttons.\n'
        '- "steps" are an ordered guided walkthrough (max 4). "target" '
        'auto-navigates ("tab:<name>", "screen:<name>", "modal:<name>", '
        '"highlight:<spot>"); "spot" lights up the exact element the user '
        "must tap. Give every step a \"spot\" when an element exists to "
        'highlight; a step with both "target" and "spot" navigates itself '
        'and then points at the element. Target-only steps (no "spot") are '
        "only for opening a destination the next step will highlight — they "
        "show a Continue button.\n"
        "- Only use targets and spots returned by get_guide_deeplinks — "
        "never invent deeplinks or spot names. Most replies need no "
        "actions/steps at all."
    )


def build_system_prompt() -> str:
    """Assembles the system prompt from pluggable sections.

    Future modules (order analysis, suggestions) add their own section here.
    Knowledge about the app UI and the outlet is NOT embedded — it is fetched
    on demand via get_guide_deeplinks / get_outlet_info to keep the prompt
    small (the provider's function-calling guide recommends a compact system
    prompt; a large contract section measurably degrades tool-call
    reliability).
    """
    sections = [
        _identity_section(),
        _behavior_section(),
        _contract_section(),
    ]
    return "\n\n".join(sections)


# --- Reply sanitization (never trust the model's targets) ---


def _clean_step(raw: object) -> dict | None:
    if not isinstance(raw, dict):
        return None
    title = str(raw.get("title") or "").strip()
    body = str(raw.get("body") or "").strip()
    if not title and not body:
        return None
    step: dict = {"title": title, "body": body}
    target = str(raw.get("target") or "").strip()
    if target and _valid_target(target):
        step["target"] = target
    spot = str(raw.get("spot") or "").strip()
    if spot and _valid_spot(spot):
        step["spot"] = spot
    return step


def _clean_action(raw: object) -> dict | None:
    if not isinstance(raw, dict):
        return None
    label = str(raw.get("label") or "").strip()
    target = str(raw.get("target") or "").strip()
    if not label or not target or not _valid_target(target):
        return None
    return {"label": label, "target": target}


def sanitize_guide(parsed: dict) -> dict:
    """Validates actions/steps against the deeplink vocabulary and caps them."""
    reply = str(parsed.get("reply") or "").strip()
    result: dict = {"reply": reply}
    raw_actions = parsed.get("actions")
    if isinstance(raw_actions, list):
        actions = [a for a in [_clean_action(x) for x in raw_actions] if a]
        if actions:
            result["actions"] = actions[:SUPPORT_LLM_MAX_ACTIONS]
    raw_steps = parsed.get("steps")
    if isinstance(raw_steps, list):
        steps = [s for s in [_clean_step(x) for x in raw_steps] if s]
        if steps:
            result["steps"] = steps[:SUPPORT_LLM_MAX_STEPS]
    return result


# --- LLM call ---


def _llm_config() -> tuple[str, str, str] | None:
    base_url = settings.SUPPORT_CHAT_LLM_BASE_URL.strip() or "https://api.deepseek.com/v1"
    api_key = (
        settings.SUPPORT_CHAT_LLM_API_KEY.strip() or settings.DEEPSEEK_API_KEY.strip()
    )
    model = (
        settings.SUPPORT_CHAT_LLM_MODEL.strip()
        or settings.CHATBOT_DEEPSEEK_MODEL.strip()
    )
    if not api_key or not model:
        return None
    return base_url.rstrip("/"), api_key, model


def _extract_json_block(text: str) -> str:
    """First balanced JSON object in the text, or '' when none is found."""
    start = text.find("{")
    while start != -1:
        depth = 0
        in_string = False
        escaped = False
        for index in range(start, len(text)):
            char = text[index]
            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    in_string = False
                continue
            if char == '"':
                in_string = True
            elif char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    return text[start : index + 1]
        start = text.find("{", start + 1)
    return ""


def _parse_json_object(content: str) -> dict:
    clean = content.strip()
    if clean.startswith("```"):
        clean = clean.strip("`").strip()
        if clean.lower().startswith("json"):
            clean = clean[4:].strip()
    parsed = json.loads(clean)
    if not isinstance(parsed, dict):
        raise ValueError("LLM response must be a JSON object.")
    return parsed


LLM_MAX_TOKENS = 4000


class LlmResponseError(RuntimeError):
    """Raised when the LLM returned a 200 payload we could not use.

    Carries ``detail`` — the raw response snapshot (finish_reason, usage,
    body snippet) merged with the request fingerprint by auto_reply — and an
    optional machine-readable ``reason`` (used by the retry wrapper so the
    last attempt's classification survives re-raising).
    """

    def __init__(self, message: str, detail: dict, reason: str | None = None):
        super().__init__(message)
        self.detail = detail
        self.reason = reason


def _response_snapshot(response: httpx.Response, payload) -> dict:
    """Raw-response diagnostics for a failed LLM call (never raises)."""
    choice: dict = {}
    if isinstance(payload, dict):
        choices = payload.get("choices")
        if isinstance(choices, list) and choices and isinstance(choices[0], dict):
            choice = choices[0]
    message = choice.get("message") if isinstance(choice, dict) else {}
    message = message if isinstance(message, dict) else {}
    try:
        body_snippet = response.text[:600]
    except Exception:
        body_snippet = ""
    return {
        "httpStatus": response.status_code,
        "contentType": response.headers.get("content-type"),
        "traceId": response.headers.get("x-ds-trace-id"),
        "model": payload.get("model") if isinstance(payload, dict) else None,
        "choicesCount": (
            len(payload["choices"])
            if isinstance(payload, dict) and isinstance(payload.get("choices"), list)
            else 0
        ),
        "finishReason": choice.get("finish_reason"),
        "messageKeys": sorted(message.keys()),
        "contentLength": len(str(message.get("content") or "")),
        "content": (str(message.get("content") or ""))[:200],
        "usage": payload.get("usage") if isinstance(payload, dict) else None,
        "bodySnippet": body_snippet,
    }


def _request_fingerprint(rows, system_prompt: str, model: str, tool_calls: int = 0) -> dict:
    """What we sent, so failures are explainable from the DB alone."""
    last = rows[-1] if rows else None
    history_chars = sum(len(row.text or "") for row in rows)
    return {
        "model": model,
        "historySize": len(rows),
        "lastMessage": (last.text or "")[:80] if last else "",
        "lastMessageLength": len(last.text or "") if last else 0,
        "systemPromptChars": len(system_prompt or ""),
        "totalInputChars": history_chars + len(system_prompt or ""),
        "maxTokens": LLM_MAX_TOKENS,
        "nativeTools": len(tools_schema()),
        "toolCalls": tool_calls,
    }


def _parse_json_arguments(raw: str) -> dict | None:
    """Resilient JSON parse for tool arguments (per agent-loop convention).

    Falls back from direct parse to stripping markdown fences, then to
    removing trailing commas. Returns None only when nothing parses — the
    caller must surface that as an error tool result, never an empty dict.
    """
    text = (raw or "").strip()
    if not text:
        return None
    candidates = [text]
    fenced = re.search(r"```(?:json)?\s*(.*?)\s*```", text, re.DOTALL)
    if fenced:
        candidates.append(fenced.group(1).strip())
    for candidate in candidates:
        try:
            parsed = json.loads(candidate)
            if isinstance(parsed, dict):
                return parsed
        except ValueError:
            pass
    cleaned = re.sub(r",\s*([}\]])", r"\1", text)
    if cleaned != text:
        try:
            parsed = json.loads(cleaned)
            if isinstance(parsed, dict):
                return parsed
        except ValueError:
            pass
    return None


async def _call_llm(
    system_prompt: str,
    history: list[dict],
    outlet_id: str | None = None,
) -> tuple[dict, dict | None]:
    """One chat-completion call with native function-calling tools.

    Follows the provider's canonical pattern: ``tools`` only, no
    ``tool_choice`` (the v4 thinking mode rejects non-auto choices and the
    model decides when it has enough data). Returns
    ``(assistant_message, parsed_final)``: ``assistant_message`` is the raw
    response message (carries ``tool_calls`` when the model asked for
    tools), ``parsed_final`` is the ``{reply, actions, steps}`` dict when
    the model answered directly — plain-text finals are normalized into the
    contract, so a prose answer still counts as a reply (None on tool
    rounds).
    """
    config = _llm_config()
    if config is None:
        raise RuntimeError("Support chat LLM is not configured.")
    base_url, api_key, model = config
    messages = [{"role": "system", "content": system_prompt}] + history
    logger.info(
        "[support_llm] llm_request outlet=%s model=%s messages=%s",
        outlet_id,
        model,
        json.dumps(messages, ensure_ascii=False),
    )
    async with httpx.AsyncClient(timeout=SUPPORT_LLM_TIMEOUT_SECONDS) as client:
        response = await client.post(
            f"{base_url}/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": model,
                "messages": messages,
                "max_tokens": LLM_MAX_TOKENS,
                "tools": tools_schema(),
            },
        )
        logger.info(
            "[support_llm] llm_response outlet=%s status=%s body=%s",
            outlet_id,
            response.status_code,
            response.text,
        )
        response.raise_for_status()
        payload = response.json()
    choice: dict = {}
    if isinstance(payload, dict):
        choices = payload.get("choices")
        if isinstance(choices, list) and choices and isinstance(choices[0], dict):
            choice = choices[0]
    message = choice.get("message")
    if not isinstance(message, dict):
        message = {}
    if isinstance(message.get("tool_calls"), list) and message["tool_calls"]:
        return message, None
    content = message.get("content")
    if not isinstance(content, str) or not content.strip():
        raise LlmResponseError(
            f"Support chat LLM returned an empty response ({model}).",
            _response_snapshot(response, payload),
        )
    try:
        return message, _parse_json_object(content)
    except ValueError:
        pass
    block = _extract_json_block(content)
    if block:
        try:
            parsed = _parse_json_object(block)
            logger.info(
                "[support_llm] final JSON recovered from prose outlet=%s",
                outlet_id,
            )
            return message, parsed
        except ValueError:
            pass
    # Canonical final: the model's plain-text content IS the answer. Wrap it
    # in the reply contract without a retry or a second call.
    logger.info(
        "[support_llm] final prose normalized into reply contract outlet=%s",
        outlet_id,
    )
    return message, {"reply": content.strip()}


# --- Tool protocol (API-native function calling, see support_llm_tools.py) ---


def _tool_result_message(call_id: str, result: dict) -> dict:
    """The tool result is fed back to the model as a ``role: "tool"`` message.
    It is never persisted as a chat message — the client only ever sees the
    final reply."""
    return {
        "role": "tool",
        "tool_call_id": call_id,
        "content": json.dumps(result, ensure_ascii=False),
    }


async def _complete_with_tools(
    system_prompt: str,
    history: list[dict],
    outlet_id: str,
) -> tuple[dict, int, list[str]]:
    """Conventional agent loop over the native function-calling protocol.

    The model may interleave up to [SUPPORT_LLM_MAX_TOOL_ITERATIONS] tool
    requests. Each request's arguments are validated against the whitelist
    in support_llm_tools and the JSON result is appended as a ``role: "tool"``
    message. Every call in a round is executed and answered (matching the
    provider's canonical loop), and the full assistant message — including
    ``reasoning_content``, which thinking mode requires to be replayed — is
    preserved between rounds. The exchange ends when the model stops calling
    tools; its final ``content`` (parsed by _call_llm) is the answer.
    Returns ``(final_dict, tool_calls, used_tools)``.
    """
    messages = list(history)
    tool_calls = 0
    used_tools: list[str] = []
    for _ in range(SUPPORT_LLM_MAX_TOOL_ITERATIONS + 1):
        assistant_msg, parsed = await _call_llm(system_prompt, messages, outlet_id)
        calls = assistant_msg.get("tool_calls") or []
        if not calls:
            return parsed, tool_calls, used_tools
        if tool_calls >= SUPPORT_LLM_MAX_TOOL_ITERATIONS:
            raise LlmResponseError(
                "Support chat LLM exceeded its tool-call budget without a final reply.",
                {"reason": "tool_budget_exceeded", "toolCalls": tool_calls},
            )
        assistant: dict = {
            "role": "assistant",
            "content": assistant_msg.get("content"),
            "tool_calls": calls,
        }
        reasoning = assistant_msg.get("reasoning_content")
        if reasoning:
            assistant["reasoning_content"] = reasoning
        messages.append(assistant)
        for call in calls:
            if not isinstance(call, dict):
                continue
            function = call.get("function") or {}
            name = str(function.get("name") or "").strip()
            tool_calls += 1
            used_tools.append(name)
            arguments = _parse_json_arguments(function.get("arguments") or "")
            if arguments is None:
                result = {"ok": False, "error": "invalid tool arguments JSON"}
            else:
                result = await execute_tool(name, arguments, outlet_id)
            messages.append(
                _tool_result_message(str(call.get("id") or ""), result)
            )
    raise LlmResponseError(
        "Support chat LLM exceeded its tool-call budget without a final reply.",
        {"reason": "tool_budget_exceeded", "toolCalls": tool_calls},
    )


# --- Auto-reply pipeline ---

_in_flight: dict[str, bool] = {}
_last_reply_at: dict[str, float] = {}


def _history_to_messages(rows) -> list[dict]:
    messages: list[dict] = []
    for row in rows:
        role = "user" if row.role == "client" else "assistant"
        messages.append({"role": role, "content": row.text})
    return messages


def _clean_history_rows(rows: list) -> list:
    """Drops trivial and repeated messages and caps the LLM context.

    Pure-punctuation messages ("?", "!") and consecutive repeats only push
    the model off the output contract, and the v4 reasoning tier degrades to
    empty/whitespace final content when the initial history grows beyond a
    couple of turns. The DB keeps every message; only the LLM context is
    trimmed.
    """
    cleaned: list = []
    previous = None
    for row in rows:
        text = (row.text or "").strip()
        if not text or not any(ch.isalnum() for ch in text):
            continue
        key = text.lower()
        if key == previous:
            continue
        previous = key
        cleaned.append(row)
    return cleaned


async def _load_history(outlet_id: str, limit: int = SUPPORT_LLM_MAX_HISTORY) -> list:
    from database import AsyncSessionLocal
    from models import SupportChatMessage

    async with AsyncSessionLocal() as session:
        rows = (
            await session.execute(
                select(SupportChatMessage)
                .where(SupportChatMessage.outlet_id == outlet_id)
                .order_by(SupportChatMessage.created_at.desc())
                .limit(limit * 4)
            )
        ).scalars().all()
    chronological = list(reversed(rows))
    return _clean_history_rows(chronological)[-limit:]


async def _record_outcome(
    message_id: str,
    *,
    status: str,
    reason: str | None = None,
    error: str | None = None,
    detail: dict | None = None,
    latency_ms: int | None = None,
    model: str | None = None,
    attempted: bool = False,
) -> None:
    """Writes the auto-reply outcome onto the triggering client message.

    ``detail`` is the raw-response snapshot + request fingerprint for failed
    calls. Never raises: diagnostics recording must not break the chat
    pipeline.
    """
    from database import AsyncSessionLocal
    from models import SupportChatMessage

    try:
        async with AsyncSessionLocal() as session:
            row = await session.get(SupportChatMessage, message_id)
            if row is None:
                return
            row.reply_status = status
            row.reply_reason = reason
            if error:
                row.reply_error = str(error)[:400]
            if detail is not None:
                row.reply_detail = detail
            row.reply_latency_ms = latency_ms
            row.reply_model = model
            if attempted:
                row.reply_attempted_at = datetime.now(timezone.utc)
            await session.commit()
    except Exception as exc:
        logger.warning(
            "[support_llm] failed to record outcome for message %s: %s",
            message_id,
            exc,
        )


def _classify_llm_error(exc: Exception) -> tuple[str, str]:
    """Maps an LLM-call exception to a (reason, error-text) pair."""
    if isinstance(exc, LlmResponseError):
        if "empty response" in str(exc):
            return REASON_EMPTY_REPLY, str(exc)[:400]
        return REASON_INVALID_JSON, str(exc)[:400]
    if isinstance(exc, httpx.TimeoutException):
        return REASON_TIMEOUT, str(exc)[:400] or "LLM request timed out"
    if isinstance(exc, httpx.HTTPStatusError):
        return REASON_HTTP_ERROR, f"HTTP {exc.response.status_code}"
    if isinstance(exc, ValueError):
        return REASON_INVALID_JSON, str(exc)[:400]
    if isinstance(exc, RuntimeError) and "empty response" in str(exc):
        return REASON_EMPTY_REPLY, str(exc)[:400]
    return REASON_LLM_ERROR, str(exc)[:400] or type(exc).__name__


def llm_config_summary() -> dict:
    """Public config snapshot for diagnostics (no secrets)."""
    config = _llm_config()
    base_url = (
        settings.SUPPORT_CHAT_LLM_BASE_URL.strip() or "https://api.deepseek.com/v1"
    )
    model = (
        settings.SUPPORT_CHAT_LLM_MODEL.strip() or settings.CHATBOT_DEEPSEEK_MODEL.strip()
    )
    if config is None:
        return {
            "configured": False,
            "baseUrl": base_url,
            "model": model,
            "apiKeyConfigured": bool(
                settings.SUPPORT_CHAT_LLM_API_KEY.strip() or settings.DEEPSEEK_API_KEY.strip()
            ),
        }
    base, _, resolved_model = config
    return {
        "configured": True,
        "baseUrl": base,
        "model": resolved_model,
        "apiKeyConfigured": True,
    }


async def diagnostics(outlet_id: str) -> dict:
    """Per-outlet diagnostics: LLM config, in-flight/cooldown state and the
    last messages with their recorded auto-reply outcomes."""
    now = time.monotonic()
    last_reply = _last_reply_at.get(outlet_id, 0.0)
    cooldown_remaining = max(0.0, SUPPORT_LLM_COOLDOWN_SECONDS - (now - last_reply))
    messages = []
    for row in await _load_history(outlet_id, limit=20):
        messages.append(
            {
                "id": row.id,
                "role": row.role,
                "senderName": row.sender_name,
                "text": (row.text or "")[:120],
                "replyStatus": row.reply_status,
                "replyReason": row.reply_reason,
                "replyError": row.reply_error,
                "replyDetail": row.reply_detail,
                "replyLatencyMs": row.reply_latency_ms,
                "replyModel": row.reply_model,
                "replyAttemptedAt": (
                    row.reply_attempted_at.isoformat() if row.reply_attempted_at else None
                ),
                "createdAt": row.created_at.isoformat() if row.created_at else None,
            }
        )
    return {
        "llmConfig": llm_config_summary(),
        "inFlight": bool(_in_flight.get(outlet_id)),
        "cooldownRemainingSeconds": round(cooldown_remaining, 1),
        "guideVocabulary": {
            "loaded": bool(GUIDE_VOCABULARY),
            "tabs": len(GUIDE_VOCABULARY.get("tabs") or []),
            "screens": len(GUIDE_VOCABULARY.get("screens") or []),
            "modals": len(GUIDE_VOCABULARY.get("modals") or []),
            "spots": len(GUIDE_VOCABULARY.get("spots") or []),
        },
        "messages": messages,
    }


async def auto_reply(outlet_id: str) -> None:
    """Generates one assistant reply for the outlet's latest client message.

    Fire-and-forget friendly: every failure is logged, never raised, and the
    outcome (replied / skipped / failed + reason) is recorded on the
    triggering client message so missing replies are diagnosable. A per-outlet
    in-flight guard prevents overlapping replies and a short cooldown stops
    message spam from queuing repeated LLM calls.
    """
    try:
        rows = await _load_history(outlet_id)
        if not rows or rows[-1].role != "client":
            return
        trigger = rows[-1]
        if _in_flight.get(outlet_id):
            logger.info("[support_llm] skipped outlet=%s reason=in_flight", outlet_id)
            await _record_outcome(trigger.id, status=OUTCOME_SKIPPED, reason=REASON_IN_FLIGHT)
            return
        now = time.monotonic()
        if now - _last_reply_at.get(outlet_id, 0.0) < SUPPORT_LLM_COOLDOWN_SECONDS:
            logger.info("[support_llm] skipped outlet=%s reason=cooldown", outlet_id)
            await _record_outcome(trigger.id, status=OUTCOME_SKIPPED, reason=REASON_COOLDOWN)
            return
        _in_flight[outlet_id] = True
        try:
            config = _llm_config()
            if config is None:
                logger.error("[support_llm] failed outlet=%s reason=no_config", outlet_id)
                await _record_outcome(
                    trigger.id,
                    status=OUTCOME_FAILED,
                    reason=REASON_NO_CONFIG,
                    error="Support chat LLM is not configured.",
                    attempted=True,
                )
                return
            base_url, api_key, model = config
            system_prompt = build_system_prompt()
            started = time.monotonic()
            tool_calls = 0
            used_tools: list[str] = []
            try:
                parsed, tool_calls, used_tools = await _complete_with_tools(
                    system_prompt,
                    _history_to_messages(rows),
                    outlet_id,
                )
            except Exception as exc:
                reason, error = _classify_llm_error(exc)
                latency_ms = int((time.monotonic() - started) * 1000)
                detail = getattr(exc, "detail", None)
                if not isinstance(detail, dict):
                    detail = {}
                detail = {
                    **detail,
                    "request": _request_fingerprint(
                        rows, system_prompt, model, tool_calls=tool_calls
                    ),
                }
                logger.error(
                    "[support_llm] failed outlet=%s reason=%s error=%s detail=%s",
                    outlet_id,
                    reason,
                    error,
                    detail,
                )
                await _record_outcome(
                    trigger.id,
                    status=OUTCOME_FAILED,
                    reason=reason,
                    error=error,
                    detail=detail,
                    latency_ms=latency_ms,
                    model=model,
                    attempted=True,
                )
                return
            latency_ms = int((time.monotonic() - started) * 1000)
            sanitized = sanitize_guide(parsed)
            reply = sanitized["reply"][:SUPPORT_LLM_MAX_REPLY_CHARS]
            if not reply:
                logger.warning(
                    "[support_llm] failed outlet=%s reason=empty_reply, skipping",
                    outlet_id,
                )
                await _record_outcome(
                    trigger.id,
                    status=OUTCOME_FAILED,
                    reason=REASON_EMPTY_REPLY,
                    error="LLM returned no usable reply.",
                    latency_ms=latency_ms,
                    model=model,
                    attempted=True,
                )
                return

            from routers.ws import _persist_support_message, _support_message_dict, manager

            try:
                message = await _persist_support_message(
                    outlet_id=outlet_id,
                    role="server",
                    sender_name=ASSISTANT_NAME,
                    text=reply,
                    actions=sanitized.get("actions"),
                    steps=sanitized.get("steps"),
                )
            except Exception as exc:
                logger.error(
                    "[support_llm] failed outlet=%s reason=persist_error: %s",
                    outlet_id,
                    exc,
                    exc_info=True,
                )
                await _record_outcome(
                    trigger.id,
                    status=OUTCOME_FAILED,
                    reason=REASON_PERSIST_ERROR,
                    error=str(exc)[:400],
                    latency_ms=latency_ms,
                    model=model,
                    attempted=True,
                )
                return
            await manager.broadcast(
                outlet_id,
                {"type": "support_msg", "data": _support_message_dict(message)},
            )
            await _record_outcome(
                trigger.id,
                status=OUTCOME_REPLIED,
                latency_ms=latency_ms,
                model=model,
                attempted=True,
                detail={"tools": used_tools, "toolCalls": tool_calls},
            )
            _last_reply_at[outlet_id] = time.monotonic()
            logger.info(
                "[support_llm] Replied to outlet %s (%d chars, %d steps, %d tool calls)",
                outlet_id,
                len(reply),
                len(sanitized.get("steps") or []),
                tool_calls,
            )
        finally:
            _in_flight[outlet_id] = False
    except asyncio.CancelledError:
        raise
    except Exception as exc:  # never let an assistant failure break the app
        logger.error(
            "[support_llm] auto_reply failed for outlet %s: %s",
            outlet_id,
            exc,
            exc_info=True,
        )
