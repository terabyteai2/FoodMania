"""Company platform admin API — manage all restaurants, outlets, subscriptions."""

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from auth import (
    create_platform_token,
    get_current_platform_admin_id,
    verify_password,
)
from config import settings
from database import get_db
from models import (
    AdminAccount,
    BkashSession,
    MenuItem,
    Order,
    Outlet,
    OutletSubscription,
    PlatformAdmin,
    Restaurant,
    UddoktaPaySession,
)
from routers.orders import _order_to_dict
from schemas import (
    PlatformAccountPatchRequest,
    PlatformLoginRequest,
    PlatformOutletPatchRequest,
    PlatformSubscriptionRequest,
    ok,
)
from subscription_service import (
    _now,
    get_or_create_subscription,
    subscription_period_days,
    subscription_to_dict,
)
from uddoktapay_client import uddokta_configured

router = APIRouter(prefix="/platform", tags=["platform"])


def _admin_dict(admin: PlatformAdmin) -> dict:
    return {
        "id": admin.id,
        "email": admin.email,
        "displayName": admin.display_name,
        "role": admin.role,
    }


def _outlet_dict(outlet: Outlet, *, restaurant_name: str | None = None) -> dict:
    base_url = settings.BASE_URL.rstrip("/")
    return {
        "id": outlet.id,
        "restaurantId": outlet.restaurant_id,
        "restaurantName": restaurant_name,
        "name": outlet.name,
        "serverId": outlet.server_id,
        "status": outlet.status or "active",
        "notes": outlet.notes,
        "customerMenuUrl": f"{base_url}/menu/{outlet.id}",
        "createdAt": outlet.created_at.isoformat(),
    }


def _account_dict(account: AdminAccount) -> dict:
    return {
        "id": account.id,
        "outletId": account.outlet_id,
        "email": account.email,
        "username": account.username,
        "role": account.role,
        "displayName": account.display_name,
        "authProvider": account.auth_provider,
        "isActive": account.is_active,
        "createdAt": account.created_at.isoformat(),
    }


def _uddokta_payment_dict(
    session: UddoktaPaySession,
    *,
    outlet_name: str | None = None,
    restaurant_name: str | None = None,
) -> dict:
    paid = session.status in {"paid", "verified"}
    return {
        "paymentId": session.id,
        "gateway": "uddokta",
        "outletId": session.outlet_id,
        "outletName": outlet_name,
        "restaurantName": restaurant_name,
        "serverId": session.server_id,
        "amount": float(session.amount),
        "currency": session.currency,
        "purpose": session.purpose,
        "plan": session.plan,
        "status": "paid" if paid else session.status,
        "invoiceId": session.invoice_id,
        "transactionId": session.transaction_id,
        "createdAt": session.created_at.isoformat(),
    }


def _bkash_payment_dict(
    session: BkashSession,
    *,
    outlet_name: str | None = None,
    restaurant_name: str | None = None,
) -> dict:
    return {
        "paymentId": session.id,
        "gateway": "bkash",
        "outletId": None,
        "outletName": outlet_name,
        "restaurantName": restaurant_name,
        "serverId": session.server_id,
        "amount": float(session.amount),
        "currency": session.currency,
        "purpose": session.purpose,
        "plan": None,
        "status": session.status,
        "invoiceId": None,
        "transactionId": None,
        "createdAt": session.created_at.isoformat(),
    }


async def _require_platform_admin(
    admin_id: str = Depends(get_current_platform_admin_id),
    db: AsyncSession = Depends(get_db),
) -> PlatformAdmin:
    admin = (
        await db.execute(select(PlatformAdmin).where(PlatformAdmin.id == admin_id))
    ).scalar_one_or_none()
    if admin is None or not admin.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin")
    return admin


async def _get_outlet_or_404(outlet_id: str, db: AsyncSession) -> Outlet:
    outlet = (
        await db.execute(
            select(Outlet)
            .options(joinedload(Outlet.restaurant))
            .where(Outlet.id == outlet_id)
        )
    ).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Outlet not found")
    return outlet


async def _outlet_names_by_server_id(db: AsyncSession) -> dict[str, tuple[str | None, str | None]]:
    rows = (
        await db.execute(
            select(Outlet.server_id, Outlet.name, Restaurant.name)
            .join(Restaurant, Outlet.restaurant_id == Restaurant.id)
        )
    ).all()
    return {row[0]: (row[1], row[2]) for row in rows}


