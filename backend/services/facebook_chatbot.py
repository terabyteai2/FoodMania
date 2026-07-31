import asyncio
import json
import logging
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
from database import AsyncSessionLocal
from models import ChatbotConversation, ChatbotIntegration, ChatbotOAuthSession, MenuItem, Outlet
from routers.ws import manager
from services.customer_orders import (
    DeliveryOrderLine,
    create_delivery_order,
    delivery_order_totals,
)
from services.order_serial import format_serial

logger = logging.getLogger(__name__)

FACEBOOK_PROVIDER = "facebook"
FACEBOOK_ORDER_SOURCE = "facebook_messenger"
FACEBOOK_OAUTH_STATE_TYPE = "facebook_chatbot_oauth"
FACEBOOK_OAUTH_CALLBACK_PATH = "/admin/chatbot/facebook/oauth/callback"
GRAPH_TIMEOUT_SECONDS = 8.0
GROQ_TIMEOUT_SECONDS = 30.0
DEEPSEEK_TIMEOUT_SECONDS = 45.0
MAX_REPLY_CHARS = 1900
BATCH_WAIT_SECONDS = 4.0
BATCH_MAX_SIZE = 5
BATCH_LLM_MAX_TOKENS = 6000
CHAT_HISTORY_CONTEXT_LIMIT = 10
CHAT_HISTORY_APP_LIMIT = 10

# LLM session lifecycle — after this many batches, restart the context
# to prevent the restaurant setup from getting lost in the window.
SESSION_BATCH_LIMIT = 12
MAX_HISTORY_FOR_NEW = 5


_chatbot_queue: asyncio.Queue = asyncio.Queue()
_batch_worker_task: asyncio.Task | None = None


class ChatbotError(RuntimeError):
    pass


def _chat_history(value: Any) -> list:
    return list(value) if isinstance(value, list) else []


def recent_chat_history(value: Any, *, limit: int = CHAT_HISTORY_APP_LIMIT) -> list[dict]:
    entries = [entry for entry in _chat_history(value) if isinstance(entry, dict)]
    if limit <= 0:
        return entries
    return entries[-limit:]


def append_chat_history(
    conversation: ChatbotConversation,
    *,
    role: str,
    text: str,
    kind: str | None = None,
) -> None:
    entry = {
        "role": role,
        "text": text,
        "at": datetime.now(timezone.utc).isoformat(),
    }
    if kind:
        entry["kind"] = kind
    history = _chat_history(conversation.history_json)
    history.append(entry)
    conversation.history_json = history


def _conversation_status(conversation: ChatbotConversation) -> str:
    state = conversation.state_json or {}
    value = str(state.get("status") or "").strip().lower()
    return value if value in {"needs", "replied", "bot"} else "bot"


def _conversation_unread(conversation: ChatbotConversation) -> int:
    state = conversation.state_json or {}
    try:
        return int(state.get("unread") or 0)
    except (TypeError, ValueError):
        return 0


def chat_update_payload(conversation: ChatbotConversation) -> dict:
    return {
        "conversationId": conversation.id,
        "status": _conversation_status(conversation),
        "unread": _conversation_unread(conversation),
        "updatedAt": conversation.updated_at.isoformat(),
    }


async def broadcast_chat_update(
    integration: ChatbotIntegration,
    conversation: ChatbotConversation,
) -> None:
    await manager.broadcast(
        integration.outlet_id,
        {"type": "chat_updated", "data": chat_update_payload(conversation)},
    )


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
    scopes = [scope.strip() for scope in settings.FACEBOOK_LOGIN_SCOPES.split(",")]
    scopes = [scope for scope in scopes if scope]
    if not scopes:
        scopes = ["pages_show_list", "pages_manage_metadata", "pages_messaging"]
    return ",".join(scopes)


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
    result = {"authorizationUrl": url, "expiresInSeconds": expires_in}
    client_token = settings.FACEBOOK_ANDROID_CLIENT_TOKEN.strip()
    if client_token:
        result["nativeAndroid"] = {
            "appId": app_id,
            "clientToken": client_token,
            "scopes": _facebook_login_scopes().split(","),
        }
    return result


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
        {
            "fields": "id,name,access_token",
            "access_token": user_access_token,
        },
        "Could not read Facebook Pages for this account.",
    )
    pages = payload.get("data")
    if not isinstance(pages, list):
        return []
    return [page for page in pages if isinstance(page, dict)]


