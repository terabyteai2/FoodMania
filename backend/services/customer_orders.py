import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Order, Outlet
from routers.ws import manager


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
        "serviceType": order.service_type,
        "covers": order.covers,
        "paymentMethod": order.payment_method,
        "items": order.items,
        "notes": order.notes,
        "customerName": order.customer_name,
        "deliveryAddress": order.delivery_address,
        "mobileNumber": order.mobile_number,
        "createdByAccountId": order.created_by_account_id,
        "createdByRole": order.created_by_role,
        "createdAt": order.created_at.isoformat(),
        "updatedAt": order.updated_at.isoformat(),
    }


def delivery_order_totals(lines: list[DeliveryOrderLine]) -> dict:
    subtotal = round(sum(line.price * line.qty for line in lines), 2)
    vat_rate_percent = 5.0
    vat_amount = round(subtotal * vat_rate_percent / 100, 2)
    total = round(subtotal + vat_amount, 2)
    return {
        "subtotal": subtotal,
        "vatRatePercent": vat_rate_percent,
        "vatAmount": vat_amount,
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
        "items": order.items,
        "notes": order.notes,
        "serviceType": order.service_type,
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
    broadcast: bool = True,
) -> Order:
    if not lines:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Order must contain at least one item",
        )

    clean_name = (customer_name or "").strip() or None
    clean_address = (delivery_address or "").strip() or None
    clean_mobile = (mobile_number or "").strip() or None
    if not (clean_name and clean_address and clean_mobile):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Delivery requires name, address, and mobile number",
        )

    totals = delivery_order_totals(lines)
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
        service_type="delivery",
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
    return order
