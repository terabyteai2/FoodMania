import hashlib
import hmac
import json
import uuid
from urllib.parse import parse_qs, urlparse

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from database import AsyncSessionLocal, create_tables
from main import app
from models import AdminAccount
from services import facebook_chatbot


def _signed_json(payload: dict, secret: str) -> tuple[bytes, dict]:
    raw = json.dumps(payload).encode("utf-8")
    digest = hmac.new(secret.encode("utf-8"), raw, hashlib.sha256).hexdigest()
    return raw, {
        "Content-Type": "application/json",
        "X-Hub-Signature-256": f"sha256={digest}",
    }


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


async def _set_account_role(outlet_id: str, role: str) -> None:
    async with AsyncSessionLocal() as db:
        account = (
            await db.execute(select(AdminAccount).where(AdminAccount.outlet_id == outlet_id))
        ).scalar_one()
        account.role = role
        await db.commit()


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
async def test_owner_can_read_facebook_chatbot_config():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id, headers = await _manager_headers(client, "bot-owner")
        await _set_account_role(outlet_id, "owner")
        response = await client.get("/admin/chatbot/facebook", headers=headers)
    assert response.status_code == 200


@pytest.mark.asyncio(loop_scope="session")
async def test_waiter_cannot_read_facebook_chatbot_config():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id, headers = await _manager_headers(client, "bot-waiter")
        await _set_account_role(outlet_id, "waiter")
        response = await client.get("/admin/chatbot/facebook", headers=headers)
    assert response.status_code == 403
    assert response.json()["detail"] == "Manager or owner access required."


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
async def test_facebook_webhook_creates_order_after_explicit_confirmation(monkeypatch):
    page_id = f"page-order-{uuid.uuid4()}"
    menu_id = f"menu-fb-{uuid.uuid4()}"

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

        draft_payload = {
            "object": "page",
            "entry": [
                {
                    "id": page_id,
                    "messaging": [
                        {"sender": {"id": "psid-1"}, "message": {"text": "2 burger"}}
                    ],
                }
            ],
        }
        draft_content, draft_headers = _signed_json(
            draft_payload, facebook_chatbot.settings.FACEBOOK_APP_SECRET
        )
        draft = await client.post(
            "/webhooks/facebook",
            content=draft_content,
            headers=draft_headers,
        )
        confirm_payload = {
            "object": "page",
            "entry": [
                {
                    "id": page_id,
                    "messaging": [
                        {"sender": {"id": "psid-1"}, "message": {"text": "yes"}}
                    ],
                }
            ],
        }
        confirm_content, confirm_headers = _signed_json(
            confirm_payload, facebook_chatbot.settings.FACEBOOK_APP_SECRET
        )
        confirm = await client.post(
            "/webhooks/facebook",
            content=confirm_content,
            headers=confirm_headers,
        )
        orders = await client.get(f"/outlets/{outlet_id}/orders", headers=headers)

    assert draft.status_code == 200
    assert confirm.status_code == 200
    assert "Reply yes" in sent_messages[0][1]
    body = orders.json()["data"]
    messenger_order = next(order for order in body if order["source"] == "facebook_messenger")
    assert messenger_order["customerName"] == "Nadia"
    assert messenger_order["totalAmount"] == 252.0


@pytest.mark.asyncio(loop_scope="session")
async def test_facebook_webhook_rejects_unsigned_payload_when_secret_is_configured(monkeypatch):
    monkeypatch.setattr(facebook_chatbot.settings, "FACEBOOK_APP_SECRET", "app-secret")
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/webhooks/facebook", json={"object": "page"})
    assert response.status_code == 403
