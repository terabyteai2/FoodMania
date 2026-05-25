import json
import logging
from datetime import datetime, timezone
from typing import Any

import httpx
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from config import settings
from models import ChatbotConversation, ChatbotIntegration, MenuItem, Outlet
from services.customer_orders import (
    DeliveryOrderLine,
    create_delivery_order,
    delivery_order_totals,
)

logger = logging.getLogger(__name__)

FACEBOOK_PROVIDER = "facebook"
FACEBOOK_ORDER_SOURCE = "facebook_messenger"
GRAPH_TIMEOUT_SECONDS = 8.0
GROQ_TIMEOUT_SECONDS = 30.0
MAX_CONTEXT_MENU_ITEMS = 80
MAX_REPLY_CHARS = 1900


class ChatbotError(RuntimeError):
    pass


def mask_page_token(token: str | None) -> str | None:
    clean = (token or "").strip()
    if not clean:
        return None
    if len(clean) <= 8:
        return "••••"
    return f"{clean[:4]}…{clean[-4:]}"


def integration_to_config(integration: ChatbotIntegration | None) -> dict:
    if integration is None:
        return {
            "isConfigured": False,
            "isEnabled": False,
            "orderingEnabled": True,
            "pageId": None,
            "pageName": None,
            "tokenPreview": None,
            "lastError": None,
        }
    return {
        "isConfigured": True,
        "isEnabled": integration.is_enabled,
        "orderingEnabled": integration.ordering_enabled,
        "pageId": integration.page_id,
        "pageName": integration.page_name,
        "tokenPreview": mask_page_token(integration.page_access_token),
        "lastError": integration.last_error,
    }


async def get_facebook_config(db: AsyncSession, outlet_id: str) -> dict:
    integration = (
        await db.execute(
            select(ChatbotIntegration).where(
                ChatbotIntegration.provider == FACEBOOK_PROVIDER,
                ChatbotIntegration.outlet_id == outlet_id,
            )
        )
    ).scalar_one_or_none()
    return integration_to_config(integration)


async def resolve_facebook_page(token: str) -> dict:
    clean = token.strip()
    if not clean:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Facebook Page access token is required.",
        )
    version = settings.META_GRAPH_API_VERSION.strip() or "v24.0"
    url = f"https://graph.facebook.com/{version}/me"
    try:
        async with httpx.AsyncClient(timeout=GRAPH_TIMEOUT_SECONDS) as client:
            response = await client.get(
                url,
                params={"fields": "id,name", "access_token": clean},
            )
    except httpx.HTTPError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not verify the Facebook Page token.",
        ) from error
    payload = response.json() if response.content else {}
    if response.status_code >= 400:
        detail = payload.get("error", {}).get("message") if isinstance(payload, dict) else None
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail or "Facebook rejected the Page token.",
        )
    page_id = str(payload.get("id") or "").strip()
    if not page_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Facebook token response did not include a Page ID.",
        )
    return {"pageId": page_id, "pageName": str(payload.get("name") or "").strip() or None}


async def save_facebook_config(
    *,
    db: AsyncSession,
    outlet_id: str,
    page_access_token: str | None,
    is_enabled: bool,
    ordering_enabled: bool,
) -> dict:
    integration = (
        await db.execute(
            select(ChatbotIntegration).where(
                ChatbotIntegration.provider == FACEBOOK_PROVIDER,
                ChatbotIntegration.outlet_id == outlet_id,
            )
        )
    ).scalar_one_or_none()

    token = (page_access_token or "").strip()
    resolved: dict | None = None
    if token:
        resolved = await resolve_facebook_page(token)
        page_id = resolved["pageId"]
        existing_page = (
            await db.execute(
                select(ChatbotIntegration).where(
                    ChatbotIntegration.provider == FACEBOOK_PROVIDER,
                    ChatbotIntegration.page_id == page_id,
                    ChatbotIntegration.outlet_id != outlet_id,
                )
            )
        ).scalar_one_or_none()
        if existing_page is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="That Facebook Page is already connected to another outlet.",
            )
    elif integration is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Facebook Page access token is required.",
        )

    now = datetime.now(timezone.utc)
    if integration is None:
        integration = ChatbotIntegration(
            outlet_id=outlet_id,
            provider=FACEBOOK_PROVIDER,
            page_id=resolved["pageId"],
            page_name=resolved["pageName"],
            page_access_token=token,
            is_enabled=is_enabled,
            ordering_enabled=ordering_enabled,
            updated_at=now,
        )
        db.add(integration)
    else:
        if resolved is not None:
            integration.page_id = resolved["pageId"]
            integration.page_name = resolved["pageName"]
            integration.page_access_token = token
            integration.last_error = None
        integration.is_enabled = is_enabled
        integration.ordering_enabled = ordering_enabled
        integration.updated_at = now

    await db.commit()
    await db.refresh(integration)
    return integration_to_config(integration)


