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

    # Review tab block (Standard/Advanced/Enterprise screens consume this).
    assert "review" in data
    review = data["review"]
    assert set(review.keys()) == {
        "hero", "kpis", "revenueByHour", "itemsSold", "bySource", "issues", "staff", "fleet",
    }
    assert set(review["kpis"].keys()) == {"orders", "covers", "avgTicketBdt", "foodCostPct"}
    assert review["kpis"]["foodCostPct"] is None  # no cost_price set yet
    assert review["itemsSold"] == []
    assert review["staff"] == []
    # Empty outlet: revenue-by-hour is a flat 15-bucket axis with no peak.
    rbh = review["revenueByHour"]
    assert len(rbh["today"]) == 15 and len(rbh["avg7"]) == 15
    assert rbh["peakLabel"] == ""
    # bySource always returns the three canonical channels.
    assert [row["key"] for row in review["bySource"]] == ["cash", "card", "online"]

    # Fleet block renders even for a single-outlet restaurant (one-row list).
    fleet = review["fleet"]
    assert set(fleet.keys()) == {"outlets", "kpis", "revenueByHour", "capacity", "topMovers"}
    assert fleet["kpis"]["outletCount"] == 1
    assert len(fleet["outlets"]) == 1
    assert fleet["outlets"][0]["rank"] == 1
