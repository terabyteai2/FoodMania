"""Unit tests for the read-only business-data tools (support_llm_tools.py).

Handlers are tested against an in-memory SQLite database with the JSONB
columns swapped to plain JSON.
"""

from datetime import datetime, timedelta, timezone

import pytest
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from models import (
    Base,
    InventoryItem,
    MenuItem,
    Order,
    Outlet,
    OutletSubscription,
)
from services import support_llm_tools as tools

TODAY = (datetime.now(timezone.utc) + tools.BDT_OFFSET).date()


def _make_engine():
    for table in (
        Order.__table__,
        MenuItem.__table__,
        InventoryItem.__table__,
        Outlet.__table__,
        OutletSubscription.__table__,
    ):
        for column in table.columns:
            if isinstance(column.type, JSONB):
                column.type = sa.JSON()
    return create_async_engine(
        "sqlite+aiosqlite://",
        poolclass=StaticPool,
        connect_args={"check_same_thread": False},
    )


@pytest.fixture
async def db_session(monkeypatch):
    engine = _make_engine()
    async with engine.begin() as conn:
        await conn.run_sync(
            Base.metadata.create_all,
            tables=[
                Order.__table__,
                MenuItem.__table__,
                InventoryItem.__table__,
                Outlet.__table__,
                OutletSubscription.__table__,
            ],
        )
    TestSession = async_sessionmaker(engine, expire_on_commit=False)
    monkeypatch.setattr("database.AsyncSessionLocal", TestSession)
    yield TestSession
    await engine.dispose()


def _seed_order(
    session,
    *,
    id,
    outlet,
    serial,
    status="completed",
    total=100.0,
    order_date=None,
    created_at=None,
    items=None,
    service_type="dine_in",
    source="pos",
):
    session.add(
        Order(
            id=id,
            outlet_id=outlet,
            serial_number=serial,
            status=status,
            total_amount=total,
            subtotal=total,
            order_date=order_date or TODAY,
            created_at=created_at
            or datetime.now(timezone.utc) - timedelta(hours=1),
            items=items
            or [
                {
                    "menuItemId": f"m-{serial}",
                    "name": f"Item {serial}",
                    "nameEn": f"Item {serial}",
                    "nameBn": f"আইটেম {serial}",
                    "qty": 1,
                    "price": total,
                    "lineTotal": total,
                }
            ],
            service_type=service_type,
            source=source,
        )
    )


def _seed_menu(session, *, id, outlet, name, price=50.0, category="Main",
               category_en="Main", is_available=True, deleted=False):
    session.add(
        MenuItem(
            id=id,
            outlet_id=outlet,
            name=name,
            name_en=name,
            name_bn=name,
            price=price,
            category=category,
            category_en=category_en,
            category_bn=category,
            is_available=is_available,
            deleted_at=datetime.now(timezone.utc) if deleted else None,
        )
    )


def _seed_stock(session, *, id, outlet, name, quantity=10.0, min_threshold=2.0,
                unit="kg", category="veg", deleted=False):
    session.add(
        InventoryItem(
            id=id,
            outlet_id=outlet,
            name=name,
            category=category,
            unit=unit,
            quantity=quantity,
            min_threshold=min_threshold,
            cost_per_unit=5.0,
            deleted_at=datetime.now(timezone.utc) if deleted else None,
        )
    )


async def test_overview_totals_today_only(db_session):
    async with db_session() as session:
        _seed_order(session, id="o1", outlet="outlet-1", serial=1, status="completed", total=500)
        _seed_order(session, id="o2", outlet="outlet-1", serial=2, status="completed", total=250)
        _seed_order(session, id="o3", outlet="outlet-1", serial=3, status="pending", total=100)
        _seed_order(session, id="o4", outlet="outlet-1", serial=4, status="completed", total=999, order_date=TODAY - timedelta(days=1))
        await session.commit()

    result = await tools._overview("outlet-1", {})
    assert result["ok"] is True
    assert result["totalOrders"] == 3
    assert result["completedOrders"] == 2
    assert result["openOrders"] == 1
    assert result["rejectedOrders"] == 0
    assert result["totalSalesBdt"] == 750.0
    assert result["date"] == TODAY.isoformat()


