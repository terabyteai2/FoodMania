"""Webhooks for the Sarvam Voice Agents platform (web widget channel).

These endpoints back the agent's API tools and lifecycle hooks so the hosted
Voice Agents runtime can create real orders in the Rastarant backend:

- POST /api/voice-agent/session   (on_start hook)   -> outlet context + menu
- POST /api/voice-agent/order     (place_order tool)-> validates + persists order
- POST /api/voice-agent/stock/in  (stock_in tool)   -> restock by name (+ create)
- POST /api/voice-agent/stock/count (stock_count tool) -> physical count for a day
- POST /api/voice-agent/stock/items (add_stock_item tool) -> create item if missing
- POST /api/voice-agent/end       (on_end hook)     -> transcript/outcome log

All requests must carry the shared secret as the X-Voice-Agent-Secret header;
the platform sends it from a secret stored in the Sarvam workspace. Requests
originate from Sarvam's servers (allowlist 4.213.167.70 in the firewall).
"""

import logging
import uuid
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from config import settings
from database import get_db
from models import DailyStockCount, InventoryItem, MenuItem, Outlet
from routers.inventory import (
    BDT_OFFSET,
    COMMON_INVENTORY_NAME_BN,
    _apply_stock_adjustment,
    _normalize_category,
    _normalize_name_key,
    _normalize_unit,
)
from routers.orders import create_order_record
from schemas import OrderLineItemPayload, OrderPayload, StockAdjustmentPayload, ok
from services.order_serial import format_serial

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/voice-agent", tags=["voice-agent"])

SERVICE_TYPES = frozenset({"delivery", "takeaway", "dine_in"})


def _require_tool_secret(
    x_voice_agent_secret: str | None = Header(None, alias="X-Voice-Agent-Secret"),
) -> None:
    expected = settings.VOICE_AGENT_TOOL_SECRET.strip()
    if not expected:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Voice agent tool secret is not configured.",
        )
    if not x_voice_agent_secret or x_voice_agent_secret.strip() != expected:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid voice agent secret.",
        )


async def _load_outlet(db: AsyncSession, outlet_id: str) -> Outlet:
    outlet_id = (outlet_id or "").strip()
    if not outlet_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="outletId is required.")
    outlet = await db.get(Outlet, outlet_id)
    if outlet is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Outlet not found.")
    return outlet


async def _load_menu_items(db: AsyncSession, outlet_id: str) -> list[MenuItem]:
    return (
        (
            await db.execute(
                select(MenuItem).where(
                    MenuItem.outlet_id == outlet_id,
                    MenuItem.is_available == True,
                    MenuItem.deleted_at == None,
                ).order_by(MenuItem.category, MenuItem.name).limit(300)
            )
        )
        .scalars()
        .all()
    )


async def _load_inventory_items(db: AsyncSession, outlet_id: str) -> list[InventoryItem]:
    return (
        (
            await db.execute(
                select(InventoryItem).where(
                    InventoryItem.outlet_id == outlet_id,
                    InventoryItem.deleted_at.is_(None),
                )
            )
        )
        .scalars()
        .all()
    )


# Spoken names come from STT, so matching is fuzzy. Build the common
# English↔Bengali inventory-name table once (see routers/inventory.py).
_COMMON_BN_BY_EN = {
    _normalize_name_key(en): _normalize_name_key(bn)
    for en, bn in COMMON_INVENTORY_NAME_BN.items()
}
_COMMON_EN_BY_BN: dict[str, list[str]] = {}
for _en, _bn in COMMON_INVENTORY_NAME_BN.items():
    _COMMON_EN_BY_BN.setdefault(_normalize_name_key(_bn), []).append(_normalize_name_key(_en))


def _match_inventory_items(spoken: str, items: list[InventoryItem]) -> list[InventoryItem]:
    """Resolve a spoken item name against the outlet's inventory.

    Matches on normalized keys (lowercase, alphanumeric only): exact match,
    the common EN↔BN inventory-name table (``atta`` ↔ ``আটা``), and
    one-sided substring containment for nearby transcriptions. Returns every
    plausible match so callers can surface ambiguity instead of guessing.
    """
    key = _normalize_name_key(spoken)
    if not key:
        return []
    spoken_bn = _COMMON_BN_BY_EN.get(key)
    spoken_en = _COMMON_EN_BY_BN.get(key, [])
    matches: list[InventoryItem] = []
    seen: set[str] = set()
    for item in items:
        item_key = _normalize_name_key(item.name)
        if not item_key or item.id in seen:
            continue
        if item_key == key:
            matches.append(item)
            seen.add(item.id)
        elif spoken_bn and item_key == spoken_bn:
            matches.append(item)
            seen.add(item.id)
        elif item_key in spoken_en or key in _COMMON_EN_BY_BN.get(item_key, []):
            matches.append(item)
            seen.add(item.id)
        elif key in item_key or item_key in key:
            matches.append(item)
            seen.add(item.id)
    return matches


