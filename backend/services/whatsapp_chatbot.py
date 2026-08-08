"""WhatsApp Business API (Meta Cloud API) chatbot channel.

Reuses the shared chatbot pipeline in `services/facebook_chatbot.py` — the
conversation storage, the micro-batching LLM worker, the ordering state
machine, and escalation to the manager inbox. This module only adapts the
WhatsApp webhook / Graph API / credential-setup specifics.

WhatsApp integrations reuse `ChatbotIntegration` with:
  provider = "whatsapp"
  page_id  = WhatsApp Phone Number ID
  page_name = display phone number
  psid     (conversation) = customer wa_id (E.164)
"""

import logging
from datetime import datetime, timezone
from typing import Any

import httpx
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from config import settings
from models import ChatbotIntegration, Outlet
from services.facebook_chatbot import (
    ChatbotError,
    GRAPH_TIMEOUT_SECONDS,
    MAX_REPLY_CHARS,
    _graph_version,
    record_inbound_message,
)

logger = logging.getLogger(__name__)

WHATSAPP_PROVIDER = "whatsapp"
WHATSAPP_ORDER_SOURCE = "whatsapp"


def _graph_url(path: str) -> str:
    clean_path = path if path.startswith("/") else f"/{path}"
    return f"https://graph.facebook.com/{_graph_version()}{clean_path}"


def _digits(value: Any) -> str:
    return "".join(ch for ch in str(value or "") if ch.isdigit())


def whatsapp_webhook_verify_token() -> str:
    """Webhook verify token for the WhatsApp subscription.

    WhatsApp Cloud API webhooks are configured on the same Meta app as the
    Messenger ones, so we fall back to the Facebook verify token when the
    WhatsApp-specific one is unset.
    """
    token = settings.WHATSAPP_WEBHOOK_VERIFY_TOKEN.strip()
    if token:
        return token
    return settings.FACEBOOK_WEBHOOK_VERIFY_TOKEN.strip()


# ── Webhook handling ──────────────────────────────────────────────────────────


async def handle_whatsapp_webhook(db: AsyncSession, payload: dict[str, Any]) -> None:
    if payload.get("object") != "whatsapp_business_account":
        return
    for entry in payload.get("entry") or []:
        if not isinstance(entry, dict):
            continue
        for change in entry.get("changes") or []:
            if not isinstance(change, dict):
                continue
            value = change.get("value")
            if not isinstance(value, dict):
                continue
            metadata = value.get("metadata") if isinstance(value.get("metadata"), dict) else {}
            phone_number_id = str(metadata.get("phone_number_id") or "").strip()
            if not phone_number_id:
                continue
            integration = await _integration_for_phone(db, phone_number_id)
            if integration is None:
                continue
            messages = value.get("messages") if isinstance(value.get("messages"), list) else []
            for message in messages:
                if isinstance(message, dict):
                    await _handle_message(db, integration, message, metadata)


async def _integration_for_phone(
    db: AsyncSession,
    phone_number_id: str,
) -> ChatbotIntegration | None:
    return (
        await db.execute(
            select(ChatbotIntegration)
            .where(
                ChatbotIntegration.provider == WHATSAPP_PROVIDER,
                ChatbotIntegration.page_id == phone_number_id,
                ChatbotIntegration.is_enabled == True,
            )
            .options(joinedload(ChatbotIntegration.outlet).joinedload(Outlet.restaurant))
        )
    ).scalar_one_or_none()


async def _handle_message(
    db: AsyncSession,
    integration: ChatbotIntegration,
    message: dict[str, Any],
    metadata: dict[str, Any],
) -> None:
    # Skip echoes of our own outbound messages.
    if _digits(message.get("from")) == _digits(metadata.get("display_phone_number")):
        return
    wa_id = str(message.get("from") or "").strip()
    if not wa_id:
        return

    text = _message_text(message)
    attachment_note = _describe_attachments(message)
    if attachment_note:
        text = f"{text} {attachment_note}".strip() if text else attachment_note

    await record_inbound_message(db, integration, wa_id, text)


