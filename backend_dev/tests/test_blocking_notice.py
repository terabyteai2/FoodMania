import pytest
from fastapi import HTTPException
from httpx import ASGITransport, AsyncClient

from auth import create_device_token
from main import app
from routers import health as health_router
from schemas import PlatformBlockingNoticeRequest
from services import blocking_notice as svc
from services.blocking_notice import (
    DEFAULT_BLOCKING_NOTICE_TITLE,
    ACKNOWLEDGED_OUTLETS_KEY,
    _acknowledged_outlet_ids,
    _target_outlet_ids,
    acknowledge_blocking_notice,
    blocking_notice_from_json,
    disabled_blocking_notice,
    get_blocking_notice,
    set_blocking_notice,
)


class _FakeResult:
    def __init__(self, config):
        self._config = config

    def scalar_one_or_none(self):
        return self._config


class _FakeConfig:
    def __init__(self, raw: str):
        self.value = raw
        self.updated_at = None


class _FakeSession:
    def __init__(self, config=None):
        self._config = config
        self.added = []

    async def execute(self, _statement):
        return _FakeResult(self._config)

    async def commit(self):
        pass

    def add(self, obj):
        self.added.append(obj)


def _enabled_raw(**overrides) -> str:
    payload = {
        "enabled": True,
        "title": "Trial",
        "message": "Trial ends soon",
        "updatedAt": "2026-08-13T00:00:00+00:00",
    }
    payload.update(overrides)
    return __import__("json").dumps(payload, ensure_ascii=False)


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


def test_blocking_notice_from_json_ignores_ack_key():
    parsed = blocking_notice_from_json(
        '{"enabled":true,"message":"Hi","_acknowledgedOutlets":["outlet-1"]}'
    )

    assert parsed["enabled"] is True
    assert ACKNOWLEDGED_OUTLETS_KEY not in parsed


def test_acknowledged_outlet_ids_parsing():
    raw = _enabled_raw(_acknowledgedOutlets=["outlet-1", "outlet-2"])
    assert _acknowledged_outlet_ids(raw) == {"outlet-1", "outlet-2"}
    assert _acknowledged_outlet_ids(None) == set()
    assert _acknowledged_outlet_ids("not json") == set()
    assert _acknowledged_outlet_ids('{"enabled":true,"message":"x"}') == set()


@pytest.mark.asyncio
async def test_get_blocking_notice_filters_acknowledged_outlet():
    raw = _enabled_raw(_acknowledgedOutlets=["outlet-1"])
    session = _FakeSession(_FakeConfig(raw))

    assert (await get_blocking_notice(session))["enabled"] is True
    assert (await get_blocking_notice(session, outlet_id="outlet-2"))["enabled"] is True
    assert (await get_blocking_notice(session, outlet_id="outlet-1"))["enabled"] is False


@pytest.mark.asyncio
async def test_acknowledge_blocking_notice_persists_idempotently():
    raw = _enabled_raw()
    config = _FakeConfig(raw)
    session = _FakeSession(config)

    first = await acknowledge_blocking_notice(session, "outlet-1")
    assert first["enabled"] is True
    assert _acknowledged_outlet_ids(config.value) == {"outlet-1"}

    second = await acknowledge_blocking_notice(session, "outlet-1")
    assert second["enabled"] is True
    assert _acknowledged_outlet_ids(config.value) == {"outlet-1"}

    assert (await get_blocking_notice(session, outlet_id="outlet-1"))["enabled"] is False


@pytest.mark.asyncio
async def test_acknowledge_blocking_notice_preserves_targets():
    raw = _enabled_raw(_outletIds=["outlet-1", "outlet-2"])
    config = _FakeConfig(raw)
    session = _FakeSession(config)

    await acknowledge_blocking_notice(session, "outlet-1")

    assert _acknowledged_outlet_ids(config.value) == {"outlet-1"}
    assert _target_outlet_ids(config.value) == {"outlet-1", "outlet-2"}
    assert (await get_blocking_notice(session, outlet_id="outlet-2"))["enabled"] is True


@pytest.mark.asyncio
async def test_acknowledge_blocking_notice_noop_when_disabled():
    config = _FakeConfig('{"enabled":false,"message":""}')
    session = _FakeSession(config)

    result = await acknowledge_blocking_notice(session, "outlet-1")
    assert result == disabled_blocking_notice()
    assert _acknowledged_outlet_ids(config.value) == set()


@pytest.mark.asyncio
async def test_acknowledge_blocking_notice_noop_without_config():
    session = _FakeSession(None)

    result = await acknowledge_blocking_notice(session, "outlet-1")
    assert result == disabled_blocking_notice()


def test_target_outlet_ids_parsing():
    raw = _enabled_raw(_outletIds=["outlet-1", "outlet-2"])
    assert _target_outlet_ids(raw) == {"outlet-1", "outlet-2"}
    assert _target_outlet_ids(_enabled_raw()) is None
    assert _target_outlet_ids(None) is None
    assert _target_outlet_ids("not json") is None


@pytest.mark.asyncio
async def test_get_blocking_notice_only_serves_targeted_outlets():
    raw = _enabled_raw(_outletIds=["outlet-1"])
    session = _FakeSession(_FakeConfig(raw))

    assert (await get_blocking_notice(session, outlet_id="outlet-1"))["enabled"] is True
    assert (await get_blocking_notice(session, outlet_id="outlet-2"))["enabled"] is False
    assert (await get_blocking_notice(session))["enabled"] is True


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


@pytest.mark.asyncio
async def test_admin_blocking_notice_get_acks_then_disables(monkeypatch):
    acknowledged: list[str] = []

    class FakeSessionContext:
        async def __aenter__(self):
            return _FakeSession(None)

        async def __aexit__(self, exc_type, exc, traceback):
            return False

    async def fake_subscription_notice(_db, _sub):
        return disabled_blocking_notice()

    async def fake_get_blocking_notice(_db, outlet_id=None):
        if outlet_id in acknowledged:
            return disabled_blocking_notice()
        return {
            "enabled": True,
            "title": "Trial",
            "message": "Trial ends soon",
            "imageUrl": None,
            "inputField": False,
            "inputLabel": None,
            "updatedAt": None,
            "type": "adminNotice",
            "ctaLabel": None,
            "ctaUrl": None,
            "dismissible": False,
        }

    async def fake_ack(_db, outlet_id):
        acknowledged.append(outlet_id)

    monkeypatch.setattr(health_router, "AsyncSessionLocal", FakeSessionContext)
    monkeypatch.setattr(
        health_router, "blocking_notice_for_subscription", fake_subscription_notice
    )
    monkeypatch.setattr(health_router, "get_blocking_notice", fake_get_blocking_notice)
    monkeypatch.setattr(
        health_router, "acknowledge_blocking_notice", fake_ack
    )

    token = create_device_token("outlet-1")
    headers = {"Authorization": f"Bearer {token}"}
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        first = await client.get("/admin/blocking-notice", headers=headers)
        second = await client.get("/admin/blocking-notice", headers=headers)

    assert first.status_code == 200
    assert first.json()["data"]["enabled"] is True
    assert acknowledged == ["outlet-1"]
    assert second.status_code == 200
    assert second.json()["data"]["enabled"] is False
