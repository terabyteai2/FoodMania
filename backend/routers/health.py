import os
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

from fastapi import APIRouter, Depends
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import select, text

from auth import bearer_scheme, decode_device_payload
from config import settings
from database import AsyncSessionLocal
from models import Outlet, OutletSubscription
from schemas import BlockingNoticeRespondRequest, ok
from services import phone_otp
from services.blocking_notice import get_blocking_notice, respond_to_blocking_notice
from subscription_service import blocking_notice_for_subscription

router = APIRouter()


def _configured(value: str) -> bool:
    return bool(value.strip())


def _public_https_base_url() -> bool:
    parsed = urlparse(settings.BASE_URL.strip())
    return parsed.scheme == "https" and bool(parsed.netloc)


def _storage_ready(path: str) -> bool:
    try:
        directory = Path(path)
        directory.mkdir(parents=True, exist_ok=True)
        return directory.is_dir() and os.access(directory, os.W_OK)
    except OSError:
        return False


@router.get("/health")
async def health():
    db_ok = False
    db_error: str | None = None
    try:
        async with AsyncSessionLocal() as db:
            await db.execute(text("SELECT 1"))
            db_ok = True
    except Exception as exc:
        db_error = str(exc)

    commit = settings.GIT_COMMIT_SHA.strip() or os.environ.get("GIT_COMMIT_SHA", "").strip()
    storage = {
        "menuImages": _storage_ready(settings.IMAGES_DIR),
        "heroMedia": _storage_ready(settings.HERO_MEDIA_DIR),
        "outletImages": _storage_ready(settings.OUTLET_IMAGES_DIR),
        "outletVideos": _storage_ready(settings.OUTLET_VIDEOS_DIR),
    }
    storage_ok = all(storage.values())
    facebook_oauth_ready = (
        _configured(settings.FACEBOOK_APP_ID)
        and _configured(settings.FACEBOOK_APP_SECRET)
        and _public_https_base_url()
    )
    facebook_webhook_ready = (
        _configured(settings.FACEBOOK_APP_SECRET)
        and _configured(settings.FACEBOOK_WEBHOOK_VERIFY_TOKEN)
        and _public_https_base_url()
    )
    chatbot_providers = {
        "openrouter": _configured(settings.OPENROUTER_API_KEY)
        or _configured(settings.OPENROUTER_API_KEYS),
        "deepseek": _configured(settings.DEEPSEEK_API_KEY),
    }
    onecodesoft_configured = phone_otp.onecodesoft_configured()
    diagnostics = {
        "database": {"ok": db_ok},
        "storage": {"ok": storage_ok, "directories": storage},
        "sms": {"ok": onecodesoft_configured, "provider": "onecodesoft" if onecodesoft_configured else None},
        "facebook": {
            "oauthReady": facebook_oauth_ready,
            "nativeAndroidReady": facebook_oauth_ready
            and _configured(settings.FACEBOOK_ANDROID_CLIENT_TOKEN),
            "webhookReady": facebook_webhook_ready,
            "publicHttpsBaseUrl": _public_https_base_url(),
        },
        "chatbotAi": {
            "ok": any(chatbot_providers.values()),
            "providers": chatbot_providers,
        },
        "monitoring": {"sentryEnabled": _configured(settings.SENTRY_DSN)},
        "realtime": {"enabled": False},
    }

    payload = {
        "status": "ok" if db_ok and storage_ok else "degraded",
        "version": "1.0.0",
        "appEnv": settings.APP_ENV,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "database": {"ok": db_ok, "error": db_error},
        "gitCommit": commit or None,
        "smsProvider": "onecodesoft" if onecodesoft_configured else None,
        "onecodesoftConfigured": onecodesoft_configured,
        "phoneOtpMode": phone_otp.phone_otp_mode(),
        "devOtpBypassEnabled": phone_otp.dev_otp_bypass_enabled(),
        "realtime": {
            "enabled": False,
            "supabaseUrl": "",
            "publishableKey": "",
            "channelPrefix": "pos:outlet:",
        },
        "monitoring": {"sentryEnabled": bool(settings.SENTRY_DSN.strip())},
        "diagnostics": diagnostics,
    }
    return ok(payload)


@router.get("/admin/blocking-notice")
async def admin_blocking_notice(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
):
    """Return a per-outlet blocking notice based on subscription status,
    falling back to the global notice if no outlet context is available.
    """
    async with AsyncSessionLocal() as db:
        if credentials:
            payload = decode_device_payload(credentials.credentials)
            outlet_id = payload.get("sub") or payload.get("outlet_id")
            if outlet_id:
                sub = (
                    await db.execute(
                        select(OutletSubscription).where(
                            OutletSubscription.outlet_id == outlet_id
                        )
                    )
                ).scalar_one_or_none()
                notice = await blocking_notice_for_subscription(db, sub)
                if notice.get("enabled"):
                    return ok(notice)
        return ok(await get_blocking_notice(db))


@router.post("/admin/blocking-notice/respond")
async def respond_blocking_notice(
    body: BlockingNoticeRespondRequest,
    credentials: str | None = Depends(bearer_scheme),
):
    if credentials is None:
        from fastapi import HTTPException, status
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing token")
    payload = decode_device_payload(credentials.credentials)
    outlet_id = payload.get("sub", "")
    if not outlet_id:
        from fastapi import HTTPException, status
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    async with AsyncSessionLocal() as db:
        outlet = (
            await db.execute(select(Outlet).where(Outlet.id == outlet_id))
        ).scalar_one_or_none()
        if not outlet:
            from fastapi import HTTPException, status
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Outlet not found")
        entry = await respond_to_blocking_notice(
            db, outlet.restaurant_id, outlet.id, outlet.name, body.response,
        )
        await db.commit()
        return ok(entry)
