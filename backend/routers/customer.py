"""Public customer-facing endpoints — no device token required."""

import json
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from database import get_db
from models import MenuItem, Order, Outlet, Restaurant
from routers.ws import manager
from services.opencage_client import reverse_geocode

router = APIRouter(prefix="/customer", tags=["customer"])


# ── helpers ────────────────────────────────────────────────────────────────────

def _ok(data):
    return {"ok": True, "data": data}


def _rewrite_upload_url(request: Request, url: str | None) -> str | None:
    """Normalize stored media URLs so they always resolve from the caller's host.

    Files uploaded historically have full URLs baked in (e.g. http://localhost:8000/...
    or http://192.168.x.x:8000/...). When a phone fetches this API over the LAN
    IP, ``localhost`` URLs are unreachable. We strip everything before ``/uploads/``
    and re-prefix with the current request's base URL — so the customer site,
    admin app, or any tunnel sees URLs that point back at the host it called.
    """
    if not url:
        return url
    marker = "/uploads/"
    idx = url.find(marker)
    if idx < 0:
        return url  # not an upload URL — leave as-is
    base = str(request.base_url).rstrip("/")
    return f"{base}{url[idx:]}"


def _icon_key_from_tags(raw: str | None) -> str | None:
    if not raw:
        return None
    try:
        tags = json.loads(raw)
    except (TypeError, ValueError):
        return None
    if not isinstance(tags, list):
        return None
    for tag in tags:
        if not isinstance(tag, str):
            continue
        value = tag.strip()
        if value.lower().startswith("icon:"):
            key = value.split(":", 1)[1].strip().lower()
            return key or None
    return None


def _item_to_dict(item: MenuItem, request: Request) -> dict:
    data = {
        "id": item.id,
        "name": item.name,
        "nameEn": item.name_en or item.name,
        "nameBn": item.name_bn or "",
        "description": item.description or "",
        "descriptionEn": item.description_en or item.description or "",
        "descriptionBn": item.description_bn or "",
        "price": float(item.price),
        "category": item.category or "General",
        "categoryEn": item.category_en or item.category or "General",
        "categoryBn": item.category_bn or "",
        "isAvailable": item.is_available,
        "imageUrl": _rewrite_upload_url(request, item.image_url),
        "videoUrl": _rewrite_upload_url(request, item.video_url),
    }
    icon_key = _icon_key_from_tags(item.tags_json)
    if icon_key:
        data["iconKey"] = icon_key
    return data


async def _get_outlet(outlet_ref: str, db: AsyncSession) -> Outlet:
    outlet = (
        await db.execute(
            select(Outlet).where(
                (Outlet.id == outlet_ref) | (Outlet.server_id == outlet_ref)
                | (Outlet.public_slug == outlet_ref.lower())
            )
        )
    ).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(status_code=404, detail="Outlet not found")
    return outlet


# ── GET menu ──────────────────────────────────────────────────────────────────

@router.get("/{outlet_id}/menu")
async def get_public_menu(
    outlet_id: str,
    request: Request,
    response: Response,
    db: AsyncSession = Depends(get_db),
):
    """Return available menu items for the customer-facing menu page."""
    response.headers["Cache-Control"] = "no-store, max-age=0"
    outlet = await _get_outlet(outlet_id, db)
    items = (
        await db.execute(
            select(MenuItem)
            .where(
                MenuItem.outlet_id == outlet.id,
                MenuItem.is_available == True,
                MenuItem.deleted_at == None,
            )
            .order_by(MenuItem.category, MenuItem.name)
        )
    ).scalars().all()
    return _ok([_item_to_dict(i, request) for i in items])


# ── POST order ────────────────────────────────────────────────────────────────

class CustomerOrderItem(BaseModel):
    menuItemId: str
    name: str
    qty: int
    price: float


class CustomerOrderRequest(BaseModel):
    items: list[CustomerOrderItem]
    customerName: str
    customerPhone: str
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    note: str | None = None
    tableNo: str | None = None

    @field_validator("customerName", "customerPhone")
    @classmethod
    def _non_empty(cls, value: str) -> str:
        if not value or not value.strip():
            raise ValueError("must not be empty")
        return value.strip()


