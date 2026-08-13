import json
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import SystemConfig
from schemas import PlatformBlockingNoticeRequest

BLOCKING_NOTICE_CONFIG_KEY = "admin_blocking_notice"
DEFAULT_BLOCKING_NOTICE_TITLE = "Notice from Terafoods"
ACKNOWLEDGED_OUTLETS_KEY = "_acknowledgedOutlets"
TARGET_OUTLETS_KEY = "_outletIds"


def disabled_blocking_notice() -> dict:
    return {
        "enabled": False,
        "title": "",
        "message": "",
        "imageUrl": None,
        "inputField": False,
        "inputLabel": None,
        "updatedAt": None,
        "type": "adminNotice",
        "ctaLabel": None,
        "ctaUrl": None,
        "dismissible": False,
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
    valid_types = {"adminNotice", "announcement", "subscription", "paymentLink"}
    raw_type = str(parsed.get("type") or "adminNotice").strip()
    return {
        "enabled": True,
        "title": title,
        "message": message,
        "imageUrl": parsed.get("imageUrl") or None,
        "inputField": bool(parsed.get("inputField")),
        "inputLabel": parsed.get("inputLabel") or None,
        "updatedAt": parsed.get("updatedAt"),
        "type": raw_type if raw_type in valid_types else "adminNotice",
        "ctaLabel": parsed.get("ctaLabel") or None,
        "ctaUrl": parsed.get("ctaUrl") or None,
        "dismissible": bool(parsed.get("dismissible")),
    }


def _acknowledged_outlet_ids(raw: str | None) -> set[str]:
    """Outlets that have already consumed the current notice.

    Kept as a private key inside the raw config JSON so it never leaks into
    the client-facing payload.
    """
    if not raw or not raw.strip():
        return set()
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return set()
    if not isinstance(parsed, dict):
        return set()
    ids = parsed.get(ACKNOWLEDGED_OUTLETS_KEY)
    if not isinstance(ids, list):
        return set()
    return {str(i).strip() for i in ids if str(i).strip()}


def _target_outlet_ids(raw: str | None) -> set[str] | None:
    """Outlets the notice was scoped to at publish time.

    ``None`` means the notice is global (all outlets). A non-empty set means
    only those outlets should see it — everyone else gets a disabled notice.
    """
    if not raw or not raw.strip():
        return None
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return None
    if not isinstance(parsed, dict):
        return None
    ids = parsed.get(TARGET_OUTLETS_KEY)
    if not isinstance(ids, list) or not ids:
        return None
    return {str(i).strip() for i in ids if str(i).strip()}


async def get_blocking_notice(db: AsyncSession, outlet_id: str | None = None) -> dict:
    config = (
        await db.execute(
            select(SystemConfig).where(SystemConfig.key == BLOCKING_NOTICE_CONFIG_KEY)
        )
    ).scalar_one_or_none()
    if config is None:
        return disabled_blocking_notice()
    if outlet_id:
        targets = _target_outlet_ids(config.value)
        if targets is not None and outlet_id not in targets:
            return disabled_blocking_notice()
        if outlet_id in _acknowledged_outlet_ids(config.value):
            return disabled_blocking_notice()
    return blocking_notice_from_json(config.value)


async def acknowledge_blocking_notice(db: AsyncSession, outlet_id: str) -> dict:
    """Mark the outlet as having consumed the notice (idempotent).

    From the next fetch onward that outlet receives a disabled notice, so its
    devices stop showing the blocker. Subscription-gate notices are unaffected
    because they short-circuit before the global notice in the health route.
    """
    config = (
        await db.execute(
            select(SystemConfig).where(SystemConfig.key == BLOCKING_NOTICE_CONFIG_KEY)
        )
    ).scalar_one_or_none()
    if config is None:
        return disabled_blocking_notice()
    payload = blocking_notice_from_json(config.value)
    if not payload["enabled"]:
        return payload
    acknowledged = _acknowledged_outlet_ids(config.value)
    if outlet_id in acknowledged:
        return payload
    acknowledged.add(outlet_id)
    try:
        doc = json.loads(config.value)
    except (json.JSONDecodeError, TypeError):
        doc = {}
    if not isinstance(doc, dict):
        doc = {}
    doc[ACKNOWLEDGED_OUTLETS_KEY] = sorted(acknowledged)
    config.value = json.dumps(doc, ensure_ascii=False, separators=(",", ":"))
    config.updated_at = datetime.now(timezone.utc)
    return payload


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
    valid_types = {"adminNotice", "announcement", "subscription", "paymentLink"}
    raw_type = (body.type or "adminNotice").strip()
    payload = {
        "enabled": True,
        "title": (body.title or "").strip() or DEFAULT_BLOCKING_NOTICE_TITLE,
        "message": message,
        "imageUrl": body.imageUrl or None,
        "inputField": bool(body.inputField),
        "inputLabel": body.inputLabel or None,
        "updatedAt": datetime.now(timezone.utc).isoformat(),
        "type": raw_type if raw_type in valid_types else "adminNotice",
        "ctaLabel": body.ctaLabel or None,
        "ctaUrl": body.ctaUrl or None,
        "dismissible": bool(body.dismissible),
    }
    if body.outletIds:
        payload[TARGET_OUTLETS_KEY] = [str(i).strip() for i in body.outletIds if str(i).strip()]
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

    await acknowledge_blocking_notice(db, outlet_id)
    return entry
