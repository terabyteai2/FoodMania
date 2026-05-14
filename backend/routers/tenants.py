from fastapi import APIRouter, Depends, Header
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import create_device_token
from database import get_db
from models import Outlet, Restaurant
from schemas import BootstrapRequest, ok

router = APIRouter()


@router.post("/tenants/bootstrap")
async def bootstrap_tenant(
    body: BootstrapRequest,
    db: AsyncSession = Depends(get_db),
    idempotency_key: str | None = Header(None, alias="Idempotency-Key"),
):
    # Re-use existing outlet if serverId already registered
    outlet = (await db.execute(select(Outlet).where(Outlet.server_id == body.serverId))).scalar_one_or_none()

    if outlet is None:
        restaurant_id = body.restaurantId
        if restaurant_id:
            restaurant = (await db.execute(select(Restaurant).where(Restaurant.id == restaurant_id))).scalar_one_or_none()
        else:
            restaurant = None

        if restaurant is None:
            restaurant = Restaurant(name=body.restaurantName)
            db.add(restaurant)
            await db.flush()

        outlet_id = body.outletId
        outlet = Outlet(
            id=outlet_id if outlet_id else None,
            restaurant_id=restaurant.id,
            name=body.outletName,
            server_id=body.serverId,
        )
        if not outlet_id:
            import uuid
            outlet.id = str(uuid.uuid4())
        db.add(outlet)
        await db.commit()
        await db.refresh(outlet)
        await db.refresh(restaurant)
    else:
        restaurant = (await db.execute(select(Restaurant).where(Restaurant.id == outlet.restaurant_id))).scalar_one()

    token = create_device_token(outlet.id)
    return ok({
        "serverId": body.serverId,
        "restaurantId": restaurant.id,
        "outletId": outlet.id,
        "restaurantName": restaurant.name,
        "outletName": outlet.name,
        "deviceToken": token,
    })