def _error_detail(exc: Exception) -> str:
    detail = getattr(exc, "detail", None)
    return str(detail or exc)


def _tool_item_error(name: str, message: str) -> dict:
    return {"name": name, "error": message}


class VoiceSessionRequest(BaseModel):
    conversationId: str | None = None
    outletId: str = ""
    caller: str | None = None


@router.post("/session")
async def voice_agent_session_start(
    body: VoiceSessionRequest,
    _: None = Depends(_require_tool_secret),
    db: AsyncSession = Depends(get_db),
):
    """On-start hook: preload outlet context and menu into agent variables.

    Preloading here means the agent never pauses mid-call to fetch the menu.
    """
    outlet = await _load_outlet(db, body.outletId)
    outlet_id = outlet.id
    menu_items = await _load_menu_items(db, outlet_id)
    menu = [
        {
            "menuItemId": item.id,
            "name": (item.name_en or item.name or "").strip(),
            "nameBn": (item.name_bn or "").strip() or None,
            "price": float(item.price),
            "category": (item.category_en or item.category or "").strip() or None,
        }
        for item in menu_items
    ]
    logger.info(
        "[voice-agent:session] conversation=%s outlet=%s menu_items=%d",
        body.conversationId,
        outlet_id,
        len(menu),
    )
    return ok(
        {
            "conversationId": body.conversationId,
            "outletId": outlet_id,
            "outletName": outlet.name,
            "deliveryCharge": float(outlet.delivery_charge or 0),
            "vatRatePercent": float(outlet.pos_vat_rate_percent or 0),
            "menu": menu,
        }
    )


class VoiceOrderItem(BaseModel):
    menuItemId: str
    qty: int = Field(default=1, ge=1, le=99)
    name: str = ""


class VoiceOrderRequest(BaseModel):
    conversationId: str | None = None
    outletId: str = ""
    items: list[VoiceOrderItem] = Field(default_factory=list)
    customerName: str | None = None
    mobileNumber: str | None = None
    deliveryAddress: str | None = None
    serviceType: str = "delivery"
    notes: str | None = None


