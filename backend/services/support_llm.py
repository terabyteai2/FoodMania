"""In-app support assistant (Volt Assistant).

Independent LLM route from the Facebook chatbot: ``SUPPORT_CHAT_LLM_*``
settings default to DeepSeek (``DEEPSEEK_API_KEY`` +
``CHATBOT_DEEPSEEK_MODEL`` against https://api.deepseek.com/v1).

Triggers on every client support-chat message and replies as the platform
assistant. The system prompt is built from pluggable sections so future
modules (order analysis, suggestions) can append their own context without
reworking the calling code.
"""

import asyncio
import json
import logging
import time

import httpx
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from config import settings

logger = logging.getLogger(__name__)

SUPPORT_LLM_TIMEOUT_SECONDS = 45.0
SUPPORT_LLM_MAX_HISTORY = 20
SUPPORT_LLM_COOLDOWN_SECONDS = 3.0
SUPPORT_LLM_MAX_ACTIONS = 3
SUPPORT_LLM_MAX_STEPS = 4
SUPPORT_LLM_MAX_REPLY_CHARS = 1200
ASSISTANT_NAME = "Volt Assistant"

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


# --- App guide knowledge (mirrors the actual app UI, admin_app_dev) ---

APP_GUIDE = """\
### THE APP YOU GUIDE USERS THROUGH
You are answering a restaurant owner/manager/waiter inside the QuickBytes
restaurant management app (the admin app, one outlet per account). The app is
offline-first and syncs with the cloud.

SIDEBAR TABS (roles see different sets):
- analytics — "Your day at a glance": gross sales, discounts, net sales,
  collection, prep cost, and profit. Tap a headline card to drill into detail.
- orders — live order feed; new orders appear instantly from tables, Facebook
  Messenger, and the restaurant's website. The + button builds a new order
  (dine-in, parcel, or delivery → pick items → send to the kitchen).
- tables — (waiter role) every table; tap a free table to seat guests and take
  their order.
- stock — inventory management: items, suppliers, stock-in, end-of-day stock
  count, and scan-to-stock.
- menu — menu management: add/edit items and categories, apply discounts,
  set the delivery charge. "Scan menu card" imports a whole printed menu by
  photographing it.
- reports — download the performance report for any period: daily sales,
  orders, and per-item totals.
- salesSummary — today's takings summary.
- live — Control Tower.
- more — settings: language, printer settings, staff management, audit log,
  sign out.

HEADER (every screen): the menu button opens the sidebar/drawer; the bell is
the notification center (new orders from Messenger and the website arrive
here); the avatar opens profile/settings.

GUIDE CONVENTIONS
- Order flows through steps: step 1 opens the right destination, later steps
  highlight the exact element.
- A "tab:" target switches the sidebar tab. A "screen:" target opens a full
  screen (staff list, audit log, stock-in, end-of-day stock count). A
  "modal:" target opens the discount / delivery-charge editor. A
  "highlight:" target lights up an element in the current screen.
- Drawer destinations are reachable via "tab:" without opening the drawer —
  the app navigates automatically.
"""

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
        "app (\"how do I…\", \"where is…\", \"can the app…\") or a shortcut would "
        "clearly help, reply with a short explanation PLUS ordered steps and/or "
        "action buttons that MANEUVER the user through the app.\n"
        "3. Each step auto-navigates: its \"target\" deeplink switches tabs, "
        "opens a screen or a modal, or highlights an element before the user "
        "reads it. The user advances with Next; the app moves for them.\n"
        "4. Never invent deeplinks or spot names — only the vocabulary listed "
        "below. If the user needs something the app cannot do, say so plainly "
        "and suggest the closest alternative.\n"
        "5. Be honest about limits. If you don't know, say you'll escalate to "
        "the QuickBytes team."
    )


def _outlet_section(outlet: dict) -> str:
    return (
        "### THIS OUTLET\n"
        f"- Name: {outlet.get('name') or 'unknown'}\n"
        f"- Plan: {outlet.get('plan') or 'trial'}\n"
        f"- Tables: {outlet.get('table_count') or 'unknown'}\n"
        "Use the outlet name when relevant. Do not invent facts about the "
        "outlet's data (sales, orders, inventory) — you cannot see it yet."
    )


def _contract_section() -> str:
    return (
        "### OUTPUT FORMAT\n"
        "Respond with a SINGLE JSON object only:\n"
        '{"reply": string, "actions": [{"label": string, "target": string}] '
        'optional, "steps": [{"title": string, "body": string, '
        '"target": string optional, "spot": string optional}] optional}\n'
        "- \"reply\" is REQUIRED and always a plain conversational message in "
        "the user's language.\n"
        '- "actions" are one-tap shortcut buttons (max 3).\n'
        '- "steps" are an ordered guided walkthrough (max 4). Each step has a '
        'short title and body. "target" auto-navigates before the step '
        '("tab:<name>", "screen:<name>", "modal:<name>", "highlight:<spot>"). '
        '"spot" lights up the exact element ("highlight:<spot>").\n'
        "- If the step's destination needs to be opened first, its target "
        "should be the tab/screen/modal deeplink; add a separate step with "
        "target \"highlight:<spot>\" to point at the exact element.\n"
        "- Do not use markdown in \"reply\".\n"
        "### DEEPLINK VOCABULARY (only these)\n"
        f'- tab: {" | ".join(sorted(_TAB_TARGETS))}\n'
        f'- screen: {" | ".join(sorted(_SCREEN_TARGETS))}\n'
        f'- modal: {" | ".join(sorted(_MODAL_TARGETS))}\n'
        f'- highlight: {" | ".join(sorted(_STATIC_SPOTS))} | nav.<tab>\n'
        'Example: to guide a user to stock-in you might emit steps '
        '[{"title": "Open Stock", "body": "Switch to the stock tab.", '
        '"target": "tab:stock"}, {"title": "Stock-in", "body": "Tap the '
        'Stock-in button to add stock.", "spot": "menu.scanCta"}] using only '
        "real vocabulary."
    )


