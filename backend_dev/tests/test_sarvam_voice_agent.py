import asyncio
import json

import pytest

from services.sarvam_voice_agent import (
    _ReplyScanner,
    _TtsWsClient,
    _append_event_reply,
    _build_menu_lookup,
    _lookup_item,
    _merge_state,
    _merge_turn_parts,
    _parse_json_object,
    _split_sentences,
    _validate_lines,
)


class _FakeItem:
    def __init__(self, name, price, item_id="mid-1"):
        self.name = name
        self.name_en = name
        self.name_bn = ""
        self.id = item_id
        self.price = price
        self.category = "Main"


MENU = [
    _FakeItem("Burger", 250.0, "mid-1"),
    _FakeItem("Pizza", 450.0, "mid-2"),
    _FakeItem("Biryani", 180.0, "mid-3"),
]


def test_build_menu_lookup_lowercases_names():
    lookup = _build_menu_lookup(MENU)
    assert "burger" in lookup
    assert lookup["biryani"]["id"] == "mid-3"
    assert lookup["pizza"]["price"] == 450.0


def test_lookup_item_direct_and_partial():
    lookup = _build_menu_lookup(MENU)
    assert _lookup_item("Burger", lookup)["id"] == "mid-1"
    assert _lookup_item("burger ", lookup)["id"] == "mid-1"
    assert _lookup_item("chicken burger", lookup)["id"] == "mid-1"
    assert _lookup_item("unknown dish", lookup) is None


def test_parse_json_object_handles_fences():
    assert _parse_json_object('{"a": 1}') == {"a": 1}
    assert _parse_json_object('```json\n{"a": 2}\n```') == {"a": 2}
    with pytest.raises(Exception):
        _parse_json_object("not json")


def test_validate_lines_resolves_missing_menu_item_id():
    lines, issue = _validate_lines(
        [{"name": "Burger", "qty": 2, "price": 0}],
        _build_menu_lookup(MENU),
    )
    assert issue is None
    assert lines == [{"name": "Burger", "menu_item_id": "mid-1", "qty": 2, "price": 250.0}]


def test_validate_lines_rejects_unknown_item():
    lines, issue = _validate_lines([{"name": "Pasta", "qty": 1}], _build_menu_lookup(MENU))
    assert lines == []
    assert issue is not None


def test_merge_state_add_and_merge_same_item():
    state = _merge_state({}, {"intent": "add_item", "item": "Burger", "qty": 1, "menu_item_id": "mid-1", "price": 250})
    assert state["items"] == [{"name": "Burger", "qty": 1, "menu_item_id": "mid-1", "price": 250}]
    state = _merge_state(state, {"intent": "add_item", "item": "Burger", "qty": 2})
    assert state["items"][0]["qty"] == 3


def test_merge_state_remove_set_info_confirm_cancel():
    state = {"items": [{"name": "Burger", "qty": 2, "menu_item_id": "mid-1", "price": 250}]}
    state = _merge_state(state, {"intent": "remove_item", "item": "Burger", "qty": 1})
    assert state["items"][0]["qty"] == 1
    state = _merge_state(state, {"intent": "set_info", "key": "customerName", "value": "Rahim"})
    assert state["customerName"] == "Rahim"
    state = _merge_state(state, {"intent": "confirm"})
    assert state["awaitingConfirmation"] is True
    state = _merge_state(state, {"intent": "cancel"})
    assert state == {"items": [], "awaitingConfirmation": False}


def test_append_event_reply_suffixes():
    assert _append_event_reply("হ্যাঁ", {"type": "order_created", "orderNumber": 5, "totalAmount": 525}) == "হ্যাঁ আপনার অর্ডার #5 সম্পন্ন হয়েছে। মোট: ৳525।"
    assert _append_event_reply("হ্যাঁ", {"type": "needs_info", "missing": ["customerName", "deliveryAddress"]}) == "হ্যাঁ আপনার নাম ও ডেলিভারি ঠিকানা জানান।"
    assert _append_event_reply("হ্যাঁ", None) == "হ্যাঁ"


def test_merge_turn_parts_replaces_progressive_segments():
    parts = ["আমার।", "আমার কথা।", "আমার কথা থেকে কি শোনা যাচ্ছে?"]
    assert _merge_turn_parts(parts) == "আমার কথা থেকে কি শোনা যাচ্ছে?"


def test_merge_turn_parts_joins_distinct_sentences():
    assert _merge_turn_parts(["একটা বার্গার", "আর একটা পিৎজা"]) == "একটা বার্গার আর একটা পিৎজা"


def test_merge_turn_parts_skips_empty_and_dupes():
    assert _merge_turn_parts(["", "বার্গার", "বার্গার", "  "]) == "বার্গার"


def test_split_sentences_bengali_danda_and_latin_punct():
    text = "আপনার অর্ডারটা বুঝেছি। মোট ৫২৫ টাকা। কনফার্ম করবেন?"
    assert _split_sentences(text) == ["আপনার অর্ডারটা বুঝেছি।", "মোট ৫২৫ টাকা।", "কনফার্ম করবেন?"]


def test_split_sentences_keeps_ellipsis_and_newlines():
    text = "একটু অপেক্ষা করুন…\nআর কিছু লাগবে?"
    assert _split_sentences(text) == ["একটু অপেক্ষা করুন…", "আর কিছু লাগবে?"]


