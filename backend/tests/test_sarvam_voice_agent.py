import pytest

from services.sarvam_voice_agent import (
    _append_event_reply,
    _build_menu_lookup,
    _lookup_item,
    _merge_state,
    _merge_turn_parts,
    _parse_json_object,
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
