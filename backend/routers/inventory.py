from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_outlet_id
from database import get_db
from models import DailyStockCount, InventoryItem, StockAdjustment
from routers.menu import _ensure_outlet, _parse_since
from schemas import (
    DailyStockCountPayload,
    InventoryItemPayload,
    StockAdjustmentPayload,
    ok,
)

router = APIRouter()

ADJUSTMENT_TYPES = {"restock", "usage", "waste", "correction"}


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
        "createdAt": row.created_at.isoformat(),
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

    return ok(
        {
            "items": [_item_to_dict(i) for i in items],
            "adjustments": [_adjustment_to_dict(a) for a in adjustments],
            "dailyCounts": [_daily_count_to_dict(c) for c in daily_counts],
        }
    )


@router.post("/outlets/{outlet_id}/inventory/items")
async def upsert_inventory_item(
    outlet_id: str,
    body: InventoryItemPayload,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
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
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
    item = await _get_item(db, outlet_id, item_id)
    now = datetime.now(timezone.utc)
    item.deleted_at = now
    item.updated_at = now
    await db.commit()
    return ok({"id": item_id, "deletedAt": now.isoformat()})


@router.post("/outlets/{outlet_id}/inventory/adjustments")
async def record_stock_adjustment(
    outlet_id: str,
    body: StockAdjustmentPayload,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
    adj_type = (body.type or "correction").strip().lower()
    if adj_type not in ADJUSTMENT_TYPES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid adjustment type.")

    existing_adj = (
        await db.execute(select(StockAdjustment).where(StockAdjustment.id == body.id))
    ).scalar_one_or_none()
    if existing_adj:
        return ok(_adjustment_to_dict(existing_adj))

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

    adjustment = StockAdjustment(
        id=body.id or str(uuid4()),
        outlet_id=outlet_id,
        inventory_item_id=body.inventoryItemId,
        delta=body.delta,
        type=adj_type,
        note=body.note or "",
        total_cost_bdt=body.totalCostBdt,
        created_at=created_at,
    )
    item.quantity = new_qty
    item.cost_per_unit = cost_per_unit
    item.updated_at = datetime.now(timezone.utc)
    db.add(adjustment)
    await db.commit()
    await db.refresh(item)
    await db.refresh(adjustment)
    return ok({"item": _item_to_dict(item), "adjustment": _adjustment_to_dict(adjustment)})


@router.post("/outlets/{outlet_id}/inventory/daily-counts")
async def upsert_daily_stock_count(
    outlet_id: str,
    body: DailyStockCountPayload,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
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
