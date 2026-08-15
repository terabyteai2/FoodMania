import uuid
from datetime import datetime, timedelta, timezone

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from config import settings
from database import AsyncSessionLocal, create_tables
from main import app
from models import DailyStockCount, InventoryItem, StockAdjustment

TOOL_SECRET = "test-voice-agent-stock-secret"


def _seed_inventory(session, *, id, outlet, name, qty=0.0, unit="kg", category="raw", cost=0.0):
    session.add(
        InventoryItem(
            id=id,
            outlet_id=outlet,
            name=name,
            category=category,
            unit=unit,
            quantity=qty,
            cost_per_unit=cost,
        )
    )


def _today_bdt() -> str:
    return (datetime.now(timezone.utc) + timedelta(hours=6)).date().isoformat()


async def _bootstrap(client):
    server_id = f"voice-stock-{uuid.uuid4()}"
    resp = await client.post(
        "/tenants/bootstrap",
        json={"serverId": server_id, "restaurantName": "Voice Stock Test", "tableCount": 4},
    )
    return resp.json()["data"]


@pytest.fixture(scope="module", autouse=True)
def _set_secret():
    old = settings.VOICE_AGENT_TOOL_SECRET
    settings.VOICE_AGENT_TOOL_SECRET = TOOL_SECRET
    yield
    settings.VOICE_AGENT_TOOL_SECRET = old


def _auth_headers():
    return {"X-Voice-Agent-Secret": TOOL_SECRET}


@pytest.mark.asyncio(loop_scope="session")
async def test_stock_in_restocks_matched_item_with_cost():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = await _bootstrap(client)
        outlet_id = data["outletId"]
        prefix = f"t-{outlet_id[:8]}"
        async with AsyncSessionLocal() as db:
            _seed_inventory(db, id=f"{prefix}-rice", outlet=outlet_id, name="Rice", qty=10.0, unit="kg", cost=70.0)
            await db.commit()

        resp = await client.post(
            "/api/voice-agent/stock/in",
            headers=_auth_headers(),
            json={
                "conversationId": "stock-1",
                "outletId": outlet_id,
                "items": [{"name": "rice", "qty": 5.0, "unit": "kg", "totalCostBdt": 400.0}],
            },
        )

    assert resp.status_code == 200
    body = resp.json()["data"]
    assert body["okCount"] == 1
    assert body["errorCount"] == 0
    line = body["items"][0]
    assert line["matched"] is True
    assert line["created"] is False
    assert line["itemId"] == f"{prefix}-rice"
    assert line["quantityBefore"] == 10.0
    assert line["quantityAfter"] == 15.0
    assert line["unitCostBdt"] == 80.0

    async with AsyncSessionLocal() as db:
        item = await db.get(InventoryItem, f"{prefix}-rice")
        assert float(item.quantity) == 15.0
        assert float(item.cost_per_unit) == 80.0
        adjustments = (
            await db.execute(
                select(StockAdjustment).where(
                    StockAdjustment.outlet_id == outlet_id,
                    StockAdjustment.type == "restock",
                )
            )
        ).scalars().all()
        assert len(adjustments) == 1
        assert float(adjustments[0].delta) == 5.0
        assert adjustments[0].created_by_role == "voice_agent"


@pytest.mark.asyncio(loop_scope="session")
async def test_stock_in_auto_creates_missing_item():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = await _bootstrap(client)
        outlet_id = data["outletId"]

        resp = await client.post(
            "/api/voice-agent/stock/in",
            headers=_auth_headers(),
            json={
                "conversationId": "stock-2",
                "outletId": outlet_id,
                "items": [{"name": "onion", "qty": 12.0, "unit": "kg"}],
            },
        )

    assert resp.status_code == 200
    body = resp.json()["data"]
    assert body["okCount"] == 1
    assert body["errorCount"] == 0
    line = body["items"][0]
    assert line["matched"] is False
    assert line["created"] is True
    assert line["quantityBefore"] == 0.0
    assert line["quantityAfter"] == 12.0
    assert line["unit"] == "kg"

    async with AsyncSessionLocal() as db:
        item = (
            await db.execute(
                select(InventoryItem).where(
                    InventoryItem.outlet_id == outlet_id,
                    InventoryItem.name == "onion",
                )
            )
        ).scalar_one_or_none()
        assert item is not None
        assert float(item.quantity) == 12.0
        assert item.deleted_at is None


@pytest.mark.asyncio(loop_scope="session")
async def test_stock_in_batch_isolates_bad_lines():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = await _bootstrap(client)
        outlet_id = data["outletId"]
        prefix = f"t-{outlet_id[:8]}"
        async with AsyncSessionLocal() as db:
            _seed_inventory(db, id=f"{prefix}-rice", outlet=outlet_id, name="Rice", qty=4.0)
            await db.commit()

        resp = await client.post(
            "/api/voice-agent/stock/in",
            headers=_auth_headers(),
            json={
                "conversationId": "stock-3",
                "outletId": outlet_id,
                "items": [
                    {"name": "rice", "qty": 2.0},
                    {"name": "", "qty": 3.0},
                ],
            },
        )

    assert resp.status_code == 200
    body = resp.json()["data"]
    assert body["okCount"] == 1
    assert body["errorCount"] == 1
    good = next(line for line in body["items"] if not line.get("error"))
    bad = next(line for line in body["items"] if line.get("error"))
    assert good["quantityAfter"] == 6.0
    assert "missing" in bad["error"]

    async with AsyncSessionLocal() as db:
        item = await db.get(InventoryItem, f"{prefix}-rice")
        assert float(item.quantity) == 6.0