@router.post("/order")
async def voice_agent_place_order(
    body: VoiceOrderRequest,
    _: None = Depends(_require_tool_secret),
    db: AsyncSession = Depends(get_db),
):
    """Place-order tool: validate items against the DB menu and persist.

    Prices, VAT and delivery charge are always computed server-side from the
    outlet's own settings; the agent's item names are never trusted for money.
    """
    outlet = await _load_outlet(db, body.outletId)
    outlet_id = outlet.id

    if not body.items:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No items in the order.",
        )

    raw_ids = {item.menuItemId.strip() for item in body.items if item.menuItemId.strip()}
    menu_by_id: dict[str, MenuItem] = {}
    if raw_ids:
        found = (
            await db.execute(
                select(MenuItem).where(
                    MenuItem.outlet_id == outlet_id,
                    MenuItem.id.in_(raw_ids),
                )
            )
        ).scalars().all()
        menu_by_id = {item.id: item for item in found}

    unavailable = [
        item.menuItemId
        for item in body.items
        if item.menuItemId not in menu_by_id or not menu_by_id[item.menuItemId].is_available
    ]
    if unavailable:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"Unavailable menu items: {', '.join(unavailable)}",
        )

    line_items: list[OrderLineItemPayload] = []
    subtotal = 0.0
    for raw in body.items:
        menu_item = menu_by_id[raw.menuItemId]
        price = float(menu_item.price)
        line_total = round(price * raw.qty, 2)
        subtotal += line_total
        line_items.append(
            OrderLineItemPayload(
                menuItemId=menu_item.id,
                name=(menu_item.name_en or menu_item.name or "").strip(),
                nameEn=(menu_item.name_en or "").strip() or None,
                nameBn=(menu_item.name_bn or "").strip() or None,
                qty=raw.qty,
                price=price,
                lineTotal=line_total,
            )
        )

    service_type = (body.serviceType or "delivery").strip().lower()
    if service_type not in SERVICE_TYPES:
        service_type = "delivery"
    vat_rate = float(outlet.pos_vat_rate_percent or 0)
    vat_amount = round(subtotal * vat_rate / 100, 2)
    delivery_charge = (
        float(outlet.delivery_charge or 0) if service_type == "delivery" else 0
    )
    total = round(subtotal + vat_amount + delivery_charge, 2)

    payload = OrderPayload(
        id=str(uuid.uuid4()),
        source="voice",
        status="pending",
        totalAmount=total,
        subtotal=round(subtotal, 2),
        vatRatePercent=vat_rate,
        vatAmount=vat_amount,
        deliveryCharge=delivery_charge,
        serviceType=service_type,
        items=line_items,
        notes=(body.notes or "").strip() or None,
        customerName=(body.customerName or "").strip() or None,
        deliveryAddress=(body.deliveryAddress or "").strip() or None,
        mobileNumber=(body.mobileNumber or "").strip() or None,
        createdByRole="voice",
    )

    order = await create_order_record(db, outlet_id, payload, created_by_role="voice")
    logger.info(
        "[voice-agent:order] conversation=%s outlet=%s order=%s serial=%s total=%s",
        body.conversationId,
        outlet_id,
        order.id,
        order.serial_number,
        total,
    )
    return ok(
        {
            "conversationId": body.conversationId,
            "orderId": order.id,
            "orderCode": format_serial(order.serial_number, order.source, order.created_by_role),
            "serialNumber": order.serial_number,
            "status": order.status,
            "subtotal": float(order.subtotal or 0),
            "vatAmount": float(order.vat_amount or 0),
            "deliveryCharge": float(order.delivery_charge or 0),
            "total": float(order.total_amount or 0),
            "serviceType": order.service_type,
            "items": [
                {
                    "menuItemId": item.get("menuItemId"),
                    "name": item.get("name"),
                    "qty": item.get("qty"),
                    "price": item.get("price"),
                    "lineTotal": item.get("lineTotal"),
                }
                for item in (order.items or [])
            ],
        }
    )


class VoiceStockInItem(BaseModel):
    name: str
    qty: float = Field(gt=0, le=1_000_000)
    unit: str | None = None
    totalCostBdt: float = Field(default=0, ge=0)
    supplierName: str | None = None
    note: str | None = None


class VoiceStockInRequest(BaseModel):
    conversationId: str | None = None
    outletId: str = ""
    createIfMissing: bool = True
    items: list[VoiceStockInItem] = Field(min_length=1, max_length=50)


class VoiceCountItem(BaseModel):
    name: str
    qty: float = Field(ge=0, le=1_000_000)
    unit: str | None = None


class VoiceCountRequest(BaseModel):
    conversationId: str | None = None
    outletId: str = ""
    countDate: str | None = None
    items: list[VoiceCountItem] = Field(min_length=1, max_length=50)


class VoiceStockItemRequest(BaseModel):
    conversationId: str | None = None
    outletId: str = ""
    name: str = Field(min_length=1, max_length=200)
    unit: str | None = None
    qty: float = Field(default=0, ge=0, le=1_000_000)
    category: str | None = None
    costPerUnitBdt: float = Field(default=0, ge=0)
    minThreshold: float = Field(default=0, ge=0)


