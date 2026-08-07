from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, File, Header, HTTPException, UploadFile, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_device_payload, get_current_outlet_id
from database import get_db
from models import AdminAccount, MenuItem, Order, PosShift
from routers.ws import manager
from schemas import (
    OrderDetailsUpdate,
    OrderItemsUpdate,
    OrderPayload,
    OrderStatusUpdate,
    ok,
)
from routers.menu import _require_manager_scan_access
from services.customer_orders import order_to_dict
from services.order_history_import import OrderHistoryCsvError, parse_order_history_csv
from services.order_serial import serial_group_filter
from services.push_notifications import send_order_push

router = APIRouter()

# Orders are grouped by the restaurant's local (Bangladesh) business day,
# matching the convention used by the dashboard.
BDT_OFFSET = timedelta(hours=6)


def _ensure_outlet(current_outlet: str, outlet_id: str) -> None:
    if current_outlet != outlet_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Token does not match this outlet.",
        )


def _order_to_dict(order: Order) -> dict:
    return order_to_dict(order)


def _normalize_order_status(status: str | None) -> str:
    normalized = (status or "").strip().lower()
    return normalized or "pending"


def _clean_text(value: object) -> str:
    return str(value or "").strip()


async def _normalize_items_list(
    outlet_id: str,
    raw_items: list[dict],
    db: AsyncSession,
) -> list[dict]:
    items = raw_items
    menu_ids = {
        menu_id
        for item in items
        if (menu_id := _clean_text(item.get("menuItemId")))
    }
    menu_by_id: dict[str, MenuItem] = {}
    if menu_ids:
        menu_items = (
            await db.execute(
                select(MenuItem).where(
                    MenuItem.outlet_id == outlet_id,
                    MenuItem.id.in_(menu_ids),
                )
            )
        ).scalars().all()
        menu_by_id = {item.id: item for item in menu_items}

    normalized: list[dict] = []
    for item in items:
        menu_id = _clean_text(item.get("menuItemId"))
        menu_item = menu_by_id.get(menu_id)
        fallback_name = _clean_text(item.get("name"))
        name_en = _clean_text(item.get("nameEn"))
        name_bn = _clean_text(item.get("nameBn"))
        if menu_item is not None:
            name_en = (
                _clean_text(menu_item.name_en)
                or _clean_text(menu_item.name)
                or name_en
            )
            name_bn = _clean_text(menu_item.name_bn) or name_bn
            if item.get("costPriceSnapshot") is None:
                item["costPriceSnapshot"] = (
                    float(menu_item.cost_price) if menu_item.cost_price is not None else 0
                )
        name_en = name_en or fallback_name
        name = name_en or fallback_name or name_bn
        item["name"] = name
        item["nameEn"] = name_en
        item["nameBn"] = name_bn
        normalized.append(item)
    return normalized


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


