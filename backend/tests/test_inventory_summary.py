import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from database import create_tables
from main import app


@pytest.mark.asyncio(loop_scope="session")
async def test_inventory_summary_reports_stock_value_and_category_buckets():
    await create_tables()
    server_id = f"inv-summary-{uuid.uuid4()}"
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        bootstrap = await client.post(
            "/tenants/bootstrap",
            json={
                "serverId": server_id,
                "restaurantName": "Inv Summary Test",
                "tableCount": 5,
            },
        )
        boot = bootstrap.json()["data"]
        outlet_id = boot["outletId"]
        headers = {"Authorization": f"Bearer {boot['deviceToken']}"}

        # Seed three items in different categories
        items = [
            {
                "id": str(uuid.uuid4()),
                "name": "Chicken / চিকেন",
                "category": "raw",
                "unit": "kg",
                "quantity": 12,
                "minThreshold": 5,
                "costPerUnit": 420,
            },
            {
                "id": str(uuid.uuid4()),
                "name": "Rice / চাল",
                "category": "dry",
                "unit": "kg",
                "quantity": 30,
                "minThreshold": 10,
                "costPerUnit": 55,
            },
            {
                "id": str(uuid.uuid4()),
                "name": "Salt",
                "category": "packaged",
                "unit": "pcs",
                "quantity": 0,
                "minThreshold": 2,
                "costPerUnit": 30,
            },
        ]
        for body in items:
            response = await client.post(
                f"/outlets/{outlet_id}/inventory/items",
                headers=headers,
                json=body,
            )
            assert response.status_code == 200

        summary = await client.get(
            f"/outlets/{outlet_id}/inventory/summary",
            headers=headers,
        )

    assert summary.status_code == 200
    data = summary.json()["data"]
    assert data["stockValueBdt"] == pytest.approx(12 * 420 + 30 * 55 + 0 * 30, abs=0.01)
    assert data["alerts"] == 1  # Salt is out
    categories = {bucket["key"]: bucket["count"] for bucket in data["categories"]}
    assert categories["all"] == 3
    assert categories["raw"] == 1
    assert categories["dry"] == 1
    assert categories["packaged"] == 1

    statuses = {row["nameEn"]: row["varianceStatus"] for row in data["items"]}
    assert statuses["Chicken"] == "ok"
    assert statuses["Rice"] == "ok"
    assert statuses["Salt"] == "out"
    chicken = next(row for row in data["items"] if row["nameEn"] == "Chicken")
    assert chicken["nameBn"] == "চিকেন"
    assert chicken["unit"] == "kg"
    salt = next(row for row in data["items"] if row["nameEn"] == "Salt")
    assert salt["nameBn"] == "লবণ"
