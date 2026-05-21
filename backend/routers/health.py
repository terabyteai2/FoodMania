import os
from datetime import datetime, timezone

from fastapi import APIRouter
from sqlalchemy import text

from config import settings
from database import AsyncSessionLocal
from schemas import ok
from services import phone_otp

router = APIRouter()


def _demo_manager_login_enabled() -> bool:
    explicit = settings.DEMO_MANAGER_LOGIN_ENABLED.strip().lower()
    if explicit in ("1", "true", "yes", "on"):
        return True
    if explicit in ("0", "false", "no", "off"):
        return False
    return settings.APP_ENV.strip().lower() == "development"


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

    payload = {
        "status": "ok" if db_ok else "degraded",
        "version": "1.0.0",
        "appEnv": settings.APP_ENV,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "database": {"ok": db_ok, "error": db_error},
        "gitCommit": commit or None,
        "demoManagerLoginEnabled": _demo_manager_login_enabled(),
        "smsProvider": "onecodesoft" if phone_otp.onecodesoft_configured() else None,
        "onecodesoftConfigured": phone_otp.onecodesoft_configured(),
        "phoneOtpMode": phone_otp.phone_otp_mode(),
        "devOtpBypassEnabled": phone_otp.dev_otp_bypass_enabled(),
        "realtime": {
            "enabled": False,
            "supabaseUrl": "",
            "publishableKey": "",
            "channelPrefix": "pos:outlet:",
        },
        "staffDevBypassEnabled": bool(settings.STAFF_DEV_BYPASS_SECRET.strip()),
        "monitoring": {"sentryEnabled": bool(settings.SENTRY_DSN.strip())},
    }
    return ok(payload)
