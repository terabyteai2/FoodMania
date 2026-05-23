import json
from datetime import datetime, timezone
from urllib.parse import urlparse

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import SystemConfig
from schemas import PlatformAppUpdateRequest

APP_UPDATE_CONFIG_KEY = "admin_app_update"


def disabled_app_update() -> dict:
    return {
        "enabled": False,
        "versionName": "",
        "versionCode": 0,
        "apkUrl": "",
        "releaseNotes": "",
        "required": False,
        "publishedAt": None,
    }


def app_update_from_json(raw: str | None) -> dict:
    if not raw or not raw.strip():
        return disabled_app_update()
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return disabled_app_update()
    if not isinstance(parsed, dict):
        return disabled_app_update()

    data = disabled_app_update()
    data.update(
        {
            "enabled": parsed.get("enabled") is True,
            "versionName": str(parsed.get("versionName") or "").strip(),
            "versionCode": _coerce_version_code(parsed.get("versionCode")),
            "apkUrl": str(parsed.get("apkUrl") or "").strip(),
            "releaseNotes": str(parsed.get("releaseNotes") or "").strip(),
            "required": parsed.get("required") is True,
            "publishedAt": parsed.get("publishedAt"),
        }
    )
    if not data["enabled"] or not data["versionName"] or not data["apkUrl"] or data["versionCode"] <= 0:
        return disabled_app_update()
    return data


async def get_app_update(db: AsyncSession) -> dict:
    config = (
        await db.execute(select(SystemConfig).where(SystemConfig.key == APP_UPDATE_CONFIG_KEY))
    ).scalar_one_or_none()
    return app_update_from_json(config.value if config else None)


async def set_app_update(db: AsyncSession, body: PlatformAppUpdateRequest) -> dict:
    payload = _payload_from_request(body)
    raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    config = (
        await db.execute(select(SystemConfig).where(SystemConfig.key == APP_UPDATE_CONFIG_KEY))
    ).scalar_one_or_none()
    if config:
        config.value = raw
        config.updated_at = datetime.now(timezone.utc)
    else:
        db.add(SystemConfig(key=APP_UPDATE_CONFIG_KEY, value=raw))
    return payload


async def clear_app_update(db: AsyncSession) -> dict:
    config = (
        await db.execute(select(SystemConfig).where(SystemConfig.key == APP_UPDATE_CONFIG_KEY))
    ).scalar_one_or_none()
    if config:
        config.value = ""
        config.updated_at = datetime.now(timezone.utc)
    else:
        db.add(SystemConfig(key=APP_UPDATE_CONFIG_KEY, value=""))
    return disabled_app_update()


def _payload_from_request(body: PlatformAppUpdateRequest) -> dict:
    version_name = body.versionName.strip()
    if not version_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="versionName is required",
        )
    apk_url = body.apkUrl.strip()
    parsed = urlparse(apk_url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="apkUrl must be a valid http(s) URL",
        )
    return {
        "enabled": body.enabled,
        "versionName": version_name,
        "versionCode": body.versionCode,
        "apkUrl": apk_url,
        "releaseNotes": (body.releaseNotes or "").strip(),
        "required": body.required,
        "publishedAt": datetime.now(timezone.utc).isoformat(),
    }


def _coerce_version_code(value: object) -> int:
    if isinstance(value, bool):
        return 0
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    try:
        return int(str(value or "").strip())
    except ValueError:
        return 0
