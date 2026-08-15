import asyncio
import base64

import pytest
import routers.ws as ws_module

from services import support_stt


class FakeResponse:
    def __init__(self, status_code=200, payload=None):
        self.status_code = status_code
        self._payload = payload or {}

    def json(self):
        return self._payload

    @property
    def text(self):
        return str(self._payload)


class FakeHttpxClient:
    def __init__(self, response):
        self._response = response
        self.calls = []

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False

    async def post(self, *args, **kwargs):
        self.calls.append((args, kwargs))
        return self._response


def _fake_client(monkeypatch, response):
    client = FakeHttpxClient(response)
    monkeypatch.setattr(support_stt.httpx, "AsyncClient", lambda timeout: client)
    return client


def test_stt_enabled_false_without_key():
    assert not support_stt.stt_enabled()


@pytest.mark.asyncio
async def test_transcribe_empty_and_missing_audio(monkeypatch):
    async def boom(*args, **kwargs):
        raise AssertionError("should not call the API")

    monkeypatch.setattr(support_stt.httpx, "AsyncClient", boom)
    monkeypatch.setattr(support_stt.settings, "SARVAM_API_KEY", "key")
    assert await support_stt.transcribe_audio("") == ""


@pytest.mark.asyncio
async def test_transcribe_bad_base64_skips(monkeypatch):
    async def boom(*args, **kwargs):
        raise AssertionError("should not call the API")

    monkeypatch.setattr(support_stt.httpx, "AsyncClient", boom)
    monkeypatch.setattr(support_stt.settings, "SARVAM_API_KEY", "key")
    assert await support_stt.transcribe_audio("###not-base64###") == ""


@pytest.mark.asyncio
async def test_transcribe_success(monkeypatch):
    client = _fake_client(
        monkeypatch,
        FakeResponse(payload={"transcript": "হ্যালো, কেমন আছেন?"}),
    )
    monkeypatch.setattr(support_stt.settings, "SARVAM_API_KEY", "key")
    monkeypatch.setattr(support_stt.settings, "SARVAM_STT_MODEL", "saaras:v3")
    monkeypatch.setattr(support_stt.settings, "SARVAM_STT_LANGUAGE", "bn-IN")
    result = await support_stt.transcribe_audio(base64.b64encode(b"\x00" * 64).decode())
    assert result == "হ্যালো, কেমন আছেন?"
    assert len(client.calls) == 1
    _, kwargs = client.calls[0]
    assert kwargs["files"]["file"][0] == "recording.wav"
    assert kwargs["data"]["model"] == "saaras:v3"
    assert kwargs["data"]["mode"] == "transcribe"


@pytest.mark.asyncio
async def test_transcribe_http_error_returns_empty(monkeypatch):
    _fake_client(monkeypatch, FakeResponse(status_code=422, payload={"error": "bad"}))
    monkeypatch.setattr(support_stt.settings, "SARVAM_API_KEY", "key")
    result = await support_stt.transcribe_audio(base64.b64encode(b"\x00" * 64).decode())
    assert result == ""


@pytest.mark.asyncio
async def test_transcribe_empty_transcript_returns_empty(monkeypatch):
    _fake_client(monkeypatch, FakeResponse(payload={"transcript": "  "}))
    monkeypatch.setattr(support_stt.settings, "SARVAM_API_KEY", "key")
    result = await support_stt.transcribe_audio(base64.b64encode(b"\x00" * 64).decode())
    assert result == ""


@pytest.mark.asyncio
async def test_ws_handler_posts_transcript_and_acks(monkeypatch):
    broadcasted = []
    persisted = []
    replies = []

    async def fake_transcribe(audio):
        return "আমার কথা শুনুন"

    async def fake_persist(outlet_id, role, sender_name, text, actions=None, steps=None):
        persisted.append((role, sender_name, text))
        message = type("Message", (), {
            "id": "msg-1",
            "outlet_id": outlet_id,
            "role": role,
            "sender_name": sender_name,
            "text": text,
            "actions_json": actions,
            "steps_json": steps,
            "reply_status": None,
            "reply_reason": None,
            "reply_error": None,
            "reply_detail": None,
            "reply_latency_ms": None,
            "reply_model": None,
            "reply_attempted_at": None,
            "created_at": None,
        })()
        return message

    async def fake_broadcast(outlet_id, payload):
        broadcasted.append(payload)

    async def fake_auto_reply(outlet_id, account=None):
        replies.append((outlet_id, account))

    def fake_create_task(coro):
        return asyncio.ensure_future(coro)

    monkeypatch.setattr(support_stt, "transcribe_audio", fake_transcribe)
    monkeypatch.setattr(ws_module, "_persist_support_message", fake_persist)
    monkeypatch.setattr(ws_module.manager, "broadcast", fake_broadcast)
    monkeypatch.setattr(ws_module, "support_llm_auto_reply", fake_auto_reply)
    monkeypatch.setattr(ws_module.asyncio, "create_task", fake_create_task)

    await ws_module._handle_support_stt("outlet-1", "AAA", "Rahim")
    await asyncio.sleep(0)
    assert persisted == [("client", "Rahim", "আমার কথা শুনুন")]
    msg_broadcasts = [p for p in broadcasted if p["type"] == "support_msg"]
    ack_broadcasts = [p for p in broadcasted if p["type"] == "support_stt_result"]
    assert msg_broadcasts[0]["data"]["text"] == "আমার কথা শুনুন"
    assert ack_broadcasts[0]["data"]["status"] == "ok"
    assert replies == [("outlet-1", None)]  # no token account on the voice clip


@pytest.mark.asyncio
async def test_ws_handler_empty_transcript_acks_empty(monkeypatch):
    broadcasted = []

    async def fake_transcribe(audio):
        return ""

    async def fake_persist(*args, **kwargs):
        raise AssertionError("empty transcript must not persist a message")

    async def fake_broadcast(outlet_id, payload):
        broadcasted.append(payload)

    monkeypatch.setattr(support_stt, "transcribe_audio", fake_transcribe)
    monkeypatch.setattr(ws_module, "_persist_support_message", fake_persist)
    monkeypatch.setattr(ws_module.manager, "broadcast", fake_broadcast)

    await ws_module._handle_support_stt("outlet-1", "AAA", None)
    assert [p["type"] for p in broadcasted] == ["support_stt_result"]
    assert broadcasted[0]["data"]["status"] == "empty"