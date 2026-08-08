import asyncio
import json

import httpx
import pytest

import routers.ws as ws
from services import support_llm
from services.support_llm import (
    APP_GUIDE,
    _call_llm,
    _clean_step,
    _llm_config,
    _valid_spot,
    _valid_target,
    auto_reply,
    build_system_prompt,
    sanitize_guide,
)


def _mock_llm(monkeypatch, content: str):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={"choices": [{"message": {"content": content}}]},
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


def test_prompt_builds_sections_and_outlet_context():
    prompt = build_system_prompt(
        {"name": "Test Cafe", "plan": "pro", "table_count": 12}
    )
    assert "Volt Assistant" in prompt
    assert "Test Cafe" in prompt
    assert "pro" in prompt
    assert "tab:" in prompt and "screen:" in prompt and "modal:" in prompt
    assert "steps" in prompt


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


def test_vocabulary_validation():
    assert _valid_target("tab:stock")
    assert _valid_target("screen:staff")
    assert _valid_target("modal:menu_discounts")
    assert _valid_target("highlight:menu.scanCta")
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
    parsed = await _call_llm(
        build_system_prompt({"name": "T", "plan": "trial", "table_count": 4}),
        [{"role": "user", "content": "how do I add stock?"}],
    )
    assert parsed == {"reply": "ok", "steps": []}


async def test_call_llm_handles_fenced_json(monkeypatch):
    _mock_llm(monkeypatch, "```json\n{\"reply\": \"hi\"}\n```")
    parsed = await _call_llm("sys", [{"role": "user", "content": "hi"}])
    assert parsed == {"reply": "hi"}


async def test_call_llm_raises_on_bad_json(monkeypatch):
    _mock_llm(monkeypatch, "not json at all")
    with pytest.raises(Exception):
        await _call_llm("sys", [{"role": "user", "content": "hi"}])


async def test_call_llm_raises_without_config(monkeypatch):
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_API_KEY", "")
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_API_KEY", "")
    monkeypatch.setattr(support_llm.settings, "SUPPORT_CHAT_LLM_MODEL", "")
    monkeypatch.setattr(support_llm.settings, "DEEPSEEK_API_KEY", "")
    monkeypatch.setattr(support_llm.settings, "CHATBOT_DEEPSEEK_MODEL", "deepseek-chat")
    with pytest.raises(RuntimeError):
        await _call_llm("sys", [{"role": "user", "content": "hi"}])


async def test_auto_reply_cooldown_prevents_second_reply(monkeypatch):
    _mock_llm(monkeypatch, json.dumps({"reply": "Done!"}))
    support_llm._last_reply_at = {}
    support_llm._in_flight = {}
    support_llm._last_reply_at["outlet-1"] = (
        asyncio.get_running_loop().time() - 0.001
    )

    persisted = []
    broadcasted = []

    async def fake_load_history(outlet_id, limit=20):
        class Row:
            role = "client"
            text = "how do I do this"

        return [Row()]

    async def fake_load_outlet(outlet_id):
        return {"name": "T", "plan": "trial", "table_count": 4}

    class FakeMessage:
        id = "m1"
        outlet_id = "outlet-1"
        role = "server"
        sender_name = "Volt Assistant"
        text = "Done!"
        actions_json = None
        steps_json = None
        created_at = None

    async def fake_persist(outlet_id, role, sender_name, text, actions=None, steps=None):
        persisted.append((outlet_id, role, sender_name, text, actions, steps))
        return FakeMessage()

    class FakeManager:
        async def broadcast(self, outlet_id, payload):
            broadcasted.append(payload)

    monkeypatch.setattr(support_llm, "_load_history", fake_load_history)
    monkeypatch.setattr(support_llm, "_load_outlet", fake_load_outlet)
    monkeypatch.setattr(ws, "_persist_support_message", fake_persist)
    monkeypatch.setattr(ws, "manager", FakeManager())

    await auto_reply("outlet-1")
    assert persisted == []
    assert broadcasted == []
    assert not support_llm._in_flight.get("outlet-1")


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

    persisted = []
    broadcasted = []

    async def fake_load_history(outlet_id, limit=20):
        class Row:
            role = "client"
            text = "how do I add stock?"

        return [Row()]

    async def fake_load_outlet(outlet_id):
        return {"name": "T", "plan": "trial", "table_count": 4}

    class FakeMessage:
        id = "m1"
        outlet_id = "outlet-1"
        role = "server"
        sender_name = "Volt Assistant"
        text = "Let me show you."
        actions_json = None
        steps_json = None
        created_at = None

    async def fake_persist(outlet_id, role, sender_name, text, actions=None, steps=None):
        persisted.append((outlet_id, role, sender_name, text, actions, steps))
        return FakeMessage()

    class FakeManager:
        async def broadcast(self, outlet_id, payload):
            broadcasted.append((outlet_id, payload))

    monkeypatch.setattr(support_llm, "_load_history", fake_load_history)
    monkeypatch.setattr(support_llm, "_load_outlet", fake_load_outlet)
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


