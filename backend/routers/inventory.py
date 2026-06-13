import logging
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from typing import Any
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_device_payload, get_current_outlet_id
from database import get_db
from models import AdminAccount, DailyStockCount, InventoryItem, InventorySupplier, Order, StockAdjustment
from routers.menu import _ensure_outlet, _parse_since
from schemas import (
    DailyStockCountPayload,
    InventoryItemPayload,
    InventorySupplierPatchPayload,
    InventorySupplierPayload,
    StockAdjustmentBatchPayload,
    StockAdjustmentPayload,
    ok,
)
from services.receipt_scan import (
    ReceiptScanError,
    extract_receipt_page_texts,
    parse_receipt_text,
)

router = APIRouter()
logger = logging.getLogger(__name__)

ADJUSTMENT_TYPES = {"restock", "usage", "waste", "correction"}

# Run on Bangladesh local time so "today's spend / variance" matches the wall clock.
BDT_OFFSET = timedelta(hours=6)
VARIANCE_TOLERANCE = 0.05  # ignore tiny rounding noise below 5% of a unit
COMMON_INVENTORY_NAME_BN = {
    "atta": "আটা",
    "banana": "কলা",
    "beef": "বিফ",
    "beef bone": "বিফ হাড়",
    "bread": "পাউরুটি",
    "bun": "বান",
    "butter": "বাটার",
    "cabbage": "বাঁধাকপি",
    "capsicum": "ক্যাপসিকাম",
    "carrot": "গাজর",
    "cheese": "চিজ",
    "chicken": "চিকেন",
    "chicken breast": "চিকেন ব্রেস্ট",
    "chicken leg": "চিকেন লেগ",
    "chili": "মরিচ",
    "chilli": "মরিচ",
    "coriander": "ধনিয়া",
    "coriander leaves": "ধনেপাতা",
    "cream": "ক্রিম",
    "cucumber": "শসা",
    "curd": "দই",
    "dal": "ডাল",
    "egg": "ডিম",
    "fish": "মাছ",
    "flour": "ময়দা",
    "garam masala": "গরম মসলা",
    "garlic": "রসুন",
    "ginger": "আদা",
    "green chili": "কাঁচা মরিচ",
    "green chilli": "কাঁচা মরিচ",
    "ketchup": "কেচাপ",
    "lemon": "লেবু",
    "lime": "লেবু",
    "maida": "ময়দা",
    "masala": "মসলা",
    "mayonnaise": "মেয়োনিজ",
    "milk": "দুধ",
    "mint": "পুদিনা",
    "mustard oil": "সরিষার তেল",
    "mutton": "মাটন",
    "noodles": "নুডলস",
    "oil": "তেল",
    "onion": "পেঁয়াজ",
    "pasta": "পাস্তা",
    "potato": "আলু",
    "red chili": "শুকনা মরিচ",
    "red chilli": "শুকনা মরিচ",
    "rice": "চাল",
    "salt": "লবণ",
    "sauce": "সস",
    "soy sauce": "সয়া সস",
    "soybean oil": "সয়াবিন তেল",
    "spice": "মসলা",
    "spices": "মসলা",
    "sugar": "চিনি",
    "tea": "চা",
    "tomato": "টমেটো",
    "tomato sauce": "টমেটো সস",
    "turmeric": "হলুদ",
    "vinegar": "ভিনেগার",
    "water": "পানি",
    "yogurt": "দই",
}


def _bdt_day_bounds(reference: datetime) -> tuple[datetime, datetime]:
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


def _parse_date_param(value: str | None) -> date:
    if not value:
        local = (datetime.now(timezone.utc) + BDT_OFFSET).date()
        return local
    try:
        return date.fromisoformat(value)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid date — expected YYYY-MM-DD.",
        ) from exc


def _normalize_category(value: str | None) -> str:
    raw = (value or "").strip().lower()
    if raw in {"raw", "kacha", "kaccha", "fresh", "produce"}:
        return "raw"
    if raw in {"dry", "shukno", "spice", "spices", "grain", "grains"}:
        return "dry"
    if raw in {"packaged", "packet", "boxed", "tin", "canned"}:
        return "packaged"
    if raw:
        return raw
    return "other"


def _category_label(key: str) -> tuple[str, str]:
    mapping = {
        "raw": ("Raw", "কাঁচা"),
        "dry": ("Dry", "শুকনা"),
        "packaged": ("Packaged", "প্যাকেট"),
        "other": ("Other", "অন্যান্য"),
    }
    return mapping.get(key, (key.title(), key.title()))