async def test_recent_orders_filters_status_and_caps(db_session):
    async with db_session() as session:
        for serial in range(1, 6):
            status = "completed" if serial % 2 else "pending"
            _seed_order(
                session,
                id=f"o{serial}",
                outlet="outlet-1",
                serial=serial,
                status=status,
                total=100.0 * serial,
            )
        await session.commit()

    capped = await tools._recent_orders("outlet-1", {"days": 7, "status": None, "limit": 2})
    assert capped["ok"] is True
    assert len(capped["orders"]) == 2
    assert capped["truncated"] is True

    completed = await tools._recent_orders("outlet-1", {"days": 7, "status": "completed", "limit": 20})
    assert len(completed["orders"]) == 3
    assert all(o["status"] == "completed" for o in completed["orders"])
    assert completed["truncated"] is False

    bad = await tools._recent_orders("outlet-1", {"days": 7, "status": "nope", "limit": 20})
    assert bad == {"ok": False, "error": "unknown status 'nope'"}


async def test_order_lookup_by_serial_and_id(db_session):
    async with db_session() as session:
        _seed_order(session, id="o1", outlet="outlet-1", serial=42, total=321)
        await session.commit()

    by_serial = await tools._order("outlet-1", {"serial": 42, "orderId": None})
    assert by_serial["ok"] is True
    order = by_serial["order"]
    assert order["serialNumber"] == 42
    assert order["totalAmount"] == 321.0
    assert order["items"][0]["nameEn"] == "Item 42"
    assert order["itemsTruncated"] is False

    by_id = await tools._order("outlet-1", {"serial": None, "orderId": "o1"})
    assert by_id["ok"] is True
    assert by_id["order"]["id"] == "o1"

    missing = await tools._order("outlet-1", {"serial": 999, "orderId": None})
    assert missing == {"ok": False, "error": "order not found"}

    no_args = await tools._order("outlet-1", {"serial": None, "orderId": None})
    assert no_args["ok"] is False


async def test_menu_items_search_category_availability(db_session):
    async with db_session() as session:
        _seed_menu(session, id="m1", outlet="outlet-1", name="Chicken Burger", price=180, category="Burgers")
        _seed_menu(session, id="m2", outlet="outlet-1", name="Beef Burger", price=220, category="Burgers", is_available=False)
        _seed_menu(session, id="m3", outlet="outlet-1", name="Fries", price=90, category="Sides")
        _seed_menu(session, id="m4", outlet="outlet-1", name="Old Pizza", price=300, category="Pizza", deleted=True)
        await session.commit()

    by_query = await tools._menu_items("outlet-1", {"query": "burger", "category": None, "availableOnly": False, "limit": 20})
    assert by_query["count"] == 2

    by_category = await tools._menu_items("outlet-1", {"query": None, "category": "Burgers", "availableOnly": False, "limit": 20})
    assert by_category["count"] == 2

    available = await tools._menu_items("outlet-1", {"query": "burger", "category": None, "availableOnly": True, "limit": 20})
    assert available["count"] == 1
    assert available["items"][0]["id"] == "m1"
    assert available["items"][0]["price"] == 180.0

    deleted_hidden = await tools._menu_items("outlet-1", {"query": "pizza", "category": None, "availableOnly": False, "limit": 20})
    assert deleted_hidden["count"] == 0


async def test_stock_low_stock_and_flags(db_session):
    async with db_session() as session:
        _seed_stock(session, id="s1", outlet="outlet-1", name="Chicken", quantity=0, min_threshold=2)
        _seed_stock(session, id="s2", outlet="outlet-1", name="Rice", quantity=1, min_threshold=5)
        _seed_stock(session, id="s3", outlet="outlet-1", name="Oil", quantity=20, min_threshold=2)
        _seed_stock(session, id="s4", outlet="outlet-1", name="Gone", quantity=3, deleted=True)
        await session.commit()

    low = await tools._stock("outlet-1", {"query": None, "lowStockOnly": True, "limit": 20})
    assert low["count"] == 2
    by_id = {i["id"]: i for i in low["items"]}
    assert by_id["s1"]["isOutOfStock"] is True
    assert by_id["s1"]["isLowStock"] is False
    assert by_id["s2"]["isLowStock"] is True

    by_query = await tools._stock("outlet-1", {"query": "chic", "lowStockOnly": False, "limit": 20})
    assert by_query["count"] == 1
    assert by_query["items"][0]["name"] == "Chicken"

    no_deleted = await tools._stock("outlet-1", {"query": "gone", "lowStockOnly": False, "limit": 20})
    assert no_deleted["count"] == 0


