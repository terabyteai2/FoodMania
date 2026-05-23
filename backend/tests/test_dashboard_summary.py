import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from database import create_tables
from main import app


@pytest.mark.asyncio(loop_scope="session")
async def test_dashboard_summary_returns_money_first_and_right_now_shapes():
    await create_tables()
    server_id = f"dashboard-{uuid.uuid4()}"
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        bootstrap = await client.post(
            "/tenants/bootstrap",
            json={
                "serverId": server_id,
                "restaurantName": "Dashboard Test",
                "tableCount": 8,
            },
        )
        assert bootstrap.status_code == 200
        boot = bootstrap.json()["data"]
        token = boot["deviceToken"]
        outlet_id = boot["outletId"]

        summary = await client.get(
            f"/outlets/{outlet_id}/dashboard/summary",
            headers={"Authorization": f"Bearer {token}"},
        )

    assert summary.status_code == 200
    data = summary.json()["data"]
    assert "moneyFirst" in data
    assert "rightNow" in data
    money = data["moneyFirst"]
    assert set(money["kpis"].keys()) == {"orders", "openOrders", "avgTicket", "profitPct"}
    assert isinstance(money["sparkline"], list) and len(money["sparkline"]) == 7
    assert money["earnedToday"] == 0
    assert money["topMovers"] == []

    right = data["rightNow"]
    assert right["tablesSeated"] == 0
    assert right["tablesTotal"] == 8
    assert right["lateMinThreshold"] == 20
    assert right["needsAttention"] == []
