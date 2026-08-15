import asyncio
import json

import httpx
import pytest

import routers.ws as ws
from services import support_llm
from services.support_llm import (
    LlmResponseError,
    _call_llm,
    _clean_history_rows,
    _clean_step,
    _extract_json_block,
    _llm_config,
    _valid_spot,
    _valid_target,
    auto_reply,
    build_system_prompt,
    sanitize_guide,
)


def _mock_llm(monkeypatch, content: str, response_json: dict | None = None):
    if response_json is None:
        response_json = {"choices": [{"message": {"content": content}}]}

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json=response_json,
        )

    real_async_client = httpx.AsyncClient

    def mock_client(*, timeout):
        return real_async_client(
            transport=httpx.MockTransport(handler),
            timeout=timeout,
        )

    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_API_KEY", "")
    monkeypatch.setattr(support_llm.settings, "DEEPSEEK_API_KEY", "deepseek-test")
    monkeypatch.setattr(support_llm.httpx, "AsyncClient", mock_client)


def _mock_llm_sequence(monkeypatch, responses: list):
    """Scripted multi-turn LLM: each call returns the next response — a
    content string or a full assistant-message dict (e.g. with tool_calls) —
    and the last one repeats once the list is exhausted."""
    state = {"n": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        index = min(state["n"], len(responses) - 1)
        state["n"] += 1
        response = responses[index]
        if isinstance(response, str):
            message = {"content": response}
        else:
            message = response
        return httpx.Response(
            200,
            json={"choices": [{"message": message}]},
        )

    real_async_client = httpx.AsyncClient

    def mock_client(*, timeout):
        return real_async_client(
            transport=httpx.MockTransport(handler),
            timeout=timeout,
        )

    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_API_KEY", "")
    monkeypatch.setattr(support_llm.settings, "DEEPSEEK_API_KEY", "deepseek-test")
    monkeypatch.setattr(support_llm.httpx, "AsyncClient", mock_client)
    return state


def _tool_call_message(name: str, arguments: str = "{}") -> dict:
    """One native tool_calls assistant message, as the API returns it."""
    return {
        "role": "assistant",
        "content": None,
        "tool_calls": [
            {
                "id": f"call_{name}",
                "type": "function",
                "function": {"name": name, "arguments": arguments},
            }
        ],
    }


def _patch_outcome_recorder(monkeypatch):
    """Replaces _record_outcome with an in-memory capture so auto_reply tests
    assert the recorded status/reason without touching a database."""
    recorded = []

    async def fake_record_outcome(message_id, **kwargs):
        recorded.append((message_id, kwargs))

    monkeypatch.setattr(support_llm, "_record_outcome", fake_record_outcome)
    return recorded


def test_prompt_builds_sections_and_fetch_instructions():
    prompt = build_system_prompt()
    assert "Volt Assistant" in prompt
    assert "steps" in prompt
    assert "get_guide_deeplinks" in prompt
    assert "get_outlet_info" in prompt
    assert "DEEPLINK" not in prompt
    assert "ANSWER FORMAT" in prompt
    assert "THE APP YOU GUIDE USERS THROUGH" not in prompt
    assert "THIS OUTLET" not in prompt


def test_prompt_describes_live_data_tools():
    prompt = build_system_prompt()
    for tool in (
        "get_outlet_overview",
        "get_outlet_info",
        "get_recent_orders",
        "get_order",
        "get_menu_items",
        "get_stock",
        "get_daily_sales",
        "get_guide_deeplinks",
    ):
        assert tool in prompt
    assert "### TOOLS" in prompt
    assert "tool message" in prompt
    assert "always call get_guide_deeplinks — its results" in prompt


def test_sanitize_guide_drops_invalid_targets_and_caps():
    steps = [
        {"title": "Open Stock", "body": "Switch tab", "target": "tab:stock"},
        {"title": "Fake", "body": "y", "target": "tab:nope"},
        {"title": "Bad Spot", "body": "z", "spot": "menu.notARealSpot"},
        {"title": "Good Spot", "body": "w", "spot": "menu.scanCta"},
        "junk",
        {"title": "", "body": ""},
    ]
    for extra in range(6):
        steps.append({"title": f"Extra {extra}", "body": "b", "target": "tab:menu"})
    result = sanitize_guide(
        {
            "reply": "Here you go.",
            "actions": [
                {"label": "Stock", "target": "modal:menu_discounts"},
                {"label": "Bad", "target": "tab:nope"},
            ],
            "steps": steps,
        }
    )
    assert result["reply"] == "Here you go."
    assert result["actions"] == [
        {"label": "Stock", "target": "modal:menu_discounts"}
    ]
    assert len(result["steps"]) == support_llm.SUPPORT_LLM_MAX_STEPS
    assert result["steps"][0] == {
        "title": "Open Stock",
        "body": "Switch tab",
        "target": "tab:stock",
    }
    kept = [s["title"] for s in result["steps"]]
    assert "Open Stock" in kept
    fake_entry = next(s for s in result["steps"] if s["title"] == "Fake")
    assert "target" not in fake_entry  # invalid target dropped, step kept
    bad_spot_entry = next(s for s in result["steps"] if s["title"] == "Bad Spot")
    assert "spot" not in bad_spot_entry  # invalid spot dropped
    good_spot = next(s for s in result["steps"] if s["title"] == "Good Spot")
    assert good_spot["spot"] == "menu.scanCta"


def test_sanitize_guide_chat_only_reply_has_no_guide():
    result = sanitize_guide({"reply": "Hi, how can I help?"})
    assert result == {"reply": "Hi, how can I help?"}


def test_clean_step_requires_content_and_validates():
    assert _clean_step({"title": "", "body": ""}) is None
    assert _clean_step("junk") is None
    step = _clean_step(
        {"title": "A", "body": "B", "target": "tab:analytics", "spot": "nav.analytics"}
    )
    assert step == {"title": "A", "body": "B", "target": "tab:analytics", "spot": "nav.analytics"}
    assert "target" not in _clean_step({"title": "A", "body": "B", "target": "bogus"})
    assert _clean_step({"title": "A", "body": "B", "shape": "bogus"}) == {
        "title": "A",
        "body": "B",
    }


def test_clean_step_passes_through_valid_shape():
    step = _clean_step(
        {
            "title": "A",
            "body": "B",
            "spot": "orders.newOrderFab",
            "shape": "circle",
        }
    )
    assert step["shape"] == "circle"
    assert _clean_step(
        {"title": "A", "body": "B", "spot": "orders.cardBill", "shape": "roundedRect"}
    )["shape"] == "roundedRect"


def test_vocabulary_validation():
    assert _valid_target("tab:stock")
    assert _valid_target("screen:staff")
    assert _valid_target("modal:menu_discounts")
    assert _valid_target("highlight:menu.scanCta")
    assert _valid_target("screen:control_tower")
    assert _valid_target("screen:settings")
    assert _valid_target("highlight:stock.table")
    assert _valid_target("highlight:more.helpGuide")
    assert not _valid_target("tab:nope")
    assert not _valid_target("screen:xyz")
    assert not _valid_target("")
    assert not _valid_target("javascript:alert(1)")
    assert _valid_spot("orders.newOrderFab")
    assert _valid_spot("nav.reports")
    assert not _valid_spot("bogus.spot")


def test_llm_config_falls_back_to_deepseek(monkeypatch):
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_BASE_URL", "")
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_API_KEY", "")
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_MODEL", "")
    monkeypatch.setattr(support_llm.settings, "DEEPSEEK_API_KEY", "dk")
    monkeypatch.setattr(support_llm.settings, "CHATBOT_DEEPSEEK_MODEL", "deepseek-chat")
    assert _llm_config() == ("https://api.deepseek.com/v1", "dk", "deepseek-chat")


def test_llm_config_none_without_key(monkeypatch):
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_API_KEY", "")
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_API_KEY", "")
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_MODEL", "")
    monkeypatch.setattr(support_llm.settings, "DEEPSEEK_API_KEY", "")
    monkeypatch.setattr(support_llm.settings, "CHATBOT_DEEPSEEK_MODEL", "deepseek-chat")
    assert _llm_config() is None


def test_llm_config_custom_route(monkeypatch):
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_BASE_URL", "https://gateway.example.com/v1")
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_API_KEY", "custom")
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_MODEL", "gpt-x")
    monkeypatch.setattr(support_llm.settings, "DEEPSEEK_API_KEY", "dk")
    assert _llm_config() == ("https://gateway.example.com/v1", "custom", "gpt-x")


async def test_call_llm_parses_json(monkeypatch):
    _mock_llm(monkeypatch, json.dumps({"reply": "ok", "steps": []}))
    assistant_msg, parsed = await _call_llm(
        build_system_prompt(),
        [{"role": "user", "content": "how do I add stock?"}],
    )
    assert parsed == {"reply": "ok", "steps": []}
    assert not assistant_msg.get("tool_calls")


async def test_call_llm_handles_fenced_json(monkeypatch):
    _mock_llm(monkeypatch, "```json\n{\"reply\": \"hi\"}\n```")
    _, parsed = await _call_llm("sys", [{"role": "user", "content": "hi"}])
    assert parsed == {"reply": "hi"}


async def test_call_llm_returns_native_tool_calls(monkeypatch):
    assistant_msg = {
        "role": "assistant",
        "content": None,
        "tool_calls": [
            {
                "id": "call_1",
                "type": "function",
                "function": {
                    "name": "get_outlet_info",
                    "arguments": "{}",
                },
            }
        ],
    }
    _mock_llm(monkeypatch, "", {"choices": [{"message": assistant_msg}]})
    returned, parsed = await _call_llm("sys", [{"role": "user", "content": "hi"}])
    assert parsed is None
    assert returned["tool_calls"][0]["id"] == "call_1"
    assert returned["tool_calls"][0]["function"]["name"] == "get_outlet_info"


async def test_call_llm_normalizes_prose_final(monkeypatch):
    _mock_llm(monkeypatch, "Today you sold 12 orders.")
    _, parsed = await _call_llm("sys", [{"role": "user", "content": "hi"}])
    assert parsed == {"reply": "Today you sold 12 orders."}


async def test_call_llm_extracts_json_from_prose(monkeypatch):
    _mock_llm(monkeypatch, 'Sure! Here you go: {"reply": "Done!"} Enjoy!')
    _, parsed = await _call_llm("sys", [{"role": "user", "content": "hi"}])
    assert parsed == {"reply": "Done!"}


async def test_call_llm_one_shot_no_retry_on_prose(monkeypatch):
    state = _mock_llm_sequence(monkeypatch, ["Here: not json"])
    _, parsed = await _call_llm("sys", [{"role": "user", "content": "hi"}])
    assert parsed == {"reply": "Here: not json"}
    assert state["n"] == 1  # one call, no retry


def test_extract_json_block_respects_strings():
    assert _extract_json_block('x {"a": "b"} y') == '{"a": "b"}'
    assert _extract_json_block('x {"a": "b}"} y') == '{"a": "b}"}'
    assert _extract_json_block('{"a": {"b": 1}, "c": 2} tail') == '{"a": {"b": 1}, "c": 2}'
    assert _extract_json_block("no json here") == ""


def test_clean_history_rows_drops_trivial_and_duplicates():
    from types import SimpleNamespace

    def row(text, role="client"):
        return SimpleNamespace(text=text, role=role)

    rows = _clean_history_rows(
        [
            row("?"),
            row("hi"),
            row("hi"),
            row("   "),
            row("replyyy"),
            row("!"),
            row("What's up?"),
        ]
    )
    assert [r.text for r in rows] == ["hi", "replyyy", "What's up?"]


def test_clean_history_rows_preserves_meaningful_repeats():
    from types import SimpleNamespace

    def row(text):
        return SimpleNamespace(text=text, role="client")

    rows = _clean_history_rows([row("how do I add stock"), row("how do I add stock")])
    assert len(rows) == 1


async def test_call_llm_raises_without_config(monkeypatch):
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_API_KEY", "")
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_API_KEY", "")
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_MODEL", "")
    monkeypatch.setattr(support_llm.settings, "DEEPSEEK_API_KEY", "")
    monkeypatch.setattr(support_llm.settings, "CHATBOT_DEEPSEEK_MODEL", "deepseek-chat")
    with pytest.raises(RuntimeError):
        await _call_llm("sys", [{"role": "user", "content": "hi"}])


async def test_auto_reply_cooldown_records_skip(monkeypatch):
    _mock_llm(monkeypatch, json.dumps({"reply": "Done!"}))
    support_llm._last_reply_at = {}
    support_llm._in_flight = {}
    support_llm._last_reply_at["outlet-1"] = (
        asyncio.get_running_loop().time() - 0.001
    )
    recorded = _patch_outcome_recorder(monkeypatch)

    persisted = []
    broadcasted = []

    async def fake_load_history(outlet_id, limit=20):
        class Row:
            id = "m-client"
            role = "client"
            text = "how do I do this"

        return [Row()]

    class FakeMessage:
        id = "m1"
        outlet_id = "outlet-1"
        role = "server"
        sender_name = "Volt Assistant"
        text = "Done!"
        actions_json = None
        steps_json = None
        reply_status = None
        reply_reason = None
        reply_error = None
        reply_latency_ms = None
        reply_model = None
        reply_attempted_at = None
        reply_detail = None
        created_at = None

    async def fake_persist(outlet_id, role, sender_name, text, actions=None, steps=None):
        persisted.append((outlet_id, role, sender_name, text, actions, steps))
        return FakeMessage()

    class FakeManager:
        async def broadcast(self, outlet_id, payload):
            broadcasted.append(payload)

    monkeypatch.setattr(support_llm, "_load_history", fake_load_history)
    monkeypatch.setattr(ws, "_persist_support_message", fake_persist)
    monkeypatch.setattr(ws, "manager", FakeManager())

    await auto_reply("outlet-1")
    assert persisted == []
    assert broadcasted == []
    assert not support_llm._in_flight.get("outlet-1")
    assert recorded == [
        ("m-client", {"status": "skipped", "reason": "cooldown"})
    ]


async def test_auto_reply_in_flight_records_skip(monkeypatch):
    support_llm._last_reply_at = {}
    support_llm._in_flight = {}
    support_llm._in_flight["outlet-1"] = True
    recorded = _patch_outcome_recorder(monkeypatch)

    async def fake_load_history(outlet_id, limit=20):
        class Row:
            id = "m-client"
            role = "client"
            text = "how do I do this"

        return [Row()]

    monkeypatch.setattr(support_llm, "_load_history", fake_load_history)

    await auto_reply("outlet-1")
    assert recorded == [
        ("m-client", {"status": "skipped", "reason": "in_flight"})
    ]


async def test_auto_reply_persists_and_broadcasts_sanitized_guide(monkeypatch):
    _mock_llm(
        monkeypatch,
        json.dumps(
            {
                "reply": "Let me show you.",
                "steps": [
                    {"title": "Open Stock", "body": "Switch.", "target": "tab:stock"},
                    {"title": "Bad", "body": "x", "target": "tab:nope"},
                ],
                "actions": [{"label": "Go", "target": "tab:menu"}],
            }
        ),
    )
    support_llm._last_reply_at = {}
    support_llm._in_flight = {}
    recorded = _patch_outcome_recorder(monkeypatch)

    persisted = []
    broadcasted = []

    async def fake_load_history(outlet_id, limit=20):
        class Row:
            id = "m-client"
            role = "client"
            text = "how do I add stock?"

        return [Row()]

    class FakeMessage:
        id = "m1"
        outlet_id = "outlet-1"
        role = "server"
        sender_name = "Volt Assistant"
        text = "Let me show you."
        actions_json = None
        steps_json = None
        reply_status = None
        reply_reason = None
        reply_error = None
        reply_latency_ms = None
        reply_model = None
        reply_attempted_at = None
        reply_detail = None
        created_at = None

    async def fake_persist(outlet_id, role, sender_name, text, actions=None, steps=None):
        persisted.append((outlet_id, role, sender_name, text, actions, steps))
        return FakeMessage()

    class FakeManager:
        async def broadcast(self, outlet_id, payload):
            broadcasted.append((outlet_id, payload))

    monkeypatch.setattr(support_llm, "_load_history", fake_load_history)
    monkeypatch.setattr(ws, "_persist_support_message", fake_persist)
    monkeypatch.setattr(ws, "manager", FakeManager())

    await auto_reply("outlet-1")

    assert len(persisted) == 1
    outlet_id, role, sender_name, text, actions, steps = persisted[0]
    assert outlet_id == "outlet-1"
    assert role == "server"
    assert sender_name == "Volt Assistant"
    assert text == "Let me show you."
    assert actions == [{"label": "Go", "target": "tab:menu"}]
    assert steps == [
        {"title": "Open Stock", "body": "Switch.", "target": "tab:stock"},
        {"title": "Bad", "body": "x"},
    ]
    assert len(broadcasted) == 1
    assert broadcasted[0][0] == "outlet-1"
    assert broadcasted[0][1]["type"] == "support_msg"
    assert broadcasted[0][1]["data"]["role"] == "server"
    assert broadcasted[0][1]["data"]["text"] == "Let me show you."
    assert support_llm._last_reply_at.get("outlet-1")

    message_id, outcome = recorded[0]
    assert message_id == "m-client"
    assert outcome["status"] == "replied"
    assert outcome["model"] == "deepseek-chat"
    assert outcome["attempted"] is True
    assert isinstance(outcome["latency_ms"], int)


async def test_auto_reply_skips_when_last_message_is_server(monkeypatch):
    async def fake_load_history(outlet_id, limit=20):
        class Row:
            id = "m-server"
            role = "server"
            text = "hi"

        return [Row()]

    monkeypatch.setattr(support_llm, "_load_history", fake_load_history)
    recorded = _patch_outcome_recorder(monkeypatch)

    called = False

    async def fake_call_llm(system_prompt, history):
        nonlocal called
        called = True
        return {}, {"reply": "x"}

    monkeypatch.setattr(support_llm, "_call_llm", fake_call_llm)
    support_llm._in_flight = {}
    support_llm._last_reply_at = {}

    await auto_reply("outlet-1")
    assert not called
    assert recorded == []  # no outcome for server messages


async def test_auto_reply_records_no_config_failure(monkeypatch):
    async def fake_load_history(outlet_id, limit=20):
        class Row:
            id = "m-client"
            role = "client"
            text = "hi"

        return [Row()]

    monkeypatch.setattr(support_llm, "_load_history", fake_load_history)
    monkeypatch.setattr(support_llm, "_llm_config", lambda: None)
    recorded = _patch_outcome_recorder(monkeypatch)
    support_llm._in_flight = {}
    support_llm._last_reply_at = {}

    await auto_reply("outlet-1")
    assert recorded == [
        (
            "m-client",
            {
                "status": "failed",
                "reason": "no_config",
                "error": "Support chat LLM is not configured.",
                "attempted": True,
            },
        )
    ]


async def test_auto_reply_survives_llm_failure(monkeypatch):
    async def fake_load_history(outlet_id, limit=20):
        class Row:
            id = "m-client"
            role = "client"
            text = "hi"

        return [Row()]

    async def fake_call_llm(system_prompt, history, outlet_id=None):
        raise httpx.TimeoutException("timed out")

    monkeypatch.setattr(support_llm, "_load_history", fake_load_history)
    monkeypatch.setattr(support_llm, "_call_llm", fake_call_llm)
    monkeypatch.setattr(
        support_llm, "_llm_config", lambda: ("https://api.deepseek.com/v1", "k", "deepseek-chat")
    )
    recorded = _patch_outcome_recorder(monkeypatch)
    support_llm._in_flight = {}
    support_llm._last_reply_at = {}

    await auto_reply("outlet-1")  # must not raise
    assert not support_llm._in_flight.get("outlet-1")
    message_id, outcome = recorded[0]
    assert message_id == "m-client"
    assert outcome["status"] == "failed"
    assert outcome["reason"] == "timeout"
    assert outcome["attempted"] is True


def test_classify_llm_error_maps_http_and_json():
    reason, error = support_llm._classify_llm_error(
        httpx.HTTPStatusError(
            "rate limited",
            request=httpx.Request("POST", "https://x"),
            response=httpx.Response(429),
        )
    )
    assert reason == "http_error"
    assert error == "HTTP 429"
    reason, error = support_llm._classify_llm_error(ValueError("bad json"))
    assert reason == "invalid_json"
    reason, error = support_llm._classify_llm_error(RuntimeError("boom"))
    assert reason == "llm_error"
    reason, error = support_llm._classify_llm_error(
        support_llm.LlmResponseError("empty response", {"finishReason": "stop"})
    )
    assert reason == "empty_reply"
    reason, error = support_llm._classify_llm_error(
        support_llm.LlmResponseError("not valid JSON", {"finishReason": "length"})
    )
    assert reason == "invalid_json"
    reason, error = support_llm._classify_llm_error(
        RuntimeError("LLM returned an empty response (deepseek-chat).")
    )
    assert reason == "empty_reply"


def test_response_snapshot_captures_raw_payload(monkeypatch):
    response = httpx.Response(
        200,
        headers={"content-type": "application/json", "x-ds-trace-id": "trace-1"},
        json={
            "model": "deepseek-chat",
            "choices": [
                {
                    "message": {"content": ""},
                    "finish_reason": "stop",
                }
            ],
            "usage": {"prompt_tokens": 500, "completion_tokens": 0},
        },
    )
    payload = response.json()
    snapshot = support_llm._response_snapshot(response, payload)
    assert snapshot["httpStatus"] == 200
    assert snapshot["traceId"] == "trace-1"
    assert snapshot["finishReason"] == "stop"
    assert snapshot["choicesCount"] == 1
    assert snapshot["contentLength"] == 0
    assert snapshot["usage"] == {"prompt_tokens": 500, "completion_tokens": 0}
    assert "deepseek-chat" in snapshot["bodySnippet"]


def test_request_fingerprint_describes_what_we_sent():
    class Row:
        role = "client"
        text = "hello there"

    fingerprint = support_llm._request_fingerprint(
        [Row()], system_prompt="SYSPROMPT", model="deepseek-chat"
    )
    assert fingerprint["model"] == "deepseek-chat"
    assert fingerprint["historySize"] == 1
    assert fingerprint["lastMessage"] == "hello there"
    assert fingerprint["lastMessageLength"] == 11
    assert fingerprint["systemPromptChars"] == 9
    assert fingerprint["maxTokens"] == support_llm.LLM_MAX_TOKENS
    assert fingerprint["nativeTools"] == len(support_llm.tools_schema())


async def test_call_llm_empty_content_raises_with_snapshot(monkeypatch):
    _mock_llm(
        monkeypatch,
        "",
        response_json={
            "model": "deepseek-chat",
            "choices": [{"message": {"content": ""}, "finish_reason": "stop"}],
            "usage": {"prompt_tokens": 500, "completion_tokens": 0},
        },
    )
    with pytest.raises(support_llm.LlmResponseError) as exc_info:
        await _call_llm("sys", [{"role": "user", "content": "hi"}])
    detail = exc_info.value.detail
    assert detail["finishReason"] == "stop"
    assert detail["httpStatus"] == 200
    assert detail["usage"]["completion_tokens"] == 0
    assert "empty response" in str(exc_info.value)


async def test_auto_reply_records_detail_on_empty_reply(monkeypatch):
    _mock_llm(
        monkeypatch,
        "",
        response_json={
            "model": "deepseek-chat",
            "choices": [{"message": {"content": ""}, "finish_reason": "stop"}],
            "usage": {"prompt_tokens": 500, "completion_tokens": 0},
        },
    )
    support_llm._last_reply_at = {}
    support_llm._in_flight = {}
    recorded = _patch_outcome_recorder(monkeypatch)

    async def fake_load_history(outlet_id, limit=20):
        class Row:
            id = "m-client"
            role = "client"
            text = "hello"

        return [Row()]

    monkeypatch.setattr(support_llm, "_load_history", fake_load_history)

    await auto_reply("outlet-1")
    assert not support_llm._in_flight.get("outlet-1")
    message_id, outcome = recorded[0]
    assert message_id == "m-client"
    assert outcome["status"] == "failed"
    assert outcome["reason"] == "empty_reply"
    detail = outcome["detail"]
    assert detail["finishReason"] == "stop"
    assert detail["model"] == "deepseek-chat"
    request = detail["request"]
    assert request["historySize"] == 1
    assert request["lastMessage"] == "hello"


def test_llm_config_summary(monkeypatch):
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_BASE_URL", "")
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_API_KEY", "")
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_MODEL", "")
    monkeypatch.setattr(support_llm.settings, "DEEPSEEK_API_KEY", "")
    monkeypatch.setattr(support_llm.settings, "CHATBOT_DEEPSEEK_MODEL", "deepseek-chat")
    summary = support_llm.llm_config_summary()
    assert summary == {
        "configured": False,
        "baseUrl": "https://api.deepseek.com/v1",
        "model": "deepseek-chat",
        "apiKeyConfigured": False,
    }
    monkeypatch.setattr(support_llm.settings, "DEEPSEEK_API_KEY", "dk")
    assert support_llm.llm_config_summary()["configured"] is True


# ---------------------------------------------------------------------------
# Tool protocol (live-data queries)
# ---------------------------------------------------------------------------


def _auto_reply_env(monkeypatch, recorded):
    """Shared fakes for auto_reply tests that exercise the tool loop."""
    support_llm._last_reply_at = {}
    support_llm._in_flight = {}
    persisted = []
    broadcasted = []

    async def fake_load_history(outlet_id, limit=20):
        class Row:
            id = "m-client"
            role = "client"
            text = "do we have any chicken left?"

        return [Row()]

    class FakeMessage:
        id = "m1"
        outlet_id = "outlet-1"
        role = "server"
        sender_name = "Volt Assistant"
        text = ""
        actions_json = None
        steps_json = None
        reply_status = None
        reply_reason = None
        reply_error = None
        reply_latency_ms = None
        reply_model = None
        reply_attempted_at = None
        reply_detail = None
        created_at = None

    async def fake_persist(outlet_id, role, sender_name, text, actions=None, steps=None):
        message = FakeMessage()
        message.text = text
        persisted.append((outlet_id, role, sender_name, text, actions, steps))
        return message

    class FakeManager:
        async def broadcast(self, outlet_id, payload):
            broadcasted.append((outlet_id, payload))

    monkeypatch.setattr(support_llm, "_load_history", fake_load_history)
    monkeypatch.setattr(ws, "_persist_support_message", fake_persist)
    monkeypatch.setattr(ws, "manager", FakeManager())
    return persisted, broadcasted


async def test_auto_reply_runs_tool_then_replies(monkeypatch):
    _mock_llm_sequence(
        monkeypatch,
        [
            _tool_call_message(
                "get_stock", '{"query": "chicken", "lowStockOnly": true}'
            ),
            json.dumps({"reply": "You have 3 kg of chicken — plenty."}),
        ],
    )
    executed = []

    async def fake_execute_tool(name, raw_args, outlet_id, account=None):
        executed.append((name, raw_args, outlet_id, account))
        return {"ok": True, "count": 1, "items": [{"name": "Chicken", "quantity": 3}]}

    monkeypatch.setattr(support_llm, "execute_tool", fake_execute_tool)
    recorded = _patch_outcome_recorder(monkeypatch)
    persisted, broadcasted = _auto_reply_env(monkeypatch, recorded)

    await auto_reply("outlet-1")

    assert executed == [
        (
            "get_stock",
            {"query": "chicken", "lowStockOnly": True},
            "outlet-1",
            None,  # no account resolved -> default (bootstrap) role
        )
    ]
    assert len(persisted) == 1
    assert persisted[0][3] == "You have 3 kg of chicken — plenty."
    assert len(broadcasted) == 1
    assert broadcasted[0][1]["data"]["text"] == "You have 3 kg of chicken — plenty."
    message_id, outcome = recorded[0]
    assert outcome["status"] == "replied"
    assert outcome["detail"] == {"tools": ["get_stock"], "toolCalls": 1}


async def test_auto_reply_unknown_tool_recovers_and_replies(monkeypatch):
    _mock_llm_sequence(
        monkeypatch,
        [
            _tool_call_message("nope"),
            json.dumps({"reply": "Sorry, I can't do that yet."}),
        ],
    )
    recorded = _patch_outcome_recorder(monkeypatch)
    persisted, _ = _auto_reply_env(monkeypatch, recorded)

    await auto_reply("outlet-1")

    assert len(persisted) == 1
    assert persisted[0][3] == "Sorry, I can't do that yet."
    message_id, outcome = recorded[0]
    assert outcome["status"] == "replied"
    # The unknown name still reaches the real whitelist in execute_tool and
    # comes back as an error result; the model recovers and replies.
    assert outcome["detail"] == {"tools": ["nope"], "toolCalls": 1}


async def test_auto_reply_tool_budget_exhausted_fails(monkeypatch):
    _mock_llm_sequence(monkeypatch, [_tool_call_message("get_stock")] * 10)
    executed = []

    async def fake_execute_tool(name, raw_args, outlet_id, account=None):
        executed.append(name)
        return {"ok": True, "count": 0, "items": []}

    monkeypatch.setattr(support_llm, "execute_tool", fake_execute_tool)
    recorded = _patch_outcome_recorder(monkeypatch)
    persisted, _ = _auto_reply_env(monkeypatch, recorded)

    await auto_reply("outlet-1")

    assert len(executed) == support_llm.SUPPORT_LLM_MAX_TOOL_ITERATIONS
    assert len(persisted) == 0
    message_id, outcome = recorded[0]
    assert outcome["status"] == "failed"


async def test_auto_reply_malformed_arguments_recovers(monkeypatch):
    _mock_llm_sequence(
        monkeypatch,
        [
            _tool_call_message("get_stock", "not-json-{{{"),
            json.dumps({"reply": "Let me try that differently."}),
        ],
    )
    results = []

    async def fake_execute_tool(name, raw_args, outlet_id, account=None):
        results.append(raw_args)
        return {"ok": True, "count": 0, "items": []}

    monkeypatch.setattr(support_llm, "execute_tool", fake_execute_tool)
    recorded = _patch_outcome_recorder(monkeypatch)
    persisted, _ = _auto_reply_env(monkeypatch, recorded)

    await auto_reply("outlet-1")

    assert results == []  # tool never executed — malformed args surfaced as error result
    assert len(persisted) == 1
    message_id, outcome = recorded[0]
    assert outcome["status"] == "replied"
    assert outcome["detail"] == {"tools": ["get_stock"], "toolCalls": 1}


def _two_tool_calls_message(first: str, second: str) -> dict:
    return {
        "role": "assistant",
        "content": None,
        "tool_calls": [
            {
                "id": "call_first",
                "type": "function",
                "function": {"name": first, "arguments": "{}"},
            },
            {
                "id": "call_second",
                "type": "function",
                "function": {"name": second, "arguments": "{}"},
            },
        ],
    }


async def test_auto_reply_parallel_tools_all_executed(monkeypatch):
    _mock_llm_sequence(
        monkeypatch,
        [
            _two_tool_calls_message("get_stock", "get_menu_items"),
            json.dumps({"reply": "2 kg left."}),
        ],
    )
    executed = []

    async def fake_execute_tool(name, raw_args, outlet_id, account=None):
        executed.append(name)
        return {"ok": True, "count": 0, "items": []}

    monkeypatch.setattr(support_llm, "execute_tool", fake_execute_tool)
    recorded = _patch_outcome_recorder(monkeypatch)
    persisted, _ = _auto_reply_env(monkeypatch, recorded)

    await auto_reply("outlet-1")

    assert executed == ["get_stock", "get_menu_items"]  # every call in the round runs
    assert len(persisted) == 1
    assert persisted[0][3] == "2 kg left."
    message_id, outcome = recorded[0]
    assert outcome["status"] == "replied"
    assert outcome["detail"] == {"tools": ["get_stock", "get_menu_items"], "toolCalls": 2}


async def test_auto_reply_prose_final_persisted(monkeypatch):
    _mock_llm_sequence(
        monkeypatch,
        [
            _tool_call_message("get_stock"),
            "You have 2 kg of flour left.",
        ],
    )
    recorded = _patch_outcome_recorder(monkeypatch)
    persisted, _ = _auto_reply_env(monkeypatch, recorded)

    await auto_reply("outlet-1")

    assert len(persisted) == 1
    assert persisted[0][3] == "You have 2 kg of flour left."
    message_id, outcome = recorded[0]
    assert outcome["status"] == "replied"
    assert outcome["detail"] == {"tools": ["get_stock"], "toolCalls": 1}


# ---------------------------------------------------------------------------
# Stock-management proposals (tool -> sanitized action -> client review)
# ---------------------------------------------------------------------------


def test_sanitize_guide_keeps_proposal_action():
    sanitized = sanitize_guide(
        {
            "reply": "Review this stock-in.",
            "actions": [
                {
                    "label": "Review stock-in",
                    "target": "screen:stock_in",
                    "proposal": {
                        "category": "stock_in",
                        "items": [
                            {
                                "nameEn": "Rice",
                                "qty": 5,
                                "unit": "kg",
                                "unitPriceBdt": 10,
                                "totalBdt": 50,
                                "matchedInventoryItemId": "s1",
                                "hack": "drop",
                            }
                        ],
                    },
                }
            ],
        }
    )
    action = sanitized["actions"][0]
    assert action["label"] == "Review stock-in"
    assert action["target"] == "screen:stock_in"
    assert action["proposal"]["category"] == "stock_in"
    (line,) = action["proposal"]["items"]
    assert line == {
        "nameEn": "Rice",
        "qty": 5.0,
        "unit": "kg",
        "unitPriceBdt": 10.0,
        "totalBdt": 50.0,
        "matchedInventoryItemId": "s1",
    }


def test_sanitize_guide_drops_invalid_proposals():
    # Wrong category, empty items, wrong target -> the action survives as a
    # plain button (proposal dropped) or is dropped entirely.
    sanitized = sanitize_guide(
        {
            "reply": "hi",
            "actions": [
                {
                    "label": "Bad category",
                    "target": "screen:stock_in",
                    "proposal": {"category": "shopping", "items": [{"qty": 1}]},
                },
                {
                    "label": "Empty items",
                    "target": "screen:stock_in",
                    "proposal": {"category": "count", "items": []},
                },
                {
                    "label": "Bad target",
                    "target": "tab:nope",
                    "proposal": {"category": "stock_in", "items": [{"qty": 1}]},
                },
                {
                    "label": "Count date",
                    "target": "screen:stock_count",
                    "proposal": {
                        "category": "count",
                        "countDate": "2026-01-05",
                        "items": [
                            {
                                "nameEn": "Rice",
                                "qty": 7,
                                "matchedInventoryItemId": "s1",
                            }
                        ],
                    },
                },
            ],
        }
    )
    assert len(sanitized["actions"]) == 3
    assert "proposal" not in sanitized["actions"][0]
    assert "proposal" not in sanitized["actions"][1]
    assert sanitized["actions"][2]["proposal"]["countDate"] == "2026-01-05"


async def test_auto_reply_stock_in_proposal_surfaces_action(monkeypatch):
    """The voice/typed support chat executes stock_in and carries the
    resulting proposal to the client for confirmation (stock-scan style)."""
    _mock_llm_sequence(
        monkeypatch,
        [
            _tool_call_message(
                "stock_in", '{"name": "Rice", "qty": 5, "totalCostBdt": 50}'
            ),
            json.dumps(
                {
                    "reply": "আমি স্টকে ৫ কেজি চাল যোগ করার প্রস্তাব দিচ্ছি — অ্যাপে কনফার্ম করুন।",
                    "actions": [
                        {
                            "label": "Review stock-in",
                            "target": "screen:stock_in",
                            "proposal": {
                                "category": "stock_in",
                                "items": [
                                    {
                                        "nameEn": "Rice",
                                        "qty": 5,
                                        "unit": "kg",
                                        "unitPriceBdt": 10,
                                        "totalBdt": 50,
                                        "matchedInventoryItemId": "s1",
                                    }
                                ],
                            },
                        }
                    ],
                }
            ),
        ],
    )
    executed = []

    async def fake_execute_tool(name, raw_args, outlet_id, account=None):
        executed.append((name, raw_args, account))
        return {
            "ok": True,
            "category": "stock_in",
            "items": [
                {
                    "nameEn": "Rice",
                    "qty": 5,
                    "unit": "kg",
                    "unitPriceBdt": 10,
                    "totalBdt": 50,
                    "matchedInventoryItemId": "s1",
                }
            ],
            "warnings": [],
        }

    monkeypatch.setattr(support_llm, "execute_tool", fake_execute_tool)
    recorded = _patch_outcome_recorder(monkeypatch)
    persisted, _ = _auto_reply_env(monkeypatch, recorded)

    await auto_reply("outlet-1")

    assert executed == [("stock_in", {"name": "Rice", "qty": 5, "totalCostBdt": 50}, None)]
    assert len(persisted) == 1
    actions = persisted[0][4]
    assert actions[0]["proposal"]["category"] == "stock_in"
    assert actions[0]["proposal"]["items"][0]["nameEn"] == "Rice"
    message_id, outcome = recorded[0]
    assert outcome["status"] == "replied"
    assert outcome["detail"] == {"tools": ["stock_in"], "toolCalls": 1}


async def test_auto_reply_threads_account_to_management_tools(monkeypatch):
    """The resolved AdminAccount from the device token reaches execute_tool,
    so the management-only gate applies to the voice path too."""
    state = _mock_llm_sequence(
        monkeypatch,
        [
            _tool_call_message("stock_in", '{"name": "Rice", "qty": 2}'),
            json.dumps({"reply": "প্রস্তাব পাঠালাম।"}),
        ],
    )
    executed = []

    async def fake_execute_tool(name, raw_args, outlet_id, account=None):
        executed.append((name, getattr(account, "role", account)))
        return {"ok": True, "category": "stock_in", "items": [], "warnings": []}

    monkeypatch.setattr(support_llm, "execute_tool", fake_execute_tool)
    recorded = _patch_outcome_recorder(monkeypatch)
    persisted, _ = _auto_reply_env(monkeypatch, recorded)

    await auto_reply("outlet-1", account=type("Account", (), {"role": "manager"})())

    assert executed == [("stock_in", "manager")]

    executed.clear()
    support_llm._last_reply_at = {}  # reset cooldown for the second run
    state["n"] = 0  # replay the tool-call round for the second run
    await auto_reply("outlet-1", account=type("Account", (), {"role": "waiter"})())
    assert executed == [("stock_in", "waiter")]