@pytest.mark.asyncio(loop_scope="session")
async def test_stock_in_requires_secret_and_valid_outlet():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = await _bootstrap(client)
        outlet_id = data["outletId"]

        no_secret = await client.post(
            "/api/voice-agent/stock/in",
            json={"conversationId": "stock-4", "outletId": outlet_id, "items": [{"name": "rice", "qty": 1.0}]},
        )
        bad_outlet = await client.post(
            "/api/voice-agent/stock/in",
            headers=_auth_headers(),
            json={"conversationId": "stock-5", "outletId": "nope", "items": [{"name": "rice", "qty": 1.0}]},
        )
        no_items = await client.post(
            "/api/voice-agent/stock/in",
            headers=_auth_headers(),
            json={"conversationId": "stock-6", "outletId": outlet_id, "items": []},
        )

    assert no_secret.status_code == 401
    assert bad_outlet.status_code == 404
    assert no_items.status_code == 422


@pytest.mark.asyncio(loop_scope="session")
async def test_stock_count_upserts_today_and_overwrites_quantity():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = await _bootstrap(client)
        outlet_id = data["outletId"]
        prefix = f"t-{outlet_id[:8]}"
        async with AsyncSessionLocal() as db:
            _seed_inventory(db, id=f"{prefix}-oil", outlet=outlet_id, name="Oil", qty=25.0, unit="ltr")
            await db.commit()

        first = await client.post(
            "/api/voice-agent/stock/count",
            headers=_auth_headers(),
            json={
                "conversationId": "count-1",
                "outletId": outlet_id,
                "items": [{"name": "oil", "qty": 18.0}],
            },
        )
        second = await client.post(
            "/api/voice-agent/stock/count",
            headers=_auth_headers(),
            json={
                "conversationId": "count-2",
                "outletId": outlet_id,
                "items": [{"name": "Oil", "qty": 17.5}],
            },
        )

    assert first.status_code == 200
    assert second.status_code == 200
    first_line = first.json()["data"]["items"][0]
    second_line = second.json()["data"]["items"][0]
    assert first_line["quantity"] == 18.0
    assert second_line["quantity"] == 17.5
    assert first_line["countDate"] == _today_bdt()
    assert second_line["countDate"] == _today_bdt()

    async with AsyncSessionLocal() as db:
        item = await db.get(InventoryItem, f"{prefix}-oil")
        assert float(item.quantity) == 17.5
        counts = (
            await db.execute(
                select(DailyStockCount).where(DailyStockCount.inventory_item_id == f"{prefix}-oil")
            )
        ).scalars().all()
        assert len(counts) == 1
        assert counts[0].count_date == _today_bdt()
        assert float(counts[0].quantity) == 17.5


@pytest.mark.asyncio(loop_scope="session")
async def test_stock_count_honors_explicit_date():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = await _bootstrap(client)
        outlet_id = data["outletId"]
        prefix = f"t-{outlet_id[:8]}"
        async with AsyncSessionLocal() as db:
            _seed_inventory(db, id=f"{prefix}-sugar", outlet=outlet_id, name="Sugar", qty=9.0, unit="kg")
            await db.commit()

        resp = await client.post(
            "/api/voice-agent/stock/count",
            headers=_auth_headers(),
            json={
                "conversationId": "count-3",
                "outletId": outlet_id,
                "countDate": "2026-08-10",
                "items": [{"name": "sugar", "qty": 5.0}],
            },
        )
        bad_date = await client.post(
            "/api/voice-agent/stock/count",
            headers=_auth_headers(),
            json={
                "conversationId": "count-4",
                "outletId": outlet_id,
                "countDate": "not-a-date",
                "items": [{"name": "sugar", "qty": 5.0}],
            },
        )

    assert resp.status_code == 200
    assert resp.json()["data"]["items"][0]["countDate"] == "2026-08-10"
    assert bad_date.status_code == 400

    async with AsyncSessionLocal() as db:
        counts = (
            await db.execute(
                select(DailyStockCount).where(DailyStockCount.inventory_item_id == f"{prefix}-sugar")
            )
        ).scalars().all()
        assert len(counts) == 1
        assert counts[0].count_date == "2026-08-10"