async def test_daily_sales_groups_completed_only(db_session):
    yesterday = TODAY - timedelta(days=1)
    async with db_session() as session:
        _seed_order(session, id="o1", outlet="outlet-1", serial=1, status="completed", total=100, order_date=TODAY)
        _seed_order(session, id="o2", outlet="outlet-1", serial=2, status="completed", total=200, order_date=TODAY)
        _seed_order(session, id="o3", outlet="outlet-1", serial=3, status="completed", total=400, order_date=yesterday)
        _seed_order(session, id="o4", outlet="outlet-1", serial=4, status="pending", total=999, order_date=TODAY)
        _seed_order(session, id="o5", outlet="outlet-1", serial=5, status="served", total=50, order_date=TODAY)
        await session.commit()

    result = await tools._daily_sales("outlet-1", {"days": 7})
    assert result["ok"] is True
    entries = {e["date"]: e for e in result["entries"]}
    assert entries[TODAY.isoformat()]["orders"] == 3  # completed + legacy served
    assert entries[TODAY.isoformat()]["salesBdt"] == 350.0
    assert entries[yesterday.isoformat()]["salesBdt"] == 400.0


async def test_tools_are_outlet_scoped(db_session):
    async with db_session() as session:
        _seed_order(session, id="o1", outlet="outlet-1", serial=1, status="completed", total=100)
        _seed_order(session, id="o2", outlet="outlet-2", serial=1, status="completed", total=9999)
        _seed_menu(session, id="m1", outlet="outlet-1", name="Chicken")
        _seed_menu(session, id="m2", outlet="outlet-2", name="Secret Dish")
        _seed_stock(session, id="s1", outlet="outlet-1", name="Rice", quantity=1)
        _seed_stock(session, id="s2", outlet="outlet-2", name="Gold", quantity=100)
        await session.commit()

    overview = await tools._overview("outlet-1", {})
    assert overview["totalOrders"] == 1
    assert overview["totalSalesBdt"] == 100.0

    orders = await tools._recent_orders("outlet-1", {"days": 7, "status": None, "limit": 20})
    assert all(o["totalAmount"] == 100.0 for o in orders["orders"])

    menu = await tools._menu_items("outlet-1", {"query": None, "category": None, "availableOnly": False, "limit": 20})
    assert menu["count"] == 1
    assert menu["items"][0]["name"] == "Chicken"

    stock = await tools._stock("outlet-1", {"query": None, "lowStockOnly": True, "limit": 20})
    assert stock["count"] == 1
    assert stock["items"][0]["name"] == "Rice"


async def test_execute_tool_validates_and_clamps(db_session):
    unknown = await tools.execute_tool("nope", {}, "outlet-1")
    assert unknown == {"ok": False, "error": "unknown tool 'nope'"}

    async with db_session() as session:
        _seed_order(session, id="o1", outlet="outlet-1", serial=1, status="completed", total=100)
        await session.commit()

    # Clamps: limit 999 -> 50, days -5 -> 1; the int status coerces to "7"
    # which is not a valid status, so the tool reports the error.
    bad_status = await tools.execute_tool(
        "get_recent_orders",
        {"days": -5, "status": 7, "limit": 999},
        "outlet-1",
    )
    assert bad_status == {"ok": False, "error": "unknown status '7'"}

    result = await tools.execute_tool(
        "get_recent_orders",
        {"days": -5, "status": "completed", "limit": 999},
        "outlet-1",
    )
    assert result["ok"] is True
    assert result["days"] == 1
    assert result["status"] == "completed"
    assert len(result["orders"]) <= 50


async def test_validate_arguments_drops_unknown_keys():
    spec = tools.TOOLS["get_stock"]
    cleaned = tools.validate_arguments(
        spec,
        {"lowStockOnly": "yes", "hack": "drop-me", "limit": "not-a-number"},
    )
    assert cleaned == {"query": None, "lowStockOnly": True, "limit": tools.TOOL_RESULT_LIMIT}


def test_tools_schema_covers_every_registered_tool():
    schema = tools.tools_schema()
    assert len(schema) == len(tools.TOOLS)
    names = {tool["type"]: None for tool in schema}
    assert set(schema[i]["type"] for i in range(len(schema))) == {"function"}
    schema_names = {tool["function"]["name"] for tool in schema}
    assert schema_names == set(tools.TOOLS)
    for tool in schema:
        fn = tool["function"]
        assert fn["description"]
        assert isinstance(fn["parameters"], dict)
        assert fn["parameters"]["type"] == "object"
        assert isinstance(fn["parameters"]["properties"], dict)


def test_tools_schema_arg_types_and_defaults():
    schema = {tool["function"]["name"]: tool["function"] for tool in tools.tools_schema()}

    orders = schema["get_recent_orders"]["parameters"]["properties"]
    assert orders["days"] == {"type": "integer", "default": 7, "minimum": 1, "maximum": 90}
    assert orders["limit"] == {
        "type": "integer",
        "default": tools.TOOL_RESULT_LIMIT,
        "minimum": 1,
        "maximum": tools.TOOL_RESULT_MAX,
    }
    assert orders["status"] == {"type": "string"}

    stock = schema["get_stock"]["parameters"]["properties"]
    assert stock["lowStockOnly"] == {"type": "boolean", "default": False}
    assert stock["query"] == {"type": "string"}

    assert schema["get_outlet_info"]["parameters"] == {
        "type": "object",
        "properties": {},
    }


