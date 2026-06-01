import json
import logging
import re
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.parse import urlencode

import httpx
from fastapi import HTTPException, status
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from auth import ALGORITHM
from config import settings
from models import ChatbotConversation, ChatbotIntegration, ChatbotOAuthSession, MenuItem, Outlet
from services.customer_orders import (
    DeliveryOrderLine,
    create_delivery_order,
    delivery_order_totals,
)

logger = logging.getLogger(__name__)

FACEBOOK_PROVIDER = "facebook"
FACEBOOK_ORDER_SOURCE = "facebook_messenger"
FACEBOOK_OAUTH_STATE_TYPE = "facebook_chatbot_oauth"
FACEBOOK_OAUTH_CALLBACK_PATH = "/admin/chatbot/facebook/oauth/callback"
GRAPH_TIMEOUT_SECONDS = 8.0
GROQ_TIMEOUT_SECONDS = 30.0
MAX_CONTEXT_MENU_ITEMS = 80
MAX_REPLY_CHARS = 1900
MAX_HISTORY_TURNS = 6          # last N user+assistant pairs kept in Groq context
MAX_HISTORY_STORE = 20         # total turns kept in DB (ring buffer)

REPLY_STYLE_BANGLISH = "banglish"
REPLY_STYLE_BN = "bn"
REPLY_STYLE_EN = "en"

BANGLISH_WORDS = {
    "ami", "apni", "ase", "ache", "bolen", "chai", "chan", "daw", "den",
    "hae", "hobe", "jabe", "khete", "ki", "lagbe", "nibo", "pawa",
    "dao", "deben", "korbo", "korben", "neben", "pete", "chai", "kono",
    "ekta", "duta", "tিনটা", "koto", "boro", "choto", "thik", "ache",
}
ENGLISH_WORDS = {
    "address", "available", "burger", "can", "cancel", "delivery", "do",
    "have", "hello", "hi", "is", "menu", "order", "please", "thanks",
    "the", "want", "what", "yes", "you",
}
BANGLISH_DISALLOWED_OPENERS = ("hey", "sure", "hello", "hi", "great", "awesome", "wonderful")
BANGLISH_ENGLISH_MARKERS = {
    "are", "can", "choose", "do", "have", "help", "like", "menu", "order",
    "please", "sure", "the", "type", "want", "we", "which", "would", "you",
}

# ─── intent tags the LLM returns (extended set) ──────────────────────────────
INTENT_NONE        = "none"
INTENT_DRAFT       = "draft"
INTENT_CONFIRM     = "confirm"
INTENT_CANCEL      = "cancel"
INTENT_ADD_MORE    = "add_more"     # customer wants to add another item
INTENT_SHOW_MENU   = "show_menu"    # customer wants to browse
INTENT_REMOVE_ITEM = "remove_item"  # customer wants to drop an item from cart


class ChatbotError(RuntimeError):
    pass


class ChatbotProvidersFailed(ChatbotError):
    pass


# ═══════════════════════════════════════════════════════════════════════════════
# Token / config helpers
# ═══════════════════════════════════════════════════════════════════════════════

def mask_page_token(token: str | None) -> str | None:
    clean = (token or "").strip()
    if not clean:
        return None
    if len(clean) <= 8:
        return "••••"
    return f"{clean[:4]}…{clean[-4:]}"


def integration_to_config(integration: "ChatbotIntegration | None") -> dict:
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


# ═══════════════════════════════════════════════════════════════════════════════
# DB helpers
# ═══════════════════════════════════════════════════════════════════════════════

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


# ═══════════════════════════════════════════════════════════════════════════════
# Graph API helpers
# ═══════════════════════════════════════════════════════════════════════════════

def _graph_version() -> str:
    return settings.META_GRAPH_API_VERSION.strip() or "v24.0"


def _graph_url(path: str) -> str:
    clean_path = path if path.startswith("/") else f"/{path}"
    return f"https://graph.facebook.com/{_graph_version()}{clean_path}"


def _public_base_url() -> str:
    base = settings.BASE_URL.strip().rstrip("/")
    if not base:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="BASE_URL is required for Facebook Login.",
        )
    return base


def facebook_oauth_redirect_uri() -> str:
    return f"{_public_base_url()}{FACEBOOK_OAUTH_CALLBACK_PATH}"


def _require_facebook_app_config() -> tuple[str, str]:
    app_id = settings.FACEBOOK_APP_ID.strip()
    app_secret = settings.FACEBOOK_APP_SECRET.strip()
    if not app_id or not app_secret:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Facebook app credentials are not configured.",
        )
    return app_id, app_secret


def _facebook_login_scopes() -> str:
    scopes = [s.strip() for s in settings.FACEBOOK_LOGIN_SCOPES.split(",") if s.strip()]
    return ",".join(scopes) if scopes else "pages_show_list,pages_manage_metadata,pages_messaging"


