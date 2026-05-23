import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from database import create_tables
from main import app


@pytest.mark.asyncio(loop_scope="session")
async def test_order_create_pull_and_status_preserve_metadata():
    await create_tables()
    server_id = f"order-metadata-{uuid.uuid4()}"
    order_id = f"order-{uuid.uuid4()}"
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        bootstrap = await client.post(
            "/tenants/bootstrap",
            json={
                "serverId": server_id,
                "restaurantName": "Metadata Test",
                "tableCount": 12,
            },
        )
        data = bootstrap.json()["data"]
        headers = {"Authorization": f"Bearer {data['deviceToken']}"}
        outlet_id = data["outletId"]

        created = await client.post(
            f"/outlets/{outlet_id}/orders",
            headers=headers,
            json={
                "id": order_id,
                "serialNumber": 42,
                "source": "manual",
                "status": "accepted",
                "totalAmount": 525,
                "subtotal": 500,
                "vatRatePercent": 5,
                "vatAmount": 25,
                "serviceType": "dine_in",
                "covers": 3,
                "paymentMethod": "bkash",
                "items": [{"name": "Rice", "qty": 1, "lineTotal": 500}],
            },
        )
        pulled = await client.get(f"/outlets/{outlet_id}/orders", headers=headers)
        served = await client.patch(
            f"/outlets/{outlet_id}/orders/{order_id}/status",
            headers=headers,
            json={"status": "served"},
        )

    assert bootstrap.status_code == 200
    assert created.status_code == 200
    created_order = created.json()["data"]
    assert created_order["subtotal"] == 500
    assert created_order["vatRatePercent"] == 5
    assert created_order["vatAmount"] == 25
    assert created_order["serviceType"] == "dine_in"
    assert created_order["covers"] == 3
    assert created_order["paymentMethod"] == "bkash"

    assert pulled.status_code == 200
    pulled_order = next(o for o in pulled.json()["data"] if o["id"] == order_id)
    assert pulled_order["paymentMethod"] == "bkash"
    assert pulled_order["vatAmount"] == 25

    assert served.status_code == 200
    served_order = served.json()["data"]
    assert served_order["status"] == "served"
    assert served_order["serviceType"] == "dine_in"
    assert served_order["paymentMethod"] == "bkash"