def test_tools_schema_round_trips_through_validate_arguments():
    spec = tools.TOOLS["get_recent_orders"]
    schema = {
        tool["function"]["name"]: tool["function"]["parameters"]
        for tool in tools.tools_schema()
    }["get_recent_orders"]
    model_args = {"days": -5, "status": "completed", "limit": 999}
    cleaned = tools.validate_arguments(spec, model_args)
    assert cleaned["days"] == max(schema["properties"]["days"]["minimum"], model_args["days"])
    assert cleaned["limit"] == min(schema["properties"]["limit"]["maximum"], model_args["limit"])


async def test_get_guide_deeplinks_returns_full_vocabulary():
    result = await tools.execute_tool("get_guide_deeplinks", {}, "outlet-1")
    assert result["ok"] is True
    assert result["version"] == 1
    assert result["kind"] == "all"
    tabs = result["tabs"]
    assert any(t["name"] == "analytics" and t["description"] for t in tabs)
    assert any(t["name"] == "orders" for t in tabs)
    screens = {s["name"] for s in result["screens"]}
    assert {"staff", "audit", "stock_in", "stock_count"} <= screens
    modals = {m["name"] for m in result["modals"]}
    assert {"menu_discounts", "menu_delivery_charge"} <= modals
    spots = {s["name"] for s in result["spots"]}
    assert "orders.newOrderFab" in spots and "header.bell" in spots
    assert result["count"] == (
        len(tabs) + len(screens) + len(modals) + len(spots)
        + len(result["conventions"]) + 1
    )
    assert isinstance(result["conventions"], list) and result["conventions"]


async def test_get_guide_deeplinks_filters_by_kind():
    tabs = await tools.execute_tool("get_guide_deeplinks", {"kind": "tabs"}, "outlet-1")
    assert tabs["ok"] is True
    assert set(tabs.keys()) == {"ok", "version", "kind", "count", "tabs"}
    assert tabs["count"] == len(tabs["tabs"])

    bad = await tools.execute_tool("get_guide_deeplinks", {"kind": "bogus"}, "outlet-1")
    assert bad["ok"] is False


def test_guide_vocabulary_matches_validator_sets():
    from services import support_llm

    tab_names = {t["name"] for t in tools.GUIDE_VOCABULARY["tabs"]}
    screen_names = {s["name"] for s in tools.GUIDE_VOCABULARY["screens"]}
    modal_names = {m["name"] for m in tools.GUIDE_VOCABULARY["modals"]}
    spot_names = {s["name"] for s in tools.GUIDE_VOCABULARY["spots"]}
    assert tab_names == support_llm._TAB_TARGETS
    assert screen_names == support_llm._SCREEN_TARGETS
    assert modal_names == support_llm._MODAL_TARGETS
    assert spot_names == support_llm._STATIC_SPOTS


async def test_get_outlet_info_reads_name_plan_and_tables(db_session):
    """Regression: lazy ``Outlet.subscription`` access must be eager-loaded
    inside async tool execution (MissingGreenlet otherwise)."""
    async with db_session() as session:
        session.add(
            Outlet(
                id="outlet-info-1",
                restaurant_id="rest-info-1",
                name="Greenlet Cafe",
                server_id="SRV-INFO-1",
                table_count=7,
            )
        )
        session.add(
            Outlet(
                id="outlet-info-2",
                restaurant_id="rest-info-1",
                name="Lone Cafe",
                server_id="SRV-INFO-2",
                table_count=3,
            )
        )
        session.add(OutletSubscription(outlet_id="outlet-info-1", plan="pro"))
        await session.commit()

    with_sub = await tools.execute_tool("get_outlet_info", {}, "outlet-info-1")
    assert with_sub == {
        "ok": True,
        "name": "Greenlet Cafe",
        "plan": "pro",
        "tableCount": 7,
    }
    without_sub = await tools.execute_tool("get_outlet_info", {}, "outlet-info-2")
    assert without_sub == {
        "ok": True,
        "name": "Lone Cafe",
        "plan": "trial",
        "tableCount": 3,
    }
    missing = await tools.execute_tool("get_outlet_info", {}, "outlet-info-999")
    assert missing == {"ok": False, "error": "outlet not found"}