@router.post("/stock/in")
async def voice_agent_stock_in(
    body: VoiceStockInRequest,
    _: None = Depends(_require_tool_secret),
    db: AsyncSession = Depends(get_db),
):
    """Stock-in tool: add quantities to inventory by spoken item name.

    Names are matched server-side (exact, common EN↔BN aliases, substring).
    Lines that don't match are created on demand when ``createIfMissing`` is
    true and then restocked, so one request covers both "restock rice" and
    "add onion — we don't have it". Costs are optional: they only update the
    item's cost per unit (totalCostBdt / qty). One bad line never aborts the
    batch.
    """
    await _load_outlet(db, body.outletId)
    outlet_id = body.outletId
    inventory = await _load_inventory_items(db, outlet_id)

    results: list[dict] = []
    ok_count = 0
    for raw in body.items:
        name = (raw.name or "").strip()
        if not name:
            results.append(_tool_item_error(raw.name, "Item name is missing."))
            continue
        matches = _match_inventory_items(name, inventory)
        if len(matches) > 1:
            candidates = ", ".join(item.name for item in matches)
            results.append(
                _tool_item_error(name, f"Ambiguous item name — candidates: {candidates}.")
            )
            continue
        try:
            if matches:
                item = matches[0]
                created = False
            elif body.createIfMissing:
                now = datetime.now(timezone.utc)
                item = InventoryItem(
                    id=str(uuid.uuid4()),
                    outlet_id=outlet_id,
                    name=name,
                    category="other",
                    unit=_normalize_unit(raw.unit),
                    quantity=0,
                    min_threshold=0,
                    cost_per_unit=0,
                    notes="",
                    created_at=now,
                    updated_at=now,
                )
                db.add(item)
                created = True
                inventory.append(item)
            else:
                results.append(_tool_item_error(name, "Item not found in stock."))
                continue
            quantity_before = float(item.quantity)
            _, adjustment = await _apply_stock_adjustment(
                db,
                outlet_id,
                StockAdjustmentPayload(
                    inventoryItemId=item.id,
                    delta=raw.qty,
                    type="restock",
                    note=raw.note or "",
                    totalCostBdt=raw.totalCostBdt,
                    supplierName=raw.supplierName or "",
                    reason="voice_agent_stock_in",
                ),
                None,
            )
            adjustment.created_by_role = "voice_agent"
            quantity_after = float(item.quantity)
            ok_count += 1
            results.append(
                {
                    "name": item.name,
                    "matched": not created,
                    "created": created,
                    "itemId": item.id,
                    "unit": item.unit or "pcs",
                    "quantityBefore": quantity_before,
                    "quantityAfter": quantity_after,
                    "unitCostBdt": float(item.cost_per_unit or 0),
                }
            )
        except Exception as exc:
            logger.warning(
                "[voice-agent:stock-in] line failed outlet=%s name=%s: %s",
                outlet_id,
                name,
                exc,
            )
            results.append(_tool_item_error(name, f"Could not apply stock-in: {_error_detail(exc)}"))
    await db.commit()
    logger.info(
        "[voice-agent:stock-in] conversation=%s outlet=%s ok=%d errors=%d",
        body.conversationId,
        outlet_id,
        ok_count,
        len(results) - ok_count,
    )
    return ok(
        {
            "conversationId": body.conversationId,
            "okCount": ok_count,
            "errorCount": len(results) - ok_count,
            "items": results,
        }
    )


@router.post("/stock/count")
async def voice_agent_stock_count(
    body: VoiceCountRequest,
    _: None = Depends(_require_tool_secret),
    db: AsyncSession = Depends(get_db),
):
    """Stock-count tool: record the physical count for a day by spoken name.

    Each line sets the item's current quantity to the counted amount and
    upserts a daily-stock-count row (defaults to today, Bangladesh local
    time), matching the app's count flow. Unknown items are reported per
    line — they are never auto-created here.
    """
    await _load_outlet(db, body.outletId)
    outlet_id = body.outletId
    if body.countDate and (body.countDate or "").strip():
        try:
            count_date = date.fromisoformat(body.countDate.strip())
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="countDate must be YYYY-MM-DD.",
            ) from exc
        count_date = count_date.isoformat()
    else:
        count_date = (datetime.now(timezone.utc) + BDT_OFFSET).date().isoformat()

    inventory = await _load_inventory_items(db, outlet_id)
    results: list[dict] = []
    ok_count = 0
    for raw in body.items:
        name = (raw.name or "").strip()
        if not name:
            results.append(_tool_item_error(raw.name, "Item name is missing."))
            continue
        matches = _match_inventory_items(name, inventory)
        if len(matches) > 1:
            candidates = ", ".join(item.name for item in matches)
            results.append(
                _tool_item_error(name, f"Ambiguous item name — candidates: {candidates}.")
            )
            continue
        if not matches:
            results.append(_tool_item_error(name, "Item not found in stock."))
            continue
        item = matches[0]
        try:
            existing = (
                await db.execute(
                    select(DailyStockCount).where(
                        DailyStockCount.outlet_id == outlet_id,
                        DailyStockCount.inventory_item_id == item.id,
                        DailyStockCount.count_date == count_date,
                    )
                )
            ).scalar_one_or_none()
            now = datetime.now(timezone.utc)
            if existing:
                existing.quantity = raw.qty
                existing.created_at = now
            else:
                db.add(
                    DailyStockCount(
                        id=str(uuid.uuid4()),
                        outlet_id=outlet_id,
                        inventory_item_id=item.id,
                        count_date=count_date,
                        quantity=raw.qty,
                        created_at=now,
                    )
                )
            item.quantity = max(0.0, float(raw.qty))
            item.updated_at = now
            ok_count += 1
            results.append(
                {
                    "name": item.name,
                    "itemId": item.id,
                    "unit": item.unit or "pcs",
                    "countDate": count_date,
                    "quantity": float(raw.qty),
                }
            )
        except Exception as exc:
            logger.warning(
                "[voice-agent:stock-count] line failed outlet=%s name=%s: %s",
                outlet_id,
                name,
                exc,
            )
            results.append(_tool_item_error(name, f"Could not record count: {_error_detail(exc)}"))
    await db.commit()
    logger.info(
        "[voice-agent:stock-count] conversation=%s outlet=%s date=%s ok=%d errors=%d",
        body.conversationId,
        outlet_id,
        count_date,
        ok_count,
        len(results) - ok_count,
    )
    return ok(
        {
            "conversationId": body.conversationId,
            "countDate": count_date,
            "okCount": ok_count,
            "errorCount": len(results) - ok_count,
            "items": results,
        }
    )


