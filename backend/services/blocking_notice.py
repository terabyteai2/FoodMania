import json
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import SystemConfig
from schemas import PlatformBlockingNoticeRequest

BLOCKING_NOTICE_CONFIG_KEY = "admin_blocking_notice"
DEFAULT_BLOCKING_NOTICE_TITLE = "Notice from Terafoods"


def disabled_blocking_notice() -> dict:
    return {
        "enabled": False,
        "title": "",
        "message": "",
        "imageUrl": None,
        "inputField": False,
        "inputLabel": None,
        "updatedAt": None,
    }


def blocking_notice_from_json(raw: str | None) -> dict:
    if not raw or not raw.strip():
        return disabled_blocking_notice()
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return disabled_blocking_notice()
    if not isinstance(parsed, dict):
        return disabled_blocking_notice()

    title = str(parsed.get("title") or "").strip() or DEFAULT_BLOCKING_NOTICE_TITLE
    message = str(parsed.get("message") or "").strip()
    if parsed.get("enabled") is not True or not message:
        return disabled_blocking_notice()
    return {
        "enabled": True,
        "title": title,
        "message": message,
        "imageUrl": parsed.get("imageUrl") or None,
        "inputField": bool(parsed.get("inputField")),
        "inputLabel": parsed.get("inputLabel") or None,
        "updatedAt": parsed.get("updatedAt"),
    }


async def get_blocking_notice(db: AsyncSession) -> dict:
    config = (
        await db.execute(
            select(SystemConfig).where(SystemConfig.key == BLOCKING_NOTICE_CONFIG_KEY)
        )
    ).scalar_one_or_none()
    return blocking_notice_from_json(config.value if config else None)


async def set_blocking_notice(
    db: AsyncSession,
    body: PlatformBlockingNoticeRequest,
) -> dict:
    message = body.message.strip()
    if not message:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="message is required",
        )
    payload = {
        "enabled": True,
        "title": (body.title or "").strip() or DEFAULT_BLOCKING_NOTICE_TITLE,
        "message": message,
        "imageUrl": body.imageUrl or None,
        "inputField": bool(body.inputField),
        "inputLabel": body.inputLabel or None,
        "updatedAt": datetime.now(timezone.utc).isoformat(),
    }
    await _store_blocking_notice(db, payload)
    return payload


async def clear_blocking_notice(db: AsyncSession) -> dict:
    await _store_blocking_notice(db, disabled_blocking_notice())
    return disabled_blocking_notice()


async def _store_blocking_notice(db: AsyncSession, payload: dict) -> None:
    raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    config = (
        await db.execute(
            select(SystemConfig).where(SystemConfig.key == BLOCKING_NOTICE_CONFIG_KEY)
        )
    ).scalar_one_or_none()
    if config:
        config.value = raw
        config.updated_at = datetime.now(timezone.utc)
    else:
        db.add(SystemConfig(key=BLOCKING_NOTICE_CONFIG_KEY, value=raw))


RESPONSES_KEY_PREFIX = "admin_blocking_notice_responses:"


async def respond_to_blocking_notice(
    db: AsyncSession,
    restaurant_id: str,
    outlet_id: str,
    outlet_name: str,
    response: str,
) -> dict:
    key = f"{RESPONSES_KEY_PREFIX}{restaurant_id}"
    config = (
        await db.execute(
            select(SystemConfig).where(SystemConfig.key == key)
        )
    ).scalar_one_or_none()

    entries = []
    if config and config.value:
        try:
            entries = json.loads(config.value)
            if not isinstance(entries, list):
                entries = []
        except (json.JSONDecodeError, TypeError):
            entries = []

    entry = {
        "outletId": outlet_id,
        "outletName": outlet_name,
        "response": response,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    entries.append(entry)

    raw = json.dumps(entries, ensure_ascii=False, separators=(",", ":"))
    if config:
        config.value = raw
        config.updated_at = datetime.now(timezone.utc)
    else:
        db.add(SystemConfig(key=key, value=raw))

    return entry
