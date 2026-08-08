import pytest
from fastapi import HTTPException
from httpx import ASGITransport, AsyncClient

from main import app
from routers import health as health_router
from schemas import PlatformBlockingNoticeRequest
from services import blocking_notice as svc
from services.blocking_notice import (
    DEFAULT_BLOCKING_NOTICE_TITLE,
    blocking_notice_from_json,
    disabled_blocking_notice,
    set_blocking_notice,
)


def test_disabled_blocking_notice():
    result = disabled_blocking_notice()
    assert result == {
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
        "imageUrl": None,
        "inputField": False,
        "inputLabel": None,
        "updatedAt": "2026-06-02T12:00:00+00:00",
        "type": "adminNotice",
        "ctaLabel": None,
        "ctaUrl": None,
        "dismissible": False,
    }


def test_blocking_notice_from_json_with_new_fields():
    parsed = blocking_notice_from_json(
        '{"enabled":true,"title":"Update needed","message":"Please update your app.",'
        '"imageUrl":"https://example.com/hero.png","inputField":true,'
        '"inputLabel":"Your contact email","updatedAt":"2026-06-11T12:00:00+00:00",'
        '"type":"announcement","ctaLabel":"Update now","ctaUrl":"https://example.com/dl",'
        '"dismissible":true}'
    )

    assert parsed == {
        "enabled": True,
        "title": "Update needed",
        "message": "Please update your app.",
        "imageUrl": "https://example.com/hero.png",
        "inputField": True,
        "inputLabel": "Your contact email",
        "updatedAt": "2026-06-11T12:00:00+00:00",
        "type": "announcement",
        "ctaLabel": "Update now",
        "ctaUrl": "https://example.com/dl",
        "dismissible": True,
    }


def test_blocking_notice_parses_empty_new_fields():
    parsed = blocking_notice_from_json(
        '{"enabled":true,"message":"Hello","imageUrl":"","inputField":false,"inputLabel":""}'
    )

    assert parsed["imageUrl"] is None
    assert parsed["inputField"] is False
    assert parsed["inputLabel"] is None


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
async def test_set_blocking_notice_with_new_fields(monkeypatch):
    async def noop_store(_db, _payload):
        pass

    monkeypatch.setattr(svc, "_store_blocking_notice", noop_store)

    result = await set_blocking_notice(
        None,
        PlatformBlockingNoticeRequest(
            title="Maintenance",
            message="We are down.",
            imageUrl="https://example.com/banner.jpg",
            inputField=True,
            inputLabel="Your phone number",
        ),
    )

    assert result["title"] == "Maintenance"
    assert result["message"] == "We are down."
    assert result["imageUrl"] == "https://example.com/banner.jpg"
    assert result["inputField"] is True
    assert result["inputLabel"] == "Your phone number"
    assert result["enabled"] is True
    assert "updatedAt" in result


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
            "imageUrl": None,
            "inputField": False,
            "inputLabel": None,
            "updatedAt": None,
        }

    monkeypatch.setattr(health_router, "AsyncSessionLocal", FakeSessionContext)
    monkeypatch.setattr(health_router, "get_blocking_notice", fake_get_blocking_notice)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/admin/blocking-notice")

    assert response.status_code == 200
    assert response.json()["data"]["message"] == "Please wait."
    assert response.json()["data"]["imageUrl"] is None
    assert response.json()["data"]["inputField"] is False