def _selectable_facebook_pages(pages: list[dict[str, Any]]) -> list[dict[str, Any]]:
    selectable = []
    for page in pages:
        page_id = str(page.get("id") or "").strip()
        token = str(page.get("access_token") or "").strip()
        if page_id and token:
            selectable.append(
                {
                    "pageId": page_id,
                    "pageName": str(page.get("name") or "").strip() or None,
                    "pageAccessToken": token,
                }
            )
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


async def complete_facebook_oauth(
    *,
    db: AsyncSession,
    state_token: str,
    code: str,
) -> dict:
    state_payload = _decode_facebook_oauth_state(state_token)
    outlet_id = str(state_payload["sub"]).strip()
    account_id = str(state_payload.get("account_id") or "").strip()
    if not account_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Facebook Login state is missing the manager account.",
        )
    short_token = await _exchange_code_for_user_token(code.strip())
    return await _create_facebook_oauth_session(
        db=db,
        outlet_id=outlet_id,
        account_id=account_id,
        user_access_token=short_token,
    )


async def complete_facebook_native_oauth(
    *,
    db: AsyncSession,
    outlet_id: str,
    account_id: str,
    user_access_token: str,
) -> dict:
    clean_token = user_access_token.strip()
    if not clean_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Facebook Login did not return a user access token.",
        )
    return await _create_facebook_oauth_session(
        db=db,
        outlet_id=outlet_id,
        account_id=account_id,
        user_access_token=clean_token,
    )


async def _create_facebook_oauth_session(
    *,
    db: AsyncSession,
    outlet_id: str,
    account_id: str,
    user_access_token: str,
) -> dict:
    user_token = await _exchange_long_lived_user_token(user_access_token)
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
            {"pageId": page["pageId"], "pageName": page.get("pageName")}
            for page in session.pages_json
        ],
    }


