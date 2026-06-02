import pytest
from fastapi import HTTPException
from httpx import ASGITransport, AsyncClient

from main import app
from routers import health as health_router
from schemas import PlatformBlockingNoticeRequest
from services.blocking_notice import (
    DEFAULT_BLOCKING_NOTICE_TITLE,
    blocking_notice_from_json,
    disabled_blocking_notice,
    set_blocking_notice,
)


def test_blocking_notice_from_json_requires_enabled_message():
    assert blocking_notice_from_json("") == disabled_blocking_notice()
    assert blocking_notice_from_json('{"enabled":true}') == disabled_blocking_notice()

    parsed = blocking_notice_from_json(
        '{"enabled":true,"title":" Service notice ","message":" Please wait ",'
        '"updatedAt":"2026-06-02T12:00:00+00:00"}'
    )

    assert parsed == {
        "enabled": True,
        "title": "Service notice",
        "message": "Please wait",
        "updatedAt": "2026-06-02T12:00:00+00:00",
    }


def test_blocking_notice_uses_default_title():
    parsed = blocking_notice_from_json('{"enabled":true,"message":"Please wait"}')

    assert parsed["title"] == DEFAULT_BLOCKING_NOTICE_TITLE


@pytest.mark.asyncio
async def test_blocking_notice_rejects_empty_message():
    with pytest.raises(HTTPException):
        await set_blocking_notice(
            None,
            PlatformBlockingNoticeRequest(message="  "),
        )


@pytest.mark.asyncio
async def test_public_blocking_notice_endpoint_does_not_require_auth(monkeypatch):
    class FakeSessionContext:
        async def __aenter__(self):
            return object()

        async def __aexit__(self, exc_type, exc, traceback):
            return False

    async def fake_get_blocking_notice(_db):
        return {
            "enabled": True,
            "title": "Service notice",
            "message": "Please wait.",
            "updatedAt": None,
        }

    monkeypatch.setattr(health_router, "AsyncSessionLocal", FakeSessionContext)
    monkeypatch.setattr(health_router, "get_blocking_notice", fake_get_blocking_notice)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/admin/blocking-notice")

    assert response.status_code == 200
    assert response.json()["data"]["message"] == "Please wait."
