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

        menu_item_id = f"menu-{uuid.uuid4()}"
        menu = await client.post(
            f"/outlets/{outlet_id}/menu",
            headers=headers,
            json={
                "id": menu_item_id,
                "name": "Rice",
                "nameEn": "Rice",
                "nameBn": "ভাত",
                "price": 500,
                "category": "Main",
            },
        )

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
                "customerName": "Ayesha Khan",
                "deliveryAddress": "House 5, Road 12, Banani",
                "mobileNumber": "01711223344",
                "items": [
                    {
                        "menuItemId": menu_item_id,
                        "name": "Legacy Rice",
                        "qty": 1,
                        "price": 500,
                        "lineTotal": 500,
                    },
                    {
                        "name": "Tea",
                        "nameEn": "Tea",
                        "nameBn": "চা",
                        "qty": 1,
                        "price": 0,
                        "lineTotal": 0,
                    },
                ],
            },
        )
        pulled = await client.get(f"/outlets/{outlet_id}/orders", headers=headers)
        served = await client.patch(
            f"/outlets/{outlet_id}/orders/{order_id}/status",
            headers=headers,
            json={"status": "served"},
        )

    assert bootstrap.status_code == 200
    assert menu.status_code == 200
    assert created.status_code == 200
    created_order = created.json()["data"]
    assert created_order["subtotal"] == 500
    assert created_order["vatRatePercent"] == 5
    assert created_order["vatAmount"] == 25
    assert created_order["serviceType"] == "dine_in"
    assert created_order["covers"] == 3
    assert created_order["paymentMethod"] == "bkash"
    assert created_order["customerName"] == "Ayesha Khan"
    assert created_order["deliveryAddress"] == "House 5, Road 12, Banani"
    assert created_order["mobileNumber"] == "01711223344"
    assert created_order["items"][0]["name"] == "Rice"
    assert created_order["items"][0]["nameEn"] == "Rice"
    assert created_order["items"][0]["nameBn"] == "ভাত"
    assert created_order["items"][1]["nameEn"] == "Tea"
    assert created_order["items"][1]["nameBn"] == "চা"

    assert pulled.status_code == 200
    pulled_order = next(o for o in pulled.json()["data"] if o["id"] == order_id)
    assert pulled_order["paymentMethod"] == "bkash"
    assert pulled_order["vatAmount"] == 25
    assert pulled_order["customerName"] == "Ayesha Khan"
    assert pulled_order["deliveryAddress"] == "House 5, Road 12, Banani"
    assert pulled_order["mobileNumber"] == "01711223344"
    assert pulled_order["items"][0]["nameBn"] == "ভাত"

    assert served.status_code == 200
    served_order = served.json()["data"]
    assert served_order["status"] == "served"
    assert served_order["serviceType"] == "dine_in"
    assert served_order["paymentMethod"] == "bkash"
    assert served_order["customerName"] == "Ayesha Khan"
    assert served_order["deliveryAddress"] == "House 5, Road 12, Banani"
    assert served_order["mobileNumber"] == "01711223344"


@pytest.mark.asyncio(loop_scope="session")
async def test_customer_delivery_order_persists_contact_info():
    await create_tables()
    server_id = f"order-delivery-{uuid.uuid4()}"
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
        data = bootstrap.json()["data"]
        headers = {"Authorization": f"Bearer {data['deviceToken']}"}
        outlet_id = data["outletId"]

        menu_item_id = f"menu-{uuid.uuid4()}"
        await client.post(
            f"/outlets/{outlet_id}/menu",
            headers=headers,
            json={
                "id": menu_item_id,
                "name": "Burger",
                "price": 300,
                "category": "Main",
            },
        )

        ok = await client.post(
            f"/customer/{outlet_id}/orders",
            json={
                "items": [
                    {"menuItemId": menu_item_id, "name": "Burger", "qty": 2, "price": 300}
                ],
                "orderType": "delivery",
                "customerName": "Ayesha Khan",
                "deliveryAddress": "House 5, Road 12, Banani",
                "mobileNumber": "01711223344",
                "note": "Ring the doorbell twice",
            },
        )
        pulled = await client.get(f"/outlets/{outlet_id}/orders", headers=headers)

        missing = await client.post(
            f"/customer/{outlet_id}/orders",
            json={
                "items": [
                    {"menuItemId": menu_item_id, "name": "Burger", "qty": 1, "price": 300}
                ],
                "orderType": "delivery",
                "customerName": "Ayesha",
            },
        )

        stale_dine_in = await client.post(
            f"/customer/{outlet_id}/orders",
            json={
                "items": [
                    {"menuItemId": menu_item_id, "name": "Burger", "qty": 1, "price": 300}
                ],
                "tableNo": "3",
            },
        )
        table_order = await client.post(
            f"/customer/{outlet_id}/orders",
            json={
                "items": [
                    {"menuItemId": menu_item_id, "name": "Burger", "qty": 1, "price": 300}
                ],
                "orderType": "dine_in",
                "tableNo": "7",
            },
        )

    assert ok.status_code == 200
    body = ok.json()["data"]
    assert body["serviceType"] == "delivery"
    assert body["customerName"] == "Ayesha Khan"
    assert body["deliveryAddress"] == "House 5, Road 12, Banani"
    assert body["mobileNumber"] == "01711223344"
    assert body["notes"] == "Ring the doorbell twice"

    assert pulled.status_code == 200
    pulled_order = next(
        o for o in pulled.json()["data"] if o["id"] == body["orderId"]
    )
    assert pulled_order["serviceType"] == "delivery"
    assert pulled_order["customerName"] == "Ayesha Khan"
    assert pulled_order["deliveryAddress"] == "House 5, Road 12, Banani"
    assert pulled_order["mobileNumber"] == "01711223344"
    assert pulled_order["notes"] == "Ring the doorbell twice"

    assert missing.status_code == 422
    assert "Delivery requires" in missing.json()["detail"]

    assert stale_dine_in.status_code == 422
    assert "Delivery requires" in stale_dine_in.json()["detail"]

    assert table_order.status_code == 200
    table_body = table_order.json()["data"]
    assert table_body["serviceType"] == "dine_in"
    assert table_body["tableNo"] == "7"
    assert table_body["customerName"] is None
    assert table_body["deliveryAddress"] is None
    assert table_body["mobileNumber"] is None
