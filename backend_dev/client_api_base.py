"""Resolve the REST API base URL as seen by the mobile app (ngrok, reverse proxy)."""

from __future__ import annotations

from starlette.requests import Request

from config import settings


def client_visible_api_base(request: Request | None) -> str:
    """Host/proto the client used for this request — staff should persist this for sync."""
    fallback = settings.BASE_URL.rstrip("/")
    if request is None:
        return fallback

    proto = (request.headers.get("x-forwarded-proto") or "").strip().lower()
    host = (request.headers.get("x-forwarded-host") or "").strip()
    if not host:
        host = (request.headers.get("host") or "").strip()
    if host:
        host = host.split(",")[0].strip()
        if proto in ("http", "https"):
            return f"{proto}://{host}".rstrip("/")
        scheme = request.url.scheme or "http"
        if scheme in ("http", "https") and host:
            return f"{scheme}://{host}".rstrip("/")

    try:
        base = str(request.base_url).rstrip("/")
        if base.startswith("http://") or base.startswith("https://"):
            return base
    except Exception:
        pass
    return fallback
