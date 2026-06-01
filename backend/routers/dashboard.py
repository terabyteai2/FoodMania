from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
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

# Review tab revenue-by-hour chart axis: 15 hourly buckets covering 9:00–23:00
# (a restaurant service day). Orders outside the window fold into the nearest end.
REVIEW_START_HOUR = 9
REVIEW_BUCKETS = 15
# Food-cost % above this flags an item as low-margin ("margin kom") in the UI.
HIGH_FOOD_COST_PCT = 38.0


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
        if order.status == "cancelled":
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
            .where(Order.created_at >= week_start)
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

    today_by_outlet: dict[str, list[Order]] = defaultdict(list)
    rev_today: dict[str, float] = defaultdict(float)
    rev_yesterday: dict[str, float] = defaultdict(float)
    covers_by_outlet: dict[str, int] = defaultdict(int)
    for order in week_orders:
        if order.status == "cancelled":
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
    for order in open_orders:
        if order.status == "cancelled":
            continue
        table = _table_no(order)
        if table:
            seated_by_outlet[order.outlet_id].add(table)
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
        delta = _delta_pct(rev_today.get(o.id, 0.0), rev_yesterday.get(o.id, 0.0))
        health: list[dict[str, Any]] = []
        if late > 0:
            late_rate = round(_safe_div(late, order_count) * 100.0) if order_count else 0
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
        sum(float(o.total_amount or 0) for o in week_orders if o.status != "cancelled") / 7.0,
        2,
    )
    top_movers, fleet_food_cost = _items_sold(fleet_qty, fleet_sales, fleet_name, menu_lookup, limit=5)

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
        },
        "revenueByHour": _revenue_by_hour(all_today, week_orders),
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
        if order.status == "cancelled":
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
        if today_start <= order.created_at < today_end and order.status != "cancelled"
    ]
    order_count_today = len(today_orders)
    avg_ticket = _safe_div(earned_today, float(order_count_today))

    today_cost = sum(
        float(adj.total_cost_bdt or 0)
        for adj in today_adjustments
        if (adj.type or "").lower() == "restock"
    )
    profit_pct = round(_safe_div(earned_today - today_cost, earned_today) * 100.0, 1)

    open_orders_count = len([o for o in open_orders_query if o.status != "cancelled"])

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
        "closeTodayHintBdt": round(earned_today, 2),
    }

    # ── Right now ─────────────────────────────────────────────────────────────
    seated_tables: set[str] = set()
    in_kitchen = 0
    late_count = 0
    late_threshold = now - timedelta(minutes=LATE_ORDER_MIN)
    needs_attention: list[dict[str, Any]] = []
    for order in open_orders_query:
        if order.status == "cancelled":
            continue
        table = _table_no_from_notes(order.notes)
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
