import json
import logging
from functools import lru_cache
from pathlib import Path
from typing import Any

import httpx
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import service_account
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from config import settings
from models import Device, Order
from services.order_serial import format_serial

logger = logging.getLogger("quickbytes.push")

_FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"


def _text(value: Any) -> str:
    return str(value or "").strip()


@lru_cache(maxsize=1)
def _service_account_info() -> dict[str, Any] | None:
    raw_json = settings.FIREBASE_SERVICE_ACCOUNT_JSON.strip()
    raw_file = settings.FIREBASE_SERVICE_ACCOUNT_FILE.strip()
    if raw_json:
        try:
            return json.loads(raw_json)
        except json.JSONDecodeError:
            logger.exception("[QB-PUSH] invalid FIREBASE_SERVICE_ACCOUNT_JSON")
            return None
    if raw_file:
        path = Path(raw_file)
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except OSError:
            logger.exception("[QB-PUSH] cannot read FIREBASE_SERVICE_ACCOUNT_FILE=%s", raw_file)
            return None
        except json.JSONDecodeError:
            logger.exception("[QB-PUSH] invalid Firebase service account file JSON")
            return None
    return None


def _project_id(info: dict[str, Any] | None) -> str:
    return settings.FIREBASE_PROJECT_ID.strip() or _text((info or {}).get("project_id"))


def _access_token(info: dict[str, Any]) -> str:
    credentials = service_account.Credentials.from_service_account_info(
        info,
        scopes=[_FCM_SCOPE],
    )
    credentials.refresh(GoogleAuthRequest())
    return _text(credentials.token)


async def _outlet_tokens(db: AsyncSession, outlet_id: str) -> list[str]:
    rows = (
        await db.execute(
            select(Device.fcm_token).where(
                Device.outlet_id == outlet_id,
                Device.fcm_token != None,
            )
        )
    ).scalars().all()
    tokens = []
    seen = set()
    for row in rows:
        token = _text(row)
        if token and token not in seen:
            tokens.append(token)
            seen.add(token)
    return tokens


async def send_fcm_to_tokens(
    *,
    tokens: list[str],
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
    collapse_key: str | None = None,
) -> int:
    if not tokens:
        logger.info("[QB-PUSH] no registered FCM tokens; skipping title=%r", title)
        return 0

    info = _service_account_info()
    project_id = _project_id(info)
    if info is None or not project_id:
        logger.info(
            "[QB-PUSH] disabled; set FIREBASE_PROJECT_ID and a Firebase service account"
        )
        return 0

    try:
        token = _access_token(info)
    except Exception:
        logger.exception("[QB-PUSH] could not mint Firebase access token")
        return 0

    string_data = {key: _text(value) for key, value in (data or {}).items()}
    endpoint = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    # Pick notification channel based on order status in data.
    status_val = string_data.get("status", "").lower()
    channel_id = (
        "pos_accepted_orders_v2"
        if status_val in ("accepted", "completed", "served")
        else "pos_pending_orders_v2"
    )
    sent = 0
    async with httpx.AsyncClient(timeout=8.0) as client:
        for device_token in tokens:
            android_block: dict[str, Any] = {
                "priority": "HIGH",
                "notification": {
                    "channel_id": channel_id,
                    "sound": "default",
                    "notification_priority": "PRIORITY_MAX",
                    "visibility": "PUBLIC",
                },
            }
            if collapse_key:
                android_block["collapse_key"] = collapse_key
            payload = {
                "message": {
                    "token": device_token,
                    "notification": {"title": title, "body": body},
                    "data": string_data,
                    "android": android_block,
                }
            }
            try:
                response = await client.post(
                    endpoint,
                    headers={"Authorization": f"Bearer {token}"},
                    json=payload,
                )
                if response.status_code < 400:
                    sent += 1
                else:
                    logger.warning(
                        "[QB-PUSH] FCM send failed status=%s body=%s",
                        response.status_code,
                        response.text[:240],
                    )
            except httpx.HTTPError:
                logger.exception("[QB-PUSH] FCM HTTP send failed")
    logger.info("[QB-PUSH] sent=%s total=%s title=%r", sent, len(tokens), title)
    return sent


def _push_copy(event_type: str, order: Order) -> tuple[str, str]:
    serial = (
        format_serial(order.serial_number, order.source, order.created_by_role)
        if order.serial_number
        else "New order"
    )
    status = _text(order.status).lower()
    if event_type == "order_created":
        if status == "accepted":
            return "Order accepted", f"{serial} accepted"
        return "New pending order", f"{serial} needs attention"
    if status == "accepted":
        return "Order accepted", f"{serial} accepted"
    if status in {"completed", "served"}:
        return "Order completed", f"{serial} completed"
    if status in {"rejected", "cancelled"}:
        return "Order rejected", f"{serial} rejected"
    return "Order updated", f"{serial} is now {status or 'updated'}"


async def send_order_push(
    *,
    db: AsyncSession,
    outlet_id: str,
    event_type: str,
    order: Order,
) -> int:
    tokens = await _outlet_tokens(db, outlet_id)
    title, body = _push_copy(event_type, order)
    status_val = _text(order.status).lower()
    # collapse_key groups rapid-fire notifications of the same type so Android
    # replaces stacked alerts with the latest one instead of showing a pile.
    collapse_key = (
        f"{outlet_id}:accepted"
        if status_val in ("accepted", "completed", "served")
        else f"{outlet_id}:pending"
    )
    return await send_fcm_to_tokens(
        tokens=tokens,
        title=title,
        body=body,
        collapse_key=collapse_key,
        data={
            "type": event_type,
            "orderId": order.id,
            "status": order.status,
            "serialNumber": order.serial_number,
            "actionTarget": "orders",
        },
    )
