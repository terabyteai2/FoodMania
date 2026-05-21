from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_outlet_id
from database import get_db
from models import Device, Outlet
from schemas import DeviceRegisterRequest, ok

router = APIRouter()


@router.post("/devices/register")
async def register_device(
    body: DeviceRegisterRequest,
    outlet_id: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    existing = (
        await db.execute(
            select(Device).where(
                (Device.outlet_id == outlet_id) & (Device.server_id == body.serverId)
            )
        )
    ).scalar_one_or_none()

    if existing is None:
        device = Device(outlet_id=outlet_id, server_id=body.serverId)
        db.add(device)
    outlet = (
        await db.execute(select(Outlet).where(Outlet.id == outlet_id))
    ).scalar_one_or_none()
    if outlet is not None and body.tableCount is not None:
        outlet.table_count = body.tableCount

    if existing is None or (outlet is not None and body.tableCount is not None):
        await db.commit()

    return ok({"registered": True, "tableCount": outlet.table_count if outlet is not None else None})
