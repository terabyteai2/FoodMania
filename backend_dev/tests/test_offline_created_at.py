import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from database import create_tables
from main import app


@pytest.mark.asyncio(loop_scope="session")
async def test_offline_order_keeps_client_created_at_and_order_date():
    await create_tables()
    server_id = f"offline-sync-{uuid.uuid4()}"
    order_id = f"order-{uuid.uuid4()}"
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        bootstrap = await client.post(
            "/tenants/bootstrap",
            json={
                "serverId": server_id,
                "restaurantName": "Offline Sync Test",
                "tableCount": 4,
            },
        )
        data = bootstrap.json()["data"]
        headers = {"Authorization": f"Bearer {data['deviceToken']}"}
        outlet_id = data["outletId"]

        # Simulate an offline device syncing an order created the previous
        # business day (17:30 BDT Aug 5 == 11:30 UTC Aug 5).
        created = await client.post(
            f"/outlets/{outlet_id}/orders",
            headers=headers,
            json={
                "id": order_id,
                "source": "manual",
                "status": "completed",
                "totalAmount": 120,
                "subtotal": 120,
                "serviceType": "dine_in",
                "items": [
                    {"name": "Rice", "qty": 1, "price": 120, "lineTotal": 120}
                ],
                "createdAt": "2026-08-05T11:30:00Z",
                "updatedAt": "2026-08-05T11:30:00Z",
            },
        )
        pulled = await client.get(f"/outlets/{outlet_id}/orders", headers=headers)

        no_created_at = await client.post(
            f"/outlets/{outlet_id}/orders",
            headers=headers,
            json={
                "id": f"order-{uuid.uuid4()}",
                "source": "manual",
                "status": "accepted",
                "totalAmount": 50,
                "items": [{"name": "Tea", "qty": 1, "price": 50, "lineTotal": 50}],
            },
        )
        future_created_at = await client.post(
            f"/outlets/{outlet_id}/orders",
            headers=headers,
            json={
                "id": f"order-{uuid.uuid4()}",
                "source": "manual",
                "status": "accepted",
                "totalAmount": 60,
                "items": [{"name": "Coffee", "qty": 1, "price": 60, "lineTotal": 60}],
                "createdAt": "2099-01-01T00:00:00Z",
            },
        )

    assert created.status_code == 200
    body = created.json()["data"]
    assert body["createdAt"] == "2026-08-05T11:30:00+00:00"
    assert body["orderDate"] == "2026-08-05"

    assert pulled.status_code == 200
    pulled_order = next(o for o in pulled.json()["data"] if o["id"] == order_id)
    assert pulled_order["createdAt"] == "2026-08-05T11:30:00+00:00"
    assert pulled_order["orderDate"] == "2026-08-05"

    assert no_created_at.status_code == 200
    assert no_created_at.json()["data"]["createdAt"] is not None

    assert future_created_at.status_code == 200
    future_body = future_created_at.json()["data"]
    assert future_body["createdAt"] != "2099-01-01T00:00:00+00:00"