@pytest.mark.asyncio(loop_scope="session")
async def test_stock_count_unknown_item_reports_line_error():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = await _bootstrap(client)
        outlet_id = data["outletId"]
        prefix = f"t-{outlet_id[:8]}"
        async with AsyncSessionLocal() as db:
            _seed_inventory(db, id=f"{prefix}-salt", outlet=outlet_id, name="Salt", qty=3.0)
            await db.commit()

        resp = await client.post(
            "/api/voice-agent/stock/count",
            headers=_auth_headers(),
            json={
                "conversationId": "count-5",
                "outletId": outlet_id,
                "items": [{"name": "turmeric", "qty": 2.0}],
            },
        )

    assert resp.status_code == 200
    body = resp.json()["data"]
    assert body["okCount"] == 0
    assert body["errorCount"] == 1
    assert "not found" in body["items"][0]["error"]

    async with AsyncSessionLocal() as db:
        item = await db.get(InventoryItem, f"{prefix}-salt")
        assert float(item.quantity) == 3.0
        created = (
            await db.execute(
                select(InventoryItem).where(
                    InventoryItem.outlet_id == outlet_id,
                    InventoryItem.name == "turmeric",
                )
            )
        ).scalar_one_or_none()
        assert created is None


@pytest.mark.asyncio(loop_scope="session")
async def test_stock_items_creates_when_missing():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = await _bootstrap(client)
        outlet_id = data["outletId"]

        resp = await client.post(
            "/api/voice-agent/stock/items",
            headers=_auth_headers(),
            json={
                "conversationId": "item-1",
                "outletId": outlet_id,
                "name": "Potato",
                "unit": "kg",
                "qty": 20.0,
                "category": "raw",
                "minThreshold": 5.0,
                "costPerUnitBdt": 45.0,
            },
        )

    assert resp.status_code == 200
    body = resp.json()["data"]
    assert body["created"] is True
    assert body["name"] == "Potato"
    assert body["quantity"] == 20.0
    assert body["unit"] == "kg"
    assert body["category"] == "raw"
    assert body["minThreshold"] == 5.0

    async with AsyncSessionLocal() as db:
        item = (
            await db.execute(
                select(InventoryItem).where(
                    InventoryItem.outlet_id == outlet_id,
                    InventoryItem.name == "Potato",
                )
            )
        ).scalar_one_or_none()
        assert item is not None
        assert float(item.quantity) == 20.0
        assert float(item.cost_per_unit) == 45.0


@pytest.mark.asyncio(loop_scope="session")
async def test_stock_items_returns_existing_without_duplicate():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = await _bootstrap(client)
        outlet_id = data["outletId"]
        prefix = f"t-{outlet_id[:8]}"
        async with AsyncSessionLocal() as db:
            _seed_inventory(db, id=f"{prefix}-potato", outlet=outlet_id, name="Potato", qty=7.0)
            await db.commit()

        resp = await client.post(
            "/api/voice-agent/stock/items",
            headers=_auth_headers(),
            json={"conversationId": "item-2", "outletId": outlet_id, "name": "potato"},
        )

    assert resp.status_code == 200
    body = resp.json()["data"]
    assert body["created"] is False
    assert body["itemId"] == f"{prefix}-potato"
    assert body["quantity"] == 7.0

    async with AsyncSessionLocal() as db:
        rows = (
            await db.execute(
                select(InventoryItem).where(
                    InventoryItem.outlet_id == outlet_id,
                    InventoryItem.name == "Potato",
                )
            )
        ).scalars().all()
        assert len(rows) == 1


@pytest.mark.asyncio(loop_scope="session")
async def test_stock_name_matching_handles_bengali_aliases():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = await _bootstrap(client)
        outlet_id = data["outletId"]
        prefix = f"t-{outlet_id[:8]}"
        async with AsyncSessionLocal() as db:
            _seed_inventory(db, id=f"{prefix}-atta", outlet=outlet_id, name="আটা", qty=0.0, unit="kg")
            await db.commit()

        resp = await client.post(
            "/api/voice-agent/stock/in",
            headers=_auth_headers(),
            json={
                "conversationId": "stock-7",
                "outletId": outlet_id,
                "items": [{"name": "atta", "qty": 3.0}],
            },
        )

    assert resp.status_code == 200
    body = resp.json()["data"]
    assert body["okCount"] == 1
    line = body["items"][0]
    assert line["matched"] is True
    assert line["itemId"] == f"{prefix}-atta"
    assert line["quantityAfter"] == 3.0


@pytest.mark.asyncio(loop_scope="session")
async def test_stock_name_matching_flags_ambiguous_names():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = await _bootstrap(client)
        outlet_id = data["outletId"]
        prefix = f"t-{outlet_id[:8]}"
        async with AsyncSessionLocal() as db:
            _seed_inventory(db, id=f"{prefix}-beef", outlet=outlet_id, name="Beef", qty=1.0)
            _seed_inventory(db, id=f"{prefix}-beef-bone", outlet=outlet_id, name="Beef Bone", qty=1.0)
            await db.commit()

        resp = await client.post(
            "/api/voice-agent/stock/in",
            headers=_auth_headers(),
            json={
                "conversationId": "stock-8",
                "outletId": outlet_id,
                "items": [{"name": "beef", "qty": 1.0}],
            },
        )

    assert resp.status_code == 200
    body = resp.json()["data"]
    assert body["okCount"] == 0
    assert body["errorCount"] == 1
    assert "Ambiguous" in body["items"][0]["error"]
    assert "Beef" in body["items"][0]["error"]