"""Public customer-facing endpoints — no device token required."""

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from database import get_db
from models import MenuItem, Order, Outlet, Restaurant
from routers.ws import manager

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


def _item_to_dict(item: MenuItem, request: Request) -> dict:
    return {
        "id": item.id,
        "name": item.name,
        "description": item.description or "",
        "price": float(item.price),
        "category": item.category or "General",
        "isAvailable": item.is_available,
        "imageUrl": _rewrite_upload_url(request, item.image_url),
        "videoUrl": _rewrite_upload_url(request, item.video_url),
    }


async def _get_outlet(outlet_ref: str, db: AsyncSession) -> Outlet:
    outlet = (
        await db.execute(
            select(Outlet).where(
                (Outlet.id == outlet_ref) | (Outlet.server_id == outlet_ref)
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
    tableNo: str | None = None
    note: str | None = None


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

    order = Order(
        id=order_id,
        outlet_id=outlet.id,
        source="customer_web",
        status="pending",
        total_amount=round(total, 2),
        items=items_payload,
        notes=body.tableNo and f"Table {body.tableNo}" or body.note,
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
                "items": order.items,
                "notes": order.notes,
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
        "items": order.items,
        "notes": order.notes,
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
            .where((Outlet.id == outlet_id) | (Outlet.server_id == outlet_id))
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