def build_system_prompt(outlet: dict) -> str:
    """Assembles the system prompt from pluggable sections.

    Future modules (order analysis, suggestions) add their own section here.
    """
    sections = [
        _identity_section(),
        _behavior_section(),
        APP_GUIDE,
        _outlet_section(outlet),
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


async def _call_llm(system_prompt: str, history: list[dict]) -> dict:
    config = _llm_config()
    if config is None:
        raise RuntimeError("Support chat LLM is not configured.")
    base_url, api_key, model = config
    messages = [{"role": "system", "content": system_prompt}] + history
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
                "temperature": 0.4,
                "max_tokens": 1500,
                "response_format": {"type": "json_object"},
            },
        )
        response.raise_for_status()
        payload = response.json()
    content = (
        ((payload.get("choices") or [{}])[0].get("message") or {}).get("content")
        if isinstance(payload, dict)
        else None
    )
    if not isinstance(content, str) or not content.strip():
        raise RuntimeError(f"Support chat LLM returned an empty response ({model}).")
    return _parse_json_object(content)


# --- Auto-reply pipeline ---

_in_flight: dict[str, bool] = {}
_last_reply_at: dict[str, float] = {}


def _history_to_messages(rows) -> list[dict]:
    messages: list[dict] = []
    for row in rows:
        role = "user" if row.role == "client" else "assistant"
        messages.append({"role": role, "content": row.text})
    return messages


async def _load_outlet(outlet_id: str) -> dict:
    from database import AsyncSessionLocal
    from models import Outlet, OutletSubscription

    async with AsyncSessionLocal() as session:
        outlet = (
            await session.execute(
                select(Outlet)
                .options(selectinload(Outlet.subscription))
                .where(Outlet.id == outlet_id)
            )
        ).scalar_one_or_none()
        if outlet is None:
            return {"name": "", "plan": "trial", "table_count": None}
        plan = "trial"
        if outlet.subscription is not None:
            plan = outlet.subscription.plan or "trial"
        return {
            "name": outlet.name,
            "plan": plan,
            "table_count": outlet.table_count,
        }


async def _load_history(outlet_id: str, limit: int = SUPPORT_LLM_MAX_HISTORY) -> list:
    from database import AsyncSessionLocal
    from models import SupportChatMessage

    async with AsyncSessionLocal() as session:
        rows = (
            await session.execute(
                select(SupportChatMessage)
                .where(SupportChatMessage.outlet_id == outlet_id)
                .order_by(SupportChatMessage.created_at.desc())
                .limit(limit)
            )
        ).scalars().all()
    return list(reversed(rows))


async def auto_reply(outlet_id: str) -> None:
    """Generates one assistant reply for the outlet's latest client message.

    Fire-and-forget friendly: every failure is logged, never raised. A
    per-outlet in-flight guard prevents overlapping replies and a short
    cooldown stops message spam from queuing repeated LLM calls.
    """
    if _in_flight.get(outlet_id):
        return
    now = time.monotonic()
    if now - _last_reply_at.get(outlet_id, 0.0) < SUPPORT_LLM_COOLDOWN_SECONDS:
        return
    _in_flight[outlet_id] = True
    try:
        rows = await _load_history(outlet_id)
        if not rows or rows[-1].role != "client":
            return
        outlet = await _load_outlet(outlet_id)
        system_prompt = build_system_prompt(outlet)
        parsed = await _call_llm(system_prompt, _history_to_messages(rows))
        sanitized = sanitize_guide(parsed)
        reply = sanitized["reply"][:SUPPORT_LLM_MAX_REPLY_CHARS]
        if not reply:
            logger.warning(
                "[support_llm] Empty reply for outlet %s, skipping", outlet_id
            )
            return

        from routers.ws import _persist_support_message, _support_message_dict, manager

        message = await _persist_support_message(
            outlet_id=outlet_id,
            role="server",
            sender_name=ASSISTANT_NAME,
            text=reply,
            actions=sanitized.get("actions"),
            steps=sanitized.get("steps"),
        )
        await manager.broadcast(
            outlet_id,
            {"type": "support_msg", "data": _support_message_dict(message)},
        )
        _last_reply_at[outlet_id] = time.monotonic()
        logger.info(
            "[support_llm] Replied to outlet %s (%d chars, %d steps)",
            outlet_id,
            len(reply),
            len(sanitized.get("steps") or []),
        )
    except asyncio.CancelledError:
        raise
    except Exception as exc:  # never let an assistant failure break the app
        logger.error(
            "[support_llm] auto_reply failed for outlet %s: %s",
            outlet_id,
            exc,
            exc_info=True,
        )
    finally:
        _in_flight[outlet_id] = False