def _message_text(message: dict[str, Any]) -> str:
    """Extract the customer's text from the message types WhatsApp can deliver."""
    msg_type = str(message.get("type") or "").strip().lower()
    if msg_type == "text":
        text = message.get("text")
        if isinstance(text, dict):
            return str(text.get("body") or "").strip()
    if msg_type == "button":
        button = message.get("button")
        if isinstance(button, dict):
            return str(button.get("text") or "").strip()
    if msg_type == "interactive":
        interactive = message.get("interactive")
        if isinstance(interactive, dict):
            for key in ("button_reply", "list_reply"):
                sub = interactive.get(key)
                if isinstance(sub, dict):
                    return str(sub.get("title") or sub.get("id") or "").strip()
    media = message.get(msg_type)
    if isinstance(media, dict):
        caption = str(media.get("caption") or "").strip()
        if caption:
            return caption
    return ""


def _describe_attachments(message: dict[str, Any]) -> str:
    """Turn WhatsApp media into a bracketed text note for the LLM and manager.

    Mirrors the Messenger attachment handling: the LLM is text-only, so media
    is described in words so both the manager (in the Messages UI) and the LLM
    (in history) know what arrived.
    """
    notes: list[str] = []
    msg_type = str(message.get("type") or "").strip().lower()
    media = message.get(msg_type)
    url = str(media.get("url") or "").strip() if isinstance(media, dict) else ""

    if msg_type == "image":
        notes.append(_media_note("an image the bot cannot see", url))
    elif msg_type == "video":
        notes.append(_media_note("a video the bot cannot see", url))
    elif msg_type == "audio":
        notes.append(_media_note("a voice/audio message the bot cannot hear", url))
    elif msg_type == "document":
        notes.append(_media_note("a file the bot cannot read", url))
    elif msg_type == "location":
        location = message.get("location")
        if isinstance(location, dict):
            lat = str(location.get("latitude") or "").strip()
            lng = str(location.get("longitude") or "").strip()
            if lat and lng:
                notes.append(f"[Customer shared a location ({lat}, {lng})]")
            else:
                notes.append("[Customer shared a location]")
        else:
            notes.append("[Customer shared a location]")
    elif msg_type == "sticker":
        notes.append("[Customer sent a sticker]")
    elif msg_type == "reaction":
        notes.append("[Customer reacted to a message]")
    elif msg_type == "contacts":
        notes.append("[Customer shared a contact card]")
    return " ".join(notes).strip()


def _media_note(what: str, url: str) -> str:
    if url:
        return f"[Customer sent {what} — view it in the WhatsApp chat: {url}]"
    return f"[Customer sent {what} — view it in the WhatsApp chat]"


# ── Outbound messaging ────────────────────────────────────────────────────────


async def send_whatsapp_message(
    integration: ChatbotIntegration, wa_id: str, text: str
) -> None:
    """Send a plain text message via the WhatsApp Cloud API."""
    if not text:
        return
    url = f"https://graph.facebook.com/{_graph_version()}/{integration.page_id}/messages"
    try:
        async with httpx.AsyncClient(timeout=GRAPH_TIMEOUT_SECONDS) as client:
            response = await client.post(
                url,
                params={"access_token": integration.page_access_token},
                json={
                    "messaging_product": "whatsapp",
                    "recipient_type": "individual",
                    "to": wa_id,
                    "type": "text",
                    "text": {"body": text[:MAX_REPLY_CHARS]},
                },
            )
            response.raise_for_status()
    except httpx.HTTPError as error:
        raise ChatbotError("Could not send WhatsApp reply.") from error


# ── Credential setup / config ─────────────────────────────────────────────────


def _mask_token(token: str | None) -> str | None:
    clean = (token or "").strip()
    if not clean:
        return None
    if len(clean) <= 8:
        return "••••"
    return f"{clean[:4]}…{clean[-4:]}"


