import json
import os
import zipfile
from datetime import datetime, timezone
from pathlib import Path
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


# ── APK storage (in-app update) ────────────────────────────────────────────────
# The released APK is kept at backend/In_App_Update_Apk_File/app-release.apk and
# served (unauthenticated) by routers/app_download.py.
_BACKEND_ROOT = Path(__file__).resolve().parent.parent
APK_DIR = _BACKEND_ROOT / "In_App_Update_Apk_File"
APK_FILENAME = "app-release.apk"
APK_MAX_BYTES = 300 * 1024 * 1024  # 300 MB safety cap
APK_MANIFEST_NAME = "AndroidManifest.xml"


def apk_path() -> Path:
    return APK_DIR / APK_FILENAME


async def save_apk_upload(upload) -> Path:
    """Stream an uploaded APK to a temp file beside the target and return its path.

    The caller validates the version, then calls promote_apk() to move it into
    place — so an invalid upload never clobbers the currently-published APK.
    """
    APK_DIR.mkdir(parents=True, exist_ok=True)
    tmp = APK_DIR / f"{APK_FILENAME}.uploading"
    total = 0
    try:
        with open(tmp, "wb") as dst:
            while True:
                chunk = await upload.read(1024 * 1024)
                if not chunk:
                    break
                total += len(chunk)
                if total > APK_MAX_BYTES:
                    raise HTTPException(
                        status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                        detail="APK exceeds the 300 MB upload limit.",
                    )
                dst.write(chunk)
    except Exception:
        tmp.unlink(missing_ok=True)
        raise
    finally:
        await upload.close()
    return tmp


def promote_apk(tmp: Path) -> None:
    os.replace(tmp, apk_path())


def validate_apk_file(path: Path) -> None:
    """Reject uploads that are not APK-shaped before publishing them.

    We still allow manual version metadata when pyaxmlparser cannot decode the
    manifest, but the uploaded file must at least be a valid ZIP with the
    Android manifest entry every APK contains.
    """
    try:
        with zipfile.ZipFile(path) as apk:
            names = set(apk.namelist())
            if APK_MANIFEST_NAME not in names:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    detail="Uploaded file is not a valid APK: AndroidManifest.xml is missing.",
                )
            bad_entry = apk.testzip()
            if bad_entry is not None:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    detail=f"Uploaded APK is corrupt near ZIP entry: {bad_entry}",
                )
    except zipfile.BadZipFile as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Uploaded file is not a valid APK ZIP archive.",
        ) from exc


def extract_apk_version(path: Path) -> tuple[str | None, int | None]:
    """Best-effort read of (versionName, versionCode) from an APK.

    Returns (None, None) if pyaxmlparser is unavailable or the file isn't a
    parseable APK — the caller then falls back to manually entered values.
    """
    try:
        from pyaxmlparser import APK
    except Exception:
        return None, None
    try:
        apk = APK(str(path))
        name = (apk.version_name or "").strip() or None
        try:
            code = int(apk.version_code)
        except (TypeError, ValueError):
            code = None
        if code is not None and code < 1:
            code = None
        return name, code
    except Exception:
        return None, None
