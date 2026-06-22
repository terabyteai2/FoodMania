from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_outlet_id
from database import get_db
from models import AdminAccount, InventoryItem, MenuItem, Order, Outlet, StockAdjustment
from routers.menu import _ensure_outlet
from schemas import ok

router = APIRouter()

# Restaurants run on Bangladesh local time (UTC+6) — pick the day boundary in
# that zone so "today" matches what an owner sees on a wall clock.
BDT_OFFSET = timedelta(hours=6)
LATE_ORDER_MIN = 20
OPEN_STATUSES = {"pending", "accepted", "preparing", "ready"}
KITCHEN_STATUSES = {"accepted", "preparing"}
REJECTED_STATUSES = {"cancelled", "rejected"}

# Review tab revenue-by-hour chart axis: 15 hourly buckets covering 9:00–23:00
# (a restaurant service day). Orders outside the window fold into the nearest end.
REVIEW_START_HOUR = 9
REVIEW_BUCKETS = 15
# Food-cost % above this flags an item as low-margin ("margin kom") in the UI.
HIGH_FOOD_COST_PCT = 38.0


def _is_rejected_status(value: str | None) -> bool:
    return (value or "").strip().lower() in REJECTED_STATUSES


def _bdt_day_bounds(reference: datetime) -> tuple[datetime, datetime]:
    """Return [start, end) in UTC for the local Dhaka day containing `reference`."""
    local = reference.astimezone(timezone(BDT_OFFSET))
    start_local = local.replace(hour=0, minute=0, second=0, microsecond=0)
    start_utc = (start_local - BDT_OFFSET).replace(tzinfo=timezone.utc)
    end_utc = start_utc + timedelta(days=1)
    return start_utc, end_utc


def _parse_as_of(value: str | None) -> datetime:
    if not value:
        return datetime.now(timezone.utc)
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid as_of timestamp.",
        ) from exc
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def _table_no_from_notes(notes: str | None) -> str | None:
    if not notes:
        return None
    text = notes.strip()
    if not text.lower().startswith("table "):
        return None
    tail = text[len("table ") :].strip()
    return tail.split()[0] if tail else None


def _line_items(order_items: Any) -> list[dict[str, Any]]:
    if isinstance(order_items, list):
        return [item for item in order_items if isinstance(item, dict)]
    return []


def _item_revenue(item: dict[str, Any]) -> float:
    total = item.get("lineTotal")
    if isinstance(total, (int, float)):
        return float(total)
    qty = item.get("qty") or 0
    price = item.get("price") or 0
    try:
        return float(qty) * float(price)
    except (TypeError, ValueError):
        return 0.0


def _item_qty(item: dict[str, Any]) -> int:
    qty = item.get("qty")
    if isinstance(qty, (int, float)):
        return int(qty)
    return 0


def _safe_div(numer: float, denom: float) -> float:
    if denom <= 0:
        return 0.0
    return numer / denom


def _delta_pct(today: float, yesterday: float) -> float:
    if yesterday <= 0:
        return 0.0 if today <= 0 else 100.0
    return round(((today - yesterday) / yesterday) * 100.0, 1)