def integration_to_whatsapp_config(integration: ChatbotIntegration | None) -> dict:
    if integration is None:
        return {
            "isConfigured": False,
            "isEnabled": False,
            "orderingEnabled": True,
            "phoneNumberId": None,
            "displayPhoneNumber": None,
            "tokenPreview": None,
            "lastError": None,
        }
    return {
        "isConfigured": True,
        "isEnabled": integration.is_enabled,
        "orderingEnabled": integration.ordering_enabled,
        "phoneNumberId": integration.page_id,
        "displayPhoneNumber": integration.page_name,
        "tokenPreview": _mask_token(integration.page_access_token),
        "lastError": integration.last_error,
    }


async def get_whatsapp_config(db: AsyncSession, outlet_id: str) -> dict:
    integration = (
        await db.execute(
            select(ChatbotIntegration).where(
                ChatbotIntegration.provider == WHATSAPP_PROVIDER,
                ChatbotIntegration.outlet_id == outlet_id,
            )
        )
    ).scalar_one_or_none()
    return integration_to_whatsapp_config(integration)


async def _resolve_phone_number(
    phone_number_id: str, access_token: str
) -> tuple[str, str | None]:
    """Validate the credentials against the Graph API.

    Returns (phone_number_id, display_phone_number). Raises HTTPException on
    invalid credentials so the app can show the exact reason.
    """
    clean_id = str(phone_number_id or "").strip()
    clean_token = str(access_token or "").strip()
    if not clean_id or not clean_token:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="WhatsApp phone number ID and access token are required.",
        )
    try:
        async with httpx.AsyncClient(timeout=GRAPH_TIMEOUT_SECONDS) as client:
            response = await client.get(
                _graph_url(f"/{clean_id}"),
                params={"access_token": clean_token},
            )
    except httpx.HTTPError as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Could not validate the WhatsApp credentials: {error}",
        ) from error
    payload = response.json() if response.content else {}
    if response.status_code >= 400:
        detail = (
            payload.get("error", {}).get("message") if isinstance(payload, dict) else None
        )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail or "WhatsApp rejected the access token.",
        )
    display_phone = (
        str(payload.get("display_phone_number") or "").strip() if isinstance(payload, dict) else ""
    )
    if not display_phone:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="WhatsApp did not return a display phone number for that ID.",
        )
    return clean_id, display_phone


async def save_whatsapp_config(
    *,
    db: AsyncSession,
    outlet_id: str,
    phone_number_id: str,
    access_token: str,
    is_enabled: bool,
    ordering_enabled: bool,
) -> dict:
    """Create or update the outlet's WhatsApp integration.

    When credentials are provided they are validated against the Graph API
    first. When they are empty and an integration exists, only the toggles are
    updated (keeps the stored token untouched).
    """
    integration = (
        await db.execute(
            select(ChatbotIntegration).where(
                ChatbotIntegration.provider == WHATSAPP_PROVIDER,
                ChatbotIntegration.outlet_id == outlet_id,
            )
        )
    ).scalar_one_or_none()

    clean_id = str(phone_number_id or "").strip()
    clean_token = str(access_token or "").strip()

    if clean_id or clean_token:
        resolved_id, display_phone = await _resolve_phone_number(clean_id, clean_token)
        clean_id = resolved_id
    elif integration is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="WhatsApp phone number ID and access token are required.",
        )
    else:
        display_phone = integration.page_name

    now = datetime.now(timezone.utc)
    if integration is None:
        integration = ChatbotIntegration(
            outlet_id=outlet_id,
            provider=WHATSAPP_PROVIDER,
            page_id=clean_id,
            page_name=display_phone,
            page_access_token=clean_token,
            is_enabled=is_enabled,
            ordering_enabled=ordering_enabled,
            created_at=now,
            updated_at=now,
        )
        db.add(integration)
    else:
        if clean_id:
            integration.page_id = clean_id
        if display_phone:
            integration.page_name = display_phone
        if clean_token:
            integration.page_access_token = clean_token
        integration.last_error = None
        integration.is_enabled = is_enabled
        integration.ordering_enabled = ordering_enabled
        integration.updated_at = now

    await db.commit()
    await db.refresh(integration)
    return integration_to_whatsapp_config(integration)
