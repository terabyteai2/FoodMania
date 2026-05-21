"""Bangladesh SMS OTP via OneCodeSoft, with optional dev bypass."""

from __future__ import annotations

import asyncio
import json
import secrets
import time
from collections import defaultdict
from dataclasses import dataclass
from threading import Lock

import httpx
from fastapi import HTTPException, status

from config import settings
from phone_utils import normalize_bd_phone

MAX_SENDS_PER_HOUR = 3
OTP_TTL_SECONDS = 600  # 10 minutes
OTP_LENGTH = 6

_send_lock = Lock()
_send_log: dict[str, list[float]] = defaultdict(list)
_otp_lock = Lock()
_otp_store: dict[str, _OtpEntry] = {}


@dataclass
class _OtpEntry:
    code: str
    expires_at: float


def onecodesoft_configured() -> bool:
    return bool(
        settings.ONECODESOFT_API_KEY.strip()
        and settings.ONECODESOFT_SENDER_ID.strip()
    )


def dev_otp_bypass_enabled() -> bool:
    raw = settings.DEV_OTP_BYPASS_ENABLED.strip().lower()
    return raw in ("1", "true", "yes", "on")


def dev_otp_bypass_code() -> str:
    code = (settings.DEV_OTP_BYPASS_CODE or "").strip()
    return code or "000000"


def dev_otp_allowed() -> bool:
    """Dev fallback when OneCodeSoft is not configured."""
    return settings.APP_ENV.strip().lower() == "development" and not onecodesoft_configured()


def phone_otp_mode() -> str:
    if dev_otp_bypass_enabled():
        return "dev_bypass"
    if dev_otp_allowed():
        return "dev_fallback"
    if onecodesoft_configured():
        return "onecodesoft"
    return "unconfigured"


def sms_provider_configured() -> bool:
    return onecodesoft_configured()


def build_otp_sms_message(code: str, app_signature: str | None = None) -> str:
    """Format SMS for Android SMS Retriever + iOS Security Code AutoFill."""
    raw = (app_signature or "").strip()
    sig = raw.splitlines()[0].strip() if raw else ""
    if sig:
        # Google SMS Retriever: <#> prefix + hash on its own line (11 chars).
        return f"<#> Your Quickbytes verification code is {code}\n{sig}"
    # iOS reads leading digits; Android User Consent API can parse this too.
    return f"{code} is your Quickbytes verification code. Valid for 10 minutes."


def _phone_to_sms_number(phone: str) -> str:
    """E.164 +8801… → 8801… for OneCodeSoft."""
    normalized = normalize_bd_phone(phone)
    return normalized.lstrip("+")


def _generate_otp() -> str:
    return "".join(str(secrets.randbelow(10)) for _ in range(OTP_LENGTH))


def _store_otp(phone: str, code: str) -> None:
    expires_at = time.time() + OTP_TTL_SECONDS
    with _otp_lock:
        _otp_store[normalize_bd_phone(phone)] = _OtpEntry(code=code, expires_at=expires_at)


def _check_rate_limit(phone: str) -> None:
    key = normalize_bd_phone(phone)
    now = time.time()
    with _send_lock:
        window = [t for t in _send_log[key] if now - t < 3600]
        if len(window) >= MAX_SENDS_PER_HOUR:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many OTP requests. Try again later.",
            )
        window.append(now)
        _send_log[key] = window


def _send_onecodesoft_sms(phone: str, message: str) -> None:
    payload = {
        "api_key": settings.ONECODESOFT_API_KEY.strip(),
        "senderid": settings.ONECODESOFT_SENDER_ID.strip(),
        "number": _phone_to_sms_number(phone),
        "message": message,
    }
    headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
    }
    url = settings.ONECODESOFT_API_URL.strip() or "https://sms.onecodesoft.com/api/send-sms"

    with httpx.Client(timeout=30.0) as client:
        response = client.request(
            "GET",
            url,
            headers=headers,
            content=json.dumps(payload),
        )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=_onecodesoft_error_detail(response),
        )

    try:
        body = response.json()
    except json.JSONDecodeError:
        body = {"raw": response.text}

    if isinstance(body, dict):
        top_message = str(body.get("message", "")).lower()
        if "success" in top_message or body.get("results"):
            return
        status_val = str(body.get("status", body.get("success", ""))).lower()
        if status_val in {"error", "failed", "false", "0"}:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=body.get("message") or body.get("error") or "SMS gateway rejected the request.",
            )


def _onecodesoft_error_detail(response: httpx.Response) -> str:
    try:
        body = response.json()
        if isinstance(body, dict):
            msg = body.get("message") or body.get("error") or body.get("detail")
            if msg:
                return f"Could not send SMS: {msg}"
    except json.JSONDecodeError:
        pass
    text = (response.text or "").strip()
    if text:
        return f"Could not send SMS (HTTP {response.status_code}): {text[:200]}"
    return f"Could not send SMS (HTTP {response.status_code})."


async def send_verification(phone: str, *, app_signature: str | None = None) -> None:
    _check_rate_limit(phone)
    if dev_otp_bypass_enabled() or dev_otp_allowed():
        _store_otp(phone, dev_otp_bypass_code())
        return

    if not onecodesoft_configured():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="SMS verification is not configured.",
        )

    code = _generate_otp()
    message = build_otp_sms_message(code, app_signature)
    try:
        await asyncio.to_thread(_send_onecodesoft_sms, phone, message)
    except HTTPException:
        raise
    except Exception as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Could not send verification code. {error}",
        ) from error

    _store_otp(phone, code)


async def check_verification(phone: str, code: str) -> None:
    normalized_code = (code or "").strip()
    bypass_code = dev_otp_bypass_code()

    if dev_otp_bypass_enabled() and normalized_code == bypass_code:
        return

    key = normalize_bd_phone(phone)
    with _otp_lock:
        entry = _otp_store.get(key)

    if dev_otp_allowed():
        if entry and normalized_code == entry.code:
            with _otp_lock:
                _otp_store.pop(key, None)
            return
        if normalized_code == bypass_code:
            return
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid verification code.")

    if not onecodesoft_configured():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="SMS verification is not configured.",
        )

    if entry is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Code expired or not requested. Send a new code.",
        )
    if time.time() > entry.expires_at:
        with _otp_lock:
            _otp_store.pop(key, None)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Code expired. Send a new code.",
        )
    if normalized_code != entry.code:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid verification code.")

    with _otp_lock:
        _otp_store.pop(key, None)