async def handle_facebook_webhook(db: AsyncSession, payload: dict[str, Any]) -> None:
    if payload.get("object") != "page":
        return
    for entry in payload.get("entry") or []:
        if not isinstance(entry, dict):
            continue
        page_id = str(entry.get("id") or "").strip()
        if not page_id:
            continue
        integration = await _integration_for_page(db, page_id)
        if integration is None:
            continue
        for event in entry.get("messaging") or []:
            if isinstance(event, dict):
                await _handle_event(db, integration, event)


async def _integration_for_page(
    db: AsyncSession,
    page_id: str,
) -> ChatbotIntegration | None:
    return (
        await db.execute(
            select(ChatbotIntegration)
            .where(
                ChatbotIntegration.provider == FACEBOOK_PROVIDER,
                ChatbotIntegration.page_id == page_id,
                ChatbotIntegration.is_enabled == True,
            )
            .options(joinedload(ChatbotIntegration.outlet).joinedload(Outlet.restaurant))
        )
    ).scalar_one_or_none()


async def _handle_event(
    db: AsyncSession,
    integration: ChatbotIntegration,
    event: dict[str, Any],
) -> None:
    message = event.get("message") if isinstance(event.get("message"), dict) else None
    postback = event.get("postback") if isinstance(event.get("postback"), dict) else None
    if message and message.get("is_echo"):
        return
    sender = event.get("sender") if isinstance(event.get("sender"), dict) else {}
    psid = str(sender.get("id") or "").strip()
    if not psid:
        return
    text = _event_text(message, postback)
    if not text:
        await _send_message(
            integration,
            psid,
            "Please send a text message so I can help with the menu or delivery order.",
        )
        return

    conversation = await _get_conversation(db, integration, psid)
    conversation.last_user_message = text
    try:
        reply = await _chatbot_reply(db, integration, conversation, text)
        integration.last_error = None
    except Exception as error:
        logger.exception("facebook chatbot failed page=%s psid=%s", integration.page_id, psid)
        reply = "Sorry, I could not process that right now. Please try again or use the menu link."
        integration.last_error = str(error)[:800]
    conversation.last_bot_message = reply
    conversation.updated_at = datetime.now(timezone.utc)
    integration.updated_at = datetime.now(timezone.utc)
    await db.commit()
    try:
        await _send_message(integration, psid, reply)
    except Exception as error:
        logger.warning(
            "facebook chatbot reply send failed page=%s psid=%s error=%s",
            integration.page_id,
            psid,
            error,
        )
        integration.last_error = str(error)[:800]
        integration.updated_at = datetime.now(timezone.utc)
        await db.commit()


def _event_text(message: dict | None, postback: dict | None) -> str:
    if postback:
        return str(postback.get("payload") or postback.get("title") or "").strip()
    if not message:
        return ""
    quick_reply = message.get("quick_reply")
    if isinstance(quick_reply, dict):
        payload = str(quick_reply.get("payload") or "").strip()
        if payload:
            return payload
    return str(message.get("text") or "").strip()


