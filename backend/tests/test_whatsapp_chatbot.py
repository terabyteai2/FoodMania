import uuid
from datetime import datetime, timezone

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from auth import create_device_token
from database import AsyncSessionLocal, create_tables
from main import app
from models import AdminAccount, ChatbotConversation, ChatbotIntegration, MenuItem, Order, Outlet
from phone_utils import phone_to_synthetic_email
from services import facebook_chatbot, whatsapp_chatbot


async def _manager_headers(client: AsyncClient, label: str) -> tuple[str, dict]:
    server_id = f"{label}-{uuid.uuid4()}"
    bootstrap = await client.post(
        "/tenants/bootstrap",
        json={"serverId": server_id, "restaurantName": label, "tableCount": 4},
    )
    assert bootstrap.status_code == 200
    outlet_id = bootstrap.json()["data"]["outletId"]
    async with AsyncSessionLocal() as db:
        outlet = (await db.execute(select(Outlet).where(Outlet.id == outlet_id))).scalar_one()
        phone = f"+88019{uuid.uuid4().hex[:8]}"
        account = AdminAccount(
            id=str(uuid.uuid4()),
            outlet_id=outlet.id,
            email=phone_to_synthetic_email(phone),
            username=phone_to_synthetic_email(phone),
            password_hash=None,
            role="owner",
            display_name="Test Manager",
            auth_provider="phone",
            phone=phone,
            phone_verified_at=datetime.now(timezone.utc),
            invite_status="accepted",
            is_active=True,
        )
        db.add(account)
        await db.commit()
        await db.refresh(account)
        token = create_device_token(outlet.id, account.id)
    return outlet_id, {"Authorization": f"Bearer {token}"}


def _whatsapp_payload(
    phone_number_id: str,
    messages: list[dict],
    *,
    display_phone_number: str = "+1 555 555 5555",
    include_statuses: bool = False,
) -> dict:
    value = {
        "messaging_product": "whatsapp",
        "metadata": {
            "display_phone_number": display_phone_number,
            "phone_number_id": phone_number_id,
        },
    }
    if messages:
        value["messages"] = messages
    if include_statuses:
        value["statuses"] = [
            {
                "id": "status-1",
                "status": "delivered",
                "timestamp": "1700000000",
                "recipient_id": "15555555555",
            }
        ]
    return {
        "object": "whatsapp_business_account",
        "entry": [
            {
                "id": "waba-123",
                "changes": [{"field": "messages", "value": value}],
            }
        ],
    }


@pytest.mark.asyncio(loop_scope="session")
async def test_whatsapp_webhook_verify_token_uses_whatsapp_token(monkeypatch):
    monkeypatch.setattr(
        whatsapp_chatbot.settings, "WHATSAPP_WEBHOOK_VERIFY_TOKEN", "wa-verify-me"
    )
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get(
            "/webhooks/whatsapp",
            params={
                "hub.mode": "subscribe",
                "hub.verify_token": "wa-verify-me",
                "hub.challenge": "challenge-xyz",
            },
        )
        bad = await client.get(
            "/webhooks/whatsapp",
            params={
                "hub.mode": "subscribe",
                "hub.verify_token": "wrong-token",
                "hub.challenge": "challenge-xyz",
            },
        )
    assert response.status_code == 200
    assert response.text == "challenge-xyz"
    assert bad.status_code == 403


@pytest.mark.asyncio(loop_scope="session")
async def test_whatsapp_webhook_verify_token_falls_back_to_facebook_token(monkeypatch):
    monkeypatch.setattr(whatsapp_chatbot.settings, "WHATSAPP_WEBHOOK_VERIFY_TOKEN", "")
    monkeypatch.setattr(whatsapp_chatbot.settings, "FACEBOOK_WEBHOOK_VERIFY_TOKEN", "fb-verify")
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get(
            "/webhooks/whatsapp",
            params={
                "hub.mode": "subscribe",
                "hub.verify_token": "fb-verify",
                "hub.challenge": "abc123",
            },
        )
    assert response.status_code == 200
    assert response.text == "abc123"


