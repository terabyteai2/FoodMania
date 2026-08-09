import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from config import settings
from database import AsyncSessionLocal, create_tables
from main import app
from models import MenuItem, Outlet

TOOL_SECRET = "test-voice-agent-secret"


def _seed_menu(session, *, id, outlet, name, price, category="Main"):
    session.add(
        MenuItem(
            id=id,
            outlet_id=outlet,
            name=name,
            name_en=name,
            name_bn=name,
            price=price,
            category=category,
            category_en=category,
            category_bn=category,
        )
    )


async def _bootstrap(client):
    server_id = f"voice-tools-{uuid.uuid4()}"
    resp = await client.post(
        "/tenants/bootstrap",
        json={"serverId": server_id, "restaurantName": "Voice Tools Test", "tableCount": 4},
    )
    return resp.json()["data"]


async def _set_outlet_pricing(outlet_id, *, vat_percent, delivery_charge):
    async with AsyncSessionLocal() as db:
        outlet = await db.get(Outlet, outlet_id)
        outlet.pos_vat_rate_percent = vat_percent
        outlet.delivery_charge = delivery_charge
        await db.commit()


async def _seed_items(outlet_id):
    prefix = f"t-{outlet_id[:8]}"
    async with AsyncSessionLocal() as db:
        _seed_menu(db, id=f"{prefix}-burger", outlet=outlet_id, name="Beef Burger", price=120.0)
        _seed_menu(db, id=f"{prefix}-fries", outlet=outlet_id, name="French Fries", price=60.0)
        await db.commit()
    return prefix


@pytest.fixture(scope="module", autouse=True)
def _set_secret():
    old = settings.VOICE_AGENT_TOOL_SECRET
    settings.VOICE_AGENT_TOOL_SECRET = TOOL_SECRET
    yield
    settings.VOICE_AGENT_TOOL_SECRET = old


def _auth_headers():
    return {"X-Voice-Agent-Secret": TOOL_SECRET}


@pytest.mark.asyncio(loop_scope="session")
async def test_voice_agent_session_preloads_outlet_and_menu():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = await _bootstrap(client)
        outlet_id = data["outletId"]
        prefix = await _seed_items(outlet_id)
        await _set_outlet_pricing(outlet_id, vat_percent=10.0, delivery_charge=30.0)

        resp = await client.post(
            "/api/voice-agent/session",
            headers=_auth_headers(),
            json={"conversationId": "conv-1", "outletId": outlet_id},
        )

    assert resp.status_code == 200
    body = resp.json()["data"]
    assert body["outletId"] == outlet_id
    assert body["outletName"] == "Voice Tools Test"
    assert body["vatRatePercent"] == 10.0
    assert body["deliveryCharge"] == 30.0
    assert len(body["menu"]) == 2
    burger = next(item for item in body["menu"] if item["menuItemId"] == f"{prefix}-burger")
    assert burger["price"] == 120.0


@pytest.mark.asyncio(loop_scope="session")
async def test_voice_agent_session_requires_secret():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = await _bootstrap(client)
        resp = await client.post(
            "/api/voice-agent/session",
            json={"conversationId": "conv-2", "outletId": data["outletId"]},
        )

    assert resp.status_code == 401


@pytest.mark.asyncio(loop_scope="session")
async def test_voice_agent_place_order_persists_with_server_prices():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = await _bootstrap(client)
        outlet_id = data["outletId"]
        device_headers = {"Authorization": f"Bearer {data['deviceToken']}"}
        prefix = await _seed_items(outlet_id)
        await _set_outlet_pricing(outlet_id, vat_percent=10.0, delivery_charge=30.0)

        resp = await client.post(
            "/api/voice-agent/order",
            headers=_auth_headers(),
            json={
                "conversationId": "conv-3",
                "outletId": outlet_id,
                "serviceType": "delivery",
                "customerName": "Rahim",
                "mobileNumber": "01711111111",
                "deliveryAddress": "Dhaka",
                "items": [
                    {"menuItemId": f"{prefix}-burger", "qty": 2, "name": "Beef Burger"},
                    {"menuItemId": f"{prefix}-fries", "qty": 1, "name": "French Fries"},
                ],
            },
        )
        order_id = resp.json()["data"]["orderId"] if resp.status_code == 200 else None
        pulled = await client.get(f"/outlets/{outlet_id}/orders", headers=device_headers)

    assert resp.status_code == 200
    body = resp.json()["data"]
    assert body["subtotal"] == 300.0
    assert body["vatAmount"] == 30.0
    assert body["deliveryCharge"] == 30.0
    assert body["total"] == 360.0
    assert body["serviceType"] == "delivery"
    assert body["status"] == "pending"
    assert body["orderCode"] == "#1"
    assert len(body["items"]) == 2

    stored = next(o for o in pulled.json()["data"] if o["id"] == order_id)
    assert stored["source"] == "voice"
    assert stored["totalAmount"] == 360.0
    assert stored["customerName"] == "Rahim"