async def _get_conversation(
    db: AsyncSession,
    integration: ChatbotIntegration,
    psid: str,
) -> ChatbotConversation:
    conversation = (
        await db.execute(
            select(ChatbotConversation).where(
                ChatbotConversation.integration_id == integration.id,
                ChatbotConversation.psid == psid,
            )
        )
    ).scalar_one_or_none()
    if conversation is not None:
        return conversation
    conversation = ChatbotConversation(
        integration_id=integration.id,
        page_id=integration.page_id,
        psid=psid,
        state_json=_empty_state(),
    )
    db.add(conversation)
    await db.flush()
    return conversation


async def _chatbot_reply(
    db: AsyncSession,
    integration: ChatbotIntegration,
    conversation: ChatbotConversation,
    user_text: str,
) -> str:
    outlet = integration.outlet
    menu_items = await _available_menu_items(db, outlet.id)
    state = _normalize_state(conversation.state_json)
    model_payload = await _chat_with_groq(
        outlet=outlet,
        menu_items=menu_items,
        state=state,
        user_text=user_text,
        ordering_enabled=integration.ordering_enabled,
    )
    reply = str(model_payload.get("reply") or "").strip()
    order_action = model_payload.get("order") if isinstance(model_payload.get("order"), dict) else {}

    if not integration.ordering_enabled:
        conversation.state_json = state
        return reply or _menu_link_reply(outlet)

    state, state_reply = await _apply_order_action(
        db=db,
        outlet=outlet,
        state=state,
        action=order_action,
    )
    conversation.state_json = state
    return state_reply or reply or "I can help with menu questions and delivery orders."


async def _chat_with_groq(
    *,
    outlet: Outlet,
    menu_items: list[MenuItem],
    state: dict,
    user_text: str,
    ordering_enabled: bool,
) -> dict:
    api_key = settings.GROQ_API_KEY.strip()
    model = settings.CHATBOT_GROQ_MODEL.strip()
    if not api_key or not model:
        return {
            "reply": (
                f"Thanks for messaging {outlet.name}. AI chat is not configured yet. "
                f"You can order here: {_menu_link(outlet)}"
            ),
            "order": {"intent": "none"},
        }

    context = _restaurant_context(outlet, menu_items, ordering_enabled)
    messages = [
        {"role": "system", "content": _system_prompt()},
        {"role": "user", "content": json.dumps({
            "restaurant": context,
            "conversationState": state,
            "customerMessage": user_text,
        }, ensure_ascii=False)},
    ]
    try:
        async with httpx.AsyncClient(timeout=GROQ_TIMEOUT_SECONDS) as client:
            response = await client.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": model,
                    "messages": messages,
                    "temperature": 0.2,
                    "max_completion_tokens": 700,
                    "response_format": {"type": "json_object"},
                },
            )
            response.raise_for_status()
            payload = response.json()
    except httpx.HTTPError as error:
        raise ChatbotError("Groq chatbot request failed.") from error

    content = (
        ((payload.get("choices") or [{}])[0].get("message") or {}).get("content")
        if isinstance(payload, dict)
        else None
    )
    if not isinstance(content, str) or not content.strip():
        raise ChatbotError("Groq returned an empty chatbot response.")
    return _parse_json_object(content)


def _system_prompt() -> str:
    return (
        "You are the restaurant's Facebook Messenger assistant. Reply briefly and warmly. "
        "Use only the provided restaurant/menu context. The only order type is delivery. "
        "Collect menu item ids, quantities, customerName, mobileNumber, and deliveryAddress. "
        "Never create an order immediately after collecting details; first summarize the cart "
        "and ask the customer to confirm. When the customer explicitly confirms, set "
        "order.intent to confirm and order.confirmed to true. Return JSON only: "
        "{\"reply\":\"...\",\"order\":{\"intent\":\"none|draft|confirm|cancel\","
        "\"items\":[{\"menuItemId\":\"...\",\"qty\":1}],\"customerName\":\"\","
        "\"mobileNumber\":\"\",\"deliveryAddress\":\"\",\"confirmed\":false}}."
    )