def _format_minutes_ago(start: datetime, now: datetime) -> int:
    delta = now - start
    minutes = int(delta.total_seconds() // 60)
    return max(0, minutes)


def _strongest_note(today: float, weekday: int, history: list[float]) -> str:
    """Tiny human-readable note next to the delta. history is last 7 days (oldest first)."""
    if not history or today <= 0:
        return ""
    weekday_names = [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday",
    ]
    matching = [history[i] for i in range(len(history)) if (i - len(history) + 1 + weekday) % 7 == 0]
    if not matching:
        return ""
    best = max(matching)
    if today >= best and best > 0:
        return f"strongest {weekday_names[weekday]} in {len(matching)} weeks"
    return ""


# ── Review-tab helpers ────────────────────────────────────────────────────────


def _bdt_local(value: datetime) -> datetime:
    return value.astimezone(timezone(BDT_OFFSET))


def _hour_bucket(local_dt: datetime) -> int:
    return max(0, min(REVIEW_BUCKETS - 1, local_dt.hour - REVIEW_START_HOUR))


def _peak_label(today_buckets: list[float]) -> tuple[int, str]:
    if not any(today_buckets):
        return 0, ""
    idx = max(range(len(today_buckets)), key=lambda i: today_buckets[i])
    hour = REVIEW_START_HOUR + idx
    suffix = "AM" if hour < 12 else "PM"
    h12 = hour % 12 or 12
    return idx, f"{h12}:00 {suffix} · ৳{int(round(today_buckets[idx])):,}"


def _revenue_by_hour(today_orders: list[Order], week_orders: list[Order]) -> dict[str, Any]:
    """Today's revenue per hour bucket plus the 7-day average (ghost series)."""
    today = [0.0] * REVIEW_BUCKETS
    week = [0.0] * REVIEW_BUCKETS
    for order in today_orders:
        today[_hour_bucket(_bdt_local(order.created_at))] += float(order.total_amount or 0)
    for order in week_orders:
        if _is_rejected_status(order.status):
            continue
        week[_hour_bucket(_bdt_local(order.created_at))] += float(order.total_amount or 0)
    today = [round(v, 2) for v in today]
    avg7 = [round(v / 7.0, 2) for v in week]
    peak_index, peak_label = _peak_label(today)
    return {
        "startHour": REVIEW_START_HOUR,
        "today": today,
        "avg7": avg7,
        "peakIndex": peak_index,
        "peakLabel": peak_label,
    }


def _source_key(method: str | None) -> str:
    raw = (method or "").strip().lower()
    if raw in {"card", "credit", "debit", "visa", "mastercard"}:
        return "card"
    if raw in {"", "cash"}:
        return "cash"
    return "online"  # bkash / nagad / rocket / online / etc.


def _by_source(today_orders: list[Order]) -> list[dict[str, Any]]:
    totals: dict[str, float] = defaultdict(float)
    for order in today_orders:
        totals[_source_key(order.payment_method)] += float(order.total_amount or 0)
    grand = sum(totals.values())
    rows: list[dict[str, Any]] = []
    for key, label in (("cash", "Cash"), ("card", "Card"), ("online", "Online")):
        value = totals.get(key, 0.0)
        rows.append(
            {
                "key": key,
                "label": label,
                "valueBdt": round(value, 2),
                "pct": round(_safe_div(value, grand) * 100.0) if grand > 0 else 0,
            }
        )
    return rows


def _service_key(service_type: str | None) -> str:
    raw = (service_type or "").strip().lower()
    if raw in {"takeaway", "parcel"}:
        return "takeaway"
    if raw == "delivery":
        return "delivery"
    return "dineIn"


def _service_mix(today_orders: list[Order]) -> list[dict[str, Any]]:
    totals: dict[str, float] = defaultdict(float)
    for order in today_orders:
        totals[_service_key(order.service_type)] += float(order.total_amount or 0)
    grand = sum(totals.values())
    return [
        {
            "key": key,
            "label": label,
            "valueBdt": round(totals.get(key, 0.0), 2),
            "pct": round(_safe_div(totals.get(key, 0.0), grand) * 100.0) if grand > 0 else 0,
        }
        for key, label in (
            ("dineIn", "Dine-in"),
            ("takeaway", "Takeaway"),
            ("delivery", "Delivery"),
        )
    ]


def _floor_tables(open_orders: list[Order], table_count: int) -> list[dict[str, Any]]:
    by_table: dict[str, list[Order]] = defaultdict(list)
    for order in open_orders:
        table = _table_no(order)
        if table:
            by_table[table].append(order)

    rows: list[dict[str, Any]] = []
    for number in range(1, table_count + 1):
        table = str(number)
        orders = by_table.get(table, [])
        bill_order = next((order for order in orders if order.status == "ready"), None)
        active_order = bill_order or (orders[0] if orders else None)
        rows.append(
            {
                "tableNo": table,
                "state": "bill" if bill_order else ("seated" if orders else "idle"),
                "covers": sum(int(order.covers or 0) for order in orders),
                "orderId": active_order.id if active_order else None,
            }
        )
    return rows


def _items_sold(
    mover_qty: dict[str, int],
    mover_sales: dict[str, float],
    mover_name: dict[str, str],
    menu_lookup: dict[str, MenuItem],
    limit: int = 6,
) -> tuple[list[dict[str, Any]], float | None]:
    """Per-item revenue with margin/food-cost when MenuItem.cost_price is set.

    Returns (items, foodCostPct). foodCostPct is None when no sold item has a
    cost price, so the UI can render a neutral state instead of a fake 0%.
    """
    items: list[dict[str, Any]] = []
    cost_known = 0.0
    rev_known = 0.0
    for menu_item_id, sales in sorted(mover_sales.items(), key=lambda kv: kv[1], reverse=True):
        row = menu_lookup.get(menu_item_id)
        qty = mover_qty.get(menu_item_id, 0)
        cost_price = float(row.cost_price) if (row and row.cost_price is not None) else None
        if cost_price is not None and sales > 0:
            cost = cost_price * qty
            margin_bdt: float | None = round(sales - cost, 2)
            food_cost_pct: float | None = round(_safe_div(cost, sales) * 100.0, 1)
            cost_known += cost
            rev_known += sales
        else:
            margin_bdt = None
            food_cost_pct = None
        items.append(
            {
                "menuItemId": menu_item_id,
                "nameEn": (row.name_en if row and row.name_en else None)
                or mover_name.get(menu_item_id, ""),
                "nameBn": (row.name_bn if row and row.name_bn else None) or "",
                "qty": qty,
                "salesBdt": round(sales, 2),
                "marginBdt": margin_bdt,
                "foodCostPct": food_cost_pct,
                "lowMargin": bool(food_cost_pct is not None and food_cost_pct > HIGH_FOOD_COST_PCT),
            }
        )
    food_cost_pct = round(_safe_div(cost_known, rev_known) * 100.0, 1) if rev_known > 0 else None
    return items[:limit], food_cost_pct


def _aggregate_items(orders: list[Order]) -> tuple[dict[str, int], dict[str, float], dict[str, str]]:
    qty: dict[str, int] = defaultdict(int)
    sales: dict[str, float] = defaultdict(float)
    name: dict[str, str] = {}
    for order in orders:
        for line in _line_items(order.items):
            menu_item_id = str(line.get("menuItemId") or "").strip()
            if not menu_item_id:
                continue
            qty[menu_item_id] += _item_qty(line)
            sales[menu_item_id] += _item_revenue(line)
            name.setdefault(menu_item_id, str(line.get("name") or "").strip())
    return qty, sales, name


def _table_no(order: Order) -> str | None:
    if order.table_no:
        return str(order.table_no).strip() or None
    return _table_no_from_notes(order.notes)


async def _staff_scoreboard(today_orders: list[Order], db: AsyncSession) -> list[dict[str, Any]]:
    by_acct: dict[str, dict[str, float]] = defaultdict(lambda: {"rev": 0.0, "covers": 0, "orders": 0})
    for order in today_orders:
        account_id = order.created_by_account_id
        if not account_id:
            continue
        entry = by_acct[account_id]
        entry["rev"] += float(order.total_amount or 0)
        entry["covers"] += int(order.covers or 0)
        entry["orders"] += 1
    if not by_acct:
        return []
    rows = (
        await db.execute(
            select(AdminAccount).where(AdminAccount.id.in_(list(by_acct.keys())))
        )
    ).scalars().all()
    names = {row.id: (row.display_name or row.username or "Staff") for row in rows}
    roles = {row.id: (row.role or "staff").title() for row in rows}
    scoreboard = [
        {
            "accountId": account_id,
            "name": names.get(account_id, "Staff"),
            "role": roles.get(account_id, "Staff"),
            "covers": int(entry["covers"]),
            "ordersToday": int(entry["orders"]),
            "avgTicketBdt": round(_safe_div(entry["rev"], entry["orders"]), 2),
        }
        for account_id, entry in by_acct.items()
    ]
    scoreboard.sort(key=lambda r: (r["covers"], r["avgTicketBdt"]), reverse=True)
    return scoreboard


async def _build_fleet(
    db: AsyncSession,
    outlet: Outlet,
    now: datetime,
    today_start: datetime,
    today_end: datetime,
    yesterday_start: datetime,
    yesterday_end: datetime,
    week_start: datetime,
) -> dict[str, Any]:
    """Cross-outlet aggregation for the Enterprise review screen.

    Aggregates every outlet sharing this outlet's restaurant_id. A single-outlet
    restaurant returns a one-row fleet so the screen still renders.
    """
    siblings = (
        await db.execute(select(Outlet).where(Outlet.restaurant_id == outlet.restaurant_id))
    ).scalars().all()
    if not siblings:
        siblings = [outlet]
    sib_ids = [o.id for o in siblings]

    week_orders = (
        await db.execute(
            select(Order)
            .where(Order.outlet_id.in_(sib_ids))
            .where(Order.created_at >= week_start - timedelta(days=1))
            .where(Order.created_at < today_end)
        )
    ).scalars().all()
    open_orders = (
        await db.execute(
            select(Order)
            .where(Order.outlet_id.in_(sib_ids))
            .where(Order.status.in_(list(OPEN_STATUSES)))
        )
    ).scalars().all()
    chart_week_orders = [order for order in week_orders if order.created_at >= week_start]
    inventory_items = (
        await db.execute(
            select(InventoryItem)
            .where(InventoryItem.outlet_id.in_(sib_ids))
            .where(InventoryItem.deleted_at.is_(None))
        )
    ).scalars().all()

    today_by_outlet: dict[str, list[Order]] = defaultdict(list)
    rev_today: dict[str, float] = defaultdict(float)
    rev_yesterday: dict[str, float] = defaultdict(float)
    covers_by_outlet: dict[str, int] = defaultdict(int)
    for order in week_orders:
        if _is_rejected_status(order.status):
            continue
        if today_start <= order.created_at < today_end:
            today_by_outlet[order.outlet_id].append(order)
            rev_today[order.outlet_id] += float(order.total_amount or 0)
            covers_by_outlet[order.outlet_id] += int(order.covers or 0)
        elif yesterday_start <= order.created_at < yesterday_end:
            rev_yesterday[order.outlet_id] += float(order.total_amount or 0)

    late_threshold = now - timedelta(minutes=LATE_ORDER_MIN)
    late_by_outlet: dict[str, int] = defaultdict(int)
    seated_by_outlet: dict[str, set[str]] = defaultdict(set)
    open_by_outlet: dict[str, list[Order]] = defaultdict(list)
    for order in open_orders:
        if _is_rejected_status(order.status):
            continue
        table = _table_no(order)
        if table:
            seated_by_outlet[order.outlet_id].add(table)
        open_by_outlet[order.outlet_id].append(order)
        if order.status == "pending" and order.created_at < late_threshold:
            late_by_outlet[order.outlet_id] += 1

    # Menu cost lookup across the fleet (for fleet food-cost % + top movers).
    all_today = [o for orders in today_by_outlet.values() for o in orders]
    fleet_qty, fleet_sales, fleet_name = _aggregate_items(all_today)
    menu_lookup: dict[str, MenuItem] = {}
    if fleet_qty:
        rows = (
            await db.execute(
                select(MenuItem)
                .where(MenuItem.outlet_id.in_(sib_ids))
                .where(MenuItem.id.in_(list(fleet_qty.keys())))
            )
        ).scalars().all()
        menu_lookup = {row.id: row for row in rows}

    outlets: list[dict[str, Any]] = []
    for o in siblings:
        items_for_outlet = today_by_outlet.get(o.id, [])
        oq, osales, _ = _aggregate_items(items_for_outlet)
        _, food_cost_pct = _items_sold(oq, osales, {}, menu_lookup, limit=0)
        order_count = len(items_for_outlet)
        late = late_by_outlet.get(o.id, 0)
        late_rate = round(_safe_div(late, order_count) * 100.0) if order_count else 0
        occupancy_pct = (
            round(_safe_div(len(seated_by_outlet.get(o.id, set())), int(o.table_count or 0)) * 100.0)
            if int(o.table_count or 0) > 0
            else 0
        )
        delta = _delta_pct(rev_today.get(o.id, 0.0), rev_yesterday.get(o.id, 0.0))
        health: list[dict[str, Any]] = []
        if late > 0:
            health.append({"tone": "late", "label": "LATE", "value": f"{late_rate}%"})
        outlets.append(
            {
                "outletId": o.id,
                "name": o.name,
                "area": o.notes or "",
                "revBdt": round(rev_today.get(o.id, 0.0), 2),
                "covers": covers_by_outlet.get(o.id, 0),
                "deltaPct": abs(delta),
                "deltaUp": delta >= 0,
                "foodCostPct": food_cost_pct,
                "tablesSeated": len(seated_by_outlet.get(o.id, set())),
                "tablesTotal": int(o.table_count or 0),
                "occupancyPct": occupancy_pct,
                "latePct": late_rate,
                "openOrders": len(open_by_outlet.get(o.id, [])),
                "sparkline": _revenue_by_hour(items_for_outlet, chart_week_orders)["today"],
                "health": health,
            }
        )
    outlets.sort(key=lambda r: r["revBdt"], reverse=True)
    for rank, row in enumerate(outlets, start=1):
        row["rank"] = rank

    capacity = [
        {
            "name": row["name"],
            "pct": round(_safe_div(row["tablesSeated"], row["tablesTotal"]) * 100.0)
            if row["tablesTotal"] > 0
            else 0,
            "status": "",
        }
        for row in outlets[:3]
    ]
    for cap in capacity:
        pct = cap["pct"]
        cap["status"] = "Full" if pct >= 85 else ("Busy" if pct >= 60 else "Steady")

    fleet_rev = sum(rev_today.values())
    fleet_orders = sum(len(v) for v in today_by_outlet.values())
    fleet_covers = sum(covers_by_outlet.values())
    on_goal = sum(1 for row in outlets if row["deltaUp"])
    fleet_delta = _delta_pct(fleet_rev, sum(rev_yesterday.values()))
    fleet_avg7 = round(
        sum(
            float(order.total_amount or 0)
            for order in week_orders
            if not _is_rejected_status(order.status) and order.created_at < today_start
        )
        / 7.0,
        2,
    )
    top_movers, fleet_food_cost = _items_sold(fleet_qty, fleet_sales, fleet_name, menu_lookup, limit=5)
    goal_bdt = fleet_avg7
    goal_pct = round(_safe_div(fleet_rev, goal_bdt) * 100.0) if goal_bdt > 0 else 0
    fleet_late = sum(late_by_outlet.values())
    fleet_late_pct = round(_safe_div(fleet_late, fleet_orders) * 100.0) if fleet_orders else 0
    low_by_outlet: dict[str, int] = defaultdict(int)
    for item in inventory_items:
        if float(item.quantity or 0) <= float(item.min_threshold or 0):
            low_by_outlet[item.outlet_id] += 1
    alerts: list[dict[str, Any]] = []
    for row in outlets:
        if row["occupancyPct"] >= 85:
            alerts.append({"kind": "capacity", "title": f'{row["name"]} is full', "body": f'{row["occupancyPct"]}% occupancy'})
        if row["latePct"] > 0:
            alerts.append({"kind": "stuck", "title": f'{row["name"]} kitchen needs attention', "body": f'{row["latePct"]}% of orders late'})
        low_count = low_by_outlet.get(row["outletId"], 0)
        if low_count:
            alerts.append({"kind": "low", "title": f'{row["name"]} inventory is low', "body": f'{low_count} items at or below threshold'})
    best_ticket = max(outlets, key=lambda row: _safe_div(row["revBdt"], len(today_by_outlet.get(row["outletId"], []))), default=None)
    worst_late = max(outlets, key=lambda row: row["latePct"], default=None)
    fleet_hourly = _revenue_by_hour(all_today, chart_week_orders)
    pressure = max(
        (row for row in outlets if row["latePct"] > 0 or row["occupancyPct"] >= 60),
        key=lambda row: (row["latePct"], row["occupancyPct"]),
        default=None,
    )

    return {
        "outlets": outlets,
        "kpis": {
            "outletCount": len(siblings),
            "revBdt": round(fleet_rev, 2),
            "deltaPct": abs(fleet_delta),
            "deltaUp": fleet_delta >= 0,
            "avg7Bdt": fleet_avg7,
            "covers": fleet_covers,
            "avgTicketBdt": round(_safe_div(fleet_rev, fleet_orders), 2),
            "foodCostPct": fleet_food_cost,
            "onGoalCount": on_goal,
            "fleetLatePct": fleet_late_pct,
        },
        "goal": {
            "targetBdt": goal_bdt,
            "progressPct": goal_pct,
            "remainingBdt": round(max(0.0, goal_bdt - fleet_rev), 2),
        },
        "alerts": alerts[:6],
        "benchmarks": {
            "bestAvgTicketOutlet": best_ticket["name"] if best_ticket else "",
            "worstLateOutlet": worst_late["name"] if worst_late and worst_late["latePct"] > 0 else "",
        },
        "staffingSuggestion": {
            "outletName": pressure["name"] if pressure else "",
            "peakLabel": fleet_hourly["peakLabel"],
        },
        "openOutlets": [row["name"] for row in outlets if row["openOrders"] > 0],
        "revenueByHour": fleet_hourly,
        "capacity": capacity,
        "topMovers": top_movers,
    }


@router.get("/outlets/{outlet_id}/dashboard/summary")
async def dashboard_summary(
    outlet_id: str,
    as_of: str | None = None,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
    now = _parse_as_of(as_of)
    today_start, today_end = _bdt_day_bounds(now)
    yesterday_start, yesterday_end = _bdt_day_bounds(now - timedelta(days=1))
    week_start = today_start - timedelta(days=6)

    outlet = (
        await db.execute(select(Outlet).where(Outlet.id == outlet_id))
    ).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Outlet not found."
        )

    week_orders = (
        await db.execute(
            select(Order)
            .where(Order.outlet_id == outlet_id)
            .where(Order.created_at >= week_start)
            .where(Order.created_at < today_end)
        )
    ).scalars().all()

    open_orders_query = (
        await db.execute(
            select(Order)
            .where(Order.outlet_id == outlet_id)
            .where(Order.status.in_(list(OPEN_STATUSES)))
        )
    ).scalars().all()

    inventory_items = (
        await db.execute(
            select(InventoryItem)
            .where(InventoryItem.outlet_id == outlet_id)
            .where(InventoryItem.deleted_at.is_(None))
        )
    ).scalars().all()

    today_adjustments = (
        await db.execute(
            select(StockAdjustment)
            .where(StockAdjustment.outlet_id == outlet_id)
            .where(StockAdjustment.created_at >= today_start)
            .where(StockAdjustment.created_at < today_end)
        )
    ).scalars().all()

    # ── Money first ───────────────────────────────────────────────────────────
    daily_totals: dict[str, float] = defaultdict(float)
    daily_counts: dict[str, int] = defaultdict(int)
    for order in week_orders:
        if _is_rejected_status(order.status):
            continue
        local_day = (order.created_at.astimezone(timezone.utc) + BDT_OFFSET).date().isoformat()
        daily_totals[local_day] += float(order.total_amount or 0)
        daily_counts[local_day] += 1

    today_key = (today_start + BDT_OFFSET).date().isoformat()
    yesterday_key = (yesterday_start + BDT_OFFSET).date().isoformat()
    earned_today = daily_totals.get(today_key, 0.0)
    earned_yesterday = daily_totals.get(yesterday_key, 0.0)
    delta_pct = _delta_pct(earned_today, earned_yesterday)

    sparkline: list[float] = []
    for i in range(7):
        day_start = today_start - timedelta(days=6 - i)
        day_key = (day_start + BDT_OFFSET).date().isoformat()
        sparkline.append(round(daily_totals.get(day_key, 0.0) / 1000.0, 2))

    today_local_weekday = (today_start + BDT_OFFSET).weekday()
    history_for_note = [daily_totals.get(
        ((today_start - timedelta(days=6 - i)) + BDT_OFFSET).date().isoformat(),
        0.0,
    ) for i in range(7)]
    delta_note = _strongest_note(earned_today, today_local_weekday, history_for_note)

    today_orders = [
        order for order in week_orders
        if today_start <= order.created_at < today_end
        and not _is_rejected_status(order.status)
    ]
    order_count_today = len(today_orders)
    avg_ticket = _safe_div(earned_today, float(order_count_today))

    today_cost = sum(
        float(adj.total_cost_bdt or 0)
        for adj in today_adjustments
        if (adj.type or "").lower() == "restock"
    )
    profit_pct = round(_safe_div(earned_today - today_cost, earned_today) * 100.0, 1)

    open_orders_count = len(
        [o for o in open_orders_query if not _is_rejected_status(o.status)]
    )

    # Top movers — aggregate today's line items by menuItemId
    mover_qty: dict[str, int] = defaultdict(int)
    mover_sales: dict[str, float] = defaultdict(float)
    mover_name: dict[str, str] = {}
    for order in today_orders:
        for line in _line_items(order.items):
            menu_item_id = str(line.get("menuItemId") or "").strip()
            if not menu_item_id:
                continue
            mover_qty[menu_item_id] += _item_qty(line)
            mover_sales[menu_item_id] += _item_revenue(line)
            if menu_item_id not in mover_name:
                mover_name[menu_item_id] = str(line.get("name") or "").strip()

    menu_lookup: dict[str, MenuItem] = {}
    if mover_qty:
        menu_rows = (
            await db.execute(
                select(MenuItem)
                .where(MenuItem.outlet_id == outlet_id)
                .where(MenuItem.id.in_(list(mover_qty.keys())))
            )
        ).scalars().all()
        menu_lookup = {row.id: row for row in menu_rows}

    sorted_movers = sorted(mover_sales.items(), key=lambda kv: kv[1], reverse=True)[:5]
    leader_sales = sorted_movers[0][1] if sorted_movers else 0.0
    top_movers: list[dict[str, Any]] = []
    for menu_item_id, sales in sorted_movers:
        menu_row = menu_lookup.get(menu_item_id)
        top_movers.append(
            {
                "menuItemId": menu_item_id,
                "nameEn": (menu_row.name_en if menu_row and menu_row.name_en else None)
                or mover_name.get(menu_item_id, ""),
                "nameBn": (menu_row.name_bn if menu_row and menu_row.name_bn else None) or "",
                "qty": mover_qty.get(menu_item_id, 0),
                "salesBdt": round(sales, 2),
                "sharePct": round(_safe_div(sales, leader_sales), 3),
            }
        )

    money_first = {
        "earnedToday": round(earned_today, 2),
        "earnedYesterday": round(earned_yesterday, 2),
        "deltaPct": delta_pct,
        "deltaNote": delta_note,
        "sparkline": sparkline,
        "kpis": {
            "orders": order_count_today,
            "openOrders": open_orders_count,
            "avgTicket": round(avg_ticket, 2),
            "profitPct": profit_pct,
        },
        "topMovers": top_movers,
        "serviceMix": _service_mix(today_orders),
        "closeTodayHintBdt": round(earned_today, 2),
    }

    # ── Right now ─────────────────────────────────────────────────────────────
    seated_tables: set[str] = set()
    in_kitchen = 0
    late_count = 0
    late_threshold = now - timedelta(minutes=LATE_ORDER_MIN)
    needs_attention: list[dict[str, Any]] = []
    for order in open_orders_query:
        if _is_rejected_status(order.status):
            continue
        table = _table_no(order)
        if table:
            seated_tables.add(table)
        if order.status in KITCHEN_STATUSES:
            in_kitchen += 1
        if order.status == "pending" and order.created_at < late_threshold:
            late_count += 1
            mins = _format_minutes_ago(order.created_at, now)
            items_brief = ""
            lines = _line_items(order.items)
            if lines:
                first = lines[0]
                tail = f" +{len(lines) - 1}" if len(lines) > 1 else ""
                items_brief = f" · {first.get('name', '')}{tail}"
            title = f"Table {table} · #{order.serial_number}" if table else f"Order #{order.serial_number}"
            needs_attention.append(
                {
                    "kind": "late",
                    "title": title,
                    "body": f"{mins} min waiting{items_brief}".strip(),
                    "cta": "check",
                    "refId": order.id,
                }
            )

    for item in inventory_items:
        on_hand = float(item.quantity or 0)
        threshold = float(item.min_threshold or 0)
        if on_hand <= 0:
            needs_attention.append(
                {
                    "kind": "low",
                    "title": f"{item.name} stock · out",
                    "body": "Sold out — reorder before next service",
                    "cta": "reorder",
                    "refId": item.id,
                }
            )
        elif threshold > 0 and on_hand <= threshold:
            needs_attention.append(
                {
                    "kind": "low",
                    "title": f"{item.name} stock · {round(on_hand, 1)} {item.unit} left",
                    "body": f"Below threshold of {round(threshold, 1)} {item.unit}",
                    "cta": "reorder",
                    "refId": item.id,
                }
            )

    review_issues = [
        {"tag": "LATE", "title": item["title"], "body": item["body"]}
        for item in needs_attention
        if item["kind"] == "late"
    ]

    needs_attention = needs_attention[:6]

    right_now = {
        "tablesSeated": len(seated_tables),
        "tablesTotal": int(outlet.table_count or 0),
        "ordersInKitchen": in_kitchen,
        "lateOrders": late_count,
        "lateMinThreshold": LATE_ORDER_MIN,
        "needsAttention": needs_attention,
        "floorTables": _floor_tables(open_orders_query, int(outlet.table_count or 0)),
        "todaySoFarBdt": round(earned_today, 2),
        "todaySoFarDeltaPct": delta_pct,
    }

    # ── Review tab ────────────────────────────────────────────────────────────
    covers_today = sum(int(order.covers or 0) for order in today_orders)
    items_sold, review_food_cost_pct = _items_sold(
        mover_qty, mover_sales, mover_name, menu_lookup, limit=6
    )
    avg7_bdt = round(sum(history_for_note) / 7.0, 2)
    staff = await _staff_scoreboard(today_orders, db)
    fleet = await _build_fleet(
        db, outlet, now, today_start, today_end, yesterday_start, yesterday_end, week_start
    )

    review = {
        "hero": {
            "earnedTodayBdt": round(earned_today, 2),
            "earnedYesterdayBdt": round(earned_yesterday, 2),
            "avg7Bdt": avg7_bdt,
            "deltaPct": abs(delta_pct),
            "deltaUp": delta_pct >= 0,
            "periodNote": delta_note,
        },
        "kpis": {
            "orders": order_count_today,
            "covers": covers_today,
            "avgTicketBdt": round(avg_ticket, 2),
            "foodCostPct": review_food_cost_pct,
        },
        "revenueByHour": _revenue_by_hour(today_orders, week_orders),
        "itemsSold": items_sold,
        "bySource": _by_source(today_orders),
        "issues": review_issues,
        "staff": staff,
        "fleet": fleet,
    }

    return ok(
        {
            "asOf": now.astimezone(timezone.utc).isoformat(),
            "moneyFirst": money_first,
            "rightNow": right_now,
            "review": review,
        }
    )


# ── Owner analytics (spec §4.8) ───────────────────────────────────────────────
# Real, range/channel/daypart-scoped analytics that replaces the old mock data
# in the Flutter analytics screen. Advanced blocks (forecast/cohort/discounts/
# wastage) are null-graceful: when their underlying data doesn't exist they
# return null and the UI hides the card (never zero-fills).

ANALYTICS_LOOKBACK_DAYS = 90  # cohort/LTV window over online channels

_MESSENGER_SOURCES = {"facebook_messenger", "facebook", "messenger", "fb_messenger"}
_WEBSITE_SOURCES = {
    "customer_web", "online", "web", "cloud_customer", "web_cloud", "customer_cloud",
}
_ONLINE_CHANNELS = {"website", "messenger"}

_CHANNEL_LABELS = {
    "website": "Website",
    "messenger": "Messenger",
    "counter": "Counter",
    "pos": "POS",
}

_SERVICE_LABELS = {
    "dineIn": "Dine-in",
    "takeaway": "Takeaway",
    "delivery": "Delivery",
}

# (key, label, time-window label) for the daypart breakdown.
_DAYPART_META = [
    ("lunch", "Lunch", "11–4 PM"),
    ("dinner", "Dinner", "6–10 PM"),
    ("late", "Late", "10–12 AM"),
]

_WEEKDAY_ABBR = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


def _channel_key(source: str | None) -> str:
    raw = (source or "").strip().lower()
    if raw in _MESSENGER_SOURCES:
        return "messenger"
    if raw in _WEBSITE_SOURCES:
        return "website"
    if raw == "desktop_pos":
        return "counter"
    return "pos"


def _daypart_key(hour: int) -> str:
    if 11 <= hour < 16:
        return "lunch"
    if 18 <= hour < 22:
        return "dinner"
    if hour >= 22 or hour < 2:
        return "late"
    return "other"


def _analytics_period(
    range_key: str, start: str | None, end: str | None, now: datetime
) -> tuple[datetime, datetime, datetime, datetime]:
    """(cur_start, cur_end, prev_start, prev_end) UTC bounds for a range key."""
    today_start, today_end = _bdt_day_bounds(now)
    key = (range_key or "today").strip().lower()
    if key == "week":
        cur_start, cur_end = today_start - timedelta(days=6), today_end
    elif key == "month":
        cur_start, cur_end = today_start - timedelta(days=29), today_end
    elif key == "custom":
        cur_start = _parse_as_of(start) if start else today_start
        cur_end = _parse_as_of(end) if end else today_end
        if cur_end <= cur_start:
            cur_end = cur_start + timedelta(days=1)
    else:  # "today" / unknown
        cur_start, cur_end = today_start, today_end
    span = cur_end - cur_start
    return cur_start, cur_end, cur_start - span, cur_start


def _matches_filters(order: Order, channel: str, daypart: str) -> bool:
    if channel and channel != "all" and _channel_key(order.source) != channel:
        return False
    if daypart and daypart != "all":
        if _daypart_key(_bdt_local(order.created_at).hour) != daypart:
            return False
    return True


@router.get("/outlets/{outlet_id}/analytics")
async def analytics(
    outlet_id: str,
    range_: str = Query("today", alias="range"),
    start: str | None = None,
    end: str | None = None,
    channel: str = "all",
    daypart: str = "all",
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
    now = datetime.now(timezone.utc)
    today_start, today_end = _bdt_day_bounds(now)
    cur_start, cur_end, prev_start, prev_end = _analytics_period(range_, start, end, now)

    outlet = (
        await db.execute(select(Outlet).where(Outlet.id == outlet_id))
    ).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Outlet not found.")

    async def _load(a: datetime, b: datetime) -> list[Order]:
        rows = (
            await db.execute(
                select(Order)
                .where(Order.outlet_id == outlet_id)
                .where(Order.created_at >= a)
                .where(Order.created_at < b)
            )
        ).scalars().all()
        return [
            o for o in rows
            if not _is_rejected_status(o.status)
            and _matches_filters(o, channel, daypart)
        ]

    cur_orders = await _load(cur_start, cur_end)
    prev_orders = await _load(prev_start, prev_end)

    revenue = sum(float(o.total_amount or 0) for o in cur_orders)
    prev_revenue = sum(float(o.total_amount or 0) for o in prev_orders)
    order_count = len(cur_orders)
    aov = _safe_div(revenue, float(order_count))

    # Menu lookup across both periods (for margins, categories, growth).
    cur_qty, cur_sales, cur_name = _aggregate_items(cur_orders)
    prev_qty, prev_sales, _prev_name = _aggregate_items(prev_orders)
    all_ids = set(cur_qty) | set(prev_qty)
    menu_lookup: dict[str, MenuItem] = {}
    if all_ids:
        menu_rows = (
            await db.execute(
                select(MenuItem)
                .where(MenuItem.outlet_id == outlet_id)
                .where(MenuItem.id.in_(list(all_ids)))
            )
        ).scalars().all()
        menu_lookup = {row.id: row for row in menu_rows}

    items_sold, overall_food_cost = _items_sold(
        cur_qty, cur_sales, cur_name, menu_lookup, limit=500
    )
    gross_margin = (
        round(1 - (overall_food_cost / 100.0), 4) if overall_food_cost is not None else None
    )

    # Product performance — sales, margin, growth vs previous period.
    products: list[dict[str, Any]] = []
    for it in items_sold:
        mid = it["menuItemId"]
        row = menu_lookup.get(mid)
        fc = it["foodCostPct"]
        products.append(
            {
                "menuItemId": mid,
                "name": it["nameEn"] or "",
                "category": (row.category if row and row.category else "") or "",
                "qty": it["qty"],
                "salesBdt": round(it["salesBdt"], 2),
                "marginPct": round(100.0 - fc, 1) if fc is not None else None,
                "growthPct": _delta_pct(it["salesBdt"], prev_sales.get(mid, 0.0)),
            }
        )

    # Revenue by category rollup.
    cat_sales: dict[str, float] = defaultdict(float)
    cat_cost: dict[str, float] = defaultdict(float)
    cat_cost_rev: dict[str, float] = defaultdict(float)
    cat_prev: dict[str, float] = defaultdict(float)
    for mid, s in cur_sales.items():
        row = menu_lookup.get(mid)
        cat = (row.category if row and row.category else None) or "Other"
        cat_sales[cat] += s
        if row and row.cost_price is not None and s > 0:
            cat_cost[cat] += float(row.cost_price) * cur_qty.get(mid, 0)
            cat_cost_rev[cat] += s
    for mid, s in prev_sales.items():
        row = menu_lookup.get(mid)
        cat = (row.category if row and row.category else None) or "Other"
        cat_prev[cat] += s
    grand_cat = sum(cat_sales.values())
    categories: list[dict[str, Any]] = []
    for cat, s in sorted(cat_sales.items(), key=lambda kv: kv[1], reverse=True):
        cm = cat_cost_rev.get(cat, 0.0)
        margin_pct = round((1 - cat_cost[cat] / cm) * 100.0, 1) if cm > 0 else None
        categories.append(
            {
                "name": cat,
                "valueBdt": round(s, 2),
                "share": round(_safe_div(s, grand_cat), 4),
                "marginPct": margin_pct,
                "growthPct": _delta_pct(s, cat_prev.get(cat, 0.0)),
            }
        )

    # Channel donut.
    ch_totals: dict[str, float] = defaultdict(float)
    for o in cur_orders:
        ch_totals[_channel_key(o.source)] += float(o.total_amount or 0)
    grand_ch = sum(ch_totals.values())
    channels = [
        {
            "key": k,
            "label": _CHANNEL_LABELS.get(k, k.title()),
            "valueBdt": round(v, 2),
            "pct": round(_safe_div(v, grand_ch) * 100.0) if grand_ch > 0 else 0,
        }
        for k, v in sorted(ch_totals.items(), key=lambda kv: kv[1], reverse=True)
    ]

    # Dayparts (share / orders / margin).
    dp_sales: dict[str, float] = defaultdict(float)
    dp_orders: dict[str, int] = defaultdict(int)
    dp_cost: dict[str, float] = defaultdict(float)
    dp_cost_rev: dict[str, float] = defaultdict(float)
    for o in cur_orders:
        k = _daypart_key(_bdt_local(o.created_at).hour)
        dp_sales[k] += float(o.total_amount or 0)
        dp_orders[k] += 1
        for line in _line_items(o.items):
            row = menu_lookup.get(str(line.get("menuItemId") or "").strip())
            rev = _item_revenue(line)
            if row and row.cost_price is not None and rev > 0:
                dp_cost[k] += float(row.cost_price) * _item_qty(line)
                dp_cost_rev[k] += rev
    grand_dp = sum(dp_sales.values())
    dayparts = []
    for k, label, window in _DAYPART_META:
        s = dp_sales.get(k, 0.0)
        cm = dp_cost_rev.get(k, 0.0)
        dayparts.append(
            {
                "key": k,
                "name": label,
                "time": window,
                "share": round(_safe_div(s, grand_dp), 4),
                "orders": dp_orders.get(k, 0),
                "marginPct": round((1 - dp_cost[k] / cm) * 100.0, 1) if cm > 0 else None,
            }
        )

    # 7-day trend + peak hours (filtered the same way, for context).
    trend_start = today_start - timedelta(days=13)
    trend_rows = (
        await db.execute(
            select(Order)
            .where(Order.outlet_id == outlet_id)
            .where(Order.created_at >= trend_start)
            .where(Order.created_at < today_end)
        )
    ).scalars().all()
    trend_orders = [
        o for o in trend_rows
        if not _is_rejected_status(o.status)
        and _matches_filters(o, channel, daypart)
    ]
    daily: dict[str, float] = defaultdict(float)
    for o in trend_orders:
        day = (o.created_at.astimezone(timezone.utc) + BDT_OFFSET).date().isoformat()
        daily[day] += float(o.total_amount or 0)
    sales_trend: list[float] = []
    prev_trend: list[float] = []
    trend_labels: list[str] = []
    for i in range(7):
        day = today_start - timedelta(days=6 - i)
        prev_day = today_start - timedelta(days=13 - i)
        key = (day + BDT_OFFSET).date().isoformat()
        prev_key = (prev_day + BDT_OFFSET).date().isoformat()
        sales_trend.append(round(daily.get(key, 0.0) / 1000.0, 2))
        prev_trend.append(round(daily.get(prev_key, 0.0) / 1000.0, 2))
        trend_labels.append(_WEEKDAY_ABBR[(day + BDT_OFFSET).weekday()])
    today_orders = [o for o in trend_orders if today_start <= o.created_at < today_end]
    peak_hours = _revenue_by_hour(today_orders, trend_orders)["today"]

    advanced = {
        "forecast": _analytics_forecast(revenue, cur_start, cur_end, now, outlet),
        "cohort": await _analytics_cohort(db, outlet_id, cur_start, now, cur_orders),
        "discounts": _analytics_discounts(cur_orders, revenue, order_count),
        "wastage": await _analytics_wastage(db, outlet_id, cur_start, cur_end),
    }

    return ok(
        {
            "range": (range_ or "today").strip().lower(),
            "channel": channel,
            "daypart": daypart,
            "periodStart": cur_start.isoformat(),
            "periodEnd": cur_end.isoformat(),
            "revenue": round(revenue),
            "prevRevenue": round(prev_revenue),
            "orders": order_count,
            "aov": round(aov),
            "margin": gross_margin,
            "salesTrend": sales_trend,
            "prevSalesTrend": prev_trend,
            "trendLabels": trend_labels,
            "peakHours": peak_hours,
            "channels": channels,
            "payments": _by_source(cur_orders),
            "products": products,
            "categories": categories,
            "dayparts": dayparts,
            "advanced": advanced,
        }
    )


def _sales_table_rows(
    orders: list[Order], menu_lookup: dict[str, MenuItem]
) -> list[dict[str, Any]]:
    """Per (item × service × channel) sales rows for the owner sales table.

    A group keys on a single menu item, so cost_price is uniform within it:
    costBdt is None when that item has no cost_price, so the UI renders margin
    and profit as "—" instead of a fabricated 0.
    """
    groups: dict[tuple[str, str, str], dict[str, Any]] = {}
    order_seen: dict[tuple[str, str, str], set[str]] = defaultdict(set)
    for order in orders:
        service_key = _service_key(order.service_type)
        channel_key = _channel_key(order.source)
        for line in _line_items(order.items):
            menu_item_id = str(line.get("menuItemId") or "").strip()
            if not menu_item_id:
                continue
            key = (menu_item_id, service_key, channel_key)
            row = groups.get(key)
            if row is None:
                menu_row = menu_lookup.get(menu_item_id)
                cost_price = (
                    float(menu_row.cost_price)
                    if (menu_row and menu_row.cost_price is not None)
                    else None
                )
                row = {
                    "menuItemId": menu_item_id,
                    "name": (menu_row.name_en if menu_row and menu_row.name_en else None)
                    or str(line.get("name") or "").strip(),
                    "category": (menu_row.category if menu_row and menu_row.category else "")
                    or "",
                    "serviceKey": service_key,
                    "service": _SERVICE_LABELS.get(service_key, "Dine-in"),
                    "channelKey": channel_key,
                    "channel": _CHANNEL_LABELS.get(channel_key, channel_key.title()),
                    "units": 0,
                    "salesBdt": 0.0,
                    "_cost": 0.0,
                    "_cost_price": cost_price,
                }
                groups[key] = row
            qty = _item_qty(line)
            row["units"] += qty
            row["salesBdt"] += _item_revenue(line)
            if row["_cost_price"] is not None:
                row["_cost"] += row["_cost_price"] * qty
            order_seen[key].add(order.id)

    rows: list[dict[str, Any]] = []
    for key, row in groups.items():
        cost_known = row["_cost_price"] is not None
        rows.append(
            {
                "id": ":".join(key),
                "menuItemId": row["menuItemId"],
                "name": row["name"],
                "category": row["category"],
                "service": row["service"],
                "serviceKey": row["serviceKey"],
                "channel": row["channel"],
                "channelKey": row["channelKey"],
                "units": row["units"],
                "orders": len(order_seen[key]),
                "salesBdt": round(row["salesBdt"], 2),
                "costBdt": round(row["_cost"], 2) if cost_known else None,
            }
        )
    rows.sort(key=lambda r: r["salesBdt"], reverse=True)
    return rows


@router.get("/outlets/{outlet_id}/analytics/sales-table")
async def sales_table(
    outlet_id: str,
    range_: str = Query("today", alias="range"),
    start: str | None = None,
    end: str | None = None,
    channel: str = "all",
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
    now = datetime.now(timezone.utc)
    cur_start, cur_end, _prev_start, _prev_end = _analytics_period(range_, start, end, now)

    rows = (
        await db.execute(
            select(Order)
            .where(Order.outlet_id == outlet_id)
            .where(Order.created_at >= cur_start)
            .where(Order.created_at < cur_end)
        )
    ).scalars().all()
    orders = [
        o
        for o in rows
        if not _is_rejected_status(o.status) and _matches_filters(o, channel, "all")
    ]

    ids = {
        str(line.get("menuItemId") or "").strip()
        for o in orders
        for line in _line_items(o.items)
        if str(line.get("menuItemId") or "").strip()
    }
    menu_lookup: dict[str, MenuItem] = {}
    if ids:
        menu_rows = (
            await db.execute(
                select(MenuItem)
                .where(MenuItem.outlet_id == outlet_id)
                .where(MenuItem.id.in_(list(ids)))
            )
        ).scalars().all()
        menu_lookup = {row.id: row for row in menu_rows}

    return ok(
        {
            "range": (range_ or "today").strip().lower(),
            "channel": channel,
            "periodStart": cur_start.isoformat(),
            "periodEnd": cur_end.isoformat(),
            "rows": _sales_table_rows(orders, menu_lookup),
        }
    )


def _analytics_forecast(
    revenue: float, cur_start: datetime, cur_end: datetime, now: datetime, outlet: Outlet
) -> dict[str, Any] | None:
    if revenue <= 0:
        return None
    span = (cur_end - cur_start).total_seconds()
    elapsed = max(0.0, min(span, (now - cur_start).total_seconds()))
    frac = elapsed / span if span > 0 else 1.0
    projected = revenue / frac if frac > 0 else revenue
    target: float | None = None
    if outlet.pos_daily_sales_target is not None:
        days = max(1, round(span / 86400.0))
        target = float(outlet.pos_daily_sales_target) * days
    pace = round(projected / target, 2) if (target and target > 0) else None
    return {
        "projected": round(projected),
        "target": round(target) if target is not None else None,
        "pace": pace,
    }


async def _analytics_cohort(
    db: AsyncSession,
    outlet_id: str,
    cur_start: datetime,
    now: datetime,
    cur_orders: list[Order],
) -> dict[str, Any] | None:
    """Repeat-rate / LTV from ONLINE channels only (messenger + website).
    FOH walk-ins never contribute. Returns null when there's no online history."""
    lookback_start = now - timedelta(days=ANALYTICS_LOOKBACK_DAYS)
    rows = (
        await db.execute(
            select(Order)
            .where(Order.outlet_id == outlet_id)
            .where(Order.created_at >= lookback_start)
            .where(Order.created_at < now)
        )
    ).scalars().all()
    online = [
        o for o in rows
        if not _is_rejected_status(o.status)
        and _channel_key(o.source) in _ONLINE_CHANNELS
    ]
    by_cust: dict[str, dict[str, Any]] = defaultdict(
        lambda: {"orders": 0, "spend": 0.0, "first": None}
    )
    for o in sorted(online, key=lambda x: x.created_at):
        key = (o.mobile_number or "").strip() or (o.customer_name or "").strip()
        if not key:
            continue
        e = by_cust[key]
        e["orders"] += 1
        e["spend"] += float(o.total_amount or 0)
        if e["first"] is None:
            e["first"] = o.created_at
    if not by_cust:
        return None
    total = len(by_cust)
    repeat = sum(1 for c in by_cust.values() if c["orders"] > 1) / total
    ltv = sum(c["spend"] for c in by_cust.values()) / total
    freq = sum(c["orders"] for c in by_cust.values()) / total
    new_c = ret_c = 0
    for o in cur_orders:
        if _channel_key(o.source) not in _ONLINE_CHANNELS:
            continue
        key = (o.mobile_number or "").strip() or (o.customer_name or "").strip()
        if not key:
            continue
        first = by_cust.get(key, {}).get("first")
        if first is not None and first >= cur_start:
            new_c += 1
        else:
            ret_c += 1
    nr = new_c + ret_c
    return {
        "repeat": round(repeat, 2),
        "ltv": round(ltv),
        "newPct": round(_safe_div(new_c, nr) * 100.0) if nr else 0,
        "returnPct": round(_safe_div(ret_c, nr) * 100.0) if nr else 0,
        "freq": round(freq, 1),
    }


def _analytics_discounts(
    cur_orders: list[Order], revenue: float, order_count: int
) -> dict[str, Any] | None:
    given = sum(float(o.discount_amount or 0) for o in cur_orders)
    if given <= 0:
        return None
    discounted = sum(1 for o in cur_orders if float(o.discount_amount or 0) > 0)
    gross = revenue + given
    return {
        "given": round(given),
        "orders": round(_safe_div(discounted, order_count), 2) if order_count else 0,
        "marginHit": round(_safe_div(given, gross), 3) if gross > 0 else 0,
    }


async def _analytics_wastage(
    db: AsyncSession, outlet_id: str, cur_start: datetime, cur_end: datetime
) -> dict[str, Any] | None:
    """Opt-in: from StockAdjustment type='waste'. Null when no wastage logged."""
    waste_rows = (
        await db.execute(
            select(StockAdjustment)
            .where(StockAdjustment.outlet_id == outlet_id)
            .where(StockAdjustment.type == "waste")
            .where(StockAdjustment.created_at >= cur_start)
            .where(StockAdjustment.created_at < cur_end)
        )
    ).scalars().all()
    if not waste_rows:
        return None
    waste_cost = sum(abs(float(r.total_cost_bdt or 0)) for r in waste_rows)
    by_item: dict[str, float] = defaultdict(float)
    for r in waste_rows:
        by_item[r.inventory_item_id] += abs(float(r.total_cost_bdt or 0))
    inv = (
        await db.execute(
            select(InventoryItem)
            .where(InventoryItem.outlet_id == outlet_id)
            .where(InventoryItem.deleted_at.is_(None))
        )
    ).scalars().all()
    inv_map = {i.id: i for i in inv}
    stock_value = sum(float(i.quantity or 0) * float(i.cost_per_unit or 0) for i in inv)
    top_id = max(by_item, key=by_item.get) if by_item else None
    top_name = inv_map[top_id].name if (top_id and top_id in inv_map) else "—"
    return {
        "cost": round(waste_cost),
        "pct": round(_safe_div(waste_cost, stock_value), 3) if stock_value > 0 else 0,
        "topItem": top_name or "—",
    }


@router.get("/outlets/{outlet_id}/menu/popularity")
async def menu_popularity(
    outlet_id: str,
    limit: int = Query(9999, ge=1, le=9999),
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    """All-time item popularity — total qty ordered per menu item.

    Aggregates every non-rejected order from the outlet's entire history
    using a DB-level JSONB query so only the summary is materialised
    in Python memory (no full Order objects loaded).
    Returns items sorted descending by totalQty.
    """
    _ensure_outlet(current_outlet, outlet_id)
    rows = (
        await db.execute(
            text("""
                SELECT
                    item->>'menuItemId' AS menu_item_id,
                    SUM(COALESCE((item->>'qty')::int, 0)) AS total_qty
                FROM orders,
                     jsonb_array_elements(items) AS items(item)
                WHERE outlet_id = :outlet_id
                  AND status NOT IN ('cancelled', 'rejected')
                  AND items IS NOT NULL
                GROUP BY menu_item_id
                ORDER BY total_qty DESC
                LIMIT :limit
            """),
            {"outlet_id": outlet_id, "limit": limit},
        )
    ).all()
    return ok([
        {"menuItemId": row.menu_item_id, "qty": row.total_qty}
        for row in rows
        if row.menu_item_id is not None
    ])


def _line_cost(item: dict[str, Any]) -> float:
    """Prep cost for a line — costPriceSnapshot × qty (0 when cost unset)."""
    cost = item.get("costPriceSnapshot")
    if not isinstance(cost, (int, float)):
        return 0.0
    return float(cost) * float(_item_qty(item))


@router.get("/outlets/{outlet_id}/analytics/summary")
async def analytics_summary(
    outlet_id: str,
    range_: str = Query("today", alias="range"),
    start: str | None = None,
    end: str | None = None,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    """QuicklyServices-style plain BD analytics (spec Part B).

    Sales Summary · Collection Summary · Service-wise Sales · Profit Estimation
    · Popular Dishes · Item-wise Sales. No AOV/cohort/LTV/forecast jargon.
    """
    _ensure_outlet(current_outlet, outlet_id)
    now = datetime.now(timezone.utc)
    cur_start, cur_end, _prev_start, _prev_end = _analytics_period(
        range_, start, end, now
    )

    orders = (
        (
            await db.execute(
                select(Order)
                .where(Order.outlet_id == outlet_id)
                .where(Order.created_at >= cur_start)
                .where(Order.created_at < cur_end)
            )
        )
        .scalars()
        .all()
    )
    orders = [o for o in orders if not _is_rejected_status(o.status)]

    # Menu lookup: menuItemId -> (name, category) for item-wise grouping.
    menu_rows = (
        (
            await db.execute(
                select(MenuItem).where(MenuItem.outlet_id == outlet_id)
            )
        )
        .scalars()
        .all()
    )
    menu_cat = {m.id: (m.category_en or m.category or "General") for m in menu_rows}
    menu_name = {m.id: (m.name_en or m.name) for m in menu_rows}

    orders_completed = len(orders)
    gross_sales = 0.0
    discount_total = 0.0
    total_collection = 0.0
    service_charge_total = 0.0
    delivery_total = 0.0
    tax_total = 0.0
    prep_cost = 0.0
    collection: dict[str, float] = defaultdict(float)
    service: dict[str, float] = defaultdict(float)
    # item_id -> [units, sales]
    item_agg: dict[str, list[float]] = defaultdict(lambda: [0.0, 0.0])

    for order in orders:
        total = float(order.total_amount or 0)
        discount = float(order.discount_amount or 0)
        total_collection += total
        discount_total += discount
        service_charge_total += float(order.service_charge_amount or 0)
        delivery_total += float(order.delivery_charge or 0)
        tax_total += float(order.vat_amount or 0)
        collection[(order.payment_method or "cash").strip().lower() or "cash"] += total
        service[_service_key(order.service_type)] += total
        lines = _line_items(order.items)
        for line in lines:
            rev = _item_revenue(line)
            gross_sales += rev
            prep_cost += _line_cost(line)
            key = str(line.get("menuItemId") or line.get("name") or "?")
            item_agg[key][0] += _item_qty(line)
            item_agg[key][1] += rev

    net_sales = gross_sales - discount_total

    # Wastage cost in the window (stock adjustments marked waste).
    wastage = float(
        (
            await db.execute(
                select(func.coalesce(func.sum(StockAdjustment.total_cost_bdt), 0))
                .where(StockAdjustment.outlet_id == outlet_id)
                .where(StockAdjustment.type == "waste")
                .where(StockAdjustment.created_at >= cur_start)
                .where(StockAdjustment.created_at < cur_end)
            )
        ).scalar_one()
        or 0
    )
    payment_fee = 0.0
    gross_profit = (
        net_sales
        + service_charge_total
        + delivery_total
        - prep_cost
        - wastage
        - payment_fee
        - tax_total
    )

    # Popular dishes — top 10 by sales.
    popular = sorted(
        (
            {
                "name": menu_name.get(key, key),
                "qty": int(units),
                "salesBdt": round(sales, 2),
            }
            for key, (units, sales) in item_agg.items()
        ),
        key=lambda r: r["salesBdt"],
        reverse=True,
    )[:10]

    # Item-wise grouped by category.
    cat_groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for key, (units, sales) in item_agg.items():
        cat = menu_cat.get(key, "General")
        cat_groups[cat].append(
            {
                "name": menu_name.get(key, key),
                "units": int(units),
                "avgUnitPrice": round(_safe_div(sales, units), 2),
                "totalPrice": round(sales, 2),
            }
        )
    item_wise = [
        {
            "category": cat,
            "units": int(sum(i["units"] for i in items)),
            "totalPrice": round(sum(i["totalPrice"] for i in items), 2),
            "items": sorted(items, key=lambda i: i["totalPrice"], reverse=True),
        }
        for cat, items in sorted(cat_groups.items())
    ]

    def _money_rows(totals: dict[str, float], labels: list[tuple[str, str]]):
        return [
            {"key": k, "label": label, "valueBdt": round(totals.get(k, 0.0), 2)}
            for k, label in labels
            if totals.get(k, 0.0) != 0
        ]

    return ok(
        {
            "rangeStart": cur_start.isoformat(),
            "rangeEnd": cur_end.isoformat(),
            "salesSummary": {
                "ordersCompleted": orders_completed,
                "grossSales": round(gross_sales, 2),
                "discountByStaff": round(discount_total, 2),
                "netSales": round(net_sales, 2),
            },
            "totalCollection": round(total_collection, 2),
            "collection": [
                {
                    "key": k,
                    "label": k.upper() if len(k) <= 4 else k.capitalize(),
                    "valueBdt": round(v, 2),
                }
                for k, v in sorted(
                    collection.items(), key=lambda kv: kv[1], reverse=True
                )
            ],
            "serviceWise": [
                {
                    "key": k,
                    "label": label,
                    "valueBdt": round(service.get(k, 0.0), 2),
                }
                for k, label in (
                    ("dineIn", "Dine-in"),
                    ("takeaway", "Takeaway"),
                    ("delivery", "Delivery Service"),
                )
            ],
            "profit": {
                "netSales": round(net_sales, 2),
                "serviceCharge": round(service_charge_total, 2),
                "deliveryCharge": round(delivery_total, 2),
                "preparationCost": round(prep_cost, 2),
                "wastage": round(wastage, 2),
                "paymentFee": round(payment_fee, 2),
                "taxes": round(tax_total, 2),
                "grossProfit": round(gross_profit, 2),
            },
            "popularDishes": popular,
            "itemWise": item_wise,
        }
    )
