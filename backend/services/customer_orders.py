import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Order, Outlet
from routers.ws import manager
from services.push_notifications import send_order_push


@dataclass(frozen=True)
class DeliveryOrderLine:
    menu_item_id: str
    name: str
    qty: int
    price: float


def order_to_dict(order: Order) -> dict:
    return {
        "id": order.id,
        "outletId": order.outlet_id,
        "serialNumber": order.serial_number,
        "source": order.source,
        "status": order.status,
        "totalAmount": float(order.total_amount),
        "subtotal": float(order.subtotal or order.total_amount or 0),
        "vatRatePercent": float(order.vat_rate_percent or 0),
        "vatAmount": float(order.vat_amount or 0),
        "deliveryCharge": float(order.delivery_charge or 0),
        "serviceType": order.service_type,
        "covers": order.covers,
        "paymentMethod": order.payment_method,
        "tableNo": order.table_no,
        "items": order.items,
        "notes": order.notes,
        "customerName": order.customer_name,
        "deliveryAddress": order.delivery_address,
        "mobileNumber": order.mobile_number,
        "createdByAccountId": order.created_by_account_id,
        "createdByRole": order.created_by_role,
        "shiftId": order.shift_id,
        "discountLabel": order.discount_label,
        "discountAmount": float(order.discount_amount or 0),
        "serviceChargeRatePercent": float(order.service_charge_rate_percent or 0),
        "serviceChargeAmount": float(order.service_charge_amount or 0),
        "billingSnapshot": order.billing_snapshot or {},
        "kotBatches": order.kot_batches or [],
        "settledAt": order.settled_at.isoformat() if order.settled_at else None,
        "createdAt": order.created_at.isoformat(),
        "updatedAt": order.updated_at.isoformat(),
    }


def delivery_order_totals(
    lines: list[DeliveryOrderLine], *, delivery_charge: float = 0
) -> dict:
    subtotal = round(sum(line.price * line.qty for line in lines), 2)
    vat_rate_percent = 5.0
    vat_amount = round(subtotal * vat_rate_percent / 100, 2)
    clean_delivery_charge = round(max(0, delivery_charge), 2)
    total = round(subtotal + vat_amount + clean_delivery_charge, 2)
    return {
        "subtotal": subtotal,
        "vatRatePercent": vat_rate_percent,
        "vatAmount": vat_amount,
        "deliveryCharge": clean_delivery_charge,
        "total": total,
    }


def _line_payload(lines: list[DeliveryOrderLine]) -> list[dict]:
    return [
        {
            "menuItemId": line.menu_item_id,
            "name": line.name,
            "qty": line.qty,
            "price": line.price,
            "lineTotal": round(line.price * line.qty, 2),
        }
        for line in lines
    ]


def public_order_response(order: Order) -> dict:
    return {
        "orderId": order.id,
        "serialNumber": order.serial_number,
        "status": order.status,
        "total": float(order.total_amount),
        "subtotal": float(order.subtotal or 0),
        "vatRatePercent": float(order.vat_rate_percent or 0),
        "vatAmount": float(order.vat_amount or 0),
        "deliveryCharge": float(order.delivery_charge or 0),
        "items": order.items,
        "notes": order.notes,
        "serviceType": order.service_type,
        "tableNo": order.table_no,
        "customerName": order.customer_name,
        "deliveryAddress": order.delivery_address,
        "mobileNumber": order.mobile_number,
    }


async def create_delivery_order(
    *,
    db: AsyncSession,
    outlet: Outlet,
    lines: list[DeliveryOrderLine],
    customer_name: str | None,
    delivery_address: str | None,
    mobile_number: str | None,
    note: str | None = None,
    source: str = "customer_web",
    created_by_role: str = "customer",
    service_type: str = "delivery",
    table_no: str | None = None,
    broadcast: bool = True,
) -> Order:
    if not lines:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Order must contain at least one item",
        )

    normalized_type = (service_type or "delivery").strip().lower().replace("-", "_")
    if normalized_type in {"dinein", "table", "table_order"}:
        normalized_type = "dine_in"
    if normalized_type not in {"delivery", "dine_in"}:
        normalized_type = "delivery"

    clean_table = (table_no or "").strip() or None
    clean_name = (customer_name or "").strip() or None
    clean_address = (delivery_address or "").strip() or None
    clean_mobile = (mobile_number or "").strip() or None
    if normalized_type == "dine_in":
        if not clean_table:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Table order requires tableNo",
            )
        clean_name = None
        clean_address = None
        clean_mobile = None
    elif not (clean_name and clean_address and clean_mobile):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Delivery requires name, address, and mobile number",
        )

    totals = delivery_order_totals(
        lines,
        delivery_charge=float(outlet.delivery_charge or 0)
        if normalized_type == "delivery"
        else 0,
    )
    now = datetime.now(timezone.utc)
    order = Order(
        id=str(uuid.uuid4()),
        outlet_id=outlet.id,
        source=source,
        status="pending",
        total_amount=totals["total"],
        subtotal=totals["subtotal"],
        vat_rate_percent=totals["vatRatePercent"],
        vat_amount=totals["vatAmount"],
        delivery_charge=totals["deliveryCharge"],
        service_type=normalized_type,
        table_no=clean_table,
        items=_line_payload(lines),
        notes=note,
        customer_name=clean_name,
        delivery_address=clean_address,
        mobile_number=clean_mobile,
        created_by_account_id=None,
        created_by_role=created_by_role,
        created_at=now,
        updated_at=now,
    )
    db.add(order)
    await db.commit()
    await db.refresh(order)

    count_res = await db.execute(
        select(func.count()).select_from(Order).where(Order.outlet_id == outlet.id)
    )
    order.serial_number = count_res.scalar() or 1
    await db.commit()
    await db.refresh(order)

    if broadcast:
        await manager.broadcast(
            outlet.id,
            {"type": "order_created", "data": order_to_dict(order)},
        )
        await send_order_push(
            db=db,
            outlet_id=outlet.id,
            event_type="order_created",
            order=order,
        )
    return order