def create_facebook_oauth_url(*, outlet_id: str, account_id: str) -> dict:
    app_id, _ = _require_facebook_app_config()
    expires_in = max(60, settings.FACEBOOK_OAUTH_STATE_EXPIRE_MINUTES * 60)
    expire = datetime.now(timezone.utc) + timedelta(seconds=expires_in)
    state = jwt.encode(
        {
            "type": FACEBOOK_OAUTH_STATE_TYPE,
            "sub": outlet_id,
            "account_id": account_id,
            "nonce": str(uuid.uuid4()),
            "exp": expire,
        },
        settings.SECRET_KEY,
        algorithm=ALGORITHM,
    )
    params = {
        "client_id": app_id,
        "redirect_uri": facebook_oauth_redirect_uri(),
        "response_type": "code",
        "scope": _facebook_login_scopes(),
        "state": state,
        "auth_type": "rerequest",
    }
    url = f"https://www.facebook.com/{_graph_version()}/dialog/oauth?{urlencode(params)}"
    return {"authorizationUrl": url, "expiresInSeconds": expires_in}


def _decode_facebook_oauth_state(raw_state: str) -> dict[str, Any]:
    try:
        payload = jwt.decode(raw_state, settings.SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != FACEBOOK_OAUTH_STATE_TYPE:
            raise ValueError("Invalid state token type.")
        outlet_id = str(payload.get("sub") or "").strip()
        if not outlet_id:
            raise ValueError("Missing outlet in state token.")
        return payload
    except (JWTError, ValueError) as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Facebook Login state is invalid or expired.",
        ) from error


def _facebook_error_detail(payload: Any, fallback: str) -> str:
    if isinstance(payload, dict):
        error = payload.get("error")
        if isinstance(error, dict):
            message = str(error.get("message") or "").strip()
            if message:
                return message
    return fallback


async def _graph_get(path: str, params: dict[str, str], fallback: str) -> dict:
    try:
        async with httpx.AsyncClient(timeout=GRAPH_TIMEOUT_SECONDS) as client:
            response = await client.get(_graph_url(path), params=params)
    except httpx.HTTPError as error:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=fallback) from error
    payload = response.json() if response.content else {}
    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_facebook_error_detail(payload, fallback),
        )
    return payload if isinstance(payload, dict) else {}


async def _graph_post(path: str, params: dict[str, str], fallback: str) -> dict:
    try:
        async with httpx.AsyncClient(timeout=GRAPH_TIMEOUT_SECONDS) as client:
            response = await client.post(_graph_url(path), params=params)
    except httpx.HTTPError as error:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=fallback) from error
    payload = response.json() if response.content else {}
    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_facebook_error_detail(payload, fallback),
        )
    return payload if isinstance(payload, dict) else {}


# ═══════════════════════════════════════════════════════════════════════════════
# OAuth flow
# ═══════════════════════════════════════════════════════════════════════════════

async def _exchange_code_for_user_token(code: str) -> str:
    app_id, app_secret = _require_facebook_app_config()
    payload = await _graph_get(
        "/oauth/access_token",
        {
            "client_id": app_id,
            "client_secret": app_secret,
            "redirect_uri": facebook_oauth_redirect_uri(),
            "code": code,
        },
        "Could not finish Facebook Login.",
    )
    token = str(payload.get("access_token") or "").strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Facebook Login did not return a user access token.",
        )
    return token


async def _exchange_long_lived_user_token(short_token: str) -> str:
    app_id, app_secret = _require_facebook_app_config()
    payload = await _graph_get(
        "/oauth/access_token",
        {
            "grant_type": "fb_exchange_token",
            "client_id": app_id,
            "client_secret": app_secret,
            "fb_exchange_token": short_token,
        },
        "Could not create a long-lived Facebook token.",
    )
    return str(payload.get("access_token") or "").strip() or short_token


async def _fetch_facebook_pages(user_access_token: str) -> list[dict[str, Any]]:
    payload = await _graph_get(
        "/me/accounts",
        {"fields": "id,name,access_token", "access_token": user_access_token},
        "Could not read Facebook Pages for this account.",
    )
    pages = payload.get("data")
    return [p for p in (pages or []) if isinstance(p, dict)]


def _selectable_facebook_pages(pages: list[dict[str, Any]]) -> list[dict[str, Any]]:
    selectable = []
    for page in pages:
        page_id = str(page.get("id") or "").strip()
        token = str(page.get("access_token") or "").strip()
        if page_id and token:
            selectable.append({
                "pageId": page_id,
                "pageName": str(page.get("name") or "").strip() or None,
                "pageAccessToken": token,
            })
    return selectable


async def _subscribe_facebook_page(page_id: str, page_access_token: str) -> None:
    await _graph_post(
        f"/{page_id}/subscribed_apps",
        {
            "subscribed_fields": "messages,messaging_postbacks",
            "access_token": page_access_token,
        },
        "Could not subscribe this Facebook Page to Messenger webhooks.",
    )


async def complete_facebook_oauth(*, db: AsyncSession, state_token: str, code: str) -> dict:
    state_payload = _decode_facebook_oauth_state(state_token)
    outlet_id = str(state_payload["sub"]).strip()
    account_id = str(state_payload.get("account_id") or "").strip()
    if not account_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Facebook Login state is missing the manager account.",
        )
    short_token = await _exchange_code_for_user_token(code.strip())
    user_token = await _exchange_long_lived_user_token(short_token)
    pages = _selectable_facebook_pages(await _fetch_facebook_pages(user_token))
    if not pages:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Facebook did not return an authorized Page access token.",
        )
    session = ChatbotOAuthSession(
        outlet_id=outlet_id,
        account_id=account_id,
        provider=FACEBOOK_PROVIDER,
        pages_json=pages,
        expires_at=datetime.now(timezone.utc)
        + timedelta(minutes=max(1, settings.FACEBOOK_OAUTH_STATE_EXPIRE_MINUTES)),
    )
    db.add(session)
    await db.commit()
    return {"sessionId": session.id}