async def get_latest_facebook_oauth_pages(
    db: AsyncSession,
    *,
    outlet_id: str,
    account_id: str,
) -> dict | None:
    session = (
        await db.execute(
            select(ChatbotOAuthSession)
            .where(
                ChatbotOAuthSession.provider == FACEBOOK_PROVIDER,
                ChatbotOAuthSession.outlet_id == outlet_id,
                ChatbotOAuthSession.account_id == account_id,
                ChatbotOAuthSession.expires_at > datetime.now(timezone.utc),
            )
            .order_by(ChatbotOAuthSession.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    if session is None:
        return None
    return {
        "sessionId": session.id,
        "pages": [
            {"pageId": page["pageId"], "pageName": page.get("pageName")}
            for page in session.pages_json
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
        (candidate for candidate in session.pages_json if candidate["pageId"] == page_id),
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


async def _ensure_facebook_page_available(
    db: AsyncSession,
    outlet_id: str,
    page_id: str,
) -> None:
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

    # The LLM is text-only and cannot see images, videos, files, or shared
    # posts/links. Describe any attachment in words so both the manager (in the
    # Messages UI) and the LLM (in history) know what arrived. Combine it with
    # the customer's own text so a "is this available?" + photo stays intact.
    attachment_note = _describe_attachments(message)
    if attachment_note:
        text = f"{text} {attachment_note}".strip() if text else attachment_note
    if not text:
        text = "[Customer sent a non-text message]"

    conversation = await _get_conversation(db, integration, psid)
    conversation.last_user_message = text
    append_chat_history(conversation, role="user", text=text)
    conversation.updated_at = datetime.now(timezone.utc)
    integration.updated_at = datetime.now(timezone.utc)
    integration.last_error = None

    # When a manager has taken over the thread — escalated ('needs') or actively
    # replying ('replied') — the bot must NOT auto-respond. Record the inbound
    # message and bump unread so it surfaces in Messages, then stop. The manager
    # hands the thread back to the bot (status -> 'bot') when done.
    control_status = str((conversation.state_json or {}).get("status") or "").strip().lower()
    if control_status in {"needs", "replied"}:
        state = dict(conversation.state_json or {})
        state["unread"] = int(state.get("unread") or 0) + 1
        conversation.state_json = state
        await db.commit()
        await broadcast_chat_update(integration, conversation)
        return

    await db.commit()
    await broadcast_chat_update(integration, conversation)

    await _chatbot_queue.put({
        "conversation_id": conversation.id,
        "text": text,
    })


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


def _describe_attachments(message: dict | None) -> str:
    """Turn Facebook message attachments into a short text note.

    The LLM cannot see media, so we record what kind of attachment arrived (and
    a URL for the manager to open where Facebook provides one). The bot uses this
    to decide whether to escalate; the manager uses it to know an image/post was
    sent and to describe it back into the conversation.
    """
    if not message:
        return ""
    attachments = message.get("attachments")
    if not isinstance(attachments, list) or not attachments:
        return ""

    notes: list[str] = []
    for attachment in attachments:
        if not isinstance(attachment, dict):
            continue
        a_type = str(attachment.get("type") or "").strip().lower()
        payload = attachment.get("payload") if isinstance(attachment.get("payload"), dict) else {}
        url = str(payload.get("url") or attachment.get("url") or "").strip()
        title = str(attachment.get("title") or payload.get("title") or "").strip()
        if a_type == "image":
            # Stickers also arrive as images; they carry a sticker_id.
            if payload.get("sticker_id") or message.get("sticker_id"):
                notes.append("[Customer sent a sticker]")
            else:
                notes.append(_media_note("an image the bot cannot see", url))
        elif a_type == "video":
            notes.append(_media_note("a video the bot cannot see", url))
        elif a_type == "audio":
            notes.append(_media_note("a voice/audio message the bot cannot hear", url))
        elif a_type == "file":
            notes.append(_media_note("a file the bot cannot read", url))
        elif a_type == "location":
            notes.append("[Customer shared a location]")
        else:
            # "fallback" = a shared Facebook post or external link.
            shared = " ".join(part for part in (title, url) if part).strip()
            notes.append(
                f"[Customer shared a post/link the bot cannot open: {shared}]"
                if shared
                else "[Customer shared a post/link the bot cannot open]"
            )
    return " ".join(notes).strip()


def _media_note(what: str, url: str) -> str:
    if url:
        return f"[Customer sent {what} — view it in the Page inbox: {url}]"
    return f"[Customer sent {what} — view it in the Page inbox]"


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


def _build_restaurant_setup(
    outlet: Outlet,
    menu_items: list[MenuItem],
    ordering_enabled: bool,
) -> dict:
    """Restaurant-only setup context — no chat history, no conversation state.

    Sent once per LLM session to prime the model with restaurant details.
    Subsequent batch messages omit this and only carry conversation data.
    """
    return {
        "type": "setup",
        "restaurantName": outlet.restaurant.name if outlet.restaurant else outlet.name,
        "outletName": outlet.name,
        "orderingEnabled": ordering_enabled,
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
            .limit(300)
        )
    ).scalars().all()


async def _apply_order_action(
    *,
    db: AsyncSession,
    outlet: Outlet,
    state: dict,
    action: dict,
) -> tuple[dict, dict | None]:
    intent = str(action.get("intent") or "none").strip().lower()
    if intent == "cancel":
        return _empty_state(), {"type": "order_cancelled"}

    state = _merge_state(state, action)
    lines, issue = await _validated_lines(db, outlet.id, state)
    if issue:
        state["awaitingConfirmation"] = False
        return state, {"type": "validation_failed", "reason": issue}
    
    if not lines:
        return state, None

    totals = delivery_order_totals(lines)
    has_details = all(
        str(state.get(key) or "").strip()
        for key in ("customerName", "mobileNumber", "deliveryAddress")
    )
    confirmed = bool(action.get("confirmed")) or intent == "confirm"
    awaiting = bool(state.get("awaitingConfirmation"))

    if confirmed and has_details:
        if awaiting or intent == "confirm":
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
            return _empty_state(), {
                "type": "order_created",
                "orderNumber": format_serial(
                    order.serial_number, order.source, order.created_by_role
                ),
                "totalAmount": float(order.total_amount),
            }
        state["awaitingConfirmation"] = True
        return state, {
            "type": "needs_confirmation",
            "items": [{"name": l.name, "qty": l.qty} for l in lines],
            "total": totals["total"],
        }

    if has_details:
        state["awaitingConfirmation"] = True
        return state, {
            "type": "needs_confirmation",
            "items": [{"name": l.name, "qty": l.qty} for l in lines],
            "total": totals["total"],
        }

    state["awaitingConfirmation"] = False
    missing = [
        key
        for key in ("customerName", "mobileNumber", "deliveryAddress")
        if not str(state.get(key) or "").strip()
    ]
    if missing:
        return state, {"type": "missing_details", "missing": missing}
    
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
            if next_state.get("awaitingConfirmation"):
                next_state["awaitingConfirmation"] = False
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
        return [], "items_unavailable"
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


async def _send_message(integration: ChatbotIntegration, psid: str, text: str) -> None:
    if not text:
        return
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
        raise ChatbotError("LLM returned invalid JSON.") from error
    if not isinstance(parsed, dict):
        raise ChatbotError("LLM response must be a JSON object.")
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


def _last_bot_message(history: Any) -> str | None:
    """Return the last bot message from history, or None if never replied."""
    entries = [e for e in _chat_history(history) if isinstance(e, dict) and e.get("role") == "bot"]
    if not entries:
        return None
    last = entries[-1].get("text", "")
    return str(last).strip() or None


def _empty_state() -> dict:
    return {
        "items": [],
        "customerName": "",
        "mobileNumber": "",
        "deliveryAddress": "",
        "awaitingConfirmation": False,
    }


# Bot-escalation reasons. Labels mirror the spec's Chat.reason values so the
# Messages UI can map them; 'needs' status routes the chat to the manager.
_ESCALATION_REASON_LABELS = {
    "photo_request": "Photo requested",
    "delivery_quote": "Delivery quote",
    "catering": "Catering ask",
    "other": "Needs your help",
}


def _safe_int(value: Any, *, fallback: int) -> int:
    if isinstance(value, int):
        return value
    try:
        return int(str(value))
    except (TypeError, ValueError):
        return fallback


# ── Micro‑batching ─────────────────────────────────────────────────────────────


def start_batch_worker() -> None:
    global _batch_worker_task
    if _batch_worker_task is None or _batch_worker_task.done():
        _batch_worker_task = asyncio.create_task(_batch_worker_loop())


async def stop_batch_worker() -> None:
    global _batch_worker_task
    if _batch_worker_task is not None and not _batch_worker_task.done():
        _batch_worker_task.cancel()
        try:
            await _batch_worker_task
        except asyncio.CancelledError:
            pass
        _batch_worker_task = None


async def _batch_worker_loop() -> None:
    while True:
        try:
            batch = []
            try:
                item = await asyncio.wait_for(
                    _chatbot_queue.get(), timeout=BATCH_WAIT_SECONDS
                )
                batch.append(item)
            except asyncio.TimeoutError:
                continue

            while len(batch) < BATCH_MAX_SIZE and not _chatbot_queue.empty():
                try:
                    batch.append(_chatbot_queue.get_nowait())
                except asyncio.QueueEmpty:
                    break

            await _process_batch(batch)
        except asyncio.CancelledError:
            break
        except Exception as exc:
            logger.exception("batch worker error: %s", exc)


async def _process_batch(batch: list[dict]) -> None:
    grouped: dict[str, dict] = {}
    for item in batch:
        grouped[item["conversation_id"]] = item

    async with AsyncSessionLocal() as db:
        conv_ids = list(grouped.keys())
        result = await db.execute(
            select(ChatbotConversation)
            .where(ChatbotConversation.id.in_(conv_ids))
            .options(
                joinedload(ChatbotConversation.integration)
                .joinedload(ChatbotIntegration.outlet)
                .joinedload(Outlet.restaurant)
            )
        )
        conversations = result.scalars().all()
        conv_map: dict[str, ChatbotConversation] = {c.id: c for c in conversations}

        outlet_ids = {
            c.integration.outlet_id
            for c in conversations
            if c.integration is not None
        }

        menu_map: dict[str, list[MenuItem]] = {}
        for oid in outlet_ids:
            menu_map[oid] = await _available_menu_items(db, oid)

        # ── Per-outlet session check ──────────────────────────────────────
        # Track batch count per outlet for session refresh.
        needs_reset_map: dict[str, bool] = {}
        for conv in conversations:
            if conv.integration is None:
                continue
            integration = conv.integration
            if integration.outlet_id not in needs_reset_map:
                needs_reset_map[integration.outlet_id] = (
                    integration.llm_batch_count >= SESSION_BATCH_LIMIT
                    or integration.llm_session_started_at is None
                )

        # ── Build per-conversation payload ────────────────────────────────
        llm_conversations: list[dict] = []
        for conv_id, item in grouped.items():
            conv = conv_map.get(conv_id)
            if conv is None or conv.integration is None:
                logger.warning("batch skipping unknown conversation %s", conv_id)
                continue
            integration = conv.integration
            outlet = integration.outlet
            state = _normalize_state(conv.state_json)

            entry: dict = {
                "id": conv_id,
                "customerMessage": item["text"],
                "conversationState": state,
                "setup": _build_restaurant_setup(
                    outlet, menu_map.get(outlet.id, []), integration.ordering_enabled
                ),
                "recentHistory": recent_chat_history(
                    conv.history_json, limit=MAX_HISTORY_FOR_NEW
                ),
            }

            llm_conversations.append(entry)

        if not llm_conversations:
            return

        logger.info(
            "LLM request: %d conversations, setup=%s",
            len(llm_conversations),
            any("setup" in c for c in llm_conversations),
        )
        logger.debug(
            "LLM request payload: %s",
            json.dumps({"conversations": llm_conversations}, ensure_ascii=False),
        )

        try:
            llm_response = await _call_batched_llm(
                llm_conversations, _batched_system_prompt()
            )
        except ChatbotError:
            logger.exception(
                "batched LLM call failed for %d conversations", len(llm_conversations)
            )
            return

        responses = llm_response.get("responses") if isinstance(llm_response, dict) else []
        logger.info("LLM response: %d responses", len(responses))
        logger.debug(
            "LLM response body: %s",
            json.dumps(llm_response, ensure_ascii=False),
        )
        if not isinstance(responses, list):
            logger.warning("batched LLM returned non-list responses: %r", responses)
            responses = []

        # ── Persist session checkpoint per outlet ─────────────────────────
        counted_outlets: set[str] = set()
        for conv in conversations:
            if conv.integration is None:
                continue
            oid = conv.integration.outlet_id
            if oid in counted_outlets:
                continue
            counted_outlets.add(oid)
            integration = conv.integration
            if needs_reset_map.get(oid):
                integration.llm_session_started_at = datetime.now(timezone.utc)
                integration.llm_batch_count = 1
            else:
                integration.llm_batch_count = (integration.llm_batch_count or 0) + 1

        conversations_needing_final_reply = []
        conversations_with_immediate_replies = []

        for resp in responses:
            if not isinstance(resp, dict):
                continue
            resp_id = resp.get("id")
            conv = conv_map.get(resp_id)
            if conv is None or conv.integration is None:
                continue
            integration = conv.integration
            outlet = integration.outlet
            state = _normalize_state(conv.state_json)

            reply = str(resp.get("reply") or "").strip()
            reply_type = str(resp.get("replyType") or "chat").strip().lower()
            order_action = resp.get("order") if isinstance(resp.get("order"), dict) else {}

            # Escalation takes precedence.
            escalate = resp.get("escalate") if isinstance(resp.get("escalate"), dict) else {}
            if bool(escalate.get("needed")):
                reason_code = str(escalate.get("reason") or "other").strip().lower()
                reason_label = _ESCALATION_REASON_LABELS.get(
                    reason_code, _ESCALATION_REASON_LABELS["other"]
                )
                conv.state_json = {**state, "status": "needs", "reason": reason_label}
                conv.last_bot_message = (
                    reply or "আমি টিমের সাথে কথা বলে একটু পরেই জানাচ্ছি।"
                )
                append_chat_history(
                    conv,
                    role="system",
                    text=f"⚠ Chatbot needs your help · {reason_label}",
                )
                append_chat_history(conv, role="bot", text=conv.last_bot_message)
                conv.updated_at = datetime.now(timezone.utc)
                conversations_with_immediate_replies.append(conv)
                continue

            # Only process order actions when replyType is "action".
            if (
                reply_type == "action"
                and integration.ordering_enabled
                and order_action
            ):
                state, system_event = await _apply_order_action(
                    db=db, outlet=outlet, state=state, action=order_action,
                )
                conv.state_json = state

                if system_event and system_event.get("type") in (
                    "order_created", "validation_failed",
                ):
                    conv.state_json["systemEvent"] = system_event
                    conversations_needing_final_reply.append(conv)
                else:
                    conv.last_bot_message = reply or "..."
            else:
                conv.state_json = state
                conv.last_bot_message = reply or "..."

            if conv not in conversations_needing_final_reply:
                append_chat_history(conv, role="bot", text=conv.last_bot_message)
                conversations_with_immediate_replies.append(conv)

            conv.updated_at = datetime.now(timezone.utc)

        await db.commit()

        for conv in conversations_with_immediate_replies:
            if conv.integration is not None:
                await broadcast_chat_update(conv.integration, conv)

        if conversations_needing_final_reply:
            final_replies = await _generate_final_replies_batch(
                conversations_needing_final_reply, menu_map
            )
            for conv in conversations_needing_final_reply:
                final_reply = final_replies.get(conv.id)
                if final_reply:
                    conv.last_bot_message = final_reply
                else:
                    conv.last_bot_message = "..."

                append_chat_history(conv, role="bot", text=conv.last_bot_message)
            await db.commit()

            for conv in conversations_needing_final_reply:
                if conv.integration is not None:
                    await broadcast_chat_update(conv.integration, conv)

        for resp in responses:
            if not isinstance(resp, dict):
                continue
            resp_id = resp.get("id")
            conv = conv_map.get(resp_id)
            if conv is None or conv.integration is None:
                continue
            try:
                await _send_message(
                    conv.integration, conv.psid, conv.last_bot_message or ""
                )
            except ChatbotError as exc:
                logger.warning(
                    "batch send failed conv=%s psid=%s error=%s",
                    conv.id, conv.psid, exc,
                )


async def _generate_final_replies_batch(
    conversations: list[ChatbotConversation], 
    menu_map: dict[str, list[MenuItem]]
) -> dict[str, str]:
    if not conversations:
        return {}

    llm_payload = []
    for conv in conversations:
        state = conv.state_json
        system_event = state.get("systemEvent", {})
        entry: dict = {
            "id": conv.id,
            "systemEvent": system_event,
            "conversationState": state,
        }
        # Only include restaurant name (not full menu) for event reply context.
        outlet = conv.integration.outlet
        if outlet:
            entry["restaurantName"] = outlet.restaurant.name if outlet.restaurant else outlet.name
        llm_payload.append(entry)

    logger.info("Final-reply LLM request: %d conversations", len(llm_payload))
    logger.debug(
        "Final-reply LLM payload: %s",
        json.dumps({"conversations": llm_payload}, ensure_ascii=False),
    )

    try:
        llm_response = await _call_batched_llm(llm_payload, _final_reply_system_prompt())
    except ChatbotError:
        logger.exception("final reply LLM call failed")
        return {}

    responses = llm_response.get("responses") if isinstance(llm_response, dict) else []
    result = {}
    if isinstance(responses, list):
        for resp in responses:
            if isinstance(resp, dict) and "id" in resp and "reply" in resp:
                result[str(resp["id"])] = str(resp["reply"]).strip()
    logger.info("Final-reply LLM response: %d replies", len(result))
    logger.debug(
        "Final-reply LLM response body: %s",
        json.dumps(llm_response, ensure_ascii=False),
    )
    return result


async def _call_batched_llm(conversations: list[dict], system_prompt: str) -> dict:
    api_key = settings.DEEPSEEK_API_KEY.strip()
    model = settings.CHATBOT_DEEPSEEK_MODEL.strip()
    if not api_key or not model:
        raise ChatbotError("DeepSeek is not configured for batch.")
    url = "https://api.deepseek.com/v1/chat/completions"

    messages = [
        {"role": "system", "content": system_prompt},
        {
            "role": "user",
            "content": json.dumps({"conversations": conversations}, ensure_ascii=False),
        },
    ]
    try:
        async with httpx.AsyncClient(timeout=DEEPSEEK_TIMEOUT_SECONDS) as client:
            response = await client.post(
                url,
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": model,
                    "messages": messages,
                    "temperature": 0.3,
                    "max_tokens": min(BATCH_LLM_MAX_TOKENS, 800 * max(len(conversations), 1)),
                    "response_format": {"type": "json_object"},
                },
            )
            response.raise_for_status()
            payload = response.json()
    except httpx.HTTPError as error:
        raise ChatbotError("DeepSeek batched chatbot request failed.") from error

    content = (
        ((payload.get("choices") or [{}])[0].get("message") or {}).get("content")
        if isinstance(payload, dict)
        else None
    )
    if not isinstance(content, str) or not content.strip():
        raise ChatbotError("DeepSeek returned an empty batched chatbot response.")
    return _parse_json_object(content)


def _batched_system_prompt() -> str:
    return (
        "You are an advanced AI assistant processing multiple simultaneous Facebook Messenger "
        "conversations for a restaurant POS system. \n\n"
        "### CORE DIRECTIVES\n"
        "1. LANGUAGE & TONE: Write only in bangla language Match the customer's tone and style. "
        " Be natural, brief, and conversational. \n"
        "2. BATCH PROCESSING: You will receive a JSON object containing an array of independent "
        "\"conversations\". You MUST process EVERY conversation in the array and return a response "
        "for EACH one. Do not mix up the context between different conversations.\n\n"
        "### FULL CONTEXT\n"
        "Each conversation entry always includes:\n"
        "- \"setup\": The restaurant's full context (name, menu with prices, delivery chargee). "
        "Use this to answer menu questions and calculate totals.\n"
        "- \"recentHistory\": The last few exchanges between the customer and the bot/manager. "
        "Each entry has a \"role\": \"user\" (customer), \"bot\" (you), \"manager\" (human staff), "
        "or \"system\" (internal notes).\n\n"
        "### HISTORY ROLES\n"
        "- \"manager\" messages are AUTHORITATIVE human notes. Trust them completely and act on "
        "them: they tell you what is available, real prices, current offers/deals, and what an "
        "image or shared post the customer sent actually is. If a manager said something is "
        "available or described a dish/offer, treat it as ground truth and help the customer "
        "accordingly (e.g. add that item, apply that offer).\n\n"
        "### IMAGES, POSTS & ATTACHMENTS\n"
        "- You are TEXT-ONLY. You cannot see images, photos, videos, files, or shared posts/links. "
        "These arrive in the message as a bracketed note like '[Customer sent an image the bot "
        "cannot see ...]'.\n"
        "- If the customer shares such media AND their request depends on its content (e.g. \"এটা "
        "আছে?\", \"is this available?\", \"how much is this?\") AND there is NO \"manager\" note in "
        "the history that already explains it, then ESCALATE (see below) with reason "
        "\"photo_request\". Do NOT guess what the image shows.\n"
        "- If a \"manager\" note in the history already explains the image/post, use that note to "
        "answer and continue normally. Do NOT escalate again.\n"
        "- A pure sticker, emoji, or thumbs-up needs no escalation — just reply naturally.\n\n"
        "### MENU & GENERAL CHAT\n"
        "- Answer questions about menu items, prices, categories, or the restaurant naturally. "
        "The full menu with prices is always in the \"setup\" field — refer to it directly.\n"
        "- If the customer goes off-topic, respond naturally in Bangla while preserving their "
        "current order state.\n\n"
        "### ORDERING RULES (Delivery Only)\n"
        "- You OWN the whole ordering conversation. Using the setup, conversationState, "
        "and recentHistory, YOU collect everything and write every message yourself in "
        "\"reply\".\n"
        "- Goal: Collect menu items (with quantities), customerName, mobileNumber, and "
        "deliveryAddress.\n"
        "- Items: Customers can add, remove, or change items freely. \n"
        "- Quantities: MANDATORY. You must ensure every item has a quantity. If the user doesn't "
        "specify, assume 1 or ask politely, but the final JSON must always have a valid integer "
        "for \"qty\".\n"
        "- Customer Details: Politely ask for any of the three details (name, mobile, address) "
        "that are still missing in conversationState. Ask naturally in your \"reply\".\n"
        "- Confirmation: Once you have AT LEAST ONE item AND all three customer details, "
        "summarize the cart in your \"reply\" (in the customer's language) and ask them to confirm. Compute "
        "the total as (sum of price×qty) + vatRatePercent% VAT + deliveryCharge so it matches "
        "the final bill. \n"
        "- Affirmative: If they reply with an affirmative (e.g., \"হ্যাঁ\", \"yes\", \"confirm\", "
        "\"ঠিক আছে\"), set \"order\".\"intent\" to \"confirm\", \"order\".\"confirmed\" to true, "
        "replyType to \"action\", and write a warm \"reply\" confirming you are placing it (the "
        "system adds the order number after).\n"
        "- Cancellation: If they want to cancel, set \"order\".\"intent\" to \"cancel\" and "
        "acknowledge it in your \"reply\".\n\n"
        "### replyType — TWO RESPONSE MODES\n"
        "Every response MUST include a \"replyType\" field that tells the backend how to handle it:"
        "\n\n"
        "1. **\"chat\"** — Normal conversation. The LLM is just chatting. No backend order "
        "processing needed. The \"order\" field should be null or empty.\n"
        "   Use this for: greetings, answering questions, casual chat, declining to order.\n\n"
        "2. **\"action\"** — The LLM wants the backend to DO something with the order. The "
        "\"order\" field will be processed (create/update order, confirm, cancel).\n"
        "   Use this for: adding items, confirming an order, cancelling, updating customer "
        "details.\n\n"
        "### ESCALATION (hand off to a human manager)\n"
        "- Some requests you CANNOT reliably fulfill. When the customer asks for any of the "
        "following, you MUST escalate to a human instead of guessing or refusing:\n"
        "  1. Anything about an image/photo/video/post the customer sent that you cannot see (see "
        "IMAGES section) — reason \"photo_request\".\n"
        "  2. A delivery charge/quote for a far or unknown area you have no fixed price for — "
        "reason \"delivery_quote\".\n"
        "  3. Catering, bulk, event, or custom orders (large party, special menu) — reason "
        "\"catering\".\n"
        "- To escalate: set \"escalate\".\"needed\" to true with the matching \"reason\", and write a "
        "short, warm holding \"reply\" (in the customer's language) telling them you're checking with the team "
        "and will get back shortly. Do NOT invent a photo, price, or promise.\n"
        "- For anything you can answer normally (including when a manager note already covers it), "
        "set \"escalate\".\"needed\" to false.\n\n"
        "### OUTPUT FORMAT\n"
        "You MUST return ONLY a valid JSON object. No markdown formatting (no ```json), no "
        "explanations, no extra text. \n"
        "The JSON must strictly follow this exact schema:\n\n"
        "{\n"
        '  "responses": [\n'
        "    {\n"
        '      "id": "<EXACT conversation id from the input>",\n'
        '      "replyType": "<chat | action>",\n'
        '      "reply": "<Your natural reply matching the customer language>",\n'
        '      "escalate": {\n'
        '        "needed": <boolean>,\n'
        '        "reason": "<photo_request | delivery_quote | catering | other>"\n'
        "      },\n"
        '      "order": <null or {\n'
        '        "intent": "<none | draft | confirm | cancel>",\n'
        '        "items": [\n'
        '          {"menuItemId": "<EXACT id from the restaurant menu>", "qty": <integer>}\n'
        "        ],\n"
        '        "customerName": "<string or empty>",\n'
        '        "mobileNumber": "<string or empty>",\n'
        '        "deliveryAddress": "<string or empty>",\n'
        '        "confirmed": <boolean>\n'
        "      }>\n"
        "    }\n"
        "  ]\n"
        "}"
    )


def _final_reply_system_prompt() -> str:
    return (
        "You are generating the final text reply for a Facebook Messenger restaurant bot. "
        "The system has processed the user's intent and updated the conversation state. "
        "Write only in bangla language Match the customer's tone and style. "
        " Be natural, brief, and conversational.\n\n"
        "Each input item includes the 'systemEvent' and 'conversationState'. "
        "Based on the 'systemEvent' in the input, generate the appropriate message:\n"
        "- 'order_created': Congratulate the user, mention the order number (orderNumber) and total amount (totalAmount).\n"
        "- 'validation_failed': Inform the user that some items are unavailable (reason) and ask them to choose again.\n\n"
        "Return ONLY a JSON object with a 'responses' array: \n"
        "{\"responses\": [{\"id\": \"<conversation id>\", \"reply\": \"<your natural reply>\"}]}"
    )