@pytest.mark.asyncio(loop_scope="session")
async def test_voice_agent_takeaway_skips_delivery_charge():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = await _bootstrap(client)
        outlet_id = data["outletId"]
        prefix = await _seed_items(outlet_id)
        await _set_outlet_pricing(outlet_id, vat_percent=10.0, delivery_charge=30.0)

        resp = await client.post(
            "/api/voice-agent/order",
            headers=_auth_headers(),
            json={
                "conversationId": "conv-4",
                "outletId": outlet_id,
                "serviceType": "takeaway",
                "items": [{"menuItemId": f"{prefix}-burger", "qty": 1}],
            },
        )

    assert resp.status_code == 200
    body = resp.json()["data"]
    assert body["subtotal"] == 120.0
    assert body["vatAmount"] == 12.0
    assert body["deliveryCharge"] == 0.0
    assert body["total"] == 132.0


@pytest.mark.asyncio(loop_scope="session")
async def test_voice_agent_place_order_rejects_unavailable_items():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = await _bootstrap(client)
        outlet_id = data["outletId"]
        prefix = await _seed_items(outlet_id)

        unknown = await client.post(
            "/api/voice-agent/order",
            headers=_auth_headers(),
            json={
                "conversationId": "conv-5",
                "outletId": outlet_id,
                "items": [{"menuItemId": f"{prefix}-ghost", "qty": 1}],
            },
        )
        async with AsyncSessionLocal() as db:
            burger = await db.get(MenuItem, f"{prefix}-burger")
            burger.is_available = False
            await db.commit()
        unavailable = await client.post(
            "/api/voice-agent/order",
            headers=_auth_headers(),
            json={
                "conversationId": "conv-6",
                "outletId": outlet_id,
                "items": [{"menuItemId": f"{prefix}-burger", "qty": 1}],
            },
        )

    assert unknown.status_code == 422
    assert "ghost" in unknown.json()["detail"]
    assert unavailable.status_code == 422
    assert "burger" in unavailable.json()["detail"]


@pytest.mark.asyncio(loop_scope="session")
async def test_voice_agent_place_order_requires_items_and_secret():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = await _bootstrap(client)
        outlet_id = data["outletId"]
        await _seed_items(outlet_id)

        no_secret = await client.post(
            "/api/voice-agent/order",
            json={
                "conversationId": "conv-7",
                "outletId": outlet_id,
                "items": [{"menuItemId": "whatever", "qty": 1}],
            },
        )
        no_items = await client.post(
            "/api/voice-agent/order",
            headers=_auth_headers(),
            json={"conversationId": "conv-8", "outletId": outlet_id, "items": []},
        )
        bad_outlet = await client.post(
            "/api/voice-agent/order",
            headers=_auth_headers(),
            json={"conversationId": "conv-9", "outletId": "nope", "items": []},
        )

    assert no_secret.status_code == 401
    assert no_items.status_code == 400
    assert bad_outlet.status_code == 404


@pytest.mark.asyncio(loop_scope="session")
async def test_voice_agent_end_hook_ok():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post(
            "/api/voice-agent/end",
            headers=_auth_headers(),
            json={
                "conversationId": "conv-10",
                "outletId": "outlet-x",
                "outcome": {"orderPlaced": True},
                "transcript": [],
            },
        )

    assert resp.status_code == 200
    assert resp.json()["data"] == {"accepted": True}
