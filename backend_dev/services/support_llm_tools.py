"""Business-data tools for Volt Assistant (the in-app support LLM).

API-native function calling (the conventional agent-loop format, see
services/support_llm.py): ``tools_schema()`` derives OpenAI-style ``tools``
JSON schemas from the [TOOLS] registry; the model replies with
``message.tool_calls``; the pipeline executes the tool here, appends the
JSON result as a ``role: "tool"`` message, and loops until the model
returns a final reply.

Most tools are READ-ONLY, outlet-scoped, and capped — never trust the model's
names or arguments. The stock-management tools (``stock_in``,
``stock_count``) never write either: they resolve items by EXACT name
(no fuzzy matching) and return a *proposal* the client shows in the
stock-scan review flow; only the manager's confirmation in the app applies
it through the existing inventory APIs. They are management-only: the model
may only use them for an owner/manager account (see [execute_tool]).

To add a function: write an async handler with the signature
``async def handler(outlet_id: str, args: dict) -> dict`` and register a
[ToolSpec] in [TOOLS].
"""

import json
import logging
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from sqlalchemy import and_, func, or_, select
from sqlalchemy.orm import selectinload

logger = logging.getLogger(__name__)

BDT_OFFSET = timedelta(hours=6)

TOOL_RESULT_LIMIT = 20
TOOL_RESULT_MAX = 50
ORDER_ITEM_LIMIT = 50

# Canonical + legacy statuses; "served" counts as completed everywhere.
ORDER_STATUSES = {
    "pending",
    "accepted",
    "completed",
    "rejected",
    "preparing",
    "ready",
    "served",
    "cancelled",
}
COMPLETED_STATUSES = ("completed", "served")

MANAGEMENT_ROLES = frozenset({"owner", "manager"})

# --- Overlay-guide deeplink vocabulary (see data/support_guide_deeplinks.json) ---

GUIDE_FILE = Path(__file__).resolve().parent.parent / "data" / "support_guide_deeplinks.json"
GUIDE_KINDS = ("tabs", "screens", "modals", "spots", "navSpots", "conventions")