def _restaurant_context(
    outlet: Outlet,
    menu_items: list[MenuItem],
    ordering_enabled: bool,
) -> dict:
    return {
        "restaurantName": outlet.restaurant.name if outlet.restaurant else outlet.name,
        "outletName": outlet.name,
        "orderingEnabled": ordering_enabled,
        "orderingUrl": _menu_link(outlet),
        "menu": [
            {
                "id": item.id,
                "name": item.name_en or item.name,
                "nameBn": item.name_bn or "",
                "category": item.category_en or item.category or "General",
                "price": float(item.price),
            }
            for item in menu_items[:MAX_CONTEXT_MENU_ITEMS]
        ],
    }


async def _available_menu_items(db: AsyncSession, outlet_id: str) -> list[MenuItem]:
    return (
        await db.execute(
            select(MenuItem)
            .where(
                MenuItem.outlet_id == outlet_id,
                MenuItem.is_available == True,
                MenuItem.deleted_at == None,
            )
            .order_by(MenuItem.category, MenuItem.name)
            .limit(MAX_CONTEXT_MENU_ITEMS)
        )
    ).scalars().all()


async def _apply_order_action(
    *,
    db: AsyncSession,
    outlet: Outlet,
    state: dict,
    action: dict,
) -> tuple[dict, str | None]:
    intent = str(action.get("intent") or "none").strip().lower()
    if intent == "cancel":
        return _empty_state(), "No problem, I cancelled the draft order. What else can I help with?"

    state = _merge_state(state, action)
    lines, issue = await _validated_lines(db, outlet.id, state)
    if issue:
        state["awaitingConfirmation"] = False
        return state, issue
    if not lines:
        return state, None

    totals = delivery_order_totals(lines)
    has_details = all(
        str(state.get(key) or "").strip()
        for key in ("customerName", "mobileNumber", "deliveryAddress")
    )
    confirmed = bool(action.get("confirmed")) or intent == "confirm"
    awaiting = bool(state.get("awaitingConfirmation"))

    if confirmed and awaiting and has_details:
        order = await create_delivery_order(
            db=db,
            outlet=outlet,
            lines=lines,
            customer_name=str(state.get("customerName") or ""),
            mobile_number=str(state.get("mobileNumber") or ""),
            delivery_address=str(state.get("deliveryAddress") or ""),
            note="Facebook Messenger order",
            source=FACEBOOK_ORDER_SOURCE,
            created_by_role="customer",
        )
        return _empty_state(), (
            "Order confirmed. "
            f"Your order number is #{order.serial_number}. Total: ৳{float(order.total_amount):.0f}."
        )

    if confirmed and not awaiting:
        state["awaitingConfirmation"] = True
        return state, _confirmation_reply(lines, totals, state)

    if has_details:
        state["awaitingConfirmation"] = True
        return state, _confirmation_reply(lines, totals, state)

    state["awaitingConfirmation"] = False
    missing = [
        label
        for key, label in [
            ("customerName", "name"),
            ("mobileNumber", "mobile number"),
            ("deliveryAddress", "delivery address"),
        ]
        if not str(state.get(key) or "").strip()
    ]
    if missing:
        return state, "Please share your " + ", ".join(missing) + " for delivery."
    return state, None


def _merge_state(state: dict, action: dict) -> dict:
    next_state = dict(state)
    raw_items = action.get("items")
    if isinstance(raw_items, list) and raw_items:
        items = []
        for raw in raw_items:
            if not isinstance(raw, dict):
                continue
            menu_id = str(raw.get("menuItemId") or "").strip()
            qty = _safe_int(raw.get("qty"), fallback=1)
            if menu_id:
                items.append({"menuItemId": menu_id, "qty": max(1, min(qty, 99))})
        if items:
            next_state["items"] = items
    for key in ("customerName", "mobileNumber", "deliveryAddress"):
        value = action.get(key)
        if isinstance(value, str) and value.strip():
            next_state[key] = value.strip()
    return _normalize_state(next_state)