async def get_facebook_oauth_pages(
    db: AsyncSession,
    *,
    session_id: str,
    outlet_id: str,
    account_id: str,
) -> dict:
    session = await _get_facebook_oauth_session(
        db, session_id=session_id, outlet_id=outlet_id, account_id=account_id
    )
    return {
        "sessionId": session.id,
        "pages": [
            {"pageId": p["pageId"], "pageName": p.get("pageName")}
            for p in session.pages_json
        ],
    }


async def complete_facebook_oauth_page_selection(
    db: AsyncSession,
    *,
    session_id: str,
    page_id: str,
    outlet_id: str,
    account_id: str,
) -> dict:
    session = await _get_facebook_oauth_session(
        db, session_id=session_id, outlet_id=outlet_id, account_id=account_id
    )
    page = next(
        (c for c in session.pages_json if c["pageId"] == page_id),
        None,
    )
    if page is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Select a Facebook Page returned by this login.",
        )
    await _ensure_facebook_page_available(db, outlet_id, page["pageId"])
    await _subscribe_facebook_page(page["pageId"], page["pageAccessToken"])
    config = await save_facebook_page_credentials(
        db=db,
        outlet_id=outlet_id,
        page_id=page["pageId"],
        page_name=page.get("pageName"),
        page_access_token=page["pageAccessToken"],
        is_enabled=True,
        ordering_enabled=True,
    )
    await db.delete(session)
    await db.commit()
    return config


async def _get_facebook_oauth_session(
    db: AsyncSession,
    *,
    session_id: str,
    outlet_id: str,
    account_id: str,
) -> ChatbotOAuthSession:
    session = (
        await db.execute(
            select(ChatbotOAuthSession).where(
                ChatbotOAuthSession.id == session_id.strip(),
                ChatbotOAuthSession.provider == FACEBOOK_PROVIDER,
                ChatbotOAuthSession.outlet_id == outlet_id,
                ChatbotOAuthSession.account_id == account_id,
            )
        )
    ).scalar_one_or_none()
    if session is None or session.expires_at <= datetime.now(timezone.utc):
        if session is not None:
            await db.delete(session)
            await db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Facebook Page selection has expired. Connect with Facebook again.",
        )
    return session


# ═══════════════════════════════════════════════════════════════════════════════
# Page token / config save
# ═══════════════════════════════════════════════════════════════════════════════

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
            response = await client.get(url, params={"fields": "id,name", "access_token": clean})
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


async def _ensure_facebook_page_available(
    db: AsyncSession,
    outlet_id: str,
    page_id: str,
) -> None:
    existing = (
        await db.execute(
            select(ChatbotIntegration).where(
                ChatbotIntegration.provider == FACEBOOK_PROVIDER,
                ChatbotIntegration.page_id == page_id,
                ChatbotIntegration.outlet_id != outlet_id,
            )
        )
    ).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="That Facebook Page is already connected to another outlet.",
        )


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
    if token:
        resolved = await resolve_facebook_page(token)
        return await save_facebook_page_credentials(
            db=db,
            outlet_id=outlet_id,
            page_id=resolved["pageId"],
            page_name=resolved["pageName"],
            page_access_token=token,
            is_enabled=is_enabled,
            ordering_enabled=ordering_enabled,
        )
    elif integration is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Facebook Page access token is required.",
        )

    now = datetime.now(timezone.utc)
    integration.is_enabled = is_enabled
    integration.ordering_enabled = ordering_enabled
    integration.updated_at = now
    await db.commit()
    await db.refresh(integration)
    return integration_to_config(integration)


async def save_facebook_page_credentials(
    *,
    db: AsyncSession,
    outlet_id: str,
    page_id: str,
    page_name: str | None,
    page_access_token: str,
    is_enabled: bool,
    ordering_enabled: bool,
) -> dict:
    clean_page_id = page_id.strip()
    clean_token = page_access_token.strip()
    if not clean_page_id or not clean_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Facebook did not return a valid Page token.",
        )
    integration = (
        await db.execute(
            select(ChatbotIntegration).where(
                ChatbotIntegration.provider == FACEBOOK_PROVIDER,
                ChatbotIntegration.outlet_id == outlet_id,
            )
        )
    ).scalar_one_or_none()
    await _ensure_facebook_page_available(db, outlet_id, clean_page_id)

    now = datetime.now(timezone.utc)
    if integration is None:
        integration = ChatbotIntegration(
            outlet_id=outlet_id,
            provider=FACEBOOK_PROVIDER,
            page_id=clean_page_id,
            page_name=(page_name or "").strip() or None,
            page_access_token=clean_token,
            is_enabled=is_enabled,
            ordering_enabled=ordering_enabled,
            updated_at=now,
        )
        db.add(integration)
    else:
        integration.page_id = clean_page_id
        integration.page_name = (page_name or "").strip() or None
        integration.page_access_token = clean_token
        integration.last_error = None
        integration.is_enabled = is_enabled
        integration.ordering_enabled = ordering_enabled
        integration.updated_at = now

    await db.commit()
    await db.refresh(integration)
    return integration_to_config(integration)


