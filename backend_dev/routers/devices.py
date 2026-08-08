from datetime import datetime, timezone

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
    else:
        device = existing

    changed = existing is None
    fields_set = getattr(body, "model_fields_set", set())
    if "fcmToken" in fields_set:
        fcm_token = (body.fcmToken or "").strip() or None
        if device.fcm_token != fcm_token:
            device.fcm_token = fcm_token
            changed = True
    if "pushPlatform" in fields_set:
        push_platform = (body.pushPlatform or "").strip().lower() or None
        if device.push_platform != push_platform:
            device.push_platform = push_platform
            changed = True
    device.last_seen_at = datetime.now(timezone.utc)
    changed = True

    outlet = (
        await db.execute(select(Outlet).where(Outlet.id == outlet_id))
    ).scalar_one_or_none()
    if outlet is not None and body.tableCount is not None:
        if outlet.table_count != body.tableCount:
            outlet.table_count = body.tableCount
            changed = True

    if changed:
        await db.commit()

    return ok({
        "registered": True,
        "pushRegistered": bool(device.fcm_token),
        "pushPlatform": device.push_platform,
        "tableCount": outlet.table_count if outlet is not None else None,
    })
