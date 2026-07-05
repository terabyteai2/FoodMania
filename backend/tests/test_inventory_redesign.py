import uuid
from datetime import datetime, timezone
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from auth import create_device_token
from database import AsyncSessionLocal, create_tables
from main import app
from models import AdminAccount, Outlet
from phone_utils import phone_to_synthetic_email


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
        async with AsyncSessionLocal() as db:
            outlet = (await db.execute(select(Outlet).where(Outlet.id == outlet_id))).scalar_one()
            phone = f"+88017{suffix.hex[:8]}"
            account = AdminAccount(
                id=str(uuid4()),
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
            account_id = account.id
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
