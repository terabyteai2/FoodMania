"""Public customer-facing endpoints — no device token required."""

import html
import json
import logging
import httpx
from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from config import settings
from database import get_db
from models import MenuItem, Order, Outlet
from routers.menu import ALLOWED_MENU_THEMES, DEFAULT_MENU_THEME
from services.customer_orders import (
    DeliveryOrderLine,
    create_delivery_order,
    public_order_response,
)
from services.menu_placeholders import infer_icon_key, resolve_placeholder_url
from services.order_serial import format_serial

router = APIRouter(prefix="/customer", tags=["customer"])
logger = logging.getLogger("quickbytes.customer")


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


def _public_menu_theme(value: str | None) -> str:
    return value if value in ALLOWED_MENU_THEMES else DEFAULT_MENU_THEME


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


def _parse_modifiers(tags_json: str | None) -> dict:
    """Parse option:label:delta and addon:price:label entries from tags_json."""
    options: list = []
    addons: list = []
    try:
        tags = json.loads(tags_json or '[]')
    except (TypeError, ValueError):
        return {'options': options, 'addons': addons}
    for tag in (tags if isinstance(tags, list) else []):
        if not isinstance(tag, str):
            continue
        s = tag.strip()
        if s.lower().startswith('option:'):
            parts = s.split(':', 2)
            if len(parts) == 3:
                try:
                    options.append({'label': parts[1], 'priceDelta': float(parts[2] or 0)})
                except ValueError:
                    pass
        elif s.lower().startswith('addon:'):
            parts = s.split(':', 2)
            if len(parts) == 3:
                try:
                    addons.append({'price': float(parts[1] or 0), 'label': parts[2]})
                except ValueError:
                    pass
    return {'options': options, 'addons': addons}


def _item_to_dict(item: MenuItem, request: Request, item_index: int = 0) -> dict:
    icon_key = _icon_key_from_tags(item.tags_json) or infer_icon_key(
        item.name,
        item.category,
    )
    image_url = _rewrite_upload_url(request, item.image_url)
    if not image_url:
        image_url = resolve_placeholder_url(icon_key, item_index, request)
    mods = _parse_modifiers(item.tags_json)
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
        "imageUrl": image_url,
        "videoUrl": _rewrite_upload_url(request, item.video_url),
        "iconKey": icon_key,
        "options": mods["options"],
        "addons": mods["addons"],
    }
    return data


def _money(value: object) -> str:
    try:
        return f"{float(value or 0):.2f}"
    except (TypeError, ValueError):
        return "0.00"


