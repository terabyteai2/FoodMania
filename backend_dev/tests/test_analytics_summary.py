import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from database import create_tables
from main import app


async def _bootstrap(client: AsyncClient, name: str):
    response = await client.post(
        "/tenants/bootstrap",
        json={
            "serverId": f"{name}-{uuid.uuid4()}",
            "restaurantName": name,
            "tableCount": 4,
        },
    )
    assert response.status_code == 200
    data = response.json()["data"]
    return data["outletId"], {"Authorization": f"Bearer {data['deviceToken']}"}


@pytest.mark.asyncio(loop_scope="session")
async def test_analytics_summary_empty_outlet_shape():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id, headers = await _bootstrap(client, "Analytics Empty")
        response = await client.get(
            f"/outlets/{outlet_id}/analytics/summary",
            headers=headers,
        )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["salesSummary"] == {
        "ordersCompleted": 0,
        "grossSales": 0,
        "discountByStaff": 0,
        "netSales": 0,
    }
    assert data["totalCollection"] == 0
    assert data["collection"] == []
    assert [row["key"] for row in data["serviceWise"]] == [
        "dineIn",
        "takeaway",
        "delivery",
    ]
    assert isinstance(data["trend"], list) and data["trend"]
    assert data["itemWise"] == []


@pytest.mark.asyncio(loop_scope="session")
async def test_analytics_summary_counts_non_rejected_and_falls_back_to_order_totals():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id, headers = await _bootstrap(client, "Analytics Orders")
        orders = [
            ("completed", 100, "cash"),
            ("served", 80, "bkash"),
            ("accepted", 20, "card"),
            ("rejected", 999, "cash"),
        ]
        for status, total, method in orders:
            created = await client.post(
                f"/outlets/{outlet_id}/orders",
                headers=headers,
                json={
                    "id": f"order-{uuid.uuid4()}",
                    "source": "manual",
                    "status": status,
                    "totalAmount": total,
                    "paymentMethod": method,
                    "items": [],
                },
            )
            assert created.status_code == 200

        response = await client.get(
            f"/outlets/{outlet_id}/analytics/summary",
            headers=headers,
        )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["salesSummary"]["ordersCompleted"] == 3
    assert data["totalCollection"] == 200
    assert data["salesSummary"]["grossSales"] == 200
    assert data["salesSummary"]["netSales"] == 200
    assert data["itemWise"] == []
    assert {row["key"]: row["valueBdt"] for row in data["collection"]} == {
        "cash": 100,
        "bkash": 80,
        "card": 20,
    }
