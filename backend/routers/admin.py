from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import create_device_token, hash_password, verify_password
from database import get_db
from models import AdminAccount, Outlet, Restaurant
from schemas import AdminCreateRequest, AdminLoginRequest, ok

router = APIRouter()


@router.post("/admin/login")
async def admin_login(body: AdminLoginRequest, db: AsyncSession = Depends(get_db)):
    outlet = (await db.execute(select(Outlet).where(Outlet.server_id == body.serverId))).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Server ID not registered.")

    account = (
        await db.execute(
            select(AdminAccount).where(
                (AdminAccount.outlet_id == outlet.id)
                & (
                    (AdminAccount.email == body.usernameOrEmail.strip())
                    | (AdminAccount.username == body.usernameOrEmail.strip())
                )
            )
        )
    ).scalar_one_or_none()

    if account is None or not verify_password(body.password, account.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials.")

    restaurant = (await db.execute(select(Restaurant).where(Restaurant.id == outlet.restaurant_id))).scalar_one()
    token = create_device_token(outlet.id)

    return ok({
        "serverId": body.serverId,
        "restaurantId": restaurant.id,
        "outletId": outlet.id,
        "restaurantName": restaurant.name,
        "outletName": outlet.name,
        "deviceToken": token,
        "account": {
            "email": account.email,
            "username": account.username,
        },
    })


@router.post("/admin/create")
async def create_admin(body: AdminCreateRequest, db: AsyncSession = Depends(get_db)):
    outlet = (await db.execute(select(Outlet).where(Outlet.id == body.outletId))).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Outlet not found.")

    existing = (
        await db.execute(
            select(AdminAccount).where(
                (AdminAccount.email == body.email) | (AdminAccount.username == body.username)
            )
        )
    ).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email or username already in use.")

    account = AdminAccount(
        outlet_id=body.outletId,
        email=body.email,
        username=body.username,
        password_hash=hash_password(body.password),
    )
    db.add(account)
    await db.commit()
    return ok({"created": True, "username": body.username, "email": body.email})