def _split_bilingual(name: str) -> tuple[str, str]:
    name = name.strip()
    if "/" in name:
        en, bn = name.split("/", 1)
        return en.strip(), bn.strip()
    if any("\u0980" <= char <= "\u09ff" for char in name):
        return "", name
    return name, _bangla_fallback_name(name)


def _normalize_name_key(value: str) -> str:
    normalized = value.strip().lower()
    chars = [char if char.isalnum() else " " for char in normalized]
    return " ".join("".join(chars).split())


def _bangla_fallback_name(value: str) -> str:
    key = _normalize_name_key(value)
    if not key:
        return ""
    if key in COMMON_INVENTORY_NAME_BN:
        return COMMON_INVENTORY_NAME_BN[key]
    if key.endswith("s") and key[:-1] in COMMON_INVENTORY_NAME_BN:
        return COMMON_INVENTORY_NAME_BN[key[:-1]]
    words = key.split()
    if len(words) > 1 and all(word in COMMON_INVENTORY_NAME_BN for word in words):
        return " ".join(COMMON_INVENTORY_NAME_BN[word] for word in words)
    return ""


def _item_to_dict(item: InventoryItem) -> dict:
    return {
        "id": item.id,
        "outletId": item.outlet_id,
        "name": item.name,
        "category": item.category or "",
        "unit": item.unit or "pcs",
        "quantity": float(item.quantity),
        "minThreshold": float(item.min_threshold),
        "costPerUnit": float(item.cost_per_unit),
        "notes": item.notes or "",
        "defaultSupplierId": item.default_supplier_id,
        "defaultReorderQty": float(item.default_reorder_qty or 0),
        "createdAt": item.created_at.isoformat(),
        "updatedAt": item.updated_at.isoformat(),
        "deletedAt": item.deleted_at.isoformat() if item.deleted_at else None,
    }


def _adjustment_to_dict(row: StockAdjustment) -> dict:
    return {
        "id": row.id,
        "inventoryItemId": row.inventory_item_id,
        "delta": float(row.delta),
        "type": row.type,
        "note": row.note or "",
        "totalCostBdt": float(row.total_cost_bdt),
        "supplierId": row.supplier_id,
        "supplierName": row.supplier_name or "",
        "reason": row.reason or "",
        "billRef": row.bill_ref or "",
        "createdByAccountId": row.created_by_account_id,
        "createdByRole": row.created_by_role,
        "createdAt": row.created_at.isoformat(),
    }


def _supplier_to_dict(row: InventorySupplier) -> dict:
    return {
        "id": row.id,
        "name": row.name,
        "phone": row.phone or "",
        "notes": row.notes or "",
        "isActive": bool(row.is_active),
        "createdAt": row.created_at.isoformat(),
        "updatedAt": row.updated_at.isoformat(),
    }


def _daily_count_to_dict(row: DailyStockCount) -> dict:
    return {
        "id": row.id,
        "inventoryItemId": row.inventory_item_id,
        "countDate": row.count_date,
        "quantity": float(row.quantity),
        "createdAt": row.created_at.isoformat(),
    }


def _normalize_unit(value: str | None) -> str:
    unit = (value or "pcs").strip().lower()
    if unit in {"kg", "gm", "ltr", "ml", "pcs"}:
        return unit
    return "pcs"


async def _get_item(
    db: AsyncSession, outlet_id: str, item_id: str, *, allow_deleted: bool = False
) -> InventoryItem:
    item = (
        await db.execute(
            select(InventoryItem).where(
                InventoryItem.id == item_id,
                InventoryItem.outlet_id == outlet_id,
            )
        )
    ).scalar_one_or_none()
    if item is None or (item.deleted_at is not None and not allow_deleted):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inventory item not found.")
    return item


