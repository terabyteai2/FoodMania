"""Public callback URLs for payment gateways (UddoktaPay redirect / webhook)."""

from __future__ import annotations

from urllib.parse import urlparse

from config import settings


def payment_callback_base() -> str:
    """HTTPS ngrok domain when configured; otherwise BASE_URL from .env."""
    domain = settings.NGROK_STATIC_DOMAIN.strip()
    if domain:
        if domain.startswith("http://") or domain.startswith("https://"):
            return domain.rstrip("/")
        return f"https://{domain}".rstrip("/")
    return settings.BASE_URL.rstrip("/")


def is_local_or_private_url(url: str) -> bool:
    try:
        host = (urlparse(url).hostname or "").lower()
    except Exception:
        return True
    if not host:
        return True
    if host in {"localhost", "127.0.0.1", "::1"}:
        return True
    if host.startswith("192.168.") or host.startswith("10."):
        return True
    if host.startswith("172."):
        parts = host.split(".")
        if len(parts) >= 2:
            try:
                second = int(parts[1])
                if 16 <= second <= 31:
                    return True
            except ValueError:
                pass
    return False


def uddokta_redirect_warning() -> str | None:
    base = payment_callback_base()
    if is_local_or_private_url(base):
        return (
            "Payment gateway needs a public HTTPS redirect URL. "
            "Set NGROK_STATIC_DOMAIN + NGROK_AUTHTOKEN and run bash start_ngrok.sh, "
            "or set BASE_URL to your public https URL (not 192.168.x.x)."
        )
    if not settings.UDDOKTAPAY_SANDBOX and not base.lower().startswith("https://"):
        return (
            "Live payments require HTTPS redirect URLs. "
            "Set BASE_URL=https://your-domain or use NGROK_STATIC_DOMAIN."
        )
    return None