# ═══════════════════════════════════════════════════════════════════════════════
# Webhook entry point
# ═══════════════════════════════════════════════════════════════════════════════

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
) -> "ChatbotIntegration | None":
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
            "Menu ba delivery order niye help korte amake ekta text message pathan.",
        )
        return

    conversation = await _get_conversation(db, integration, psid)
    conversation.last_user_message = text
    try:
        reply = await _chatbot_reply(db, integration, conversation, text)
        integration.last_error = None
    except ChatbotProvidersFailed as error:
        logger.exception("facebook chatbot failed page=%s psid=%s", integration.page_id, psid)
        reply = "Ami ekjon AI ChatBot.  Arektu bujhiye bolun, kindly"
        integration.last_error = str(error)[:800]
    except Exception as error:
        logger.exception("facebook chatbot failed page=%s psid=%s", integration.page_id, psid)
        reply = "Ektu technical somossa hocche. Arektu pore abar try korben."
        integration.last_error = str(error)[:800]

    # persist bot reply into history before saving
    _append_history(conversation, "user", text)
    _append_history(conversation, "assistant", reply)

    conversation.last_bot_message = reply
    conversation.updated_at = datetime.now(timezone.utc)
    integration.updated_at = datetime.now(timezone.utc)
    await db.commit()

    try:
        await _send_message(integration, psid, reply)
    except Exception as error:
        logger.warning(
            "facebook chatbot reply send failed page=%s psid=%s error=%s",
            integration.page_id, psid, error,
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


# ═══════════════════════════════════════════════════════════════════════════════
# Conversation state & history
# ═══════════════════════════════════════════════════════════════════════════════

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


def _append_history(conversation: ChatbotConversation, role: str, content: str) -> None:
    """Ring-buffer: keep the last MAX_HISTORY_STORE turns in state_json['history']."""
    state = _normalize_state(conversation.state_json)
    history: list[dict] = state.get("history") or []
    history.append({"role": role, "content": content})
    if len(history) > MAX_HISTORY_STORE * 2:
        history = history[-(MAX_HISTORY_STORE * 2):]
    state["history"] = history
    conversation.state_json = state


def _recent_history(state: dict, n_turns: int = MAX_HISTORY_TURNS) -> list[dict]:
    """Return last n_turns user+assistant pairs as Groq messages."""
    raw: list[dict] = state.get("history") or []
    # each turn = 2 entries; grab last n_turns * 2 messages, skip the very last
    # user message (we send it as the final user message separately)
    pairs = raw[-(n_turns * 2):]
    # drop trailing user entry if present (will be re-sent as current message)
    if pairs and pairs[-1].get("role") == "user":
        pairs = pairs[:-1]
    return [{"role": m["role"], "content": m["content"]} for m in pairs]


# ═══════════════════════════════════════════════════════════════════════════════
# Core chatbot reply
# ═══════════════════════════════════════════════════════════════════════════════

async def _chatbot_reply(
    db: AsyncSession,
    integration: ChatbotIntegration,
    conversation: ChatbotConversation,
    user_text: str,
) -> str:
    outlet = integration.outlet
    menu_items = await _available_menu_items(db, outlet.id)
    state = _normalize_state(conversation.state_json)
    reply_style = _detect_reply_style(user_text)
    resolved_selection = _resolve_numbered_selection(
        user_text,
        conversation.last_bot_message,
        menu_items,
    )
    if resolved_selection is not None:
        state["selectedMenuItemId"] = resolved_selection["menuItemId"]

    model_payload = await _chat_with_groq(
        outlet=outlet,
        menu_items=menu_items,
        state=state,
        user_text=user_text,
        ordering_enabled=integration.ordering_enabled,
        reply_style=reply_style,
        history=_recent_history(state),
        resolved_selection=resolved_selection,
    )

    reply = str(model_payload.get("reply") or "").strip()
    order_action = model_payload.get("order") if isinstance(model_payload.get("order"), dict) else {}

    if not integration.ordering_enabled:
        conversation.state_json = state
        if not reply:
            raise ChatbotError("Groq returned an empty chatbot reply.")
        return reply

    state, state_reply = await _apply_order_action(
        db=db,
        outlet=outlet,
        state=state,
        action=order_action,
        reply_style=reply_style,
        menu_items=menu_items,
    )
    conversation.state_json = state
    if state_reply:
        return state_reply
    if not reply:
        raise ChatbotError("Groq returned an empty chatbot reply.")
    return reply


# ═══════════════════════════════════════════════════════════════════════════════
# Groq LLM call
# ═══════════════════════════════════════════════════════════════════════════════

async def _chat_with_groq(
    *,
    outlet: Outlet,
    menu_items: list[MenuItem],
    state: dict,
    user_text: str,
    ordering_enabled: bool,
    reply_style: str,
    history: list[dict],
    resolved_selection: dict[str, Any] | None = None,
) -> dict:
    api_key = settings.GROQ_API_KEY.strip()
    model = settings.CHATBOT_GROQ_MODEL.strip()
    if not api_key or not model:
        raise ChatbotError("Groq chatbot is not configured.")

    context = _restaurant_context(outlet, menu_items, ordering_enabled)

    # Build the message list: system → history → current user message
    messages: list[dict] = [{"role": "system", "content": _system_prompt()}]
    messages.extend(history)
    messages.append({
        "role": "user",
        "content": json.dumps({
            "restaurant": context,
            "conversationState": _state_for_llm(state),
            "customerMessage": user_text,
            "replyStyle": reply_style,
            "resolvedNumberedSelection": resolved_selection,
        }, ensure_ascii=False),
    })

    async with httpx.AsyncClient(timeout=GROQ_TIMEOUT_SECONDS) as client:
        for attempt in range(2):
            if attempt:
                messages.append({
                    "role": "user",
                    "content": (
                        "Rewrite your previous JSON reply. Keep the same factual meaning and "
                        "order object, but strictly follow replyStyle. For banglish, write only "
                        "natural Roman Bangla like the customer — short, warm, no English sentences, "
                        "no greetings like Hey/Sure/Hello, no emoji. Return JSON only."
                    ),
                })
            payload = await _chat_completion_with_fallback(
                client=client,
                groq_api_key=api_key,
                groq_model=model,
                messages=messages,
            )
            content = (
                ((payload.get("choices") or [{}])[0].get("message") or {}).get("content")
                if isinstance(payload, dict) else None
            )
            if not isinstance(content, str) or not content.strip():
                raise ChatbotError("Groq returned an empty chatbot response.")
            parsed = _parse_json_object(content)
            reply = str(parsed.get("reply") or "").strip()
            if not _reply_needs_rewrite(reply, reply_style):
                return parsed
            messages.append({"role": "assistant", "content": content})
    raise ChatbotError("Groq chatbot reply did not follow the requested language style.")


async def _chat_completion_with_fallback(
    *,
    client: httpx.AsyncClient,
    groq_api_key: str,
    groq_model: str,
    messages: list[dict],
) -> dict:
    providers = [
        (
            "groq",
            "https://api.groq.com/openai/v1/chat/completions",
            groq_api_key,
            groq_model,
        ),
    ]
    openrouter_model = settings.CHATBOT_OPENROUTER_MODEL.strip()
    if openrouter_model:
        for index, openrouter_key in enumerate(_openrouter_api_keys(), start=1):
            providers.append(
                (
                    f"openrouter[{index}]",
                    "https://openrouter.ai/api/v1/chat/completions",
                    openrouter_key,
                    openrouter_model,
                )
            )

    errors = []
    for provider, url, api_key, model in providers:
        try:
            response = await client.post(
                url,
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": model,
                    "messages": messages,
                    "temperature": 0.25,
                    "max_completion_tokens": 800,
                    "response_format": {"type": "json_object"},
                },
            )
            response.raise_for_status()
            payload = response.json()
            if isinstance(payload, dict):
                return payload
            raise ChatbotError(f"{provider} returned a malformed response.")
        except (httpx.HTTPError, ValueError, ChatbotError) as error:
            body = ""
            if isinstance(error, httpx.HTTPStatusError):
                body = error.response.text[:1000]
            logger.warning(
                "facebook chatbot provider failed provider=%s model=%s error=%s body=%s",
                provider,
                model,
                error,
                body,
            )
            errors.append(f"{provider}: {error}")
    raise ChatbotProvidersFailed("Chatbot providers failed: " + "; ".join(errors))