@pytest.mark.asyncio(loop_scope="session")
async def test_manager_can_save_whatsapp_chatbot_config(monkeypatch):
    phone_id = f"phone-{uuid.uuid4()}"
    resolves = []

    async def fake_resolve(phone_number_id: str, access_token: str):
        resolves.append((phone_number_id, access_token))
        return phone_number_id, "+880 1700-000000"

    monkeypatch.setattr(whatsapp_chatbot, "_resolve_phone_number", fake_resolve)
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        _, headers = await _manager_headers(client, "wa-config")
        saved = await client.put(
            "/admin/chatbot/whatsapp",
            headers=headers,
            json={
                "phoneNumberId": phone_id,
                "accessToken": "wa-system-token",
                "isEnabled": True,
                "orderingEnabled": True,
            },
        )
        fetched = await client.get("/admin/chatbot/whatsapp", headers=headers)
        toggled = await client.put(
            "/admin/chatbot/whatsapp",
            headers=headers,
            json={"isEnabled": False, "orderingEnabled": False},
        )

    assert saved.status_code == 200
    assert saved.json()["data"]["phoneNumberId"] == phone_id
    assert saved.json()["data"]["displayPhoneNumber"] == "+880 1700-000000"
    assert saved.json()["data"]["tokenPreview"] == "wa-s…oken"
    assert "wa-system-token" not in saved.text
    assert resolves == [(phone_id, "wa-system-token")]

    assert fetched.json()["data"]["isConfigured"] is True
    assert fetched.json()["data"]["displayPhoneNumber"] == "+880 1700-000000"

    # Toggle-only save must not re-validate and must keep the stored token.
    assert toggled.status_code == 200
    assert toggled.json()["data"]["isEnabled"] is False
    assert len(resolves) == 1
    async with AsyncSessionLocal() as db:
        integration = (
            await db.execute(
                select(ChatbotIntegration).where(ChatbotIntegration.page_id == phone_id)
            )
        ).scalar_one()
    assert integration.page_access_token == "wa-system-token"


@pytest.mark.asyncio(loop_scope="session")
async def test_manager_whatsapp_config_requires_credentials_when_unconfigured(monkeypatch):
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        _, headers = await _manager_headers(client, "wa-config-req")
        response = await client.put(
            "/admin/chatbot/whatsapp",
            headers=headers,
            json={"isEnabled": True, "orderingEnabled": True},
        )
    assert response.status_code == 422


@pytest.mark.asyncio(loop_scope="session")
async def test_whatsapp_webhook_creates_conversation_and_broadcasts(monkeypatch):
    phone_id = f"phone-webhook-{uuid.uuid4()}"
    broadcasts = []

    async def fake_resolve(phone_number_id: str, access_token: str):
        return phone_number_id, "+1 555 555 5555"

    async def fake_broadcast(outlet_id: str, payload: dict):
        broadcasts.append((outlet_id, payload))

    monkeypatch.setattr(whatsapp_chatbot.settings, "FACEBOOK_APP_SECRET", "")
    monkeypatch.setattr(whatsapp_chatbot, "_resolve_phone_number", fake_resolve)
    monkeypatch.setattr(facebook_chatbot.manager, "broadcast", fake_broadcast)

    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        _, headers = await _manager_headers(client, "wa-webhook")
        saved = await client.put(
            "/admin/chatbot/whatsapp",
            headers=headers,
            json={
                "phoneNumberId": phone_id,
                "accessToken": "wa-token",
                "isEnabled": True,
                "orderingEnabled": True,
            },
        )
        assert saved.status_code == 200

        webhook = await client.post(
            "/webhooks/whatsapp",
            json=_whatsapp_payload(
                phone_id,
                [
                    {
                        "from": "15559998877",
                        "id": "wamid-1",
                        "timestamp": "1700000000",
                        "type": "text",
                        "text": {"body": "hello"},
                    }
                ],
            ),
        )

    assert webhook.status_code == 200
    assert len(broadcasts) == 1
    assert broadcasts[0][1]["type"] == "chat_updated"

    async with AsyncSessionLocal() as db:
        conv = (
            await db.execute(
                select(ChatbotConversation).where(
                    ChatbotConversation.psid == "15559998877"
                )
            )
        ).scalar_one()
    assert conv.last_user_message == "hello"
    assert conv.page_id == phone_id
    user_entries = [e for e in conv.history_json if e.get("role") == "user"]
    assert user_entries[-1]["text"] == "hello"