async def test_auto_reply_skips_when_last_message_is_server(monkeypatch):
    async def fake_load_history(outlet_id, limit=20):
        class Row:
            role = "server"
            text = "hi"

        return [Row()]

    monkeypatch.setattr(support_llm, "_load_history", fake_load_history)

    called = False

    async def fake_call_llm(system_prompt, history):
        nonlocal called
        called = True
        return {"reply": "x"}

    monkeypatch.setattr(support_llm, "_call_llm", fake_call_llm)
    support_llm._in_flight = {}
    support_llm._last_reply_at = {}

    await auto_reply("outlet-1")
    assert not called


async def test_auto_reply_survives_llm_failure(monkeypatch):
    async def fake_load_history(outlet_id, limit=20):
        class Row:
            role = "client"
            text = "hi"

        return [Row()]

    async def fake_load_outlet(outlet_id):
        return {"name": "T", "plan": "trial", "table_count": 4}

    async def fake_call_llm(system_prompt, history):
        raise RuntimeError("boom")

    monkeypatch.setattr(support_llm, "_load_history", fake_load_history)
    monkeypatch.setattr(support_llm, "_load_outlet", fake_load_outlet)
    monkeypatch.setattr(support_llm, "_call_llm", fake_call_llm)
    support_llm._in_flight = {}
    support_llm._last_reply_at = {}

    await auto_reply("outlet-1")  # must not raise
    assert not support_llm._in_flight.get("outlet-1")


def test_app_guide_describes_maneuver_vocabulary():
    assert "tab:" in APP_GUIDE
    assert "screen:" in APP_GUIDE
    assert "highlight:" in APP_GUIDE
    assert "orders" in APP_GUIDE and "stock" in APP_GUIDE


async def test_load_outlet_reads_subscription_against_real_db(monkeypatch):
    """Regression: lazy ``Outlet.subscription`` access raised MissingGreenlet
    inside async auto_reply; the relationship must be eager-loaded."""
    import sqlalchemy as sa
    from sqlalchemy.dialects.postgresql import JSONB
    from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
    from sqlalchemy.pool import StaticPool

    from models import Base, Outlet, OutletSubscription

    for table in (Outlet.__table__, OutletSubscription.__table__):
        for column in table.columns:
            if isinstance(column.type, JSONB):
                column.type = sa.JSON()

    engine = create_async_engine(
        "sqlite+aiosqlite://",
        poolclass=StaticPool,
        connect_args={"check_same_thread": False},
    )
    async with engine.begin() as conn:
        await conn.run_sync(
            Base.metadata.create_all,
            tables=[Outlet.__table__, OutletSubscription.__table__],
        )
    TestSession = async_sessionmaker(engine, expire_on_commit=False)

    async with TestSession() as session:
        session.add(
            Outlet(
                id="outlet-db-1",
                restaurant_id="rest-db-1",
                name="Greenlet Cafe",
                server_id="SRV-DB-1",
                table_count=7,
            )
        )
        session.add(
            Outlet(
                id="outlet-db-2",
                restaurant_id="rest-db-1",
                name="Lone Cafe",
                server_id="SRV-DB-2",
                table_count=3,
            )
        )
        session.add(OutletSubscription(outlet_id="outlet-db-1", plan="pro"))
        await session.commit()

    monkeypatch.setattr("database.AsyncSessionLocal", TestSession)
    try:
        with_sub = await support_llm._load_outlet("outlet-db-1")
        without_sub = await support_llm._load_outlet("outlet-db-2")
        missing = await support_llm._load_outlet("outlet-db-999")
    finally:
        await engine.dispose()

    assert with_sub == {"name": "Greenlet Cafe", "plan": "pro", "table_count": 7}
    assert without_sub == {"name": "Lone Cafe", "plan": "trial", "table_count": 3}
    assert missing == {"name": "", "plan": "trial", "table_count": None}