def test_split_sentences_does_not_split_decimal_number():
    assert _split_sentences("মোট ৳2.5 বাকি আছে। ধন্যবাদ!") == ["মোট ৳2.5 বাকি আছে।", "ধন্যবাদ!"]


def test_split_sentences_empty_and_whitespace():
    assert _split_sentences("") == []
    assert _split_sentences("   ") == []


def test_scanner_waits_for_closed_reply_value():
    scanner = _ReplyScanner()
    assert scanner.feed('{"replyType": "chat", "reply": "আসসালামু') == []
    assert scanner.feed('আলাইকুম।') == []
    assert scanner.feed('" }') == ["আসসালামুআলাইকুম।"]


def test_scanner_emits_sentences_incrementally():
    scanner = _ReplyScanner()
    out = scanner.feed('{"replyType":"action","reply":"একটা বার্গার যোগ হলো। আর কিছু লাগবে?')
    assert out == []
    out = scanner.feed('", "action": {"intent": "add_item"}}')
    assert out == ["একটা বার্গার যোগ হলো।", "আর কিছু লাগবে?"]
    assert scanner.feed("x") == []


def test_scanner_emits_reply_before_action_tail():
    scanner = _ReplyScanner()
    assert scanner.feed('{"replyType":"action","reply":"আপনার অর্ডার: বার্গার।') == []
    out = scanner.feed('", "action": {"intent": "add_item", "item": "Burger", "qty": 1}')
    assert out == ["আপনার অর্ডার: বার্গার।"]


def test_scanner_does_not_match_replytype():
    scanner = _ReplyScanner()
    assert scanner.feed('{"replyType":"chat"}') == []
    assert scanner.feed(', "reply": ""') == []


def test_scanner_handles_escaped_quotes_in_reply():
    scanner = _ReplyScanner()
    out = scanner.feed('{"replyType":"chat","reply":"বলুন \\"হ্যাঁ\\" দিতে পারি।"}')
    assert out == ['বলুন \\"হ্যাঁ\\" দিতে পারি।']


def test_scanner_tracks_emitted_chars():
    scanner = _ReplyScanner()
    scanner.feed('{"replyType":"chat","reply":"জি বলুন।"}')
    assert scanner.emitted_chars == len("জি বলুন。")


class _FakeWsState:
    def __init__(self, name="OPEN"):
        self.name = name


class _FakeTtsWs:
    def __init__(self, state="OPEN"):
        self.state = _FakeWsState(state)
        self.sent = []

    async def send(self, payload):
        self.sent.append(payload)

    async def close(self):
        self.state = _FakeWsState("CLOSED")


def test_tts_ws_connect_uses_config_type_and_model_query(monkeypatch):
    captured = {}
    fake = _FakeTtsWs()

    async def fake_connect(url, additional_headers=None, **kwargs):
        captured["url"] = url
        captured["headers"] = additional_headers
        return fake

    import services.sarvam_voice_agent as m
    monkeypatch.setattr(m.websockets, "connect", fake_connect)

    client = _TtsWsClient()
    assert asyncio.run(client.connect()) is True
    assert captured["url"].startswith(m.TTS_WS_URL + "?")
    assert "model=bulbul%3Av3" in captured["url"]
    assert "send_completion_event=true" in captured["url"]
    assert captured["headers"] == {"api-subscription-key": m.settings.SARVAM_API_KEY}
    assert fake.sent
    msg = json.loads(fake.sent[0])
    assert msg["type"] == "config"
    assert msg["data"]["model"] == "bulbul:v3"
    assert msg["data"]["speaker"] == "suhani"


def test_tts_ws_connect_does_not_reconnect_while_open(monkeypatch):
    import services.sarvam_voice_agent as m

    async def fail_connect(*args, **kwargs):
        raise AssertionError("should not reconnect")

    monkeypatch.setattr(m.websockets, "connect", fail_connect)

    client = _TtsWsClient()
    client.ws = _FakeTtsWs(state="OPEN")
    assert asyncio.run(client.connect()) is True


def test_tts_ws_connect_reconnects_after_closed(monkeypatch):
    captured = {}
    fake = _FakeTtsWs()

    async def fake_connect(url, additional_headers=None, **kwargs):
        captured["url"] = url
        return fake

    import services.sarvam_voice_agent as m
    monkeypatch.setattr(m.websockets, "connect", fake_connect)

    client = _TtsWsClient()
    client.ws = _FakeTtsWs(state="CLOSED")
    assert asyncio.run(client.connect()) is True
    assert "model=bulbul%3Av3" in captured["url"]


def test_tts_ws_send_text_returns_true_and_flushes(monkeypatch):
    import services.sarvam_voice_agent as m

    async def fake_connect(url, additional_headers=None, **kwargs):
        return _FakeTtsWs()

    monkeypatch.setattr(m.websockets, "connect", fake_connect)

    client = _TtsWsClient()
    assert asyncio.run(client.send_text("হ্যাঁ, শুনতে পাচ্ছি!")) is True
    messages = [json.loads(p) for p in client.ws.sent]
    assert messages[-2] == {"type": "text", "data": {"text": "হ্যাঁ, শুনতে পাচ্ছি!"}}
    assert messages[-1] == {"type": "flush"}