@router.post("/{outlet_id}/orders")
async def place_customer_order(
    outlet_id: str,
    body: CustomerOrderRequest,
    db: AsyncSession = Depends(get_db),
):
    """Place an order from the customer menu web app."""
    if not body.items:
        raise HTTPException(status_code=422, detail="Order must contain at least one item")

    outlet = await _get_outlet(outlet_id, db)

    total = sum(item.price * item.qty for item in body.items)
    vat_rate_percent = 5.0
    vat_amount = round(total * vat_rate_percent / 100, 2)
    final_total = round(total + vat_amount, 2)
    now = datetime.now(timezone.utc)
    order_id = str(uuid.uuid4())

    items_payload = [
        {
            "menuItemId": item.menuItemId,
            "name": item.name,
            "qty": item.qty,
            "price": item.price,
            "lineTotal": round(item.price * item.qty, 2),
        }
        for item in body.items
    ]

    delivery_address = await reverse_geocode(body.latitude, body.longitude)

    order = Order(
        id=order_id,
        outlet_id=outlet.id,
        source="customer_web",
        status="pending",
        total_amount=final_total,
        subtotal=round(total, 2),
        vat_rate_percent=vat_rate_percent,
        vat_amount=vat_amount,
        service_type="delivery",
        payment_method="cod",
        items=items_payload,
        notes=body.note,
        customer_name=body.customerName,
        customer_phone=body.customerPhone,
        customer_lat=body.latitude,
        customer_lng=body.longitude,
        delivery_address=delivery_address,
        created_at=now,
        updated_at=now,
    )
    db.add(order)
    await db.commit()
    await db.refresh(order)

    # Assign a 1-based serial number scoped to this outlet
    count_res = await db.execute(
        select(func.count()).select_from(Order).where(Order.outlet_id == outlet.id)
    )
    order.serial_number = count_res.scalar()
    await db.commit()

    # Broadcast to the admin POS via WebSocket
    await manager.broadcast(
        outlet.id,
        {
            "type": "order_created",
            "data": {
                "id": order.id,
                "outletId": order.outlet_id,
                "serialNumber": order.serial_number,
                "source": order.source,
                "status": order.status,
                "totalAmount": float(order.total_amount),
                "subtotal": float(order.subtotal or 0),
                "vatRatePercent": float(order.vat_rate_percent or 0),
                "vatAmount": float(order.vat_amount or 0),
                "serviceType": order.service_type,
                "covers": order.covers,
                "paymentMethod": order.payment_method,
                "items": order.items,
                "notes": order.notes,
                "customerName": order.customer_name,
                "customerPhone": order.customer_phone,
                "customerLat": float(order.customer_lat) if order.customer_lat is not None else None,
                "customerLng": float(order.customer_lng) if order.customer_lng is not None else None,
                "deliveryAddress": order.delivery_address,
                "createdByAccountId": None,
                "createdByRole": "customer",
                "createdAt": order.created_at.isoformat(),
                "updatedAt": order.updated_at.isoformat(),
            },
        },
    )

    return _ok({
        "orderId": order.id,
        "serialNumber": order.serial_number,
        "status": order.status,
        "total": float(order.total_amount),
        "subtotal": float(order.subtotal or 0),
        "vatRatePercent": float(order.vat_rate_percent or 0),
        "vatAmount": float(order.vat_amount or 0),
        "items": order.items,
        "notes": order.notes,
        "customerName": order.customer_name,
        "customerPhone": order.customer_phone,
        "deliveryAddress": order.delivery_address,
    })


# ── GET restaurant info ────────────────────────────────────────────────────────

@router.get("/{outlet_id}/info")
async def get_outlet_info(
    outlet_id: str,
    request: Request,
    response: Response,
    db: AsyncSession = Depends(get_db),
):
    """Return restaurant/outlet name for display on the customer menu page."""
    response.headers["Cache-Control"] = "no-store, max-age=0"
    outlet = (
        await db.execute(
            select(Outlet)
            .where(
                (Outlet.id == outlet_id)
                | (Outlet.server_id == outlet_id)
                | (Outlet.public_slug == outlet_id.lower())
            )
            .options(joinedload(Outlet.restaurant))
        )
    ).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(status_code=404, detail="Outlet not found")
    gallery = [
        _rewrite_upload_url(request, u) for u in (outlet.gallery_images or [])
    ]
    return _ok({
        "outletId": outlet.id,
        "restaurantName": outlet.restaurant.name if outlet.restaurant else "",
        "outletName": outlet.name,
        "bannerUrl": _rewrite_upload_url(request, outlet.banner_url),
        "videoUrl": _rewrite_upload_url(request, outlet.video_url),
        "galleryImages": gallery,
    })