async def _require_inventory_account(
    db: AsyncSession,
    outlet_id: str,
    payload: dict,
    *,
    manager_only: bool = False,
) -> AdminAccount | None:
    account_id = str(payload.get("account_id") or "")
    if not account_id:
        # Bootstrap and older devices hold an outlet-scoped token until the
        # first account login. Preserve that setup path; role checks apply as
        # soon as a token carries an account id.
        return None
    account = (
        await db.execute(
            select(AdminAccount).where(
                AdminAccount.id == account_id,
                AdminAccount.outlet_id == outlet_id,
                AdminAccount.is_active.is_(True),
            )
        )
    ).scalar_one_or_none()
    if account is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Active account required.")
    if manager_only and account.role not in ("owner", "manager"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Manager access required.")
    return account


@router.get("/outlets/{outlet_id}/inventory")
async def pull_inventory(
    outlet_id: str,
    since: str | None = None,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    """Pull inventory items, stock adjustments, and daily counts changed since `since`."""
    _ensure_outlet(current_outlet, outlet_id)
    since_dt = _parse_since(since) if since else None

    item_query = select(InventoryItem).where(InventoryItem.outlet_id == outlet_id)
    if since_dt:
        item_query = item_query.where(InventoryItem.updated_at > since_dt)
    items = (await db.execute(item_query)).scalars().all()

    adj_query = select(StockAdjustment).where(StockAdjustment.outlet_id == outlet_id)
    if since_dt:
        adj_query = adj_query.where(StockAdjustment.created_at > since_dt)
    adjustments = (await db.execute(adj_query.order_by(StockAdjustment.created_at.asc()))).scalars().all()

    count_query = select(DailyStockCount).where(DailyStockCount.outlet_id == outlet_id)
    if since_dt:
        count_query = count_query.where(DailyStockCount.created_at > since_dt)
    daily_counts = (await db.execute(count_query.order_by(DailyStockCount.created_at.asc()))).scalars().all()
    suppliers = (
        await db.execute(
            select(InventorySupplier)
            .where(InventorySupplier.outlet_id == outlet_id)
            .order_by(InventorySupplier.name.asc())
        )
    ).scalars().all()

    return ok(
        {
            "items": [_item_to_dict(i) for i in items],
            "adjustments": [_adjustment_to_dict(a) for a in adjustments],
            "dailyCounts": [_daily_count_to_dict(c) for c in daily_counts],
            "suppliers": [_supplier_to_dict(s) for s in suppliers],
        }
    )


@router.post("/outlets/{outlet_id}/inventory/items")
async def upsert_inventory_item(
    outlet_id: str,
    body: InventoryItemPayload,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(str(payload["sub"]), outlet_id)
    await _require_inventory_account(db, outlet_id, payload, manager_only=True)
    now = datetime.now(timezone.utc)
    created_at = now
    if body.createdAt:
        try:
            created_at = datetime.fromisoformat(body.createdAt.replace("Z", "+00:00"))
            if created_at.tzinfo is None:
                created_at = created_at.replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    updated_at = now
    if body.updatedAt:
        try:
            updated_at = datetime.fromisoformat(body.updatedAt.replace("Z", "+00:00"))
            if updated_at.tzinfo is None:
                updated_at = updated_at.replace(tzinfo=timezone.utc)
        except ValueError:
            pass

    existing = (
        await db.execute(
            select(InventoryItem).where(
                InventoryItem.id == body.id,
                InventoryItem.outlet_id == outlet_id,
            )
        )
    ).scalar_one_or_none()

    if existing:
        if existing.updated_at > updated_at:
            return ok(_item_to_dict(existing))
        existing.name = body.name
        existing.category = body.category or ""
        existing.unit = _normalize_unit(body.unit)
        existing.quantity = body.quantity
        existing.min_threshold = body.minThreshold
        existing.cost_per_unit = body.costPerUnit
        existing.notes = body.notes or ""
        existing.default_supplier_id = body.defaultSupplierId
        existing.default_reorder_qty = body.defaultReorderQty
        existing.updated_at = updated_at
        existing.deleted_at = None
        await db.commit()
        await db.refresh(existing)
        return ok(_item_to_dict(existing))

    item = InventoryItem(
        id=body.id,
        outlet_id=outlet_id,
        name=body.name,
        category=body.category or "",
        unit=_normalize_unit(body.unit),
        quantity=body.quantity,
        min_threshold=body.minThreshold,
        cost_per_unit=body.costPerUnit,
        notes=body.notes or "",
        default_supplier_id=body.defaultSupplierId,
        default_reorder_qty=body.defaultReorderQty,
        created_at=created_at,
        updated_at=updated_at,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return ok(_item_to_dict(item))


@router.delete("/outlets/{outlet_id}/inventory/items/{item_id}")
async def delete_inventory_item(
    outlet_id: str,
    item_id: str,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(str(payload["sub"]), outlet_id)
    await _require_inventory_account(db, outlet_id, payload, manager_only=True)
    item = await _get_item(db, outlet_id, item_id)
    now = datetime.now(timezone.utc)
    item.deleted_at = now
    item.updated_at = now
    await db.commit()
    return ok({"id": item_id, "deletedAt": now.isoformat()})


@router.get("/outlets/{outlet_id}/inventory/suppliers")
async def list_inventory_suppliers(
    outlet_id: str,
    include_archived: bool = False,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
    query = select(InventorySupplier).where(InventorySupplier.outlet_id == outlet_id)
    if not include_archived:
        query = query.where(InventorySupplier.is_active.is_(True))
    rows = (await db.execute(query.order_by(InventorySupplier.name.asc()))).scalars().all()
    return ok([_supplier_to_dict(row) for row in rows])


@router.post("/outlets/{outlet_id}/inventory/suppliers")
async def create_inventory_supplier(
    outlet_id: str,
    body: InventorySupplierPayload,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(str(payload["sub"]), outlet_id)
    await _require_inventory_account(db, outlet_id, payload, manager_only=True)
    row = InventorySupplier(
        id=body.id or str(uuid4()),
        outlet_id=outlet_id,
        name=body.name.strip(),
        phone=(body.phone or "").strip(),
        notes=(body.notes or "").strip(),
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return ok(_supplier_to_dict(row))


@router.patch("/outlets/{outlet_id}/inventory/suppliers/{supplier_id}")
async def update_inventory_supplier(
    outlet_id: str,
    supplier_id: str,
    body: InventorySupplierPatchPayload,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(str(payload["sub"]), outlet_id)
    await _require_inventory_account(db, outlet_id, payload, manager_only=True)
    row = (
        await db.execute(
            select(InventorySupplier).where(
                InventorySupplier.id == supplier_id,
                InventorySupplier.outlet_id == outlet_id,
            )
        )
    ).scalar_one_or_none()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Supplier not found.")
    if body.name is not None:
        row.name = body.name.strip()
    if body.phone is not None:
        row.phone = body.phone.strip()
    if body.notes is not None:
        row.notes = body.notes.strip()
    if body.isActive is not None:
        row.is_active = body.isActive
    row.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(row)
    return ok(_supplier_to_dict(row))


@router.delete("/outlets/{outlet_id}/inventory/suppliers/{supplier_id}")
async def archive_inventory_supplier(
    outlet_id: str,
    supplier_id: str,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    return await update_inventory_supplier(
        outlet_id,
        supplier_id,
        InventorySupplierPatchPayload(isActive=False),
        payload,
        db,
    )


async def _apply_stock_adjustment(
    db: AsyncSession,
    outlet_id: str,
    body: StockAdjustmentPayload,
    account: AdminAccount | None,
) -> tuple[InventoryItem, StockAdjustment]:
    adj_type = (body.type or "correction").strip().lower()
    if adj_type not in ADJUSTMENT_TYPES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid adjustment type.")
    existing_adj = (
        await db.execute(select(StockAdjustment).where(StockAdjustment.id == body.id))
    ).scalar_one_or_none()
    if existing_adj:
        return await _get_item(db, outlet_id, existing_adj.inventory_item_id), existing_adj
    item = await _get_item(db, outlet_id, body.inventoryItemId)
    new_qty = max(0.0, float(item.quantity) + float(body.delta))
    cost_per_unit = float(item.cost_per_unit)
    if adj_type == "restock" and body.delta > 0 and body.totalCostBdt > 0:
        cost_per_unit = body.totalCostBdt / body.delta
    created_at = datetime.now(timezone.utc)
    if body.createdAt:
        try:
            created_at = datetime.fromisoformat(body.createdAt.replace("Z", "+00:00"))
            if created_at.tzinfo is None:
                created_at = created_at.replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    supplier_name = (body.supplierName or "").strip()
    if body.supplierId:
        supplier = (
            await db.execute(
                select(InventorySupplier).where(
                    InventorySupplier.id == body.supplierId,
                    InventorySupplier.outlet_id == outlet_id,
                )
            )
        ).scalar_one_or_none()
        if supplier is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid supplier.")
        supplier_name = supplier.name
    adjustment = StockAdjustment(
        id=body.id or str(uuid4()),
        outlet_id=outlet_id,
        inventory_item_id=body.inventoryItemId,
        delta=body.delta,
        type=adj_type,
        note=body.note or "",
        total_cost_bdt=body.totalCostBdt,
        supplier_id=body.supplierId,
        supplier_name=supplier_name,
        reason=(body.reason or "").strip(),
        bill_ref=(body.billRef or "").strip(),
        invoice_ref=(body.billRef or "").strip(),
        created_by_account_id=account.id if account else None,
        created_by_role=account.role if account else None,
        created_at=created_at,
    )
    item.quantity = new_qty
    item.cost_per_unit = cost_per_unit
    item.updated_at = datetime.now(timezone.utc)
    db.add(adjustment)
    return item, adjustment


@router.post("/outlets/{outlet_id}/inventory/adjustments")
async def record_stock_adjustment(
    outlet_id: str,
    body: StockAdjustmentPayload,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(str(payload["sub"]), outlet_id)
    account = await _require_inventory_account(db, outlet_id, payload)
    item, adjustment = await _apply_stock_adjustment(db, outlet_id, body, account)
    await db.commit()
    await db.refresh(item)
    await db.refresh(adjustment)
    return ok({"item": _item_to_dict(item), "adjustment": _adjustment_to_dict(adjustment)})


@router.post("/outlets/{outlet_id}/inventory/adjustments/batch")
async def record_stock_adjustment_batch(
    outlet_id: str,
    body: StockAdjustmentBatchPayload,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(str(payload["sub"]), outlet_id)
    account = await _require_inventory_account(db, outlet_id, payload)
    results = [
        await _apply_stock_adjustment(db, outlet_id, adjustment, account)
        for adjustment in body.adjustments
    ]
    await db.commit()
    return ok(
        {
            "items": [_item_to_dict(item) for item, _ in results],
            "adjustments": [_adjustment_to_dict(row) for _, row in results],
        }
    )


@router.post("/outlets/{outlet_id}/inventory/daily-counts")
async def upsert_daily_stock_count(
    outlet_id: str,
    body: DailyStockCountPayload,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(str(payload["sub"]), outlet_id)
    await _require_inventory_account(db, outlet_id, payload)
    await _get_item(db, outlet_id, body.inventoryItemId)

    existing = (
        await db.execute(
            select(DailyStockCount).where(
                DailyStockCount.outlet_id == outlet_id,
                DailyStockCount.inventory_item_id == body.inventoryItemId,
                DailyStockCount.count_date == body.countDate,
            )
        )
    ).scalar_one_or_none()

    now = datetime.now(timezone.utc)
    if existing:
        existing.quantity = body.quantity
        existing.created_at = now
        row = existing
    else:
        row = DailyStockCount(
            id=body.id or str(uuid4()),
            outlet_id=outlet_id,
            inventory_item_id=body.inventoryItemId,
            count_date=body.countDate,
            quantity=body.quantity,
            created_at=now,
        )
        db.add(row)

    item = await _get_item(db, outlet_id, body.inventoryItemId)
    item.quantity = max(0.0, float(body.quantity))
    item.updated_at = now
    await db.commit()
    await db.refresh(row)
    await db.refresh(item)
    return ok({"item": _item_to_dict(item), "dailyCount": _daily_count_to_dict(row)})


# ── Summary, daily report, receipt scan ───────────────────────────────────────


@router.get("/outlets/{outlet_id}/inventory/summary")
async def inventory_summary(
    outlet_id: str,
    as_of: str | None = None,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
    now = _parse_as_of(as_of)
    today_start, today_end = _bdt_day_bounds(now)
    today_local = (today_start + BDT_OFFSET).date().isoformat()

    items = (
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

    today_counts = (
        await db.execute(
            select(DailyStockCount)
            .where(DailyStockCount.outlet_id == outlet_id)
            .where(DailyStockCount.count_date == today_local)
        )
    ).scalars().all()
    count_by_item = {row.inventory_item_id: float(row.quantity) for row in today_counts}

    in_by_item: dict[str, float] = defaultdict(float)
    out_by_item: dict[str, float] = defaultdict(float)
    spend_by_item: dict[str, float] = defaultdict(float)
    for adj in today_adjustments:
        delta = float(adj.delta or 0)
        kind = (adj.type or "").lower()
        if kind == "restock":
            in_by_item[adj.inventory_item_id] += max(delta, 0.0)
            spend_by_item[adj.inventory_item_id] += float(adj.total_cost_bdt or 0)
        elif kind in {"usage", "waste"}:
            out_by_item[adj.inventory_item_id] += abs(delta) if delta < 0 else delta
        elif kind == "correction" and delta < 0:
            out_by_item[adj.inventory_item_id] += abs(delta)
        elif kind == "correction" and delta > 0:
            in_by_item[adj.inventory_item_id] += delta

    stock_value = 0.0
    variance_total_bdt = 0.0
    variance_item_count = 0
    alerts = 0
    category_counts: dict[str, int] = defaultdict(int)
    summary_items: list[dict[str, Any]] = []

    for item in items:
        on_hand = float(item.quantity or 0)
        threshold = float(item.min_threshold or 0)
        cost_per_unit = float(item.cost_per_unit or 0)
        category_key = _normalize_category(item.category)
        category_counts[category_key] += 1
        stock_value += on_hand * cost_per_unit

        item_in = float(in_by_item.get(item.id, 0.0))
        item_out = float(out_by_item.get(item.id, 0.0))

        if on_hand <= 0:
            status_key = "out"
            variance_qty = 0.0
        elif threshold > 0 and on_hand <= threshold:
            status_key = "low"
            variance_qty = 0.0
        else:
            status_key = "ok"
            variance_qty = 0.0

        counted = count_by_item.get(item.id)
        if counted is not None:
            expected = on_hand  # current quantity already reflects today's adjustments
            diff = round(counted - expected, 4)
            if abs(diff) > VARIANCE_TOLERANCE:
                status_key = "variance"
                variance_qty = diff
                variance_total_bdt += diff * cost_per_unit
                variance_item_count += 1

        if status_key in {"out", "low", "variance"}:
            alerts += 1

        en, bn = _split_bilingual(item.name)
        summary_items.append(
            {
                "id": item.id,
                "nameEn": en or item.name,
                "nameBn": bn,
                "category": category_key,
                "unit": item.unit or "pcs",
                "onHand": round(on_hand, 3),
                "minThreshold": round(threshold, 3),
                "todayIn": round(item_in, 3),
                "todayOut": round(item_out, 3),
                "todaySpendBdt": round(spend_by_item.get(item.id, 0.0), 2),
                "varianceQty": round(variance_qty, 3),
                "varianceStatus": status_key,
                "costPerUnit": round(cost_per_unit, 2),
            }
        )

    categories = [
        {
            "key": key,
            "labelEn": _category_label(key)[0],
            "labelBn": _category_label(key)[1],
            "count": count,
        }
        for key, count in sorted(category_counts.items(), key=lambda kv: kv[0])
    ]
    categories.insert(
        0,
        {"key": "all", "labelEn": "All", "labelBn": "সব", "count": len(summary_items)},
    )

    return ok(
        {
            "asOf": now.astimezone(timezone.utc).isoformat(),
            "stockValueBdt": round(stock_value, 2),
            "varianceTodayBdt": round(variance_total_bdt, 2),
            "varianceItemCount": variance_item_count,
            "alerts": alerts,
            "categories": categories,
            "items": summary_items,
        }
    )


def _expected_from_history(
    start_qty: float,
    adjustments: list[StockAdjustment],
) -> float:
    expected = start_qty
    for adj in adjustments:
        delta = float(adj.delta or 0)
        kind = (adj.type or "").lower()
        if kind == "restock":
            expected += max(delta, 0.0)
        elif kind in {"usage", "waste"}:
            expected -= abs(delta) if delta < 0 else delta
        elif kind == "correction":
            expected += delta
    return max(expected, 0.0)


@router.get("/outlets/{outlet_id}/inventory/daily-report")
async def inventory_daily_report(
    outlet_id: str,
    date_param: str | None = Query(default=None, alias="date"),
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
    target_date = _parse_date_param(date_param)
    target_str = target_date.isoformat()
    yesterday_str = (target_date - timedelta(days=1)).isoformat()
    four_weeks_ago = target_date - timedelta(days=28)
    day_start = datetime.combine(target_date, datetime.min.time(), tzinfo=timezone(BDT_OFFSET)).astimezone(timezone.utc)
    day_end = day_start + timedelta(days=1)

    items = (
        await db.execute(
            select(InventoryItem)
            .where(InventoryItem.outlet_id == outlet_id)
            .where(InventoryItem.deleted_at.is_(None))
        )
    ).scalars().all()
    item_lookup = {item.id: item for item in items}

    today_counts = (
        await db.execute(
            select(DailyStockCount)
            .where(DailyStockCount.outlet_id == outlet_id)
            .where(DailyStockCount.count_date == target_str)
        )
    ).scalars().all()

    yesterday_counts = (
        await db.execute(
            select(DailyStockCount)
            .where(DailyStockCount.outlet_id == outlet_id)
            .where(DailyStockCount.count_date == yesterday_str)
        )
    ).scalars().all()
    yest_lookup = {row.inventory_item_id: float(row.quantity) for row in yesterday_counts}

    day_adjustments = (
        await db.execute(
            select(StockAdjustment)
            .where(StockAdjustment.outlet_id == outlet_id)
            .where(StockAdjustment.created_at >= day_start)
            .where(StockAdjustment.created_at < day_end)
        )
    ).scalars().all()
    adj_by_item: dict[str, list[StockAdjustment]] = defaultdict(list)
    for adj in day_adjustments:
        adj_by_item[adj.inventory_item_id].append(adj)

    recent_counts = (
        await db.execute(
            select(DailyStockCount)
            .where(DailyStockCount.outlet_id == outlet_id)
            .where(DailyStockCount.count_date >= four_weeks_ago.isoformat())
            .where(DailyStockCount.count_date < target_str)
        )
    ).scalars().all()

    breakdown: list[dict[str, Any]] = []
    unexplained = 0.0
    variance_items = 0

    for row in today_counts:
        item = item_lookup.get(row.inventory_item_id)
        if not item:
            continue
        start_qty = yest_lookup.get(row.inventory_item_id, float(item.quantity or 0))
        expected = _expected_from_history(start_qty, adj_by_item.get(row.inventory_item_id, []))
        actual = float(row.quantity)
        diff = round(actual - expected, 3)
        if abs(diff) <= VARIANCE_TOLERANCE:
            continue
        cost_per_unit = float(item.cost_per_unit or 0)
        unexplained += diff * cost_per_unit
        variance_items += 1

        # Count past weeks where the same item showed expected > actual.
        recurring_weeks = 0
        seen_weeks: set[int] = set()
        for past in recent_counts:
            if past.inventory_item_id != row.inventory_item_id:
                continue
            try:
                past_date = date.fromisoformat(past.count_date)
            except ValueError:
                continue
            days_ago = (target_date - past_date).days
            week_bucket = days_ago // 7
            if week_bucket in seen_weeks:
                continue
            past_qty = float(past.quantity)
            if past_qty < start_qty - VARIANCE_TOLERANCE:
                seen_weeks.add(week_bucket)
                recurring_weeks += 1

        en, bn = _split_bilingual(item.name)
        note_en = "Recurring pattern — review?" if recurring_weeks >= 2 else ""
        breakdown.append(
            {
                "itemId": item.id,
                "nameEn": en or item.name,
                "nameBn": bn,
                "varianceQty": diff,
                "unit": item.unit or "pcs",
                "expectedQty": round(expected, 3),
                "actualQty": round(actual, 3),
                "recurringWeeks": recurring_weeks,
                "noteEn": note_en,
                "varianceBdt": round(diff * cost_per_unit, 2),
            }
        )

    breakdown.sort(key=lambda r: abs(r["varianceBdt"]), reverse=True)

    reorder_suggestions: list[dict[str, Any]] = []
    for item in items:
        on_hand = float(item.quantity or 0)
        threshold = float(item.min_threshold or 0)
        if threshold > 0 and on_hand <= threshold and on_hand > 0:
            qty_to_order = max(threshold * 2 - on_hand, threshold)
            en, bn = _split_bilingual(item.name)
            unit = item.unit or "pcs"
            reorder_suggestions.append(
                {
                    "itemId": item.id,
                    "nameEn": en or item.name,
                    "nameBn": bn,
                    "qtyToOrder": round(qty_to_order, 2),
                    "unit": unit,
                    "ctaEn": f"{en or item.name} below par · order ~{round(qty_to_order, 1)} {unit} before noon",
                    "supplierId": item.default_supplier_id,
                    "defaultReorderQty": round(float(item.default_reorder_qty or 0), 2),
                }
            )

    headline_en = ""
    if breakdown:
        worst = breakdown[0]
        if worst["recurringWeeks"] >= 2:
            headline_en = (
                f"{worst['nameEn']} is short {worst['recurringWeeks']} weeks in a row. "
                "Want me to flag shifts for review?"
            )
        else:
            headline_en = f"{worst['nameEn']} is off by {abs(worst['varianceQty'])} {worst['unit']} today."

    today_in = 0.0
    today_out = 0.0
    today_spend = 0.0
    for adjustment in day_adjustments:
        delta = float(adjustment.delta or 0)
        if adjustment.type == "restock":
            today_in += max(delta, 0)
            today_spend += float(adjustment.total_cost_bdt or 0)
        elif adjustment.type in {"usage", "waste"}:
            today_out += abs(delta)

    orders = (
        await db.execute(
            select(Order)
            .where(Order.outlet_id == outlet_id)
            .where(Order.created_at >= day_start)
            .where(Order.created_at < day_end)
            .where(Order.status.notin_(("cancelled", "rejected")))
        )
    ).scalars().all()
    revenue_by_source: dict[str, float] = defaultdict(float)
    seller_qty: dict[str, int] = defaultdict(int)
    seller_sales: dict[str, float] = defaultdict(float)
    for order in orders:
        method = (order.payment_method or "cash").strip().lower()
        source = "card" if method in {"card", "credit", "debit", "visa", "mastercard"} else (
            "cash" if method in {"", "cash"} else "online"
        )
        revenue_by_source[source] += float(order.total_amount or 0)
        for line in order.items if isinstance(order.items, list) else []:
            if not isinstance(line, dict):
                continue
            name = str(line.get("nameEn") or line.get("name") or "").strip()
            if not name:
                continue
            qty = int(line.get("qty") or 0)
            sales = float(line.get("lineTotal") or (qty * float(line.get("price") or 0)))
            seller_qty[name] += qty
            seller_sales[name] += sales
    revenue_total = sum(revenue_by_source.values())
    revenue_split = [
        {
            "key": key,
            "label": label,
            "valueBdt": round(revenue_by_source.get(key, 0), 2),
            "pct": round((revenue_by_source.get(key, 0) / revenue_total) * 100) if revenue_total else 0,
        }
        for key, label in (("cash", "Cash"), ("card", "Card"), ("online", "Online"))
    ]
    top_sellers = [
        {"name": name, "qty": seller_qty[name], "salesBdt": round(sales, 2)}
        for name, sales in sorted(seller_sales.items(), key=lambda pair: pair[1], reverse=True)[:5]
    ]

    return ok(
        {
            "date": target_str,
            "unexplainedVarianceBdt": round(unexplained, 2),
            "varianceItemCount": variance_items,
            "headlineEn": headline_en,
            "headlineBn": "",
            "breakdown": breakdown,
            "reorderSuggestions": reorder_suggestions[:5],
            "stockFlow": {
                "inQty": round(today_in, 3),
                "outQty": round(today_out, 3),
                "spendBdt": round(today_spend, 2),
            },
            "revenueSplit": revenue_split,
            "topSellers": top_sellers,
        }
    )


@router.post("/outlets/{outlet_id}/inventory/receipt/scan")
async def scan_inventory_receipt(
    outlet_id: str,
    files: list[UploadFile] = File(...),
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(str(payload["sub"]), outlet_id)
    await _require_inventory_account(db, outlet_id, payload)
    if not files:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Select at least one receipt image.",
        )

    pages: list[tuple[bytes, str]] = []
    for upload in files:
        content_type = (upload.content_type or "").lower()
        if not content_type.startswith("image/"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"{upload.filename or 'Uploaded file'} is not an image.",
            )
        data = await upload.read()
        if not data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"{upload.filename or 'Uploaded file'} is empty.",
            )
        pages.append((data, content_type))

    logger.info(
        "receipt scan request outlet=%s pages=%s bytes=%s",
        outlet_id,
        len(pages),
        sum(len(image_bytes) for image_bytes, _ in pages),
    )

    try:
        page_texts = await extract_receipt_page_texts(pages)
        parsed = await parse_receipt_text(page_texts)
    except ReceiptScanError as error:
        logger.warning("receipt scan failed outlet=%s error=%s", outlet_id, error)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(error),
        ) from error

    logger.info(
        "receipt scan parsed outlet=%s provider=%s items=%s warnings=%s",
        outlet_id,
        parsed.provider,
        len(parsed.items),
        len(parsed.warnings),
    )
    return ok(
        {
            "items": [item.model_dump() for item in parsed.items],
            "provider": parsed.provider,
            "pageCount": len(pages),
            "warnings": parsed.warnings,
        }
    )