@pytest.mark.asyncio(loop_scope="session")
async def test_whatsapp_webhook_ignores_statuses_and_self_messages(monkeypatch):
    phone_id = f"phone-ignore-{uuid.uuid4()}"
    broadcasts = []

    async def fake_resolve(phone_number_id: str, access_token: str):
        return phone_number_id, "+1 555 555 5555"

    async def fake_broadcast(outlet_id: str, payload: dict):
        broadcasts.append((outlet_id, payload))

    monkeypatch.setattr(whatsapp_chatbot.settings, "FACEBOOK_APP_SECRET", "")
    monkeypatch.setattr(whatsapp_chatbot, "_resolve_phone_number", fake_resolve)
    monkeypatch.setattr(facebook_chatbot.manager, "broadcast", fake_broadcast)

    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        _, headers = await _manager_headers(client, "wa-ignore")
        saved = await client.put(
            "/admin/chatbot/whatsapp",
            headers=headers,
            json={
                "phoneNumberId": phone_id,
                "accessToken": "wa-token",
                "isEnabled": True,
                "orderingEnabled": True,
            },
        )
        assert saved.status_code == 200

        webhook = await client.post(
            "/webhooks/whatsapp",
            json=_whatsapp_payload(
                phone_id,
                [
                    {
                        "from": "15559998877",
                        "id": "wamid-customer",
                        "timestamp": "1700000000",
                        "type": "text",
                        "text": {"body": "customer message"},
                    },
                    {
                        "from": "15555555555",
                        "id": "wamid-self",
                        "timestamp": "1700000001",
                        "type": "text",
                        "text": {"body": "our own echo"},
                    },
                ],
                include_statuses=True,
            ),
        )

    assert webhook.status_code == 200
    assert len(broadcasts) == 1

    async with AsyncSessionLocal() as db:
        rows = (
            await db.execute(
                select(ChatbotConversation).where(
                    ChatbotIntegration.id == ChatbotConversation.integration_id,
                    ChatbotIntegration.page_id == phone_id,
                )
            )
        ).scalars().all()
    assert len(rows) == 1
    assert rows[0].psid == "15559998877"
    assert rows[0].last_user_message == "customer message"


@pytest.mark.asyncio(loop_scope="session")
async def test_whatsapp_webhook_records_image_caption_and_location(monkeypatch):
    phone_id = f"phone-media-{uuid.uuid4()}"
    broadcasts = []

    async def fake_resolve(phone_number_id: str, access_token: str):
        return phone_number_id, "+1 555 555 5555"

    async def fake_broadcast(outlet_id: str, payload: dict):
        broadcasts.append((outlet_id, payload))

    monkeypatch.setattr(whatsapp_chatbot.settings, "FACEBOOK_APP_SECRET", "")
    monkeypatch.setattr(whatsapp_chatbot, "_resolve_phone_number", fake_resolve)
    monkeypatch.setattr(facebook_chatbot.manager, "broadcast", fake_broadcast)

    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        _, headers = await _manager_headers(client, "wa-media")
        saved = await client.put(
            "/admin/chatbot/whatsapp",
            headers=headers,
            json={
                "phoneNumberId": phone_id,
                "accessToken": "wa-token",
                "isEnabled": True,
                "orderingEnabled": True,
            },
        )
        assert saved.status_code == 200

        webhook = await client.post(
            "/webhooks/whatsapp",
            json=_whatsapp_payload(
                phone_id,
                [
                    {
                        "from": "15559998877",
                        "id": "wamid-img",
                        "timestamp": "1700000000",
                        "type": "image",
                        "image": {
                            "caption": "is this available?",
                            "mime_type": "image/jpeg",
                            "url": "https://whatsapp-cdn.example/img.jpg",
                        },
                    },
                    {
                        "from": "15559998877",
                        "id": "wamid-loc",
                        "timestamp": "1700000001",
                        "type": "location",
                        "location": {"latitude": 23.81, "longitude": 90.41},
                    },
                ],
            ),
        )

    assert webhook.status_code == 200
    async with AsyncSessionLocal() as db:
        conv = (
            await db.execute(
                select(ChatbotConversation).where(
                    ChatbotConversation.psid == "15559998877"
                )
            )
        ).scalar_one()
    assert "(23.81, 90.41)" in conv.last_user_message
    user_entries = [e for e in conv.history_json if e.get("role") == "user"]
    image_entry = user_entries[-2]
    assert image_entry["text"].startswith("is this available?")
    assert "the bot cannot see" in image_entry["text"]
    assert "https://whatsapp-cdn.example/img.jpg" in image_entry["text"]


