from fastapi import APIRouter, Depends, Header
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.requests import Request

from auth import create_device_token
from client_api_base import client_visible_api_base
from database import get_db
from models import Outlet, Restaurant
from schemas import BootstrapRequest, ok

router = APIRouter()


@router.post("/tenants/bootstrap")
async def bootstrap_tenant(
    request: Request,
    body: BootstrapRequest,
    db: AsyncSession = Depends(get_db),
    idempotency_key: str | None = Header(None, alias="Idempotency-Key"),
):
    # Re-use existing outlet if serverId already registered
    outlet = (await db.execute(select(Outlet).where(Outlet.server_id == body.serverId))).scalar_one_or_none()

    if outlet is None:
        import uuid

        restaurant_id = body.restaurantId
        if restaurant_id:
            restaurant = (await db.execute(select(Restaurant).where(Restaurant.id == restaurant_id))).scalar_one_or_none()
        else:
            restaurant = None

        if restaurant is None:
            restaurant = Restaurant(name=body.restaurantName)
            db.add(restaurant)
            await db.flush()

        # The client may pass an outletId from a previous (now-wiped) install.
        # If that UUID already belongs to a DIFFERENT tenant in this DB, fall
        # back to a fresh UUID so we don't trip the outlets_pkey constraint.
        outlet_id = (body.outletId or "").strip() or None
        if outlet_id:
            conflict = (
                await db.execute(select(Outlet).where(Outlet.id == outlet_id))
            ).scalar_one_or_none()
            if conflict is not None:
                outlet_id = None
        if not outlet_id:
            outlet_id = str(uuid.uuid4())

        outlet = Outlet(
            id=outlet_id,
            restaurant_id=restaurant.id,
            name=body.outletName,
            server_id=body.serverId,
        )
        db.add(outlet)
        await db.commit()
        await db.refresh(outlet)
        await db.refresh(restaurant)
    else:
        restaurant = (await db.execute(select(Restaurant).where(Restaurant.id == outlet.restaurant_id))).scalar_one()
        changed = False
        if body.restaurantName.strip() and restaurant.name != body.restaurantName:
            restaurant.name = body.restaurantName
            changed = True
        if body.outletName.strip() and outlet.name != body.outletName:
            outlet.name = body.outletName
            changed = True
        if changed:
            await db.commit()
            await db.refresh(outlet)
            await db.refresh(restaurant)

    token = create_device_token(outlet.id)
    return ok({
        "serverId": body.serverId,
        "restaurantId": restaurant.id,
        "outletId": outlet.id,
        "restaurantName": restaurant.name,
        "outletName": outlet.name,
        "deviceToken": token,
        "publicApiBaseUrl": client_visible_api_base(request),
    })
