import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from database import create_tables
from main import app
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