@pytest.mark.asyncio(loop_scope="session")
async def test_whatsapp_batch_creates_order_with_wa_source(monkeypatch):
    phone_id = f"phone-order-{uuid.uuid4()}"
    menu_id = f"menu-wa-{uuid.uuid4()}"
    sent = []

    async def fake_resolve(phone_number_id: str, access_token: str):
        return phone_number_id, "+1 555 555 5555"

    async def fake_call(conversations, system_prompt):
        entry = conversations[0]
        if "systemEvent" in entry:
            return {
                "responses": [
                    {
                        "id": entry["id"],
                        "reply": "আপনার অর্ডারটি প্লেস হয়েছে।",
                    }
                ]
            }
        return {
            "responses": [
                {
                    "id": entry["id"],
                    "reply": "Placing it now.",
                    "replyType": "action",
                    "escalate": {"needed": False},
                    "order": {"intent": "confirm", "confirmed": True},
                }
            ]
        }

    async def fake_send(integration, customer_key: str, text: str):
        sent.append((customer_key, text))

    monkeypatch.setattr(whatsapp_chatbot.settings, "FACEBOOK_APP_SECRET", "")
    monkeypatch.setattr(whatsapp_chatbot, "_resolve_phone_number", fake_resolve)
    monkeypatch.setattr(facebook_chatbot, "_call_batched_llm", fake_call)
    monkeypatch.setattr(facebook_chatbot, "_send_message", fake_send)

    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id, headers = await _manager_headers(client, "wa-order")
        config = await client.put(
            "/admin/chatbot/whatsapp",
            headers=headers,
            json={
                "phoneNumberId": phone_id,
                "accessToken": "wa-token",
                "isEnabled": True,
                "orderingEnabled": True,
            },
        )
        assert config.status_code == 200
        created = await client.post(
            f"/outlets/{outlet_id}/menu",
            headers=headers,
            json={"id": menu_id, "name": "Burger", "price": 120, "category": "Food"},
        )
        assert created.status_code == 200

    async with AsyncSessionLocal() as db:
        integration = (
            await db.execute(
                select(ChatbotIntegration).where(ChatbotIntegration.page_id == phone_id)
            )
        ).scalar_one()
        conv = ChatbotConversation(
            integration_id=integration.id,
            page_id=phone_id,
            psid="15559998877",
            state_json={
                "items": [{"menuItemId": menu_id, "qty": 2}],
                "customerName": "Nadia",
                "mobileNumber": "01700000000",
                "deliveryAddress": "Road 1",
                "awaitingConfirmation": True,
            },
            history_json=[{"role": "user", "text": "yes"}],
            last_user_message="yes",
        )
        db.add(conv)
        await db.commit()
        conv_id = conv.id

    await facebook_chatbot._process_batch([{"conversation_id": conv_id, "text": "yes"}])

    assert sent, "expected a WhatsApp reply to be sent"
    assert sent[0][0] == "15559998877"

    async with AsyncSessionLocal() as db:
        order = (
            await db.execute(
                select(Order)
                .where(Order.source == "whatsapp")
                .order_by(Order.created_at.desc())
            )
        ).scalars().first()
        assert order is not None
        assert order.customer_name == "Nadia"
        assert order.mobile_number == "01700000000"
        assert order.note == "WhatsApp order"
        assert float(order.total_amount) == 252.0
        assert order.created_by_role == "customer"
        serial = facebook_chatbot.format_serial(
            order.serial_number, order.source, order.created_by_role
        )
        assert serial == "#WA1"