def _openrouter_api_keys() -> list[str]:
    raw_keys = [
        settings.OPENROUTER_API_KEY,
        *settings.OPENROUTER_API_KEYS.split(","),
    ]
    keys = []
    for raw_key in raw_keys:
        key = raw_key.strip()
        if key and key not in keys:
            keys.append(key)
    return keys


def _state_for_llm(state: dict) -> dict:
    """Send only the cart fields to the LLM, not the full history buffer."""
    return {k: v for k, v in state.items() if k != "history"}


def _resolve_numbered_selection(
    user_text: str,
    last_bot_message: str | None,
    menu_items: list[MenuItem],
) -> dict[str, Any] | None:
    match = re.search(r"\b(\d{1,2})\s*(?:number|num(?:ber)?|no\.?)?\b", user_text, re.IGNORECASE)
    if match is None or not last_bot_message:
        return None
    selected_number = int(match.group(1))
    shown_items: dict[int, str] = {}
    for raw_line in last_bot_message.splitlines():
        line = raw_line.strip()
        shown = re.match(r"^(\d{1,2})\s*[\.\)]\s*(.+?)(?:\s*[-–—]\s*৳?\s*\d+(?:\.\d+)?)?$", line)
        if shown:
            shown_items[int(shown.group(1))] = shown.group(2).strip()
    shown_name = shown_items.get(selected_number)
    if not shown_name:
        return None
    normalized_name = _normalized_menu_name(shown_name)
    item = next(
        (
            menu_item
            for menu_item in menu_items
            if normalized_name in {
                _normalized_menu_name(menu_item.name),
                _normalized_menu_name(menu_item.name_en or ""),
                _normalized_menu_name(menu_item.name_bn or ""),
            }
        ),
        None,
    )
    if item is None:
        return None
    return {
        "number": selected_number,
        "menuItemId": item.id,
        "name": item.name_en or item.name,
        "price": float(item.price),
    }