def _parse_client_iso(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    # Older Flutter builds send local ISO strings without timezone; treat
    # them as UTC to keep comparisons deterministic.
    return parsed if parsed.tzinfo is not None else parsed.replace(tzinfo=timezone.utc)


@router.get("/outlets/{outlet_id}/orders")
async def pull_orders(
    outlet_id: str,
    since: str | None = None,
    limit: int | None = None,
    order_date: str | None = None,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
    query = select(Order).where(Order.outlet_id == outlet_id).order_by(Order.created_at.desc())
    if since:
        dt = _parse_since(since)
        query = query.where(Order.updated_at > dt)
    if order_date:
        from datetime import date
        parsed = date.fromisoformat(order_date)
        query = query.where(Order.order_date == parsed)
    # Clients pass `limit` on the initial (no-`since`) pull so memory-constrained
    # devices only load the most recent slice of history instead of every order.
    if limit and limit > 0:
        query = query.limit(limit)
    orders = (await db.execute(query)).scalars().all()
    return ok([_order_to_dict(o) for o in orders])


@router.post("/outlets/{outlet_id}/orders")
async def push_order(
    outlet_id: str,
    body: OrderPayload,
    current_outlet: str = Depends(get_current_outlet_id),
    device_payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
    idempotency_key: str | None = Header(None, alias="Idempotency-Key"),
):
    _ensure_outlet(current_outlet, outlet_id)
    created_by_role = (body.createdByRole or "").strip().lower() or None
    status_value = _normalize_order_status(body.status)
    # Staff-created manual orders should enter the manager's actionable flow
    # directly so manager-side auto-print can run without extra status taps.
    if created_by_role in ("staff", "waiter") and status_value == "pending":
        status_value = "accepted"
    existing = (await db.execute(select(Order).where(Order.id == body.id))).scalar_one_or_none()
    if existing:
        return ok(_order_to_dict(existing))

    desktop_account: AdminAccount | None = None
    if (body.source or "").strip().lower() == "desktop_pos":
        account_id = str(device_payload.get("account_id") or "")
        desktop_account = (
            await db.execute(
                select(AdminAccount).where(
                    AdminAccount.id == account_id,
                    AdminAccount.outlet_id == outlet_id,
                    AdminAccount.is_active.is_(True),
                )
            )
        ).scalar_one_or_none()
        if desktop_account is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Desktop POS sales require an authenticated account token.",
            )
        shift_id = (body.shiftId or "").strip()
        active_shift = (
            await db.execute(
                select(PosShift).where(
                    PosShift.id == shift_id,
                    PosShift.outlet_id == outlet_id,
                    PosShift.status == "open",
                )
            )
        ).scalar_one_or_none()
        if active_shift is None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Desktop sales require an open outlet register shift.",
            )

    now = datetime.now(timezone.utc)
    # Offline devices sync queued orders in a burst once they reconnect. The
    # client-supplied createdAt carries the true local creation time; honor it
    # so synced history keeps its real timestamps instead of the sync moment.
    created_at = _parse_client_iso(body.createdAt)
    if created_at is None:
        created_at = now
    elif created_at > now + timedelta(seconds=30):
        # Guard against client clock skew / future timestamps.
        created_at = now
    # Order is billed under the restaurant's local (Bangladesh) business day.
    today = (created_at + BDT_OFFSET).date()
    # Effective role is the desktop account's role when present (desktop POS),
    # otherwise the client-supplied role. Used for source-aware serial grouping.
    effective_role = desktop_account.role if desktop_account else created_by_role
    max_serial = await db.execute(
        select(func.coalesce(func.max(Order.serial_number), 0))
        .where(
            Order.outlet_id == outlet_id,
            Order.order_date == today,
            serial_group_filter(body.source, effective_role),
        )
    )
    next_serial = (max_serial.scalar() or 0) + 1

    order = Order(
        id=body.id,
        outlet_id=outlet_id,
        serial_number=next_serial,
        order_date=today,
        source=body.source,
        status=status_value,
        total_amount=body.totalAmount,
        subtotal=body.subtotal if body.subtotal is not None else body.totalAmount,
        vat_rate_percent=body.vatRatePercent if body.vatRatePercent is not None else 0,
        vat_amount=body.vatAmount if body.vatAmount is not None else 0,
        delivery_charge=body.deliveryCharge if body.deliveryCharge is not None else 0,
        service_type=body.serviceType,
        covers=body.covers,
        payment_method=body.paymentMethod,
        table_no=(body.tableNo or "").strip() or None,
        items=await _normalize_items_list(
            outlet_id,
            [item.model_dump(exclude_none=True) for item in body.items],
            db,
        ),
        notes=body.notes,
        customer_name=(body.customerName or "").strip() or None,
        delivery_address=(body.deliveryAddress or "").strip() or None,
        mobile_number=(body.mobileNumber or "").strip() or None,
        created_by_account_id=desktop_account.id if desktop_account else body.createdByAccountId,
        created_by_role=desktop_account.role if desktop_account else created_by_role,
        shift_id=(body.shiftId or "").strip() or None,
        discount_label=(body.discountLabel or "").strip() or None,
        discount_amount=body.discountAmount or 0,
        service_charge_rate_percent=body.serviceChargeRatePercent or 0,
        service_charge_amount=body.serviceChargeAmount or 0,
        billing_snapshot=body.billingSnapshot or {},
        kot_batches=body.kotBatches or [],
        settled_at=_parse_client_iso(body.settledAt),
        created_at=created_at,
        updated_at=now,
    )
    db.add(order)
    await db.commit()
    await db.refresh(order)

    await manager.broadcast(outlet_id, {"type": "order_created", "data": _order_to_dict(order)})
    await send_order_push(
        db=db,
        outlet_id=outlet_id,
        event_type="order_created",
        order=order,
    )
    return ok(_order_to_dict(order))


