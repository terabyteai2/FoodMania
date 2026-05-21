from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_outlet_id
from database import get_db
from models import Order
from routers.ws import manager
from schemas import OrderPayload, OrderStatusUpdate, ok

router = APIRouter()


def _ensure_outlet(current_outlet: str, outlet_id: str) -> None:
    if current_outlet != outlet_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Token does not match this outlet.",
        )


def _order_to_dict(order: Order) -> dict:
    return {
        "id": order.id,
        "outletId": order.outlet_id,
        "serialNumber": order.serial_number,
        "source": order.source,
        "status": order.status,
        "totalAmount": float(order.total_amount),
        "items": order.items,
        "notes": order.notes,
        "createdByAccountId": order.created_by_account_id,
        "createdByRole": order.created_by_role,
        "createdAt": order.created_at.isoformat(),
        "updatedAt": order.updated_at.isoformat(),
    }


def _normalize_order_status(status: str | None) -> str:
    normalized = (status or "").strip().lower()
    return normalized or "pending"


def _parse_since(value: str) -> datetime:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid since timestamp.",
        ) from exc

    # Older Flutter builds send local ISO strings without timezone.
    # Treat those as UTC to keep comparisons deterministic.
    dt = parsed if parsed.tzinfo is not None else parsed.replace(tzinfo=timezone.utc)

    # Guard against future cursors (clock skew / missing timezone) that would
    # otherwise stall incremental sync for hours.
    now = datetime.now(timezone.utc)
    if dt > now + timedelta(seconds=30):
        return now - timedelta(seconds=5)
    return dt


@router.get("/outlets/{outlet_id}/orders")
async def pull_orders(
    outlet_id: str,
    since: str | None = None,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
    query = select(Order).where(Order.outlet_id == outlet_id).order_by(Order.created_at.desc())
    if since:
        dt = _parse_since(since)
        query = query.where(Order.updated_at > dt)
    orders = (await db.execute(query)).scalars().all()
    return ok([_order_to_dict(o) for o in orders])


@router.post("/outlets/{outlet_id}/orders")
async def push_order(
    outlet_id: str,
    body: OrderPayload,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
    idempotency_key: str | None = Header(None, alias="Idempotency-Key"),
):
    _ensure_outlet(current_outlet, outlet_id)
    created_by_role = (body.createdByRole or "").strip().lower() or None
    status_value = _normalize_order_status(body.status)
    # Staff-created manual orders should enter the manager's actionable flow
    # directly so manager-side auto-print can run without extra status taps.
    if created_by_role == "staff" and status_value == "pending":
        status_value = "accepted"
    existing = (await db.execute(select(Order).where(Order.id == body.id))).scalar_one_or_none()
    if existing:
        return ok(_order_to_dict(existing))

    now = datetime.now(timezone.utc)
    order = Order(
        id=body.id,
        outlet_id=outlet_id,
        serial_number=body.serialNumber,
        source=body.source,
        status=status_value,
        total_amount=body.totalAmount,
        items=body.items,
        notes=body.notes,
        created_by_account_id=body.createdByAccountId,
        created_by_role=created_by_role,
        created_at=now,
        updated_at=now,
    )
    db.add(order)
    await db.commit()
    await db.refresh(order)

    await manager.broadcast(outlet_id, {"type": "order_created", "data": _order_to_dict(order)})
    return ok(_order_to_dict(order))


@router.patch("/outlets/{outlet_id}/orders/{order_id}/status")
async def update_order_status(
    outlet_id: str,
    order_id: str,
    body: OrderStatusUpdate,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
    idempotency_key: str | None = Header(None, alias="Idempotency-Key"),
):
    _ensure_outlet(current_outlet, outlet_id)
    order = (
        await db.execute(
            select(Order).where((Order.id == order_id) & (Order.outlet_id == outlet_id))
        )
    ).scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found.")

    order.status = body.status
    order.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(order)

    await manager.broadcast(outlet_id, {"type": "order_status_updated", "data": _order_to_dict(order)})
    return ok(_order_to_dict(order))
