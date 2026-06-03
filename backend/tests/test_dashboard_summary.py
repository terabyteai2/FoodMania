import uuid
from types import SimpleNamespace

import pytest
from httpx import ASGITransport, AsyncClient

from database import create_tables
from main import app
from routers.dashboard import _floor_tables, _service_mix


def test_dashboard_derives_service_mix_and_floor_states_from_existing_orders():
    dine_in = SimpleNamespace(
        id="order-dine-in", service_type=None, total_amount=120, table_no="1",
        notes=None, status="accepted", covers=2,
    )
    bill = SimpleNamespace(
        id="order-bill", service_type="dine_in", total_amount=80, table_no="2",
        notes=None, status="ready", covers=1,
    )
    takeaway = SimpleNamespace(
        id="order-takeaway", service_type="takeaway", total_amount=50, table_no=None,
        notes=None, status="accepted", covers=0,
    )
    delivery = SimpleNamespace(
        id="order-delivery", service_type="delivery", total_amount=50, table_no=None,
        notes=None, status="accepted", covers=0,
    )

    mix = _service_mix([dine_in, bill, takeaway, delivery])
    assert mix == [
        {"key": "dineIn", "label": "Dine-in", "valueBdt": 200.0, "pct": 67},
        {"key": "takeaway", "label": "Takeaway", "valueBdt": 50.0, "pct": 17},
        {"key": "delivery", "label": "Delivery", "valueBdt": 50.0, "pct": 17},
    ]
    floor = _floor_tables([dine_in, bill, takeaway, delivery], 3)
    assert floor == [
        {"tableNo": "1", "state": "seated", "covers": 2, "orderId": "order-dine-in"},
        {"tableNo": "2", "state": "bill", "covers": 1, "orderId": "order-bill"},
        {"tableNo": "3", "state": "idle", "covers": 0, "orderId": None},
    ]


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
    assert [row["key"] for row in money["serviceMix"]] == ["dineIn", "takeaway", "delivery"]

    right = data["rightNow"]
    assert right["tablesSeated"] == 0
    assert right["tablesTotal"] == 8
    assert right["lateMinThreshold"] == 20
    assert right["needsAttention"] == []
    assert len(right["floorTables"]) == 8
    assert right["floorTables"][0] == {
        "tableNo": "1", "state": "idle", "covers": 0, "orderId": None,
    }

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
    assert set(fleet.keys()) == {
        "outlets", "kpis", "goal", "alerts", "benchmarks", "staffingSuggestion",
        "openOutlets", "revenueByHour", "capacity", "topMovers",
    }
    assert fleet["kpis"]["outletCount"] == 1
    assert fleet["kpis"]["fleetLatePct"] == 0
    assert fleet["goal"] == {"targetBdt": 0.0, "progressPct": 0, "remainingBdt": 0.0}
    assert fleet["alerts"] == []
    assert fleet["openOutlets"] == []
    assert len(fleet["outlets"]) == 1
    assert fleet["outlets"][0]["rank"] == 1