@router.post("/outlets/{outlet_id}/orders/history/import")
async def import_order_history_csv(
    outlet_id: str,
    file: UploadFile = File(...),
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    await _require_manager_scan_access(outlet_id, payload, db)
    filename = (file.filename or "").strip().lower()
    if not filename.endswith(".csv"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Upload a CSV export from the older POS.",
        )
    contents = await file.read()
    if len(contents) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Order history CSV must be 10 MB or smaller.",
        )
    try:
        parsed = parse_order_history_csv(contents, outlet_id=outlet_id)
    except OrderHistoryCsvError as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(error),
        ) from error
    if not parsed.orders:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="CSV did not contain importable dated orders.",
        )

    existing_ids = set(
        (
            await db.execute(
                select(Order.id).where(
                    Order.outlet_id == outlet_id,
                    Order.id.in_([order.id for order in parsed.orders]),
                )
            )
        ).scalars()
    )
    updated_at = datetime.now(timezone.utc)
    imported = 0
    for legacy in parsed.orders:
        if legacy.id in existing_ids:
            continue
        db.add(
            Order(
                id=legacy.id,
                outlet_id=outlet_id,
                # Local order numbers are unique per current app database;
                # old POS invoice numbers can repeat and live ticket sequences
                # may already use them. Keep the original in notes instead.
                serial_number=0,
                source="manual",
                status="served",
                total_amount=legacy.total_amount,
                subtotal=legacy.total_amount,
                vat_rate_percent=0,
                vat_amount=0,
                items=legacy.items,
                notes=legacy.notes,
                created_by_role="legacy_import",
                created_at=legacy.created_at,
                updated_at=updated_at,
            )
        )
        imported += 1
    await db.commit()
    return ok(
        {
            "importedOrders": imported,
            "duplicateOrders": len(parsed.orders) - imported,
            "skippedRows": parsed.skipped_rows,
            "rowCount": parsed.row_count,
            "columns": parsed.columns,
            "errors": parsed.errors,
        }
    )


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
    await send_order_push(
        db=db,
        outlet_id=outlet_id,
        event_type="order_status_updated",
        order=order,
    )
    return ok(_order_to_dict(order))


@router.patch("/outlets/{outlet_id}/orders/{order_id}")
async def update_order_details(
    outlet_id: str,
    order_id: str,
    body: OrderDetailsUpdate,
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

    if body.serviceType is not None:
        order.service_type = (body.serviceType or "").strip() or None
    if body.tableNo is not None:
        order.table_no = (body.tableNo or "").strip() or None
    if body.notes is not None:
        order.notes = (body.notes or "").strip() or None
    if body.customerName is not None:
        order.customer_name = (body.customerName or "").strip() or None
    if body.deliveryAddress is not None:
        order.delivery_address = (body.deliveryAddress or "").strip() or None
    if body.mobileNumber is not None:
        order.mobile_number = (body.mobileNumber or "").strip() or None
    if body.clearDiscount:
        order.discount_label = None
        order.discount_amount = 0
    elif body.discountAmount is not None:
        order.discount_label = (body.discountLabel or "").strip() or None
        order.discount_amount = body.discountAmount
    order.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(order)

    await manager.broadcast(outlet_id, {"type": "order_updated", "data": _order_to_dict(order)})
    return ok(_order_to_dict(order))


@router.patch("/outlets/{outlet_id}/orders/{order_id}/items")
async def update_order_items(
    outlet_id: str,
    order_id: str,
    body: OrderItemsUpdate,
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

    if not body.items:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Order must contain at least one item.",
        )

    normalized = await _normalize_items_list(
        outlet_id,
        [item.model_dump(exclude_none=True) for item in body.items],
        db,
    )
    order.items = normalized
    if body.subtotal is not None:
        order.subtotal = body.subtotal
    if body.totalAmount is not None:
        order.total_amount = body.totalAmount
    if body.vatRatePercent is not None:
        order.vat_rate_percent = body.vatRatePercent
    if body.vatAmount is not None:
        order.vat_amount = body.vatAmount
    if body.deliveryCharge is not None:
        order.delivery_charge = body.deliveryCharge
    order.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(order)

    await manager.broadcast(outlet_id, {"type": "order_updated", "data": _order_to_dict(order)})
    return ok(_order_to_dict(order))


@router.delete("/outlets/{outlet_id}/orders/{order_id}")
async def delete_order(
    outlet_id: str,
    order_id: str,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
    order = (
        await db.execute(
            select(Order).where((Order.id == order_id) & (Order.outlet_id == outlet_id))
        )
    ).scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found.")

    order.status = "cancelled"
    order.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(order)

    await manager.broadcast(outlet_id, {"type": "order_deleted", "data": _order_to_dict(order)})
    return ok(_order_to_dict(order))