async def _validated_lines(
    db: AsyncSession,
    outlet_id: str,
    state: dict,
) -> tuple[list[DeliveryOrderLine], str | None]:
    items = state.get("items")
    if not isinstance(items, list) or not items:
        return [], None
    menu_ids = [str(item.get("menuItemId") or "").strip() for item in items if isinstance(item, dict)]
    menu_ids = [item for item in menu_ids if item]
    if not menu_ids:
        return [], None
    rows = (
        await db.execute(
            select(MenuItem).where(
                MenuItem.outlet_id == outlet_id,
                MenuItem.id.in_(menu_ids),
                MenuItem.is_available == True,
                MenuItem.deleted_at == None,
            )
        )
    ).scalars().all()
    by_id = {item.id: item for item in rows}
    missing = [menu_id for menu_id in menu_ids if menu_id not in by_id]
    if missing:
        return [], "Some selected items are no longer available. Please choose from the current menu."
    lines: list[DeliveryOrderLine] = []
    for raw in items:
        if not isinstance(raw, dict):
            continue
        menu_id = str(raw.get("menuItemId") or "").strip()
        item = by_id.get(menu_id)
        if item is None:
            continue
        qty = max(1, min(_safe_int(raw.get("qty"), fallback=1), 99))
        lines.append(
            DeliveryOrderLine(
                menu_item_id=item.id,
                name=item.name_en or item.name,
                qty=qty,
                price=float(item.price),
            )
        )
    return lines, None


def _confirmation_reply(lines: list[DeliveryOrderLine], totals: dict, state: dict) -> str:
    item_text = ", ".join(f"{line.qty} x {line.name}" for line in lines)
    return (
        f"Please confirm your delivery order: {item_text}. "
        f"Name: {state.get('customerName')}. Mobile: {state.get('mobileNumber')}. "
        f"Address: {state.get('deliveryAddress')}. Total: ৳{totals['total']:.0f}. "
        "Reply yes to place the order."
    )


async def _send_message(integration: ChatbotIntegration, psid: str, text: str) -> None:
    version = settings.META_GRAPH_API_VERSION.strip() or "v24.0"
    url = f"https://graph.facebook.com/{version}/{integration.page_id}/messages"
    try:
        async with httpx.AsyncClient(timeout=GRAPH_TIMEOUT_SECONDS) as client:
            response = await client.post(
                url,
                params={"access_token": integration.page_access_token},
                json={
                    "recipient": {"id": psid},
                    "messaging_type": "RESPONSE",
                    "message": {"text": text[:MAX_REPLY_CHARS]},
                },
            )
            response.raise_for_status()
    except httpx.HTTPError as error:
        raise ChatbotError("Could not send Facebook Messenger reply.") from error


def _parse_json_object(content: str) -> dict:
    clean = content.strip()
    if clean.startswith("```"):
        clean = clean.strip("`").strip()
        if clean.lower().startswith("json"):
            clean = clean[4:].strip()
    try:
        parsed = json.loads(clean)
    except json.JSONDecodeError as error:
        raise ChatbotError("Groq returned invalid JSON.") from error
    if not isinstance(parsed, dict):
        raise ChatbotError("Groq response must be a JSON object.")
    return parsed


def _normalize_state(value: Any) -> dict:
    state = value if isinstance(value, dict) else {}
    return {
        "items": state.get("items") if isinstance(state.get("items"), list) else [],
        "customerName": str(state.get("customerName") or "").strip(),
        "mobileNumber": str(state.get("mobileNumber") or "").strip(),
        "deliveryAddress": str(state.get("deliveryAddress") or "").strip(),
        "awaitingConfirmation": bool(state.get("awaitingConfirmation")),
    }


def _empty_state() -> dict:
    return {
        "items": [],
        "customerName": "",
        "mobileNumber": "",
        "deliveryAddress": "",
        "awaitingConfirmation": False,
    }


def _safe_int(value: Any, *, fallback: int) -> int:
    if isinstance(value, int):
        return value
    try:
        return int(str(value))
    except (TypeError, ValueError):
        return fallback


def _menu_link(outlet: Outlet) -> str:
    slug = (outlet.public_slug or "").strip().lower()
    if slug:
        return f"https://{slug}.quickbytes.buzz"
    return f"{settings.BASE_URL.rstrip('/')}/menu/{outlet.id}"


def _menu_link_reply(outlet: Outlet) -> str:
    return f"You can view the menu and order here: {_menu_link(outlet)}"