def _load_guide_vocabulary() -> dict:
    """Reads the deeplink vocabulary + descriptions from the JSON data file.

    Never raises: on a missing or corrupt file the guide tool reports
    "guide vocabulary unavailable" and the model falls back to chat-only.
    """
    try:
        data = json.loads(GUIDE_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    if not isinstance(data, dict):
        return {}
    loaded = {
        key: data[key]
        for key in GUIDE_KINDS
        if isinstance(data.get(key), (list, dict))
    }
    version = data.get("version")
    if isinstance(version, int) and version > 0:
        loaded["version"] = version
    return loaded


GUIDE_VOCABULARY = _load_guide_vocabulary()


def _today_bdt() -> date:
    return (datetime.now(timezone.utc) + BDT_OFFSET).date()


def _to_float(value) -> float:
    try:
        return round(float(value), 2)
    except (TypeError, ValueError):
        return 0.0


def _iso(dt) -> str | None:
    return dt.isoformat() if dt is not None else None


def _iso_date(dt) -> str | None:
    return dt.isoformat() if dt is not None else None


class ToolSpec:
    """Declarative tool registration.

    ``args`` maps argument name -> rules:
      - kind: "int" | "float" | "bool" | "str" (default "str")
      - default: used when the model omits the argument
      - min / max: int/float clamps; max_len: string truncation

    ``management_only`` marks tools that must only run for an owner/manager
    account; [execute_tool] enforces it.
    """

    def __init__(
        self,
        name: str,
        description: str,
        handler,
        args: dict | None = None,
        *,
        management_only: bool = False,
    ):
        self.name = name
        self.description = description
        self.handler = handler
        self.args = args or {}
        self.management_only = management_only


def _clean_int(raw, rules: dict) -> int:
    default = int(rules.get("default", 0))
    try:
        value = int(raw)
    except (TypeError, ValueError):
        return default
    if "min" in rules:
        value = max(rules["min"], value)
    if "max" in rules:
        value = min(rules["max"], value)
    return value


def _clean_float(raw, rules: dict) -> float:
    default = float(rules.get("default", 0))
    try:
        value = round(float(raw), 2)
    except (TypeError, ValueError):
        return default
    if "min" in rules:
        value = max(rules["min"], value)
    if "max" in rules:
        value = min(rules["max"], value)
    return value


def _clean_bool(raw, rules: dict) -> bool:
    if raw is None:
        return bool(rules.get("default", False))
    if isinstance(raw, bool):
        return raw
    if isinstance(raw, str):
        return raw.strip().lower() in ("1", "true", "yes", "on")
    return bool(raw)


def _clean_str(raw, rules: dict) -> str | None:
    if raw is None:
        default = rules.get("default")
        return default
    text = str(raw).strip()
    if not text:
        return rules.get("default")
    return text[: rules.get("max_len", 200)]


def validate_arguments(spec: ToolSpec, raw) -> dict:
    """Coerces and clamps the model's arguments; unknown keys are dropped."""
    raw = raw if isinstance(raw, dict) else {}
    cleaned: dict = {}
    for name, rules in spec.args.items():
        kind = rules.get("kind", "str")
        if kind == "int":
            cleaned[name] = _clean_int(raw.get(name), rules)
        elif kind == "float":
            cleaned[name] = _clean_float(raw.get(name), rules)
        elif kind == "bool":
            cleaned[name] = _clean_bool(raw.get(name), rules)
        else:
            cleaned[name] = _clean_str(raw.get(name), rules)
    return cleaned


def _arg_schema(rules: dict) -> dict:
    """One JSON-Schema property from a ToolSpec argument rule."""
    kind = rules.get("kind", "str")
    if kind == "int":
        schema: dict = {"type": "integer"}
        if "min" in rules:
            schema["minimum"] = rules["min"]
        if "max" in rules:
            schema["maximum"] = rules["max"]
    elif kind == "float":
        schema: dict = {"type": "number"}
        if "min" in rules:
            schema["minimum"] = rules["min"]
        if "max" in rules:
            schema["maximum"] = rules["max"]
    elif kind == "bool":
        schema = {"type": "boolean"}
    else:
        schema = {"type": "string"}
    if rules.get("default") is not None:
        schema["default"] = rules["default"]
    return schema


def tools_schema() -> list[dict]:
    """OpenAI-style ``tools`` definitions derived from the TOOLS registry.

    Native function calling (the conventional agent-loop format): the API
    enforces this grammar, so the model returns ``message.tool_calls``
    instead of having to imitate a custom JSON envelope from the prompt.
    Every argument is optional — missing ones fall back to the spec default
    or ``None``, and handlers error-recover.
    """
    tools: list[dict] = []
    for spec in TOOLS.values():
        properties = {
            name: _arg_schema(rules) for name, rules in spec.args.items()
        }
        parameters: dict = {"type": "object", "properties": properties}
        tools.append(
            {
                "type": "function",
                "function": {
                    "name": spec.name,
                    "description": spec.description,
                    "parameters": parameters,
                },
            }
        )
    return tools


# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------


async def _outlet_info(outlet_id: str, args: dict) -> dict:
    """Outlet identity: name, plan and table count."""
    from database import AsyncSessionLocal
    from models import Outlet, OutletSubscription

    async with AsyncSessionLocal() as session:
        outlet = (
            await session.execute(
                select(Outlet)
                .options(selectinload(Outlet.subscription))
                .where(Outlet.id == outlet_id)
            )
        ).scalar_one_or_none()
    if outlet is None:
        return {"ok": False, "error": "outlet not found"}
    plan = outlet.subscription.plan if outlet.subscription is not None else None
    return {
        "ok": True,
        "name": outlet.name,
        "plan": plan or "trial",
        "tableCount": outlet.table_count,
    }


async def _overview(outlet_id: str, args: dict) -> dict:
    """Today's headline numbers: order counts, sales, open orders."""
    from database import AsyncSessionLocal
    from models import Order

    today = _today_bdt()
    start_utc = datetime.combine(today, datetime.min.time(), tzinfo=timezone.utc) - BDT_OFFSET
    async with AsyncSessionLocal() as session:
        rows = (
            await session.execute(
                select(Order)
                .where(
                    Order.outlet_id == outlet_id,
                    or_(
                        Order.order_date == today,
                        # Rows without an order_date fall back to the
                        # created_at window so they still count for today.
                        and_(
                            Order.order_date.is_(None),
                            Order.created_at >= start_utc,
                        ),
                    ),
                )
                .order_by(Order.created_at.desc())
            )
        ).scalars().all()
    total_orders = len(rows)
    completed = [o for o in rows if o.status in COMPLETED_STATUSES]
    open_orders = [o for o in rows if o.status in ("pending", "accepted")]
    rejected = [o for o in rows if o.status in ("rejected", "cancelled")]
    sales = sum(_to_float(o.total_amount) for o in completed)
    return {
        "ok": True,
        "date": today.isoformat(),
        "totalOrders": total_orders,
        "completedOrders": len(completed),
        "openOrders": len(open_orders),
        "rejectedOrders": len(rejected),
        "totalSalesBdt": sales,
    }


def _order_summary(order) -> dict:
    items = order.items or []
    return {
        "serialNumber": order.serial_number,
        "status": order.status,
        "totalAmount": _to_float(order.total_amount),
        "serviceType": order.service_type,
        "source": order.source,
        "tableNo": order.table_no,
        "itemCount": len(items),
        "itemNames": [
            (i.get("nameEn") or i.get("nameBn") or i.get("name") or "")
            for i in items[:5]
        ],
        "createdAt": _iso(order.created_at),
    }


async def _recent_orders(outlet_id: str, args: dict) -> dict:
    """Recent orders within a day window, optionally filtered by status."""
    from database import AsyncSessionLocal
    from models import Order

    days = args["days"]
    status = args["status"]
    limit = args["limit"]
    if status and status not in ORDER_STATUSES:
        return {"ok": False, "error": f"unknown status '{status}'"}

    since = datetime.now(timezone.utc) - timedelta(days=days)
    query = select(Order).where(
        Order.outlet_id == outlet_id,
        Order.created_at >= since,
    )
    if status:
        query = query.where(Order.status == status)
    query = query.order_by(Order.created_at.desc()).limit(limit)
    async with AsyncSessionLocal() as session:
        rows = (await session.execute(query)).scalars().all()
    return {
        "ok": True,
        "days": days,
        "status": status,
        "count": len(rows),
        "truncated": len(rows) == limit,
        "orders": [_order_summary(o) for o in rows],
    }


async def _order(outlet_id: str, args: dict) -> dict:
    """One full order by serial number or order id (serial wins)."""
    from database import AsyncSessionLocal
    from models import Order

    serial = args["serial"]
    order_id = args["orderId"]
    if serial is None and not order_id:
        return {"ok": False, "error": "provide 'serial' or 'orderId'"}
    query = select(Order).where(Order.outlet_id == outlet_id)
    if serial is not None:
        query = query.where(Order.serial_number == serial)
    else:
        query = query.where(Order.id == order_id)
    async with AsyncSessionLocal() as session:
        order = (await session.execute(query.limit(1))).scalars().first()
    if order is None:
        return {"ok": False, "error": "order not found"}
    items = order.items or []
    truncated = len(items) > ORDER_ITEM_LIMIT
    return {
        "ok": True,
        "order": {
            "id": order.id,
            "serialNumber": order.serial_number,
            "status": order.status,
            "source": order.source,
            "serviceType": order.service_type,
            "tableNo": order.table_no,
            "covers": order.covers,
            "paymentMethod": order.payment_method,
            "subtotal": _to_float(order.subtotal),
            "vatAmount": _to_float(order.vat_amount),
            "deliveryCharge": _to_float(order.delivery_charge),
            "discountLabel": order.discount_label,
            "discountAmount": _to_float(order.discount_amount),
            "serviceChargeAmount": _to_float(order.service_charge_amount),
            "totalAmount": _to_float(order.total_amount),
            "customerName": order.customer_name,
            "deliveryAddress": order.delivery_address,
            "mobileNumber": order.mobile_number,
            "notes": order.notes,
            "createdAt": _iso(order.created_at),
            "items": [
                {
                    "name": i.get("name"),
                    "nameEn": i.get("nameEn"),
                    "nameBn": i.get("nameBn"),
                    "qty": i.get("qty"),
                    "price": i.get("price"),
                    "lineTotal": i.get("lineTotal"),
                    "note": i.get("note"),
                }
                for i in items[:ORDER_ITEM_LIMIT]
            ],
            "itemsTruncated": truncated,
        },
    }


async def _menu_items(outlet_id: str, args: dict) -> dict:
    """Menu items by name search / category / availability."""
    from database import AsyncSessionLocal
    from models import MenuItem

    query_text = args["query"]
    category = args["category"]
    available_only = args["availableOnly"]
    limit = args["limit"]
    query = select(MenuItem).where(
        MenuItem.outlet_id == outlet_id,
        MenuItem.deleted_at.is_(None),
    )
    if query_text:
        pattern = f"%{query_text}%"
        query = query.where(
            or_(
                MenuItem.name.ilike(pattern),
                MenuItem.name_en.ilike(pattern),
                MenuItem.name_bn.ilike(pattern),
            )
        )
    if category:
        query = query.where(
            or_(
                MenuItem.category == category,
                MenuItem.category_en == category,
                MenuItem.category_bn == category,
            )
        )
    if available_only:
        query = query.where(MenuItem.is_available.is_(True))
    query = query.order_by(MenuItem.name.asc()).limit(limit)
    async with AsyncSessionLocal() as session:
        rows = (await session.execute(query)).scalars().all()
    return {
        "ok": True,
        "count": len(rows),
        "truncated": len(rows) == limit,
        "items": [
            {
                "id": m.id,
                "name": m.name,
                "nameEn": m.name_en,
                "nameBn": m.name_bn,
                "price": _to_float(m.price),
                "costPrice": _to_float(m.cost_price),
                "category": m.category,
                "categoryEn": m.category_en,
                "categoryBn": m.category_bn,
                "isAvailable": m.is_available,
            }
            for m in rows
        ],
    }


async def _stock(outlet_id: str, args: dict) -> dict:
    """Inventory items by name search; optionally only low/out-of-stock."""
    from database import AsyncSessionLocal
    from models import InventoryItem

    query_text = args["query"]
    low_only = args["lowStockOnly"]
    limit = args["limit"]
    query = select(InventoryItem).where(
        InventoryItem.outlet_id == outlet_id,
        InventoryItem.deleted_at.is_(None),
    )
    if query_text:
        pattern = f"%{query_text}%"
        query = query.where(InventoryItem.name.ilike(pattern))
    if low_only:
        query = query.where(
            or_(
                InventoryItem.quantity <= InventoryItem.min_threshold,
                InventoryItem.quantity <= 0,
            )
        )
    query = query.order_by(InventoryItem.quantity.asc()).limit(limit)
    async with AsyncSessionLocal() as session:
        rows = (await session.execute(query)).scalars().all()
    return {
        "ok": True,
        "count": len(rows),
        "truncated": len(rows) == limit,
        "items": [
            {
                "id": s.id,
                "name": s.name,
                "category": s.category,
                "unit": s.unit,
                "quantity": float(s.quantity),
                "minThreshold": float(s.min_threshold),
                "costPerUnit": _to_float(s.cost_per_unit),
                "isLowStock": s.quantity > 0 and s.quantity <= s.min_threshold,
                "isOutOfStock": s.quantity <= 0,
            }
            for s in rows
        ],
    }


def _normalize_lookup_key(value: str) -> str:
    """Lowercase alphanumeric key for EXACT-name comparison only.

    Not fuzzy matching: no substring, no aliases, no transliteration. The
    model is expected to copy names verbatim from get_stock; this only
    absorbs case/punctuation differences from the transcript.
    """
    return "".join(ch for ch in (value or "").strip().lower() if ch.isalnum())


async def _find_item_by_exact_name(session, outlet_id: str, name: str):
    from models import InventoryItem

    key = _normalize_lookup_key(name)
    if not key:
        return None
    rows = (
        await session.execute(
            select(InventoryItem).where(
                InventoryItem.outlet_id == outlet_id,
                InventoryItem.deleted_at.is_(None),
            )
        )
    ).scalars().all()
    for item in rows:
        if _normalize_lookup_key(item.name) == key:
            return item
    return None


async def _stock_in(outlet_id: str, args: dict) -> dict:
    """Stock-in proposal: add a quantity to an inventory item by exact name.

    Resolves the item with EXACT name equality only (the model copies the
    name from get_stock) and returns a ``stock_in`` proposal in the
    stock-scan wire format — this tool never changes stock. The manager
    reviews and confirms the proposal in the app, which applies it through
    the same inventory APIs the stock scan uses. Names not in stock become
    new-item lines that the app creates on confirmation (add-to-stock).
    """
    from database import AsyncSessionLocal

    name = (args.get("name") or "").strip()
    qty = args.get("qty") or 0.0
    if not name:
        return {
            "ok": False,
            "error": "item name is required — copy the exact name from get_stock",
        }
    if qty <= 0:
        return {"ok": False, "error": "qty must be greater than zero"}
    unit = (args.get("unit") or "").strip() or None
    total_cost = args.get("totalCostBdt") or 0.0
    supplier_name = (args.get("supplierName") or "").strip() or None
    note = (args.get("note") or "").strip() or None

    async with AsyncSessionLocal() as session:
        item = await _find_item_by_exact_name(session, outlet_id, name)

    warnings: list[str] = []
    if item is not None:
        unit_price = (
            round(total_cost / qty, 2) if total_cost > 0 else _to_float(item.cost_per_unit)
        )
        item_unit = item.unit or "pcs"
        if unit and _normalize_lookup_key(unit) != _normalize_lookup_key(item_unit):
            warnings.append(f"unit '{unit}' differs from '{item_unit}'")
        line = {
            "nameEn": item.name,
            "nameBn": None,
            "qty": round(qty, 2),
            "unit": item_unit,
            "unitPriceBdt": unit_price,
            "totalBdt": round(total_cost if total_cost > 0 else unit_price * qty, 2),
            "matchedInventoryItemId": item.id,
        }
    else:
        line = {
            "nameEn": name,
            "nameBn": None,
            "qty": round(qty, 2),
            "unit": unit or "pcs",
            "unitPriceBdt": round(total_cost / qty, 2) if total_cost > 0 else 0.0,
            "totalBdt": round(total_cost, 2),
            "matchedInventoryItemId": None,
        }
        warnings.append("new item — created on confirmation")
    return {"ok": True, "category": "stock_in", "items": [line], "warnings": warnings}


async def _stock_count(outlet_id: str, args: dict) -> dict:
    """Stock-count proposal: record the physical count for a day by exact name.

    Resolves the item with EXACT name equality only and returns a ``count``
    proposal in the stock-scan wire format — this tool never changes stock.
    The manager reviews and confirms the proposal in the app, which applies
    it through the same inventory APIs the stock scan uses. Unknown items
    are rejected: counts never create items.
    """
    from database import AsyncSessionLocal

    name = (args.get("name") or "").strip()
    qty = args.get("qty") or 0.0
    if not name:
        return {
            "ok": False,
            "error": "item name is required — copy the exact name from get_stock",
        }
    if qty < 0:
        return {"ok": False, "error": "qty cannot be negative"}
    raw_date = (args.get("countDate") or "").strip() or None
    count_date = _today_bdt().isoformat()
    if raw_date:
        try:
            count_date = date.fromisoformat(raw_date).isoformat()
        except ValueError:
            return {"ok": False, "error": "countDate must be YYYY-MM-DD"}

    async with AsyncSessionLocal() as session:
        item = await _find_item_by_exact_name(session, outlet_id, name)
    if item is None:
        return {
            "ok": False,
            "error": f"'{name}' is not in stock — check get_stock; counts never create items",
        }
    return {
        "ok": True,
        "category": "count",
        "countDate": count_date,
        "items": [
            {
                "nameEn": item.name,
                "nameBn": None,
                "qty": round(qty, 2),
                "unit": item.unit or "pcs",
                "unitPriceBdt": 0.0,
                "totalBdt": 0.0,
                "matchedInventoryItemId": item.id,
            }
        ],
        "warnings": [],
    }


async def _daily_sales(outlet_id: str, args: dict) -> dict:
    """Per-day sales totals (completed orders only) over a day window."""
    from database import AsyncSessionLocal
    from models import Order

    days = args["days"]
    since = _today_bdt() - timedelta(days=days - 1)
    query = (
        select(
            Order.order_date,
            func.count(Order.id),
            func.coalesce(func.sum(Order.total_amount), 0),
        )
        .where(
            Order.outlet_id == outlet_id,
            Order.order_date >= since,
            Order.order_date.is_not(None),
            Order.status.in_(COMPLETED_STATUSES),
        )
        .group_by(Order.order_date)
        .order_by(Order.order_date.desc())
    )
    async with AsyncSessionLocal() as session:
        rows = (await session.execute(query)).all()
    return {
        "ok": True,
        "days": days,
        "count": len(rows),
        "entries": [
            {
                "date": row[0].isoformat() if row[0] else None,
                "orders": int(row[1]),
                "salesBdt": _to_float(row[2]),
            }
            for row in rows
        ],
    }


# ---------------------------------------------------------------------------
# Registry + dispatch
# ---------------------------------------------------------------------------

async def _guide_deeplinks(outlet_id: str, args: dict) -> dict:
    """The overlay-guide deeplink vocabulary with descriptions."""
    if not GUIDE_VOCABULARY:
        return {"ok": False, "error": "guide vocabulary unavailable"}
    kind = args["kind"]
    if kind == "all":
        payload = GUIDE_VOCABULARY
    elif kind in GUIDE_VOCABULARY:
        payload = {kind: GUIDE_VOCABULARY[kind]}
    else:
        return {"ok": False, "error": f"unknown kind '{kind}'"}
    count = sum(
        len(value) if isinstance(value, list) else 1
        for key, value in payload.items()
        if key != "version"
    )
    version = GUIDE_VOCABULARY.get("version") or 1
    return {"ok": True, "version": version, "kind": kind, "count": count, **payload}


TOOLS: dict[str, ToolSpec] = {
    "get_guide_deeplinks": ToolSpec(
        name="get_guide_deeplinks",
        description=(
            "The overlay-guide deeplink vocabulary with descriptions: tabs, "
            "screens, modals, highlight spots, and navigation conventions. "
            "Call this BEFORE emitting guide steps or actions so you only "
            "use real deeplinks; filter with kind (tabs|screens|modals|"
            "spots|navSpots|conventions) or omit it for everything."
        ),
        handler=_guide_deeplinks,
        args={
            "kind": {"kind": "str", "default": "all", "max_len": 20},
        },
    ),
    "get_outlet_overview": ToolSpec(
        name="get_outlet_overview",
        description=(
            "Today's headline numbers: total/completed/open/rejected order "
            "counts and total sales (completed orders) in BDT."
        ),
        handler=_overview,
        args={},
    ),
    "get_outlet_info": ToolSpec(
        name="get_outlet_info",
        description=(
            "This outlet's identity: name, plan (trial|pro) and table "
            "count. Call it when the reply needs to mention the outlet by "
            "name or its plan/tables."
        ),
        handler=_outlet_info,
        args={},
    ),
    "get_recent_orders": ToolSpec(
        name="get_recent_orders",
        description=(
            "Recent orders within the last N days, optionally filtered by "
            "status (pending|accepted|completed|rejected). Returns summaries "
            "with serial, status, total, item count and first item names."
        ),
        handler=_recent_orders,
        args={
            "days": {"kind": "int", "default": 7, "min": 1, "max": 90},
            "status": {"kind": "str", "default": None, "max_len": 20},
            "limit": {"kind": "int", "default": TOOL_RESULT_LIMIT, "min": 1, "max": TOOL_RESULT_MAX},
        },
    ),
    "get_order": ToolSpec(
        name="get_order",
        description=(
            "One full order by serial number (serial) or order id (orderId). "
            "Returns every field plus the line items."
        ),
        handler=_order,
        args={
            "serial": {"kind": "int", "default": None},
            "orderId": {"kind": "str", "default": None, "max_len": 64},
        },
    ),
    "get_menu_items": ToolSpec(
        name="get_menu_items",
        description=(
            "Menu items by name search (query), category, or availability "
            "(availableOnly). Returns price, category and availability."
        ),
        handler=_menu_items,
        args={
            "query": {"kind": "str", "default": None, "max_len": 100},
            "category": {"kind": "str", "default": None, "max_len": 100},
            "availableOnly": {"kind": "bool", "default": False},
            "limit": {"kind": "int", "default": TOOL_RESULT_LIMIT, "min": 1, "max": TOOL_RESULT_MAX},
        },
    ),
    "get_stock": ToolSpec(
        name="get_stock",
        description=(
            "Inventory items by name search (query); lowStockOnly returns "
            "only low/out-of-stock items. Returns quantity, unit, threshold "
            "and cost per unit."
        ),
        handler=_stock,
        args={
            "query": {"kind": "str", "default": None, "max_len": 100},
            "lowStockOnly": {"kind": "bool", "default": False},
            "limit": {"kind": "int", "default": TOOL_RESULT_LIMIT, "min": 1, "max": TOOL_RESULT_MAX},
        },
    ),
    "stock_in": ToolSpec(
        name="stock_in",
        description=(
            "PROPOSES adding a quantity to an inventory item by EXACT name "
            "(call get_stock first and copy the name verbatim). Returns a "
            "stock_in proposal the manager reviews and confirms in the app — "
            "this tool never changes stock. A name that is not in stock "
            "becomes a new-item line that gets created on confirmation "
            "(add to stock). Owner/manager only."
        ),
        handler=_stock_in,
        management_only=True,
        args={
            "name": {"kind": "str", "default": None, "max_len": 200},
            "qty": {"kind": "float", "default": 0, "min": 0, "max": 1_000_000},
            "unit": {"kind": "str", "default": None, "max_len": 20},
            "totalCostBdt": {"kind": "float", "default": 0, "min": 0, "max": 1_000_000_000},
            "supplierName": {"kind": "str", "default": None, "max_len": 100},
            "note": {"kind": "str", "default": None, "max_len": 200},
        },
    ),
    "stock_count": ToolSpec(
        name="stock_count",
        description=(
            "PROPOSES recording the physical count of an inventory item for "
            "a day by EXACT name (call get_stock first and copy the name "
            "verbatim). Returns a count proposal the manager reviews and "
            "confirms in the app — this tool never changes stock. "
            "countDate defaults to today (Bangladesh); names not in stock "
            "are rejected, counts never create items. Owner/manager only."
        ),
        handler=_stock_count,
        management_only=True,
        args={
            "name": {"kind": "str", "default": None, "max_len": 200},
            "qty": {"kind": "float", "default": 0, "min": 0, "max": 1_000_000},
            "countDate": {"kind": "str", "default": None, "max_len": 10},
        },
    ),
    "get_daily_sales": ToolSpec(
        name="get_daily_sales",
        description=(
            "Per-day sales totals (completed orders only) for the last N "
            "days. Returns date, order count and sales in BDT."
        ),
        handler=_daily_sales,
        args={
            "days": {"kind": "int", "default": 7, "min": 1, "max": 90},
        },
    ),
}


async def execute_tool(name: str, raw_args, outlet_id: str, account=None) -> dict:
    """Validates and runs one tool. Never raises; failures return an
    ``{"ok": False, "error": ...}`` dict so the model can recover.

    ``account`` is the AdminAccount ORM object (or None for bootstrap /
    non-account callers). Management-only tools run for an owner/manager
    account or for bootstrap callers — mirroring the inventory API's
    ``_require_inventory_account`` semantics; the final authority on the
    apply side stays those same management-only endpoints.
    """
    spec = TOOLS.get(name)
    if spec is None:
        return {"ok": False, "error": f"unknown tool '{name}'"}
    if spec.management_only:
        role = account if isinstance(account, str) else getattr(account, "role", None)
        if role is not None and role not in MANAGEMENT_ROLES:
            return {
                "ok": False,
                "error": "Only the owner or manager can manage stock.",
            }
    try:
        args = validate_arguments(spec, raw_args)
        return await spec.handler(outlet_id, args)
    except Exception as exc:
        logger.warning(
            "[support_llm_tools] tool %s failed for outlet %s: %s",
            name,
            outlet_id,
            exc,
            exc_info=True,
        )
        return {"ok": False, "error": "tool failed"}