def _order_details_html(order: Order, outlet: Outlet) -> str:
    restaurant_name = html.escape(outlet.restaurant.name if outlet.restaurant else outlet.name)
    service = html.escape((order.service_type or "dine_in").replace("_", " ").title())
    rows = []
    for item in order.items or []:
        name = html.escape(str(item.get("nameEn") or item.get("name") or "Item"))
        qty = html.escape(str(item.get("qty") or 1))
        total = _money(item.get("lineTotal") or (float(item.get("price") or 0) * float(item.get("qty") or 1)))
        rows.append(f"<tr><td>{qty}x {name}</td><td>৳{total}</td></tr>")
    delivery = ""
    if (order.service_type or "").lower() == "delivery":
        delivery = f"""
        <section>
          <h2>Delivery</h2>
          <p>{html.escape(order.customer_name or "")}</p>
          <p>{html.escape(order.mobile_number or "")}</p>
          <p>{html.escape(order.delivery_address or "")}</p>
        </section>
        """
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{restaurant_name} Order {format_serial(order.serial_number, order.source, order.created_by_role)}</title>
  <style>
    body {{ margin: 0; font-family: Inter, system-ui, sans-serif; background: #f7f2e8; color: #201812; }}
    main {{ max-width: 720px; margin: 0 auto; padding: 28px 18px 48px; }}
    h1 {{ margin: 0 0 6px; font-size: 30px; }}
    h2 {{ margin: 22px 0 8px; font-size: 15px; text-transform: uppercase; letter-spacing: .08em; }}
    .meta, table, section {{ background: white; border: 1px solid #e4d8c4; border-radius: 12px; padding: 14px; }}
    .meta p, section p {{ margin: 4px 0; }}
    table {{ width: 100%; border-collapse: separate; border-spacing: 0 8px; }}
    td:last-child {{ text-align: right; white-space: nowrap; }}
    .total {{ font-size: 22px; font-weight: 700; text-align: right; }}
  </style>
</head>
<body>
  <main>
    <h1>{restaurant_name}</h1>
    <div class="meta">
      <p><strong>Order:</strong> {format_serial(order.serial_number, order.source, order.created_by_role)}</p>
      <p><strong>Type:</strong> {service}</p>
      <p><strong>Status:</strong> {html.escape(order.status.title())}</p>
    </div>
    {delivery}
    <h2>Items</h2>
    <table><tbody>{"".join(rows)}</tbody></table>
    <p class="total">Total ৳{_money(order.total_amount)}</p>
  </main>
</body>
</html>"""


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
    return _ok([_item_to_dict(i, request, index) for index, i in enumerate(items)])


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
    orderType: str | None = None
    customerName: str | None = None
    deliveryAddress: str | None = None
    mobileNumber: str | None = None


class ReverseGeocodeRequest(BaseModel):
    lat: float = Field(..., ge=-90, le=90)
    lng: float = Field(..., ge=-180, le=180)


async def _reverse_geocode_address(lat: float, lng: float) -> str:
    access_token = settings.MAPBOX_ACCESS_TOKEN.strip()
    if not access_token:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Address lookup is not configured.",
        )

    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            response = await client.get(
                f"https://api.mapbox.com/geocoding/v5/mapbox.places/{lng},{lat}.json",
                params={
                    "access_token": access_token,
                    "types": "address,place",
                    "language": "en",
                    "limit": 1,
                },
            )
            response.raise_for_status()
            payload = response.json()
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Address lookup failed.",
        ) from exc

    features = payload.get("features") or []
    address = (features[0].get("place_name") or "").strip() if features else ""
    if not address:
        raise HTTPException(status_code=404, detail="No address found near this location.")
    return address


@router.post("/{outlet_id}/geocode/reverse")
async def reverse_geocode_customer_location(
    outlet_id: str,
    body: ReverseGeocodeRequest,
    db: AsyncSession = Depends(get_db),
):
    """Return a formatted address for a customer-provided browser location."""
    await _get_outlet(outlet_id, db)
    logger.info(
        "[QB-CUSTOMER-GEO] reverse request outlet=%s lat=%.6f lng=%.6f",
        outlet_id,
        body.lat,
        body.lng,
    )
    address = await _reverse_geocode_address(body.lat, body.lng)
    logger.info(
        "[QB-CUSTOMER-GEO] reverse success outlet=%s address_len=%s",
        outlet_id,
        len(address),
    )
    return {"address": address}


@router.post("/{outlet_id}/orders")
async def place_customer_order(
    outlet_id: str,
    body: CustomerOrderRequest,
    db: AsyncSession = Depends(get_db),
):
    """Place an order from the customer menu web app."""
    outlet = await _get_outlet(outlet_id, db)
    lines = [
        DeliveryOrderLine(
            menu_item_id=item.menuItemId,
            name=item.name,
            qty=item.qty,
            price=item.price,
        )
        for item in body.items
    ]
    order_type = (body.orderType or "delivery").strip().lower()
    order = await create_delivery_order(
        db=db,
        outlet=outlet,
        lines=lines,
        customer_name=body.customerName,
        delivery_address=body.deliveryAddress,
        mobile_number=body.mobileNumber,
        note=body.note,
        service_type=order_type,
        table_no=body.tableNo,
    )
    return _ok(public_order_response(order))


@router.get("/orders/{order_id}")
async def get_public_order_details_page(
    order_id: str,
    db: AsyncSession = Depends(get_db),
):
    order = (
        await db.execute(
            select(Order)
            .where(Order.id == order_id)
            .options(joinedload(Order.outlet).joinedload(Outlet.restaurant))
        )
    ).scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=404, detail="Order not found")
    return Response(
        content=_order_details_html(order, order.outlet),
        media_type="text/html; charset=utf-8",
        headers={"Cache-Control": "no-store, max-age=0"},
    )


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
        "logoUrl": _rewrite_upload_url(request, outlet.logo_url),
        "logoBitmapUrl": _rewrite_upload_url(request, outlet.logo_bitmap_url),
        "videoUrl": _rewrite_upload_url(request, outlet.video_url),
        "deliveryCharge": float(outlet.delivery_charge or 0),
        "galleryImages": gallery,
        "menuTheme": _public_menu_theme(outlet.menu_theme),
    })
