import uuid
from urllib.parse import parse_qs, urlparse

import pytest
from fastapi import HTTPException
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from database import AsyncSessionLocal, create_tables
from main import app
from models import ChatbotConversation, ChatbotIntegration
from services import facebook_chatbot


async def _manager_headers(client: AsyncClient, label: str) -> tuple[str, dict]:
    server_id = f"{label}-{uuid.uuid4()}"
    bootstrap = await client.post(
        "/tenants/bootstrap",
        json={"serverId": server_id, "restaurantName": label, "tableCount": 4},
    )
    assert bootstrap.status_code == 200
    outlet_id = bootstrap.json()["data"]["outletId"]
    email = f"{label}-{uuid.uuid4()}@example.com"
    created = await client.post(
        "/admin/create",
        json={
            "outletId": outlet_id,
            "email": email,
            "username": email,
            "password": "secret123",
            "role": "manager",
        },
    )
    assert created.status_code == 200
    login = await client.post(
        "/admin/login",
        json={
            "usernameOrEmail": email,
            "password": "secret123",
            "serverId": server_id,
        },
    )
    assert login.status_code == 200
    token = login.json()["data"]["deviceToken"]
    return outlet_id, {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio(loop_scope="session")
async def test_facebook_webhook_verify_token(monkeypatch):
    monkeypatch.setattr(facebook_chatbot.settings, "FACEBOOK_WEBHOOK_VERIFY_TOKEN", "verify-me")
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get(
            "/webhooks/facebook",
            params={
                "hub.mode": "subscribe",
                "hub.verify_token": "verify-me",
                "hub.challenge": "abc123",
            },
        )
    assert response.status_code == 200
    assert response.text == "abc123"


@pytest.mark.asyncio(loop_scope="session")
async def test_manager_can_save_facebook_chatbot_config(monkeypatch):
    page_id = f"page-{uuid.uuid4()}"

    async def fake_resolve(token: str):
        assert token == "page-token"
        return {"pageId": page_id, "pageName": "Test Page"}

    monkeypatch.setattr(facebook_chatbot, "resolve_facebook_page", fake_resolve)
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        _, headers = await _manager_headers(client, "bot-config")
        saved = await client.put(
            "/admin/chatbot/facebook",
            headers=headers,
            json={
                "pageAccessToken": "page-token",
                "isEnabled": True,
                "orderingEnabled": True,
            },
        )
        fetched = await client.get("/admin/chatbot/facebook", headers=headers)

    assert saved.status_code == 200
    assert saved.json()["data"]["pageId"] == page_id
    assert saved.json()["data"]["tokenPreview"] == "page…oken"
    assert "page-token" not in saved.text
    assert fetched.json()["data"]["pageName"] == "Test Page"


@pytest.mark.asyncio(loop_scope="session")
async def test_manager_can_start_facebook_chatbot_oauth(monkeypatch):
    monkeypatch.setattr(facebook_chatbot.settings, "FACEBOOK_APP_ID", "app-123")
    monkeypatch.setattr(facebook_chatbot.settings, "FACEBOOK_APP_SECRET", "secret-123")
    monkeypatch.setattr(facebook_chatbot.settings, "BASE_URL", "https://api.example.test")

    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        _, headers = await _manager_headers(client, "bot-oauth-start")
        response = await client.post("/admin/chatbot/facebook/oauth/start", headers=headers)

    assert response.status_code == 200
    data = response.json()["data"]
    parsed = urlparse(data["authorizationUrl"])
    params = parse_qs(parsed.query)
    assert parsed.scheme == "https"
    assert parsed.netloc == "www.facebook.com"
    assert parsed.path == "/v24.0/dialog/oauth"
    assert params["client_id"] == ["app-123"]
    assert params["redirect_uri"] == [
        "https://api.example.test/admin/chatbot/facebook/oauth/callback"
    ]
    assert set(params["scope"][0].split(",")) >= {
        "pages_show_list",
        "pages_manage_metadata",
        "pages_messaging",
    }
    assert params["state"][0]


@pytest.mark.asyncio(loop_scope="session")
async def test_facebook_oauth_start_exposes_android_native_login_config(monkeypatch):
    monkeypatch.setattr(facebook_chatbot.settings, "FACEBOOK_APP_ID", "app-123")
    monkeypatch.setattr(facebook_chatbot.settings, "FACEBOOK_APP_SECRET", "secret-123")
    monkeypatch.setattr(facebook_chatbot.settings, "FACEBOOK_ANDROID_CLIENT_TOKEN", "client-123")
    monkeypatch.setattr(facebook_chatbot.settings, "BASE_URL", "https://api.example.test")

    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        _, headers = await _manager_headers(client, "bot-native-start")
        response = await client.post("/admin/chatbot/facebook/oauth/start", headers=headers)

    assert response.status_code == 200
    native = response.json()["data"]["nativeAndroid"]
    assert native["appId"] == "app-123"
    assert native["clientToken"] == "client-123"
    assert set(native["scopes"]) >= {
        "pages_show_list",
        "pages_manage_metadata",
        "pages_messaging",
    }


@pytest.mark.asyncio(loop_scope="session")
async def test_facebook_native_oauth_creates_page_selection_session(monkeypatch):
    page_id = f"native-page-{uuid.uuid4()}"

    async def fake_long_lived(token: str):
        assert token == "native-short-token"
        return "native-long-token"

    async def fake_pages(token: str):
        assert token == "native-long-token"
        return [{"id": page_id, "name": "Native Cafe", "access_token": "native-page-token"}]

    monkeypatch.setattr(facebook_chatbot, "_exchange_long_lived_user_token", fake_long_lived)
    monkeypatch.setattr(facebook_chatbot, "_fetch_facebook_pages", fake_pages)

    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        _, headers = await _manager_headers(client, "bot-native-complete")
        completed = await client.post(
            "/admin/chatbot/facebook/oauth/native",
            headers=headers,
            json={"userAccessToken": "native-short-token"},
        )
        session_id = completed.json()["data"]["sessionId"]
        pages = await client.get(
            "/admin/chatbot/facebook/oauth/pages",
            headers=headers,
            params={"sessionId": session_id},
        )

    assert completed.status_code == 200
    assert "native-short-token" not in completed.text
    assert "native-long-token" not in completed.text
    assert "native-page-token" not in pages.text
    assert pages.json()["data"]["pages"] == [{"pageId": page_id, "pageName": "Native Cafe"}]


@pytest.mark.asyncio(loop_scope="session")
async def test_facebook_native_oauth_rejects_invalid_token(monkeypatch):
    async def fake_long_lived(_token: str):
        raise HTTPException(status_code=400, detail="Invalid Facebook token.")

    monkeypatch.setattr(facebook_chatbot, "_exchange_long_lived_user_token", fake_long_lived)

    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        _, headers = await _manager_headers(client, "bot-native-invalid")
        response = await client.post(
            "/admin/chatbot/facebook/oauth/native",
            headers=headers,
            json={"userAccessToken": "bad-native-token"},
        )

    assert response.status_code == 400
    assert "bad-native-token" not in response.text


@pytest.mark.asyncio(loop_scope="session")
async def test_facebook_native_oauth_rejects_account_without_pages(monkeypatch):
    async def fake_long_lived(_token: str):
        return "native-long-token"

    async def fake_pages(_token: str):
        return []

    monkeypatch.setattr(facebook_chatbot, "_exchange_long_lived_user_token", fake_long_lived)
    monkeypatch.setattr(facebook_chatbot, "_fetch_facebook_pages", fake_pages)

    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        _, headers = await _manager_headers(client, "bot-native-no-pages")
        response = await client.post(
            "/admin/chatbot/facebook/oauth/native",
            headers=headers,
            json={"userAccessToken": "native-short-token"},
        )

    assert response.status_code == 400
    assert "authorized Page access token" in response.text


@pytest.mark.asyncio(loop_scope="session")
async def test_facebook_oauth_callback_saves_page_token(monkeypatch):
    page_id = f"oauth-page-{uuid.uuid4()}"
    subscribed = []

    monkeypatch.setattr(facebook_chatbot.settings, "FACEBOOK_APP_ID", "app-123")
    monkeypatch.setattr(facebook_chatbot.settings, "FACEBOOK_APP_SECRET", "secret-123")
    monkeypatch.setattr(facebook_chatbot.settings, "BASE_URL", "https://api.example.test")

    async def fake_exchange_code(code: str):
        assert code == "auth-code"
        return "short-user-token"

    async def fake_long_lived(token: str):
        assert token == "short-user-token"
        return "long-user-token"

    async def fake_pages(token: str):
        assert token == "long-user-token"
        return [
            {
                "id": page_id,
                "name": "OAuth Cafe",
                "access_token": "oauth-page-token",
            }
        ]

    async def fake_subscribe(page: str, token: str):
        subscribed.append((page, token))

    monkeypatch.setattr(facebook_chatbot, "_exchange_code_for_user_token", fake_exchange_code)
    monkeypatch.setattr(facebook_chatbot, "_exchange_long_lived_user_token", fake_long_lived)
    monkeypatch.setattr(facebook_chatbot, "_fetch_facebook_pages", fake_pages)
    monkeypatch.setattr(facebook_chatbot, "_subscribe_facebook_page", fake_subscribe)

    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        _, headers = await _manager_headers(client, "bot-oauth-callback")
        started = await client.post("/admin/chatbot/facebook/oauth/start", headers=headers)
        state = parse_qs(urlparse(started.json()["data"]["authorizationUrl"]).query)["state"][0]
        callback = await client.get(
            "/admin/chatbot/facebook/oauth/callback",
            params={"code": "auth-code", "state": state},
        )
        session_id = parse_qs(urlparse(callback.headers["location"]).query)["sessionId"][0]
        pages = await client.get(
            "/admin/chatbot/facebook/oauth/pages",
            headers=headers,
            params={"sessionId": session_id},
        )
        completed = await client.post(
            "/admin/chatbot/facebook/oauth/complete",
            headers=headers,
            json={"sessionId": session_id, "pageId": page_id},
        )
        fetched = await client.get("/admin/chatbot/facebook", headers=headers)

    assert callback.status_code == 303
    assert "status=success" in callback.headers["location"]
    assert pages.json()["data"]["pages"] == [{"pageId": page_id, "pageName": "OAuth Cafe"}]
    assert "oauth-page-token" not in pages.text
    assert completed.status_code == 200
    assert subscribed == [(page_id, "oauth-page-token")]
    config = fetched.json()["data"]
    assert config["isConfigured"] is True
    assert config["isEnabled"] is True
    assert config["orderingEnabled"] is True
    assert config["pageId"] == page_id
    assert config["pageName"] == "OAuth Cafe"
    assert config["tokenPreview"] == "oaut…oken"
    assert "oauth-page-token" not in fetched.text


@pytest.mark.asyncio(loop_scope="session")
async def test_chat_history_api_returns_recent_ten_without_truncating_db(monkeypatch):
    page_id = f"history-page-{uuid.uuid4()}"
    broadcasts = []

    async def fake_resolve(_token: str):
        return {"pageId": page_id, "pageName": "History Page"}

    async def fake_send(_integration, _psid: str, _text: str):
        return None

    async def fake_broadcast(outlet_id: str, payload: dict):
        broadcasts.append((outlet_id, payload))

    monkeypatch.setattr(facebook_chatbot, "resolve_facebook_page", fake_resolve)
    monkeypatch.setattr(facebook_chatbot, "_send_message", fake_send)
    monkeypatch.setattr(facebook_chatbot.manager, "broadcast", fake_broadcast)

    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        _, headers = await _manager_headers(client, "bot-history")
        saved = await client.put(
            "/admin/chatbot/facebook",
            headers=headers,
            json={"pageAccessToken": "page-token", "isEnabled": True, "orderingEnabled": True},
        )
        assert saved.status_code == 200

        async with AsyncSessionLocal() as db:
            integration = (
                await db.execute(
                    select(ChatbotIntegration).where(ChatbotIntegration.page_id == page_id)
                )
            ).scalar_one()
            conv = ChatbotConversation(
                integration_id=integration.id,
                page_id=page_id,
                psid="psid-history",
                state_json={"status": "needs", "reason": "Photo requested", "unread": 2},
                history_json=[
                    {"role": "user", "text": f"m{i}"}
                    for i in range(12)
                ],
                last_user_message="m11",
            )
            db.add(conv)
            await db.commit()
            conv_id = conv.id

        reply = await client.post(
            f"/admin/chatbot/chats/{conv_id}/reply",
            headers=headers,
            json={"text": "manager answer"},
        )
        handback = await client.post(
            f"/admin/chatbot/chats/{conv_id}/handback",
            headers=headers,
        )
        listed = await client.get("/admin/chatbot/chats", headers=headers)

    assert reply.status_code == 200
    assert handback.status_code == 200
    assert listed.status_code == 200
    assert [payload["type"] for _, payload in broadcasts] == [
        "chat_updated",
        "chat_updated",
    ]
    assert [payload["data"]["conversationId"] for _, payload in broadcasts] == [
        conv_id,
        conv_id,
    ]
    chat = next(row for row in listed.json()["data"]["chats"] if row["id"] == conv_id)
    assert [m["text"] for m in chat["messages"]] == [
        "m4",
        "m5",
        "m6",
        "m7",
        "m8",
        "m9",
        "m10",
        "m11",
        "manager answer",
        "Handed back to bot",
    ]

    async with AsyncSessionLocal() as db:
        stored = (
            await db.execute(
                select(ChatbotConversation).where(ChatbotConversation.id == conv_id)
            )
        ).scalar_one()
        assert len(stored.history_json) == 14
        assert stored.history_json[0]["text"] == "m0"
        assert stored.history_json[-1]["text"] == "Handed back to bot"


@pytest.mark.asyncio(loop_scope="session")
async def test_facebook_webhook_broadcasts_chat_update_for_customer_message(monkeypatch):
    page_id = f"webhook-chat-page-{uuid.uuid4()}"
    broadcasts = []

    async def fake_resolve(_token: str):
        return {"pageId": page_id, "pageName": "Webhook Chat Page"}

    async def fake_broadcast(outlet_id: str, payload: dict):
        broadcasts.append((outlet_id, payload))

    monkeypatch.setattr(facebook_chatbot.settings, "FACEBOOK_APP_SECRET", "")
    monkeypatch.setattr(facebook_chatbot, "resolve_facebook_page", fake_resolve)
    monkeypatch.setattr(facebook_chatbot.manager, "broadcast", fake_broadcast)

    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        _, headers = await _manager_headers(client, "bot-webhook-chat-event")
        saved = await client.put(
            "/admin/chatbot/facebook",
            headers=headers,
            json={"pageAccessToken": "page-token", "isEnabled": True, "orderingEnabled": True},
        )
        assert saved.status_code == 200
        webhook = await client.post(
            "/webhooks/facebook",
            json={
                "object": "page",
                "entry": [
                    {
                        "id": page_id,
                        "messaging": [
                            {"sender": {"id": "psid-live"}, "message": {"text": "hello"}}
                        ],
                    }
                ],
            },
        )

    assert webhook.status_code == 200
    assert len(broadcasts) == 1
    assert broadcasts[0][1]["type"] == "chat_updated"
    assert broadcasts[0][1]["data"]["conversationId"]


@pytest.mark.asyncio(loop_scope="session")
async def test_batched_llm_receives_recent_ten_without_truncating_db(monkeypatch):
    page_id = f"llm-history-page-{uuid.uuid4()}"
    captured = {}
    broadcasts = []

    async def fake_resolve(_token: str):
        return {"pageId": page_id, "pageName": "LLM History Page"}

    async def fake_call(conversations, _system_prompt):
        captured["history"] = conversations[0]["history"]
        return {
            "responses": [
                {
                    "id": conversations[0]["id"],
                    "reply": "ঠিক আছে",
                    "escalate": {"needed": False},
                    "order": {},
                }
            ]
        }

    async def fake_send(_integration, _psid: str, _text: str):
        return None

    async def fake_broadcast(outlet_id: str, payload: dict):
        broadcasts.append((outlet_id, payload))

    monkeypatch.setattr(facebook_chatbot, "resolve_facebook_page", fake_resolve)
    monkeypatch.setattr(facebook_chatbot, "_call_batched_llm", fake_call)
    monkeypatch.setattr(facebook_chatbot, "_send_message", fake_send)
    monkeypatch.setattr(facebook_chatbot.manager, "broadcast", fake_broadcast)

    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        _, headers = await _manager_headers(client, "bot-llm-history")
        saved = await client.put(
            "/admin/chatbot/facebook",
            headers=headers,
            json={"pageAccessToken": "page-token", "isEnabled": True, "orderingEnabled": True},
        )
        assert saved.status_code == 200

    async with AsyncSessionLocal() as db:
        integration = (
            await db.execute(
                select(ChatbotIntegration).where(ChatbotIntegration.page_id == page_id)
            )
        ).scalar_one()
        conv = ChatbotConversation(
            integration_id=integration.id,
            page_id=page_id,
            psid="psid-llm-history",
            state_json={},
            history_json=[{"role": "user", "text": f"h{i}"} for i in range(12)],
            last_user_message="h11",
        )
        db.add(conv)
        await db.commit()
        conv_id = conv.id

    await facebook_chatbot._process_batch([{"conversation_id": conv_id, "text": "h11"}])

    assert [payload["type"] for _, payload in broadcasts] == ["chat_updated"]
    assert broadcasts[0][1]["data"]["conversationId"] == conv_id
    assert [entry["text"] for entry in captured["history"]] == [
        "h2",
        "h3",
        "h4",
        "h5",
        "h6",
        "h7",
        "h8",
        "h9",
        "h10",
        "h11",
    ]

    async with AsyncSessionLocal() as db:
        stored = (
            await db.execute(
                select(ChatbotConversation).where(ChatbotConversation.id == conv_id)
            )
        ).scalar_one()
        assert len(stored.history_json) == 13
        assert stored.history_json[0]["text"] == "h0"
        assert stored.history_json[-1]["text"] == "ঠিক আছে"


@pytest.mark.asyncio(loop_scope="session")
async def test_facebook_webhook_creates_order_after_explicit_confirmation(monkeypatch):
    page_id = f"page-order-{uuid.uuid4()}"
    menu_id = f"menu-fb-{uuid.uuid4()}"
    monkeypatch.setattr(facebook_chatbot.settings, "FACEBOOK_APP_SECRET", "")

    async def fake_resolve(_token: str):
        return {"pageId": page_id, "pageName": "Order Page"}

    calls = []
    sent_messages = []

    async def fake_groq(**kwargs):
        calls.append(kwargs["user_text"])
        if len(calls) == 1:
            return {
                    "reply": "I found that item.",
                    "order": {
                        "intent": "draft",
                        "items": [{"menuItemId": menu_id, "qty": 2}],
                    "customerName": "Nadia",
                    "mobileNumber": "01700000000",
                    "deliveryAddress": "Road 1",
                    "confirmed": False,
                },
            }
        return {
            "reply": "Placing it now.",
            "order": {"intent": "confirm", "confirmed": True},
        }

    async def fake_send(_integration, psid: str, text: str):
        sent_messages.append((psid, text))

    monkeypatch.setattr(facebook_chatbot, "resolve_facebook_page", fake_resolve)
    monkeypatch.setattr(facebook_chatbot, "_chat_with_groq", fake_groq)
    monkeypatch.setattr(facebook_chatbot, "_send_message", fake_send)

    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id, headers = await _manager_headers(client, "bot-order")
        config = await client.put(
            "/admin/chatbot/facebook",
            headers=headers,
            json={"pageAccessToken": "page-token", "isEnabled": True, "orderingEnabled": True},
        )
        assert config.status_code == 200
        created = await client.post(
            f"/outlets/{outlet_id}/menu",
            headers=headers,
            json={"id": menu_id, "name": "Burger", "price": 120, "category": "Food"},
        )
        assert created.status_code == 200

        draft = await client.post(
            "/webhooks/facebook",
            json={
                "object": "page",
                "entry": [
                    {
                        "id": page_id,
                        "messaging": [
                            {"sender": {"id": "psid-1"}, "message": {"text": "2 burger"}}
                        ],
                    }
                ],
            },
        )
        confirm = await client.post(
            "/webhooks/facebook",
            json={
                "object": "page",
                "entry": [
                    {
                        "id": page_id,
                        "messaging": [
                            {"sender": {"id": "psid-1"}, "message": {"text": "yes"}}
                        ],
                    }
                ],
            },
        )
        orders = await client.get(f"/outlets/{outlet_id}/orders", headers=headers)

    assert draft.status_code == 200
    assert confirm.status_code == 200
    assert "Reply yes" in sent_messages[0][1]
    body = orders.json()["data"]
    messenger_order = next(order for order in body if order["source"] == "facebook_messenger")
    assert messenger_order["customerName"] == "Nadia"
    assert messenger_order["totalAmount"] == 252.0
