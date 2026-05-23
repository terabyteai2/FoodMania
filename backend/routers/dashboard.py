from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_outlet_id
from database import get_db
from models import InventoryItem, MenuItem, Order, Outlet, StockAdjustment
from routers.menu import _ensure_outlet
from schemas import ok

router = APIRouter()

# Restaurants run on Bangladesh local time (UTC+6) — pick the day boundary in
# that zone so "today" matches what an owner sees on a wall clock.
BDT_OFFSET = timedelta(hours=6)
LATE_ORDER_MIN = 20
OPEN_STATUSES = {"pending", "accepted", "preparing", "ready"}
KITCHEN_STATUSES = {"accepted", "preparing"}


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

    return ok(
        {
            "asOf": now.astimezone(timezone.utc).isoformat(),
            "moneyFirst": money_first,
            "rightNow": right_now,
        }
    )