def _normalized_menu_name(value: str) -> str:
    return re.sub(r"[^a-z0-9\u0980-\u09ff]+", "", value.lower())


# ═══════════════════════════════════════════════════════════════════════════════
# System prompt  ← the most important improvement
# ═══════════════════════════════════════════════════════════════════════════════

def _system_prompt() -> str:
    return """You are a friendly, human-sounding restaurant staff member on Facebook Messenger.
Your job is to take delivery orders naturally — like a real person chatting, not a bot.

LANGUAGE RULES
- Default language: banglish (Roman Bangla). Use only natural Roman Bangla words, short sentences.
  Example: "Kon burger ta neben?" not "Which burger would you like to order?"
- Never start a reply with Hey, Hi, Hello, Sure, Great, Awesome, or any English greeting.
- Never use emoji unless the customer used one first.
- If replyStyle is "bn", reply fully in Bengali script.
- If replyStyle is "en", reply fully in English.
- Mirror the customer's energy: short reply → short reply, detailed → more detail.

ORDERING FLOW — follow this strictly:

STEP 1 — ITEM DISAMBIGUATION
If a customer names a category (e.g. "burger", "pizza") and there are multiple matching items in
restaurant.menu, list ALL matching items with their prices and ask which one they want.
Format: "Amader burgers:\n1. Chicken Burger - ৳120\n2. Beef Burger - ৳150\n3. Veggie Burger - ৳100\nKonTa neben?"
Never assume which item they want if multiple matches exist.

STEP 2 — QUANTITY
Once the exact item is clear, ask how many they want (if not already said).
Example: "Kototgulo neben?" or "Koy piis lagbe?"

STEP 3 — MORE ITEMS
After quantity is set, always ask if they want anything else before collecting details.
Example: "Thik ache! Ar kono kichu add korben?"
Set order.intent = "add_more" if customer says yes.

STEP 4 — COLLECT DETAILS
When customer is done adding items, ask for: name, mobile number, delivery address.
You may ask all three at once or one at a time depending on flow.
Example: "Delivery-r jonno apnar naam, mobile number, ar address-ta deben?"

STEP 5 — CONFIRM
When all details are collected, summarize the full order and ask for confirmation.
Show: items + qty, total price, name, mobile, address.
Only set order.confirmed = true when the customer clearly says yes/hae/confirm/thik ache/done.

STEP 6 — AFTER ORDER
After successful order, always ask: "Ar kono kichu lagbe?"

ITEM REMOVAL
If customer says "eta bad dao" or "remove koren", set order.intent = "remove_item" and include
the updated items list without that item.

CANCELLATION
If customer wants to cancel: set order.intent = "cancel".

MENU BROWSING
If customer asks to see the menu or a category, show relevant available items from restaurant.menu
with names and prices. Never invent items or prices.
When showing menu choices, always number each line consistently: "1. Item name - ৳price".
If resolvedNumberedSelection is present, it is the exact current available menu item chosen from
your previous numbered list. Use that item directly, acknowledge it naturally, and ask quantity if
the customer did not provide quantity. Do not say you could not understand the numbered choice.

IMPORTANT RULES
- Never invent menu items, prices, or availability.
- Only use menuItemId values from restaurant.menu.
- Do not place the order until order.confirmed = true AND order.intent = "confirm".
- Keep replies SHORT. 2-4 lines max.
- Be warm but efficient — help them order fast.
- If customer is confused or going in circles, gently steer back: "Ki order korben seta bolun, ami help korbo."

RESPONSE FORMAT — always return valid JSON:
{
  "reply": "...",
  "order": {
    "intent": "none|draft|confirm|cancel|add_more|remove_item|show_menu",
    "items": [{"menuItemId": "...", "qty": 1}],
    "customerName": "",
    "mobileNumber": "",
    "deliveryAddress": "",
    "confirmed": false
  }
}"""


# ═══════════════════════════════════════════════════════════════════════════════
# Restaurant context
# ═══════════════════════════════════════════════════════════════════════════════

