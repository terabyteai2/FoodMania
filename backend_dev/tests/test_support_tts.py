import asyncio
import json

import pytest
import routers.ws as ws_module

from services import support_tts
from services.sarvam_tts import SarvamTtsWsClient, split_sentences


def test_split_sentences_bengali_and_latin_punct():
    assert split_sentences("আপনার অর্ডারটা বুঝেছি। মোট ৫২৫ টাকা। কনফার্ম করবেন?") == [
        "আপনার অর্ডারটা বুঝেছি।",
        "মোট ৫২৫ টাকা।",
        "কনফার্ম করবেন?",
    ]
    assert split_sentences("") == []


def test_set_muted_and_is_muted():
    support_tts.set_muted("outlet-1", True)
    assert support_tts.is_muted("outlet-1")
    support_tts.set_muted("outlet-1", False)
    assert not support_tts.is_muted("outlet-1")
    support_tts._muted_outlets.discard("outlet-1")


@pytest.mark.asyncio
async def test_stream_support_audio_muted_skips(monkeypatch):
    support_tts.set_muted("outlet-1", True)
    called = {"connect": 0, "broadcast": 0}

    class FakeClient:
        async def connect(self):
            called["connect"] += 1
            return True

        async def close(self):
            pass

    monkeypatch.setattr(support_tts, "SarvamTtsWsClient", FakeClient)

    async def fake_broadcast(outlet_id, payload):
        called["broadcast"] += 1

    monkeypatch.setattr(ws_module.manager, "broadcast", fake_broadcast)
    monkeypatch.setattr(support_tts.settings, "SARVAM_API_KEY", "key")
    await support_tts.stream_support_audio("outlet-1", "msg-1", "হ্যালো।")
    assert called["connect"] == 0
    assert called["broadcast"] == 0
    support_tts.set_muted("outlet-1", False)


@pytest.mark.asyncio
async def test_stream_support_audio_relays_frames_and_done(monkeypatch):
    broadcasted = []

    class FakeWs:
        def __init__(self, messages):
            self._messages = list(messages)

        async def recv(self):
            if not self._messages:
                raise ConnectionError("closed")
            return self._messages.pop(0)

        async def send(self, raw):
            pass

    class FakeClient:
        def __init__(self):
            self.ws = FakeWs([
                json.dumps({"type": "audio", "data": {"audio": "AAA"}}),
                json.dumps({"type": "audio", "data": {"audio": "BBB"}}),
                json.dumps({"type": "event", "data": {"event_type": "final"}}),
            ])

        async def connect(self):
            return True

        async def send_text(self, text):
            return True

        async def close(self):
            pass

    async def fake_broadcast(outlet_id, payload):
        broadcasted.append(payload)

    monkeypatch.setattr(support_tts, "SarvamTtsWsClient", FakeClient)
    monkeypatch.setattr(ws_module.manager, "broadcast", fake_broadcast)
    monkeypatch.setattr(support_tts.settings, "SARVAM_API_KEY", "key")
    await support_tts.stream_support_audio("outlet-1", "msg-1", "হ্যালো। কেমন আছেন?")
    audio_frames = [p for p in broadcasted if p["type"] == "support_audio"]
    done_frames = [p for p in broadcasted if p["type"] == "support_audio_done"]
    assert [f["data"]["audio"] for f in audio_frames] == ["AAA", "BBB"]
    assert all(f["data"]["messageId"] == "msg-1" for f in audio_frames)
    assert done_frames == [{"type": "support_audio_done", "data": {"messageId": "msg-1"}}]


@pytest.mark.asyncio
async def test_stream_support_audio_no_key_skips(monkeypatch):
    called = {"connect": 0}

    class FakeClient:
        async def connect(self):
            called["connect"] += 1
            return True

        async def close(self):
            pass

    monkeypatch.setattr(support_tts, "SarvamTtsWsClient", FakeClient)
    monkeypatch.setattr(support_tts.settings, "SARVAM_API_KEY", "")
    await support_tts.stream_support_audio("outlet-1", "msg-1", "হ্যালো।")
    assert called["connect"] == 0