# ── Auth ──────────────────────────────────────────────────────────────────────

@router.post("/auth/login")
async def platform_login(body: PlatformLoginRequest, db: AsyncSession = Depends(get_db)):
    email = body.email.strip().lower()
    admin = (
        await db.execute(select(PlatformAdmin).where(PlatformAdmin.email == email))
    ).scalar_one_or_none()
    if admin is None or not admin.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    if not verify_password(body.password, admin.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    token = create_platform_token(admin.id)
    return ok({"token": token, "admin": _admin_dict(admin)})


@router.get("/auth/me")
async def platform_me(admin: PlatformAdmin = Depends(_require_platform_admin)):
    return ok(_admin_dict(admin))


# ── Dashboard ─────────────────────────────────────────────────────────────────

@router.get("/stats")
async def platform_stats(
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    now = _now()
    week_ago = now - timedelta(days=7)

    restaurants_count = (await db.execute(select(func.count()).select_from(Restaurant))).scalar() or 0
    outlets_count = (await db.execute(select(func.count()).select_from(Outlet))).scalar() or 0
    active_subs = (
        await db.execute(
            select(func.count()).select_from(OutletSubscription).where(
                OutletSubscription.status == "active"
            )
        )
    ).scalar() or 0
    pending_payments = (
        await db.execute(
            select(func.count()).select_from(UddoktaPaySession).where(
                UddoktaPaySession.status == "pending"
            )
        )
    ).scalar() or 0
    orders_7d = (
        await db.execute(
            select(func.count()).select_from(Order).where(Order.created_at >= week_ago)
        )
    ).scalar() or 0

    recent_outlets = (
        await db.execute(
            select(Outlet, Restaurant.name)
            .join(Restaurant, Outlet.restaurant_id == Restaurant.id)
            .order_by(Outlet.created_at.desc())
            .limit(10)
        )
    ).all()

    recent_payments = (
        await db.execute(
            select(UddoktaPaySession).order_by(UddoktaPaySession.created_at.desc()).limit(10)
        )
    ).scalars().all()
    names_by_server = await _outlet_names_by_server_id(db)

    return ok(
        {
            "restaurants": restaurants_count,
            "outlets": outlets_count,
            "activeSubscriptions": active_subs,
            "pendingPayments": pending_payments,
            "ordersLast7Days": orders_7d,
            "recentOutlets": [
                {**_outlet_dict(o, restaurant_name=rname), "restaurantName": rname}
                for o, rname in recent_outlets
            ],
            "recentPayments": [
                _uddokta_payment_dict(
                    p,
                    outlet_name=names_by_server.get(p.server_id, (None, None))[0],
                    restaurant_name=names_by_server.get(p.server_id, (None, None))[1],
                )
                for p in recent_payments
            ],
        }
    )


# ── Restaurants ───────────────────────────────────────────────────────────────

@router.get("/restaurants")
async def list_restaurants(
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
    q: str | None = Query(None),
):
    _ = admin
    query = select(Restaurant).order_by(Restaurant.created_at.desc())
    if q:
        query = query.where(Restaurant.name.ilike(f"%{q}%"))
    restaurants = (await db.execute(query)).scalars().all()

    outlet_rows = (
        await db.execute(select(Outlet).order_by(Outlet.created_at.desc()))
    ).scalars().all()
    outlets_by_restaurant: dict[str, list[Outlet]] = {}
    for outlet in outlet_rows:
        outlets_by_restaurant.setdefault(outlet.restaurant_id, []).append(outlet)

    return ok(
        [
            {
                "id": r.id,
                "name": r.name,
                "createdAt": r.created_at.isoformat(),
                "outlets": [
                    _outlet_dict(o, restaurant_name=r.name)
                    for o in outlets_by_restaurant.get(r.id, [])
                ],
            }
            for r in restaurants
        ]
    )


@router.get("/restaurants/{restaurant_id}")
async def get_restaurant(
    restaurant_id: str,
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    restaurant = (
        await db.execute(select(Restaurant).where(Restaurant.id == restaurant_id))
    ).scalar_one_or_none()
    if restaurant is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Restaurant not found")

    outlets = (
        await db.execute(
            select(Outlet).where(Outlet.restaurant_id == restaurant_id).order_by(Outlet.created_at)
        )
    ).scalars().all()

    return ok(
        {
            "id": restaurant.id,
            "name": restaurant.name,
            "createdAt": restaurant.created_at.isoformat(),
            "outlets": [_outlet_dict(o, restaurant_name=restaurant.name) for o in outlets],
        }
    )


# ── Outlets ───────────────────────────────────────────────────────────────────

@router.get("/outlets")
async def list_outlets(
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
    q: str | None = Query(None),
    status_filter: str | None = Query(None, alias="status"),
):
    _ = admin
    query = (
        select(Outlet, Restaurant.name)
        .join(Restaurant, Outlet.restaurant_id == Restaurant.id)
        .order_by(Outlet.created_at.desc())
    )
    if q:
        query = query.where(
            Outlet.name.ilike(f"%{q}%") | Restaurant.name.ilike(f"%{q}%") | Outlet.server_id.ilike(f"%{q}%")
        )
    if status_filter:
        query = query.where(Outlet.status == status_filter)

    rows = (await db.execute(query)).all()
    return ok([_outlet_dict(o, restaurant_name=rname) for o, rname in rows])


@router.get("/outlets/{outlet_id}")
async def get_outlet(
    outlet_id: str,
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    outlet = await _get_outlet_or_404(outlet_id, db)
    sub = (
        await db.execute(
            select(OutletSubscription).where(OutletSubscription.outlet_id == outlet_id)
        )
    ).scalar_one_or_none()

    return ok(
        {
            **_outlet_dict(outlet, restaurant_name=outlet.restaurant.name),
            "subscription": subscription_to_dict(sub, outlet_name=outlet.name) if sub else None,
        }
    )


@router.patch("/outlets/{outlet_id}")
async def patch_outlet(
    outlet_id: str,
    body: PlatformOutletPatchRequest,
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    outlet = await _get_outlet_or_404(outlet_id, db)
    if body.name is not None:
        outlet.name = body.name.strip()
    if body.status is not None:
        if body.status not in {"active", "suspended"}:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid status")
        outlet.status = body.status
    if body.notes is not None:
        outlet.notes = body.notes
    await db.commit()
    await db.refresh(outlet)
    return ok(_outlet_dict(outlet, restaurant_name=outlet.restaurant.name))


# ── Accounts ──────────────────────────────────────────────────────────────────

@router.get("/outlets/{outlet_id}/accounts")
async def list_outlet_accounts(
    outlet_id: str,
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    await _get_outlet_or_404(outlet_id, db)
    accounts = (
        await db.execute(
            select(AdminAccount)
            .where(AdminAccount.outlet_id == outlet_id)
            .order_by(AdminAccount.created_at)
        )
    ).scalars().all()
    return ok([_account_dict(a) for a in accounts])


@router.patch("/accounts/{account_id}")
async def patch_account(
    account_id: str,
    body: PlatformAccountPatchRequest,
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    account = (
        await db.execute(select(AdminAccount).where(AdminAccount.id == account_id))
    ).scalar_one_or_none()
    if account is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found")

    if body.isActive is not None:
        account.is_active = body.isActive
    if body.role is not None:
        if body.role not in {"manager", "staff"}:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid role")
        account.role = body.role
    if body.displayName is not None:
        account.display_name = body.displayName

    await db.commit()
    await db.refresh(account)
    return ok(_account_dict(account))


# ── Subscriptions ─────────────────────────────────────────────────────────────

@router.get("/subscriptions")
async def list_subscriptions(
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
    status_filter: str | None = Query(None, alias="status"),
):
    _ = admin
    query = (
        select(OutletSubscription, Outlet.name, Restaurant.name)
        .join(Outlet, OutletSubscription.outlet_id == Outlet.id)
        .join(Restaurant, Outlet.restaurant_id == Restaurant.id)
        .order_by(OutletSubscription.updated_at.desc())
    )
    if status_filter:
        query = query.where(OutletSubscription.status == status_filter)

    rows = (await db.execute(query)).all()
    return ok(
        [
            {
                **subscription_to_dict(sub, outlet_name=oname),
                "restaurantName": rname,
            }
            for sub, oname, rname in rows
        ]
    )


@router.post("/outlets/{outlet_id}/subscription")
async def manage_subscription(
    outlet_id: str,
    body: PlatformSubscriptionRequest,
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    outlet = await _get_outlet_or_404(outlet_id, db)
    sub = await get_or_create_subscription(db, outlet_id)
    now = _now()

    if body.status not in {"trial", "active", "expired", "cancelled"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid status")

    sub.plan = body.plan if body.plan in {"monthly", "annual"} else sub.plan
    sub.status = body.status

    if body.extendDays is not None and body.extendDays > 0:
        base = sub.expires_at if sub.expires_at and sub.expires_at > now else now
        sub.expires_at = base + timedelta(days=body.extendDays)
        sub.status = "active"
    elif body.status == "active" and sub.expires_at is None:
        sub.expires_at = now + timedelta(days=subscription_period_days(sub.plan))

    sub.updated_at = now
    await db.commit()
    await db.refresh(sub)
    return ok(subscription_to_dict(sub, outlet_name=outlet.name))


# ── Payments ────────────────────────────────────────────────────────────────────

@router.get("/payments")
async def list_payments(
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
    limit: int = Query(50, ge=1, le=200),
    gateway: str | None = Query(None),
):
    _ = admin
    names_by_server = await _outlet_names_by_server_id(db)
    results: list[dict] = []

    if gateway in (None, "uddokta"):
        uddokta = (
            await db.execute(
                select(UddoktaPaySession).order_by(UddoktaPaySession.created_at.desc()).limit(limit)
            )
        ).scalars().all()
        for p in uddokta:
            oname, rname = names_by_server.get(p.server_id, (None, None))
            results.append(_uddokta_payment_dict(p, outlet_name=oname, restaurant_name=rname))

    if gateway in (None, "bkash"):
        bkash = (
            await db.execute(
                select(BkashSession).order_by(BkashSession.created_at.desc()).limit(limit)
            )
        ).scalars().all()
        for p in bkash:
            oname, rname = names_by_server.get(p.server_id, (None, None))
            results.append(_bkash_payment_dict(p, outlet_name=oname, restaurant_name=rname))

    results.sort(key=lambda x: x["createdAt"], reverse=True)
    return ok(results[:limit])


# ── Orders (read-only) ────────────────────────────────────────────────────────

@router.get("/outlets/{outlet_id}/orders")
async def list_outlet_orders(
    outlet_id: str,
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
    limit: int = Query(50, ge=1, le=200),
):
    _ = admin
    await _get_outlet_or_404(outlet_id, db)
    orders = (
        await db.execute(
            select(Order)
            .where(Order.outlet_id == outlet_id)
            .order_by(Order.created_at.desc())
            .limit(limit)
        )
    ).scalars().all()
    return ok([_order_to_dict(o) for o in orders])


# ── Customer preview ──────────────────────────────────────────────────────────

@router.get("/outlets/{outlet_id}/customer-info")
async def outlet_customer_info(
    outlet_id: str,
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    outlet = await _get_outlet_or_404(outlet_id, db)
    menu_count = (
        await db.execute(
            select(func.count())
            .select_from(MenuItem)
            .where(MenuItem.outlet_id == outlet_id, MenuItem.deleted_at.is_(None))
        )
    ).scalar() or 0

    base_url = settings.BASE_URL.rstrip("/")
    return ok(
        {
            "outletId": outlet.id,
            "outletName": outlet.name,
            "restaurantName": outlet.restaurant.name,
            "customerMenuUrl": f"{base_url}/menu/{outlet.id}",
            "bannerUrl": outlet.banner_url,
            "videoUrl": outlet.video_url,
            "galleryImageCount": len(outlet.gallery_images or []),
            "menuItemCount": menu_count,
        }
    )


# ── System config ─────────────────────────────────────────────────────────────

@router.get("/system/config")
async def system_config(admin: PlatformAdmin = Depends(_require_platform_admin)):
    _ = admin
    return ok(
        {
            "baseUrl": settings.BASE_URL,
            "uddoktaPayEnabled": uddokta_configured(),
            "uddoktaPaySandbox": settings.UDDOKTAPAY_SANDBOX,
        }
    )