@pytest.mark.asyncio(loop_scope="session")
async def test_manager_reply_uses_whatsapp_sender(monkeypatch):
    phone_id = f"phone-reply-{uuid.uuid4()}"
    sent = []

    async def fake_resolve(phone_number_id: str, access_token: str):
        return phone_number_id, "+1 555 555 5555"

    async def fake_send(integration, wa_id: str, text: str):
        sent.append((wa_id, text))

    async def fake_broadcast(_outlet_id: str, _payload: dict):
        return None

    monkeypatch.setattr(whatsapp_chatbot.settings, "FACEBOOK_APP_SECRET", "")
    monkeypatch.setattr(whatsapp_chatbot, "_resolve_phone_number", fake_resolve)
    monkeypatch.setattr(whatsapp_chatbot, "send_whatsapp_message", fake_send)
    monkeypatch.setattr(facebook_chatbot.manager, "broadcast", fake_broadcast)

    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        _, headers = await _manager_headers(client, "wa-reply")
        saved = await client.put(
            "/admin/chatbot/whatsapp",
            headers=headers,
            json={
                "phoneNumberId": phone_id,
                "accessToken": "wa-token",
                "isEnabled": True,
                "orderingEnabled": True,
            },
        )
        assert saved.status_code == 200

        webhook = await client.post(
            "/webhooks/whatsapp",
            json=_whatsapp_payload(
                phone_id,
                [
                    {
                        "from": "15559998877",
                        "id": "wamid-1",
                        "timestamp": "1700000000",
                        "type": "text",
                        "text": {"body": "hello"},
                    }
                ],
            ),
        )
        assert webhook.status_code == 200

        async with AsyncSessionLocal() as db:
            conv = (
                await db.execute(
                    select(ChatbotConversation).where(
                        ChatbotConversation.psid == "15559998877"
                    )
                )
            ).scalar_one()
            conv_id = conv.id

        reply = await client.post(
            f"/admin/chatbot/chats/{conv_id}/reply",
            headers=headers,
            json={"text": "manager answer"},
        )
        listed = await client.get("/admin/chatbot/chats", headers=headers)

    assert reply.status_code == 200
    assert sent == [("15559998877", "manager answer")]
    chat = next(row for row in listed.json()["data"]["chats"] if row["id"] == conv_id)
    assert chat["name"] == "WhatsApp customer"
    assert chat["messages"][-1]["from"] == "manager"


@pytest.mark.asyncio(loop_scope="session")
async def test_whatsapp_send_message_posts_to_graph_api(monkeypatch):
    integration = ChatbotIntegration(
        id="integration-wa-send",
        outlet_id="outlet-wa-send",
        provider="whatsapp",
        page_id="phone-123",
        page_name="+1 555 555 5555",
        page_access_token="wa-token",
        is_enabled=True,
        ordering_enabled=True,
    )
    captured = {}

    class _FakeResponse:
        def raise_for_status(self):
            return None

    class _FakeClient:
        def __init__(self, *args, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            return None

        async def post(self, url, *, params, json):
            captured["url"] = url
            captured["params"] = params
            captured["json"] = json
            return _FakeResponse()

    monkeypatch.setattr(whatsapp_chatbot.httpx, "AsyncClient", _FakeClient)

    await whatsapp_chatbot.send_whatsapp_message(integration, "15559998877", "hello")

    assert captured["url"].endswith("/phone-123/messages")
    assert captured["params"] == {"access_token": "wa-token"}
    assert captured["json"]["messaging_product"] == "whatsapp"
    assert captured["json"]["to"] == "15559998877"
    assert captured["json"]["text"] == {"body": "hello"}
