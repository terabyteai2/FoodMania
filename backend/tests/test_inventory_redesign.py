import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from database import create_tables
from main import app


@pytest.mark.asyncio(loop_scope="session")
async def test_supplier_and_batch_adjustments_capture_actor_and_rollback_together():
    await create_tables()
    suffix = uuid.uuid4()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        boot = (
            await client.post(
                "/tenants/bootstrap",
                json={"serverId": f"inventory-redesign-{suffix}", "restaurantName": "Inventory Redesign"},
            )
        ).json()["data"]
        outlet_id = boot["outletId"]
        await client.post(
            "/admin/create",
            json={
                "outletId": outlet_id,
                "email": f"inventory-{suffix}@example.com",
                "username": f"inventory-{suffix}@example.com",
                "password": "password",
                "role": "manager",
            },
        )
        login = await client.post(
            "/admin/login",
            json={
                "serverId": f"inventory-redesign-{suffix}",
                "usernameOrEmail": f"inventory-{suffix}@example.com",
                "password": "password",
            },
        )
        token = login.json()["data"]["deviceToken"]
        account_id = login.json()["data"]["account"]["id"]
        headers = {"Authorization": f"Bearer {token}"}

        supplier = await client.post(
            f"/outlets/{outlet_id}/inventory/suppliers",
            headers=headers,
            json={"name": "Fresh Foods", "phone": "01700000000"},
        )
        assert supplier.status_code == 200
        supplier_id = supplier.json()["data"]["id"]

        item_ids = [str(uuid.uuid4()), str(uuid.uuid4())]
        for item_id in item_ids:
            response = await client.post(
                f"/outlets/{outlet_id}/inventory/items",
                headers=headers,
                json={
                    "id": item_id,
                    "name": f"Item {item_id[:4]}",
                    "unit": "kg",
                    "quantity": 10,
                    "defaultSupplierId": supplier_id,
                    "defaultReorderQty": 8,
                },
            )
            assert response.status_code == 200

        batch = await client.post(
            f"/outlets/{outlet_id}/inventory/adjustments/batch",
            headers=headers,
            json={
                "adjustments": [
                    {"inventoryItemId": item_ids[0], "delta": 5, "type": "restock", "supplierId": supplier_id},
                    {"inventoryItemId": item_ids[1], "delta": -2, "type": "usage", "reason": "kitchen"},
                ]
            },
        )
        assert batch.status_code == 200
        adjustments = batch.json()["data"]["adjustments"]
        assert adjustments[0]["supplierName"] == "Fresh Foods"
        assert adjustments[1]["reason"] == "kitchen"
        assert adjustments[1]["createdByAccountId"] == account_id

        invalid = await client.post(
            f"/outlets/{outlet_id}/inventory/adjustments/batch",
            headers=headers,
            json={
                "adjustments": [
                    {"inventoryItemId": item_ids[0], "delta": 3, "type": "restock"},
                    {"inventoryItemId": item_ids[1], "delta": 3, "type": "restock", "supplierId": "missing"},
                ]
            },
        )
        assert invalid.status_code == 400

        pull = await client.get(f"/outlets/{outlet_id}/inventory", headers=headers)
        quantities = {item["id"]: item["quantity"] for item in pull.json()["data"]["items"]}
        assert quantities[item_ids[0]] == 15
        assert quantities[item_ids[1]] == 8