@router.post("/stock/items")
async def voice_agent_add_stock_item(
    body: VoiceStockItemRequest,
    _: None = Depends(_require_tool_secret),
    db: AsyncSession = Depends(get_db),
):
    """Add-to-stock tool: create an inventory item when it doesn't exist.

    Returns the existing item (``created: False``) when the name already
    matches, so the agent can route to the stock-in tool instead of
    duplicating the item.
    """
    await _load_outlet(db, body.outletId)
    outlet_id = body.outletId
    name = (body.name or "").strip()
    if not name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Item name is required.",
        )
    inventory = await _load_inventory_items(db, outlet_id)
    matches = _match_inventory_items(name, inventory)
    if len(matches) > 1:
        candidates = ", ".join(item.name for item in matches)
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Ambiguous item name — candidates: {candidates}.",
        )
    if matches:
        item = matches[0]
        return ok(
            {
                "conversationId": body.conversationId,
                "name": item.name,
                "itemId": item.id,
                "unit": item.unit or "pcs",
                "quantity": float(item.quantity),
                "category": item.category or "",
                "created": False,
            }
        )

    now = datetime.now(timezone.utc)
    item = InventoryItem(
        id=str(uuid.uuid4()),
        outlet_id=outlet_id,
        name=name,
        category=_normalize_category(body.category),
        unit=_normalize_unit(body.unit),
        quantity=float(body.qty),
        min_threshold=float(body.minThreshold),
        cost_per_unit=float(body.costPerUnitBdt),
        notes="",
        created_at=now,
        updated_at=now,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    logger.info(
        "[voice-agent:stock-items] conversation=%s outlet=%s created=%s",
        body.conversationId,
        outlet_id,
        item.id,
    )
    return ok(
        {
            "conversationId": body.conversationId,
            "name": item.name,
            "itemId": item.id,
            "unit": item.unit or "pcs",
            "quantity": float(item.quantity),
            "category": item.category or "",
            "minThreshold": float(item.min_threshold),
            "costPerUnitBdt": float(item.cost_per_unit),
            "created": True,
        }
    )


class VoiceEndRequest(BaseModel):
    conversationId: str | None = None
    outletId: str = ""
    outcome: dict | None = None
    transcript: list | None = None


@router.post("/end")
async def voice_agent_end(
    body: VoiceEndRequest,
    _: None = Depends(_require_tool_secret),
):
    """On-end hook: record the conversation outcome (transcript stays in
    Sarvam's analytics; we keep a short log line for diagnostics)."""
    outcome = body.outcome or {}
    logger.info(
        "[voice-agent:end] conversation=%s outlet=%s outcome=%s",
        body.conversationId,
        body.outletId,
        outcome,
    )
    return ok({"accepted": True})