def _restaurant_context(
    outlet: Outlet,
    menu_items: list[MenuItem],
    ordering_enabled: bool,
) -> dict:
    # Group items by category so the LLM can present them cleanly
    categories: dict[str, list[dict]] = {}
    for item in menu_items[:MAX_CONTEXT_MENU_ITEMS]:
        cat = item.category_en or item.category or "General"
        categories.setdefault(cat, []).append({
            "id": item.id,
            "name": item.name_en or item.name,
            "nameBn": item.name_bn or "",
            "price": float(item.price),
        })
    return {
        "restaurantName": outlet.restaurant.name if outlet.restaurant else outlet.name,
        "outletName": outlet.name,
        "orderingEnabled": ordering_enabled,
        "orderingUrl": _menu_link(outlet),
        "menuByCategory": categories,
        # flat list kept for backward-compat / item lookup
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


# ═══════════════════════════════════════════════════════════════════════════════
# Order action handler
# ═══════════════════════════════════════════════════════════════════════════════

async def _apply_order_action(
    *,
    db: AsyncSession,
    outlet: Outlet,
    state: dict,
    action: dict,
    reply_style: str = REPLY_STYLE_BANGLISH,
    menu_items: list[MenuItem] | None = None,
) -> tuple[dict, str | None]:
    intent = str(action.get("intent") or INTENT_NONE).strip().lower()

    # ── cancel ──────────────────────────────────────────────────────────────
    if intent == INTENT_CANCEL:
        return _empty_state(), _localized_reply("cancel", reply_style)

    # ── remove_item ──────────────────────────────────────────────────────────
    if intent == INTENT_REMOVE_ITEM:
        state = _merge_state(state, action)
        conversation_state = _normalize_state(state)
        return conversation_state, None  # LLM reply handles this

    # ── add_more / show_menu — just persist state, LLM reply is used ─────────
    if intent in (INTENT_ADD_MORE, INTENT_SHOW_MENU):
        state = _merge_state(state, action)
        return _normalize_state(state), None

    # ── draft / confirm / none ───────────────────────────────────────────────
    state = _merge_state(state, action)
    lines, issue = await _validated_lines(db, outlet.id, state)
    if issue:
        state["awaitingConfirmation"] = False
        return state, _localized_reply("unavailable", reply_style)
    if not lines:
        return state, None

    totals = delivery_order_totals(lines)
    has_details = all(
        str(state.get(key) or "").strip()
        for key in ("customerName", "mobileNumber", "deliveryAddress")
    )
    confirmed = bool(action.get("confirmed")) or intent == INTENT_CONFIRM
    awaiting = bool(state.get("awaitingConfirmation"))

    # ── place order ──────────────────────────────────────────────────────────
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
        new_state = _empty_state()
        return new_state, _localized_reply(
            "success",
            reply_style,
            serial=order.serial_number,
            total=float(order.total_amount),
        )

    # ── first confirmation attempt ──────────────────────────────────────────
    if confirmed and not awaiting:
        state["awaitingConfirmation"] = True
        return state, _confirmation_reply(lines, totals, state, reply_style)

    # ── all details ready → show confirmation ───────────────────────────────
    if has_details and lines:
        state["awaitingConfirmation"] = True
        return state, _confirmation_reply(lines, totals, state, reply_style)

    # ── missing details → ask ────────────────────────────────────────────────
    state["awaitingConfirmation"] = False
    missing = [
        label
        for key, label in [
            ("customerName", "naam"),
            ("mobileNumber", "mobile number"),
            ("deliveryAddress", "delivery address"),
        ]
        if not str(state.get(key) or "").strip()
    ]
    if missing:
        return state, _missing_details_reply(missing, reply_style)
    return state, None


# ═══════════════════════════════════════════════════════════════════════════════
# State helpers
# ═══════════════════════════════════════════════════════════════════════════════

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
    menu_ids = [
        str(item.get("menuItemId") or "").strip()
        for item in items
        if isinstance(item, dict)
    ]
    menu_ids = [mid for mid in menu_ids if mid]
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
    missing = [mid for mid in menu_ids if mid not in by_id]
    if missing:
        return [], "Some selected items are no longer available."
    lines: list[DeliveryOrderLine] = []
    for raw in items:
        if not isinstance(raw, dict):
            continue
        menu_id = str(raw.get("menuItemId") or "").strip()
        item = by_id.get(menu_id)
        if item is None:
            continue
        qty = max(1, min(_safe_int(raw.get("qty"), fallback=1), 99))
        lines.append(DeliveryOrderLine(
            menu_item_id=item.id,
            name=item.name_en or item.name,
            qty=qty,
            price=float(item.price),
        ))
    return lines, None


# ═══════════════════════════════════════════════════════════════════════════════
# Reply builders
# ═══════════════════════════════════════════════════════════════════════════════

def _confirmation_reply(
    lines: list[DeliveryOrderLine], totals: dict, state: dict, reply_style: str
) -> str:
    item_lines = "\n".join(f"  • {line.qty}x {line.name} — ৳{line.qty * line.price:.0f}" for line in lines)
    total_str = f"৳{totals['total']:.0f}"
    name = state.get("customerName") or "—"
    mobile = state.get("mobileNumber") or "—"
    address = state.get("deliveryAddress") or "—"

    if reply_style == REPLY_STYLE_BN:
        return (
            f"আপনার অর্ডার একবার মিলিয়ে নিন:\n{item_lines}\n"
            f"মোট: {total_str}\n"
            f"নাম: {name} | মোবাইল: {mobile}\n"
            f"ঠিকানা: {address}\n\n"
            "কনফার্ম করতে হ্যাঁ লিখুন।"
        )
    if reply_style == REPLY_STYLE_EN:
        return (
            f"Please confirm your order:\n{item_lines}\n"
            f"Total: {total_str}\n"
            f"Name: {name} | Mobile: {mobile}\n"
            f"Address: {address}\n\n"
            "Reply yes to confirm."
        )
    return (
        f"Order-ta ektu check koren:\n{item_lines}\n"
        f"Total: {total_str}\n"
        f"Naam: {name} | Mobile: {mobile}\n"
        f"Address: {address}\n\n"
        "Confirm korte 'hae' likhun."
    )


def _missing_details_reply(missing: list[str], reply_style: str) -> str:
    bn_labels = {"name": "নাম", "naam": "নাম", "mobile number": "মোবাইল নম্বর", "delivery address": "ডেলিভারি ঠিকানা"}
    if reply_style == REPLY_STYLE_BN:
        return "ডেলিভারির জন্য আপনার " + ", ".join(bn_labels[i] for i in missing) + " দিন।"
    if reply_style == REPLY_STYLE_EN:
        en_labels = {"name": "name", "naam": "name", "mobile number": "mobile number", "delivery address": "delivery address"}
        return "Please share your " + ", ".join(en_labels[i] for i in missing) + " for delivery."
    return "Delivery-r jonno apnar " + ", ".join(missing) + " deben?"


def _localized_reply(kind: str, reply_style: str, **values: Any) -> str:
    replies: dict[str, dict[str, str]] = {
        "cancel": {
            REPLY_STYLE_BANGLISH: "Thik ache, order-ta cancel kore dilam. Ar kichu lagbe?",
            REPLY_STYLE_BN: "ঠিক আছে, অর্ডারটি বাতিল করা হয়েছে। আর কিছু লাগবে?",
            REPLY_STYLE_EN: "Done, I've cancelled your order. Anything else?",
        },
        "unavailable": {
            REPLY_STYLE_BANGLISH: "Kichhu item ekhon available nei. Current menu theke choose korben?",
            REPLY_STYLE_BN: "কিছু আইটেম এখন পাওয়া যাচ্ছে না। বর্তমান মেনু থেকে বেছে নিন।",
            REPLY_STYLE_EN: "Some items are no longer available. Please choose from the current menu.",
        },
        "success": {
            REPLY_STYLE_BANGLISH: "Order confirmed! Apnar order number #{serial}. Total: ৳{total:.0f}. Ar kichu lagbe?",
            REPLY_STYLE_BN: "অর্ডার নিশ্চিত! অর্ডার নম্বর #{serial}। মোট: ৳{total:.0f}। আর কিছু লাগবে?",
            REPLY_STYLE_EN: "Order confirmed! Your order #{serial}. Total: ৳{total:.0f}. Anything else?",
        },
        "general": {
            REPLY_STYLE_BANGLISH: "Menu ba delivery order niye ki help korte pari?",
            REPLY_STYLE_BN: "মেনু বা ডেলিভারি অর্ডার নিয়ে কিভাবে সাহায্য করতে পারি?",
            REPLY_STYLE_EN: "How can I help you with the menu or a delivery order?",
        },
    }
    return replies[kind][reply_style].format(**values)


# ═══════════════════════════════════════════════════════════════════════════════
# Language detection & style checks
# ═══════════════════════════════════════════════════════════════════════════════

def _detect_reply_style(text: str) -> str:
    if re.search(r"[\u0980-\u09ff]", text):
        return REPLY_STYLE_BN
    words = set(re.findall(r"[a-z]+", text.lower()))
    if words & BANGLISH_WORDS:
        return REPLY_STYLE_BANGLISH
    if words & ENGLISH_WORDS:
        return REPLY_STYLE_EN
    return REPLY_STYLE_BANGLISH


def _reply_needs_rewrite(reply: str, reply_style: str) -> bool:
    clean = reply.strip()
    if not clean:
        return True
    if reply_style != REPLY_STYLE_BANGLISH:
        return False
    lower = clean.lower()
    # disallowed openers
    for opener in BANGLISH_DISALLOWED_OPENERS:
        if lower.startswith(opener):
            return True
    # emoji
    if re.search(r"[\U0001F300-\U0001FAFF]", clean):
        return True
    # too much English
    words = re.findall(r"[a-z]+", lower)
    english_markers = sum(w in BANGLISH_ENGLISH_MARKERS for w in words)
    banglish_markers = sum(w in BANGLISH_WORDS for w in words)
    return english_markers >= 3 and english_markers > banglish_markers


# ═══════════════════════════════════════════════════════════════════════════════
# Send message
# ═══════════════════════════════════════════════════════════════════════════════

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


# ═══════════════════════════════════════════════════════════════════════════════
# Misc utilities
# ═══════════════════════════════════════════════════════════════════════════════

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
        "selectedMenuItemId": str(state.get("selectedMenuItemId") or "").strip(),
        "history": state.get("history") if isinstance(state.get("history"), list) else [],
    }


def _empty_state() -> dict:
    return {
        "items": [],
        "customerName": "",
        "mobileNumber": "",
        "deliveryAddress": "",
        "awaitingConfirmation": False,
        "selectedMenuItemId": "",
        "history": [],
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


def _menu_link_reply(outlet: Outlet, reply_style: str = REPLY_STYLE_BANGLISH) -> str:
    link = _menu_link(outlet)
    if reply_style == REPLY_STYLE_BN:
        return f"এখানে মেনু দেখে অর্ডার করতে পারেন: {link}"
    if reply_style == REPLY_STYLE_EN:
        return f"You can view the menu and order here: {link}"
    return f"Ekhane menu dekhe order korte paren: {link}"
