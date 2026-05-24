import uuid
from unittest.mock import AsyncMock

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from database import AsyncSessionLocal, create_tables
from main import app
from models import Order


@pytest.mark.asyncio(loop_scope="session")
async def test_customer_delivery_order_persists_geocoded_address(monkeypatch):
    await create_tables()
    server_id = f"delivery-{uuid.uuid4()}"
    menu_item_id = f"menu-{uuid.uuid4()}"

    monkeypatch.setattr(
        "routers.customer.reverse_geocode",
        AsyncMock(return_value="123 Test Rd, Dhaka, Bangladesh"),
    )

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        bootstrap = await client.post(
            "/tenants/bootstrap",
            json={
                "serverId": server_id,
                "restaurantName": "Delivery Test",
                "tableCount": 4,
            },
        )
        assert bootstrap.status_code == 200
        data = bootstrap.json()["data"]
        outlet_id = data["outletId"]
        headers = {"Authorization": f"Bearer {data['deviceToken']}"}

        created = await client.post(
            f"/outlets/{outlet_id}/menu",
            headers=headers,
            json={
                "id": menu_item_id,
                "name": "Chicken Biryani",
                "price": 350,
                "category": "Biryani",
            },
        )
        assert created.status_code == 200

        order_resp = await client.post(
            f"/customer/{outlet_id}/orders",
            json={
                "items": [
                    {"menuItemId": menu_item_id, "name": "Chicken Biryani", "qty": 2, "price": 350}
                ],
                "customerName": "  Rita Rahman  ",
                "customerPhone": "01712345678",
                "latitude": 23.7806,
                "longitude": 90.4193,
                "note": "extra spicy",
            },
        )
        assert order_resp.status_code == 200, order_resp.text
        payload = order_resp.json()["data"]
        assert payload["customerName"] == "Rita Rahman"
        assert payload["customerPhone"] == "01712345678"
        assert payload["deliveryAddress"] == "123 Test Rd, Dhaka, Bangladesh"
        order_id = payload["orderId"]

    async with AsyncSessionLocal() as db:
        row = (
            await db.execute(select(Order).where(Order.id == order_id))
        ).scalar_one()
        assert row.service_type == "delivery"
        assert row.payment_method == "cod"
        assert row.customer_name == "Rita Rahman"
        assert row.customer_phone == "01712345678"
        assert float(row.customer_lat) == pytest.approx(23.7806)
        assert float(row.customer_lng) == pytest.approx(90.4193)
        assert row.delivery_address == "123 Test Rd, Dhaka, Bangladesh"


@pytest.mark.asyncio(loop_scope="session")
async def test_customer_delivery_order_rejects_missing_customer_fields(monkeypatch):
    await create_tables()
    server_id = f"delivery-bad-{uuid.uuid4()}"

    monkeypatch.setattr(
        "routers.customer.reverse_geocode",
        AsyncMock(return_value=None),
    )

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        bootstrap = await client.post(
            "/tenants/bootstrap",
            json={"serverId": server_id, "restaurantName": "X", "tableCount": 2},
        )
        outlet_id = bootstrap.json()["data"]["outletId"]

        resp = await client.post(
            f"/customer/{outlet_id}/orders",
            json={
                "items": [{"menuItemId": "x", "name": "X", "qty": 1, "price": 10}],
                "customerName": "   ",
                "customerPhone": "01712345678",
                "latitude": 23.0,
                "longitude": 90.0,
            },
        )
    assert resp.status_code == 422
