"""Company platform admin API — manage all restaurants, outlets, subscriptions."""

import json
import re
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from sqlalchemy import desc, extract, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from auth import (
    create_platform_token,
    get_current_platform_admin_id,
    hash_password,
    verify_password,
)
from config import settings
from database import get_db
from models import (
    AdminAccount,
    BkashSession,
    Device,
    MenuItem,
    Order,
    Outlet,
    OutletSubscription,
    PlatformAdmin,
    Restaurant,
    SystemConfig,
    UddoktaPaySession,
)
from routers.orders import _order_to_dict
from routers.ws import manager
from schemas import (
    OutletAccountCreateRequest,
    OutletCreateRequest,
    PlatformAppUpdateRequest,
    PlatformAccountPatchRequest,
    PlatformAdminCreateRequest,
    PlatformAdminPatchRequest,
    PlatformBlockingNoticeRequest,
    PlatformLoginRequest,
    PlatformOutletPatchRequest,
    PlatformPaymentStatusPatchRequest,
    PlatformSubscriptionRequest,
    SystemConfigPatchRequest,
    ok,
)
from subscription_service import (
    activate_subscription_from_payment,
    _now,
    get_or_create_subscription,
    grant_outlet_access,
    outlet_has_app_access,
    outlet_needs_activation,
    resolve_outlet_by_server_id,
    subscription_to_dict,
)
from services.app_update import (
    apk_filename,
    app_update_event_type,
    clear_app_update,
    extract_apk_version,
    get_app_update,
    normalize_app_update_channel,
    promote_apk,
    save_apk_upload,
    set_app_update,
    validate_apk_file,
)
from services.blocking_notice import (
    clear_blocking_notice,
    get_blocking_notice,
    set_blocking_notice,
)
from uddoktapay_client import uddokta_configured

router = APIRouter(prefix="/platform", tags=["platform"])


def _customer_menu_url(outlet: Outlet) -> str:
    base_url = settings.BASE_URL.rstrip("/")
    subdomain = (outlet.public_slug or "").strip().lower()
    is_uuid_like = bool(
        re.fullmatch(
            r"[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}",
            subdomain,
        )
    )
    if (
        not is_uuid_like
        and re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", subdomain)
    ):
        if base_url == "https://quickbytes.buzz":
            return f"https://{subdomain}.quickbytes.buzz"
    return f"{base_url}/menu/{outlet.id}"


def _admin_dict(admin: PlatformAdmin) -> dict:
    return {
        "id": admin.id,
        "email": admin.email,
        "displayName": admin.display_name,
        "role": admin.role,
    }


def _platform_admin_full_dict(admin: PlatformAdmin) -> dict:
    return {
        "id": admin.id,
        "email": admin.email,
        "displayName": admin.display_name,
        "role": admin.role,
        "isActive": admin.is_active,
        "createdAt": admin.created_at.isoformat(),
    }


def _outlet_dict(outlet: Outlet, *, restaurant_name: str | None = None) -> dict:
    return {
        "id": outlet.id,
        "restaurantId": outlet.restaurant_id,
        "restaurantName": restaurant_name,
        "name": outlet.name,
        "serverId": outlet.server_id,
        "publicSlug": outlet.public_slug,
        "status": outlet.status or "active",
        "notes": outlet.notes,
        "customerMenuUrl": _customer_menu_url(outlet),
        "createdAt": outlet.created_at.isoformat(),
    }


def _account_dict(account: AdminAccount) -> dict:
    from phone_utils import display_phone

    return {
        "id": account.id,
        "outletId": account.outlet_id,
        "email": account.email,
        "username": account.username,
        "phone": display_phone(account.phone),
        "role": account.role,
        "displayName": account.display_name,
        "authProvider": account.auth_provider,
        "isActive": account.is_active,
        "inviteStatus": account.invite_status,
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


async def _manager_email_for_outlet(db: AsyncSession, outlet_id: str) -> str | None:
    return (
        await db.execute(
            select(AdminAccount.email)
            .where(AdminAccount.outlet_id == outlet_id, AdminAccount.role.in_(("owner", "manager")))
            .limit(1)
        )
    ).scalar_one_or_none()


async def _manager_phone_for_outlet(db: AsyncSession, outlet_id: str) -> str | None:
    from phone_utils import display_phone

    phone = (
        await db.execute(
            select(AdminAccount.phone)
            .where(AdminAccount.outlet_id == outlet_id, AdminAccount.role.in_(("owner", "manager")))
            .limit(1)
        )
    ).scalar_one_or_none()
    return display_phone(phone)


def _activation_dict(
    *,
    outlet: Outlet,
    restaurant_name: str,
    sub: OutletSubscription | None,
    manager_email: str | None,
    manager_phone: str | None = None,
) -> dict:
    return {
        "outletId": outlet.id,
        "outletName": outlet.name,
        "restaurantName": restaurant_name,
        "serverId": outlet.server_id,
        "managerEmail": manager_email,
        "managerPhone": manager_phone,
        "plan": sub.plan if sub else "monthly",
        "package": sub.package if sub else None,
        "status": sub.status if sub else "none",
        "hasAppAccess": outlet_has_app_access(sub),
        "createdAt": outlet.created_at.isoformat(),
        "requestedAt": (sub.updated_at if sub else outlet.created_at).isoformat(),
    }


async def _list_pending_activations(db: AsyncSession, *, limit: int = 50) -> list[dict]:
    rows = (
        await db.execute(
            select(Outlet, Restaurant.name, OutletSubscription)
            .join(Restaurant, Outlet.restaurant_id == Restaurant.id)
            .outerjoin(OutletSubscription, OutletSubscription.outlet_id == Outlet.id)
            .order_by(desc(Outlet.created_at))
        )
    ).all()
    results: list[dict] = []
    for outlet, rname, sub in rows:
        if not outlet_needs_activation(sub):
            continue
        manager_email = await _manager_email_for_outlet(db, outlet.id)
        manager_phone = await _manager_phone_for_outlet(db, outlet.id)
        results.append(
            _activation_dict(
                outlet=outlet,
                restaurant_name=rname,
                sub=sub,
                manager_email=manager_email,
                manager_phone=manager_phone,
            )
        )
        if len(results) >= limit:
            break
    return results


async def _count_pending_activations(db: AsyncSession) -> int:
    rows = (
        await db.execute(
            select(Outlet, OutletSubscription)
            .outerjoin(OutletSubscription, OutletSubscription.outlet_id == Outlet.id)
        )
    ).all()
    return sum(1 for _outlet, sub in rows if outlet_needs_activation(sub))


async def _get_system_config(db: AsyncSession) -> dict[str, str]:
    rows = (await db.execute(select(SystemConfig))).scalars().all()
    return {r.key: r.value for r in rows}


async def _set_system_config(db: AsyncSession, key: str, value: str) -> None:
    existing = (
        await db.execute(select(SystemConfig).where(SystemConfig.key == key))
    ).scalar_one_or_none()
    if existing:
        existing.value = value
        existing.updated_at = _now()
    else:
        db.add(SystemConfig(key=key, value=value))


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
    return ok(_platform_admin_full_dict(admin))


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
    trial_subs = (
        await db.execute(
            select(func.count()).select_from(OutletSubscription).where(
                OutletSubscription.status == "trial"
            )
        )
    ).scalar() or 0
    active_subs = (
        await db.execute(
            select(func.count()).select_from(OutletSubscription).where(
                OutletSubscription.status == "active"
            )
        )
    ).scalar() or 0
    pending_activations = await _count_pending_activations(db)
    orders_7d = (
        await db.execute(
            select(func.count()).select_from(Order).where(Order.created_at >= week_ago)
        )
    ).scalar() or 0

    # MRR: sum of paid sessions in last 30 days
    thirty_days_ago = now - timedelta(days=30)
    mrr_result = (
        await db.execute(
            select(func.sum(UddoktaPaySession.amount))
            .where(
                UddoktaPaySession.created_at >= thirty_days_ago,
                UddoktaPaySession.status.in_(["paid", "verified"]),
            )
        )
    ).scalar()
    mrr = float(mrr_result or 0)

    # Expiring subs in next 7 days
    seven_days_ahead = now + timedelta(days=7)
    expiring_soon = (
        await db.execute(
            select(func.count())
            .select_from(OutletSubscription)
            .where(
                OutletSubscription.status.in_(["trial", "active"]),
                OutletSubscription.expires_at <= seven_days_ahead,
                OutletSubscription.expires_at >= now,
            )
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

    pending_activation_rows = await _list_pending_activations(db, limit=10)

    return ok(
        {
            "restaurants": restaurants_count,
            "outlets": outlets_count,
            "trialSubscriptions": trial_subs,
            "activeSubscriptions": active_subs,
            "pendingActivations": pending_activations,
            "pendingPayments": pending_activations,
            "ordersLast7Days": orders_7d,
            "mrr": mrr,
            "expiringSoon": expiring_soon,
            "recentOutlets": [
                {**_outlet_dict(o, restaurant_name=rname), "restaurantName": rname}
                for o, rname in recent_outlets
            ],
            "pendingActivationsList": pending_activation_rows,
            "recentPayments": [],
        }
    )


# ── Analytics ─────────────────────────────────────────────────────────────────

@router.get("/analytics")
async def platform_analytics(
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    now = _now()
    six_months_ago = now - timedelta(days=183)
    thirty_days_ago = now - timedelta(days=30)

    # MRR and ARR
    mrr_result = (
        await db.execute(
            select(func.sum(UddoktaPaySession.amount))
            .where(
                UddoktaPaySession.created_at >= thirty_days_ago,
                UddoktaPaySession.status.in_(["paid", "verified"]),
            )
        )
    ).scalar()
    mrr = float(mrr_result or 0)
    arr = mrr * 12

    # Revenue by month (last 6 months), paid sessions only
    revenue_rows = (
        await db.execute(
            select(
                extract("year", UddoktaPaySession.created_at).label("yr"),
                extract("month", UddoktaPaySession.created_at).label("mo"),
                func.sum(UddoktaPaySession.amount).label("revenue"),
                func.count(UddoktaPaySession.id).label("count"),
            )
            .where(
                UddoktaPaySession.created_at >= six_months_ago,
                UddoktaPaySession.status.in_(["paid", "verified"]),
            )
            .group_by("yr", "mo")
            .order_by("yr", "mo")
        )
    ).all()

    revenue_by_month = [
        {
            "month": f"{int(row.yr)}-{int(row.mo):02d}",
            "revenue": float(row.revenue or 0),
            "count": int(row.count or 0),
        }
        for row in revenue_rows
    ]

    # New outlets by month (last 6 months)
    outlet_rows = (
        await db.execute(
            select(
                extract("year", Outlet.created_at).label("yr"),
                extract("month", Outlet.created_at).label("mo"),
                func.count(Outlet.id).label("count"),
            )
            .where(Outlet.created_at >= six_months_ago)
            .group_by("yr", "mo")
            .order_by("yr", "mo")
        )
    ).all()

    outlets_by_month = [
        {
            "month": f"{int(row.yr)}-{int(row.mo):02d}",
            "count": int(row.count or 0),
        }
        for row in outlet_rows
    ]

    # Subscription status breakdown
    sub_rows = (
        await db.execute(
            select(OutletSubscription.status, func.count(OutletSubscription.id))
            .group_by(OutletSubscription.status)
        )
    ).all()
    subscription_breakdown = {row[0]: int(row[1]) for row in sub_rows}

    # Top outlets by total revenue (all time)
    top_rows = (
        await db.execute(
            select(
                UddoktaPaySession.outlet_id,
                Outlet.name.label("outlet_name"),
                Restaurant.name.label("restaurant_name"),
                func.sum(UddoktaPaySession.amount).label("total_revenue"),
                func.count(UddoktaPaySession.id).label("payment_count"),
            )
            .join(Outlet, UddoktaPaySession.outlet_id == Outlet.id)
            .join(Restaurant, Outlet.restaurant_id == Restaurant.id)
            .where(UddoktaPaySession.status.in_(["paid", "verified"]))
            .group_by(UddoktaPaySession.outlet_id, Outlet.name, Restaurant.name)
            .order_by(desc("total_revenue"))
            .limit(10)
        )
    ).all()

    top_outlets = [
        {
            "outletId": row.outlet_id,
            "outletName": row.outlet_name,
            "restaurantName": row.restaurant_name,
            "totalRevenue": float(row.total_revenue or 0),
            "paymentCount": int(row.payment_count or 0),
        }
        for row in top_rows
    ]

    # Total revenue all time
    total_revenue_result = (
        await db.execute(
            select(func.sum(UddoktaPaySession.amount))
            .where(UddoktaPaySession.status.in_(["paid", "verified"]))
        )
    ).scalar()
    total_revenue = float(total_revenue_result or 0)

    return ok(
        {
            "mrr": mrr,
            "arr": arr,
            "totalRevenue": total_revenue,
            "revenueByMonth": revenue_by_month,
            "outletsByMonth": outlets_by_month,
            "subscriptionBreakdown": subscription_breakdown,
            "topOutlets": top_outlets,
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


@router.post("/outlets")
async def create_outlet(
    body: OutletCreateRequest,
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    existing = (
        await db.execute(select(Outlet).where(Outlet.server_id == body.serverId))
    ).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Server ID already exists")

    if body.restaurantId:
        restaurant = (
            await db.execute(select(Restaurant).where(Restaurant.id == body.restaurantId))
        ).scalar_one_or_none()
        if restaurant is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Restaurant not found")
        if body.restaurantName.strip():
            restaurant.name = body.restaurantName.strip()
    else:
        restaurant = Restaurant(name=body.restaurantName.strip())
        db.add(restaurant)
        await db.flush()

    outlet = Outlet(
        restaurant_id=restaurant.id,
        name=body.outletName.strip(),
        server_id=body.serverId.strip(),
        status="active",
    )
    db.add(outlet)
    await db.flush()

    now = _now()
    sub = OutletSubscription(
        outlet_id=outlet.id,
        plan="trial",
        status="trial",
        starts_at=now,
        expires_at=now + timedelta(days=10),
    )
    db.add(sub)
    await db.commit()
    await db.refresh(outlet)
    return ok(_outlet_dict(outlet, restaurant_name=restaurant.name))


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


# ── Outlet activity ───────────────────────────────────────────────────────────

@router.get("/outlets/{outlet_id}/activity")
async def outlet_activity(
    outlet_id: str,
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    await _get_outlet_or_404(outlet_id, db)
    now = _now()
    thirty_days_ago = now - timedelta(days=30)

    total_orders = (
        await db.execute(
            select(func.count()).select_from(Order).where(Order.outlet_id == outlet_id)
        )
    ).scalar() or 0

    orders_30d = (
        await db.execute(
            select(func.count())
            .select_from(Order)
            .where(Order.outlet_id == outlet_id, Order.created_at >= thirty_days_ago)
        )
    ).scalar() or 0

    last_order = (
        await db.execute(
            select(Order)
            .where(Order.outlet_id == outlet_id)
            .order_by(Order.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    account_count = (
        await db.execute(
            select(func.count()).select_from(AdminAccount).where(AdminAccount.outlet_id == outlet_id)
        )
    ).scalar() or 0

    device_count = (
        await db.execute(
            select(func.count()).select_from(Device).where(Device.outlet_id == outlet_id)
        )
    ).scalar() or 0

    total_revenue = (
        await db.execute(
            select(func.sum(UddoktaPaySession.amount))
            .where(
                UddoktaPaySession.outlet_id == outlet_id,
                UddoktaPaySession.status.in_(["paid", "verified"]),
            )
        )
    ).scalar()

    return ok(
        {
            "outletId": outlet_id,
            "totalOrders": total_orders,
            "ordersLast30Days": orders_30d,
            "lastOrderAt": last_order.created_at.isoformat() if last_order else None,
            "accountCount": account_count,
            "deviceCount": device_count,
            "totalRevenue": float(total_revenue or 0),
        }
    )


# ── Accounts ──────────────────────────────────────────────────────────────────

@router.get("/accounts/search")
async def search_accounts(
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
    q: str = Query("", min_length=1),
):
    _ = admin
    rows = (
        await db.execute(
            select(AdminAccount, Outlet.name, Restaurant.name)
            .join(Outlet, AdminAccount.outlet_id == Outlet.id)
            .join(Restaurant, Outlet.restaurant_id == Restaurant.id)
            .where(AdminAccount.phone.ilike(f"%{q}%"))
            .order_by(AdminAccount.created_at.desc())
            .limit(50)
        )
    ).all()
    results = []
    for account, outlet_name, restaurant_name in rows:
        from phone_utils import display_phone
        results.append({
            "id": account.id,
            "outletId": account.outlet_id,
            "outletName": outlet_name,
            "restaurantName": restaurant_name,
            "phone": display_phone(account.phone),
            "displayName": account.display_name,
        })
    return ok(results)


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


@router.post("/outlets/{outlet_id}/accounts")
async def create_outlet_account(
    outlet_id: str,
    body: OutletAccountCreateRequest,
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    await _get_outlet_or_404(outlet_id, db)

    email_taken = (
        await db.execute(select(AdminAccount).where(AdminAccount.email == body.email.strip().lower()))
    ).scalar_one_or_none()
    if email_taken:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already in use")

    username_taken = (
        await db.execute(select(AdminAccount).where(AdminAccount.username == body.username.strip()))
    ).scalar_one_or_none()
    if username_taken:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Username already in use")

    role = body.role if body.role in {"owner", "manager", "waiter"} else "manager"
    account = AdminAccount(
        outlet_id=outlet_id,
        email=body.email.strip().lower(),
        username=body.username.strip(),
        password_hash=hash_password(body.password),
        role=role,
        display_name=body.displayName,
        auth_provider="password",
        is_active=True,
    )
    db.add(account)
    await db.commit()
    await db.refresh(account)
    return ok(_account_dict(account))


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
        if body.role not in {"owner", "manager", "waiter"}:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid role")
        account.role = body.role
    if body.displayName is not None:
        account.display_name = body.displayName

    await db.commit()
    await db.refresh(account)
    return ok(_account_dict(account))


# ── Platform admins ───────────────────────────────────────────────────────────

@router.get("/admins")
async def list_platform_admins(
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    admins = (
        await db.execute(select(PlatformAdmin).order_by(PlatformAdmin.created_at))
    ).scalars().all()
    return ok([_platform_admin_full_dict(a) for a in admins])


@router.post("/admins")
async def create_platform_admin(
    body: PlatformAdminCreateRequest,
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    email = body.email.strip().lower()
    existing = (
        await db.execute(select(PlatformAdmin).where(PlatformAdmin.email == email))
    ).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already in use")

    new_admin = PlatformAdmin(
        email=email,
        password_hash=hash_password(body.password),
        display_name=body.displayName,
        role="admin",
        is_active=True,
    )
    db.add(new_admin)
    await db.commit()
    await db.refresh(new_admin)
    return ok(_platform_admin_full_dict(new_admin))


@router.patch("/admins/{admin_id}")
async def patch_platform_admin(
    admin_id: str,
    body: PlatformAdminPatchRequest,
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    target = (
        await db.execute(select(PlatformAdmin).where(PlatformAdmin.id == admin_id))
    ).scalar_one_or_none()
    if target is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Admin not found")

    if body.isActive is not None:
        target.is_active = body.isActive
    if body.displayName is not None:
        target.display_name = body.displayName
    if body.password:
        target.password_hash = hash_password(body.password)

    await db.commit()
    await db.refresh(target)
    return ok(_platform_admin_full_dict(target))


# ── Subscriptions ─────────────────────────────────────────────────────────────

@router.get("/activations")
async def list_pending_activations(
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
    limit: int = Query(100, ge=1, le=200),
):
    """Outlets waiting for platform admin to grant app access (no payment gateway required)."""
    _ = admin
    return ok(await _list_pending_activations(db, limit=limit))


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


_VALID_SUB_STATUSES = frozenset({"trial", "active", "on_hold", "paused", "cancelled"})
_LEGACY_STATUS_MAP = {"pending": "on_hold", "expired": "on_hold"}


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

    # Normalise status — accept new values and map legacy ones
    raw_status = (body.status or "").strip().lower()
    status = _LEGACY_STATUS_MAP.get(raw_status, raw_status)
    if status not in _VALID_SUB_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status. Use one of: {', '.join(sorted(_VALID_SUB_STATUSES))}",
        )

    if body.package:
        clean = body.package.strip().lower()
        if clean not in {"standard", "pro", "premium"}:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Package must be one of: standard, pro, premium",
            )
        sub.package = clean

    sub.plan = body.plan if body.plan in {"monthly", "annual"} else sub.plan
    sub.status = status

    # Custom expiresAt takes priority over extendDays
    custom_expires_at: datetime | None = None
    if body.expiresAt:
        try:
            parsed = datetime.fromisoformat(body.expiresAt.replace("Z", "+00:00"))
            custom_expires_at = parsed.astimezone(timezone.utc).replace(tzinfo=timezone.utc)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid expiresAt date")

    if status == "active":
        pkg = body.package.strip().lower() if body.package else (sub.package or "standard")
        if custom_expires_at is not None:
            sub.status = "active"
            sub.starts_at = now
            sub.expires_at = custom_expires_at
            sub.updated_at = now
            await db.flush()
        else:
            days = body.extendDays if body.extendDays and body.extendDays > 0 else None
            sub = await grant_outlet_access(
                db,
                outlet_id,
                package=pkg,
                grant_days=days,
            )
    elif body.extendDays is not None and body.extendDays > 0:
        base = sub.expires_at if sub.expires_at and sub.expires_at > now else now
        sub.expires_at = base + timedelta(days=body.extendDays)
        sub.updated_at = now
    elif status == "active" and sub.expires_at is None:
        sub.expires_at = now + timedelta(days=30)
        sub.updated_at = now
    else:
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


_PAYMENT_STATUSES = frozenset({"pending", "paid", "verified", "failed", "cancelled"})


@router.patch("/payments/{gateway}/{payment_id}")
async def patch_payment_status(
    gateway: str,
    payment_id: str,
    body: PlatformPaymentStatusPatchRequest,
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    """Update payment status (e.g. mark paid) so the outlet can use the admin app."""
    _ = admin
    status_value = body.status.strip().lower()
    if status_value not in _PAYMENT_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status. Use one of: {', '.join(sorted(_PAYMENT_STATUSES))}",
        )

    gateway_key = gateway.strip().lower()
    if gateway_key == "uddokta":
        session = (
            await db.execute(
                select(UddoktaPaySession).where(UddoktaPaySession.id == payment_id)
            )
        ).scalar_one_or_none()
        if session is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found.")
        session.status = status_value
        if status_value in {"paid", "verified"} and body.activateSubscription:
            await activate_subscription_from_payment(db, session)
        await db.commit()
        await db.refresh(session)
        names = await _outlet_names_by_server_id(db)
        oname, rname = names.get(session.server_id, (None, None))
        return ok(_uddokta_payment_dict(session, outlet_name=oname, restaurant_name=rname))

    if gateway_key == "bkash":
        session = (
            await db.execute(select(BkashSession).where(BkashSession.id == payment_id))
        ).scalar_one_or_none()
        if session is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found.")
        session.status = "verified" if status_value in {"paid", "verified"} else status_value
        if status_value in {"paid", "verified"} and body.activateSubscription:
            outlet = await resolve_outlet_by_server_id(db, session.server_id)
            if outlet is not None:
                sub = await get_or_create_subscription(db, outlet.id)
                now = _now()
                sub.status = "active"
                sub.expires_at = now + timedelta(days=subscription_period_days("monthly"))
                sub.updated_at = now
        await db.commit()
        await db.refresh(session)
        names = await _outlet_names_by_server_id(db)
        oname, rname = names.get(session.server_id, (None, None))
        return ok(_bkash_payment_dict(session, outlet_name=oname, restaurant_name=rname))

    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unknown gateway.")


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

    return ok(
        {
            "outletId": outlet.id,
            "outletName": outlet.name,
            "restaurantName": outlet.restaurant.name,
            "customerMenuUrl": _customer_menu_url(outlet),
            "publicSlug": outlet.public_slug,
            "bannerUrl": outlet.banner_url,
            "logoUrl": outlet.logo_url,
            "videoUrl": outlet.video_url,
            "galleryImageCount": len(outlet.gallery_images or []),
            "menuItemCount": menu_count,
        }
    )


# ── Alerts ────────────────────────────────────────────────────────────────────

@router.get("/alerts")
async def platform_alerts(
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    now = _now()
    seven_days_ahead = now + timedelta(days=7)
    twenty_four_hours_ago = now - timedelta(hours=24)

    alerts: list[dict] = []

    # Subscriptions expiring in <= 7 days
    expiring = (
        await db.execute(
            select(OutletSubscription, Outlet.name, Restaurant.name)
            .join(Outlet, OutletSubscription.outlet_id == Outlet.id)
            .join(Restaurant, Outlet.restaurant_id == Restaurant.id)
            .where(
                OutletSubscription.status.in_(["trial", "active"]),
                OutletSubscription.expires_at <= seven_days_ahead,
                OutletSubscription.expires_at >= now,
            )
            .order_by(OutletSubscription.expires_at)
            .limit(20)
        )
    ).all()
    for sub, oname, rname in expiring:
        days_left = max(0, (sub.expires_at - now).days) if sub.expires_at else 0
        alerts.append(
            {
                "type": "expiring_subscription",
                "severity": "warning" if days_left > 2 else "critical",
                "title": f"Subscription expiring soon — {oname}",
                "message": f"{rname} · {oname} subscription expires in {days_left} day(s)",
                "outletId": sub.outlet_id,
                "meta": {"expiresAt": sub.expires_at.isoformat() if sub.expires_at else None},
            }
        )

    pending_count = await _count_pending_activations(db)
    if pending_count > 0:
        alerts.append(
            {
                "type": "pending_activations",
                "severity": "warning",
                "title": f"{pending_count} restaurant(s) awaiting activation",
                "message": "Open Activations to grant app access after plan selection",
                "outletId": None,
                "meta": {"count": pending_count},
            }
        )

    # Suspended outlets
    suspended = (
        await db.execute(
            select(Outlet, Restaurant.name)
            .join(Restaurant, Outlet.restaurant_id == Restaurant.id)
            .where(Outlet.status == "suspended")
            .limit(10)
        )
    ).all()
    for outlet, rname in suspended:
        alerts.append(
            {
                "type": "suspended_outlet",
                "severity": "info",
                "title": f"Outlet suspended — {outlet.name}",
                "message": f"{rname} · {outlet.name} is currently suspended",
                "outletId": outlet.id,
                "meta": {},
            }
        )

    # New outlet registrations in last 24h
    new_outlets = (
        await db.execute(
            select(Outlet, Restaurant.name)
            .join(Restaurant, Outlet.restaurant_id == Restaurant.id)
            .where(Outlet.created_at >= twenty_four_hours_ago)
            .order_by(Outlet.created_at.desc())
            .limit(10)
        )
    ).all()
    for outlet, rname in new_outlets:
        alerts.append(
            {
                "type": "new_registration",
                "severity": "success",
                "title": f"New outlet registered — {outlet.name}",
                "message": f"{rname} · {outlet.name} joined in the last 24 hours",
                "outletId": outlet.id,
                "meta": {"createdAt": outlet.created_at.isoformat()},
            }
        )

    return ok(alerts)


# ── System health ─────────────────────────────────────────────────────────────

@router.get("/health")
async def platform_health(
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    now = _now()
    twenty_four_hours_ago = now - timedelta(hours=24)

    db_ok = True
    try:
        await db.execute(select(func.count()).select_from(Restaurant))
    except Exception:
        db_ok = False

    restaurants_count = (await db.execute(select(func.count()).select_from(Restaurant))).scalar() or 0
    outlets_count = (await db.execute(select(func.count()).select_from(Outlet))).scalar() or 0
    orders_24h = (
        await db.execute(
            select(func.count()).select_from(Order).where(Order.created_at >= twenty_four_hours_ago)
        )
    ).scalar() or 0

    from storage import use_r2
    storage_mode = "r2" if use_r2() else "local"

    return ok(
        {
            "api": "ok",
            "database": "ok" if db_ok else "error",
            "storageMode": storage_mode,
            "baseUrl": settings.BASE_URL,
            "uddoktaPayConfigured": uddokta_configured(),
            "restaurants": restaurants_count,
            "outlets": outlets_count,
            "ordersLast24h": orders_24h,
            "checkedAt": now.isoformat(),
        }
    )


# ── System config ─────────────────────────────────────────────────────────────

@router.get("/system/config")
async def system_config(
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    cfg = await _get_system_config(db)
    sub_prices_raw = cfg.get("subscription_prices")
    addon_prices_raw = cfg.get("addon_prices")
    subscription_prices = (
        json.loads(sub_prices_raw) if sub_prices_raw
        else {"standard": 500, "pro": 700, "premium": 1000}
    )
    addon_prices = (
        json.loads(addon_prices_raw) if addon_prices_raw
        else {"inventory": 199, "website_qr": 199, "messenger_bot": 199}
    )

    return ok(
        {
            "baseUrl": cfg.get("base_url") or settings.BASE_URL,
            "uddoktaPayEnabled": uddokta_configured(),
            "uddoktaPaySandbox": settings.UDDOKTAPAY_SANDBOX,
            "bkashEnabled": cfg.get("bkash_enabled", "false") == "true",
            "maintenanceMode": cfg.get("maintenance_mode", "false") == "true",
            "supportEmail": cfg.get("support_email", ""),
            "subscriptionPrices": subscription_prices,
            "addonPrices": addon_prices,
        }
    )


@router.patch("/system/config")
async def update_system_config(
    body: SystemConfigPatchRequest,
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    if body.baseUrl is not None:
        await _set_system_config(db, "base_url", body.baseUrl.strip())
    if body.bkashEnabled is not None:
        await _set_system_config(db, "bkash_enabled", "true" if body.bkashEnabled else "false")
    if body.maintenanceMode is not None:
        await _set_system_config(db, "maintenance_mode", "true" if body.maintenanceMode else "false")
    if body.supportEmail is not None:
        await _set_system_config(db, "support_email", body.supportEmail.strip())
    if body.subscriptionPrices is not None:
        await _set_system_config(
            db, "subscription_prices", json.dumps(body.subscriptionPrices)
        )
    if body.addonPrices is not None:
        await _set_system_config(
            db, "addon_prices", json.dumps(body.addonPrices)
        )
    await db.commit()

    cfg = await _get_system_config(db)
    sub_prices_raw = cfg.get("subscription_prices")
    addon_prices_raw = cfg.get("addon_prices")
    subscription_prices = (
        json.loads(sub_prices_raw) if sub_prices_raw
        else {"standard": 500, "pro": 700, "premium": 1000}
    )
    addon_prices = (
        json.loads(addon_prices_raw) if addon_prices_raw
        else {"inventory": 199, "website_qr": 199, "messenger_bot": 199}
    )
    return ok(
        {
            "baseUrl": cfg.get("base_url") or settings.BASE_URL,
            "uddoktaPayEnabled": uddokta_configured(),
            "uddoktaPaySandbox": settings.UDDOKTAPAY_SANDBOX,
            "bkashEnabled": cfg.get("bkash_enabled", "false") == "true",
            "maintenanceMode": cfg.get("maintenance_mode", "false") == "true",
            "supportEmail": cfg.get("support_email", ""),
            "subscriptionPrices": subscription_prices,
            "addonPrices": addon_prices,
        }
    )


@router.get("/app-update")
async def current_app_update(
    app: str = Query("admin"),
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    return ok(await get_app_update(db, app=app))


@router.post("/app-update")
async def publish_app_update(
    body: PlatformAppUpdateRequest,
    app: str = Query("admin"),
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    channel = normalize_app_update_channel(app)
    payload = await set_app_update(db, body, app=channel)
    await db.commit()

    event_type = app_update_event_type(channel, enabled=True)
    outlet_ids = (await db.execute(select(Outlet.id))).scalars().all()
    for outlet_id in outlet_ids:
        await manager.broadcast(
            outlet_id,
            {"type": event_type, "data": payload},
        )

    return ok({**payload, "app": channel, "notifiedOutlets": len(outlet_ids)})


@router.post("/app-update/upload")
async def upload_app_update(
    file: UploadFile = File(...),
    versionName: str | None = Form(None),
    versionCode: int | None = Form(None),
    releaseNotes: str | None = Form(None),
    required: bool = Form(True),
    app: str = Query("admin"),
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    """Upload the release APK from the platform dashboard and publish it in one
    step. The file is stored at backend/In_App_Update_Apk_File/app-release.apk and
    served by /app-download/app-release.apk. The version is read from the APK
    (manual form fields are a fallback). Publish is rejected unless the new
    versionCode is higher than the currently-published one."""
    _ = admin
    channel = normalize_app_update_channel(app)
    tmp = await save_apk_upload(file, app=channel)
    try:
        validate_apk_file(tmp)
        detected_name, detected_code = extract_apk_version(tmp)
        final_name = detected_name or (versionName or "").strip()
        final_code = detected_code if detected_code is not None else versionCode
        if not final_name or not final_code or final_code < 1:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=(
                    "Could not read the APK version automatically. "
                    "Enter the version name and version code, then upload again."
                ),
            )
        current = await get_app_update(db, app=channel)
        current_code = int(current.get("versionCode") or 0) if current.get("enabled") else 0
        if final_code <= current_code:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    f"Uploaded APK version code {final_code} must be higher than the "
                    f"currently published version ({current_code})."
                ),
            )
        promote_apk(tmp, app=channel)
    except Exception:
        tmp.unlink(missing_ok=True)
        raise

    base = settings.BASE_URL.rstrip("/")
    apk_url = f"{base}/app-download/{apk_filename(channel)}?v={final_code}"
    payload = await set_app_update(
        db,
        PlatformAppUpdateRequest(
            versionName=final_name,
            versionCode=final_code,
            apkUrl=apk_url,
            releaseNotes=releaseNotes,
            required=required,
            enabled=True,
        ),
        app=channel,
    )
    await db.commit()

    event_type = app_update_event_type(channel, enabled=True)
    outlet_ids = (await db.execute(select(Outlet.id))).scalars().all()
    for outlet_id in outlet_ids:
        await manager.broadcast(
            outlet_id,
            {"type": event_type, "data": payload},
        )

    return ok(
        {
            **payload,
            "app": channel,
            "notifiedOutlets": len(outlet_ids),
            "autoDetectedVersion": detected_code is not None,
        }
    )


@router.delete("/app-update")
async def disable_app_update(
    app: str = Query("admin"),
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    channel = normalize_app_update_channel(app)
    payload = await clear_app_update(db, app=channel)
    await db.commit()

    event_type = app_update_event_type(channel, enabled=False)
    outlet_ids = (await db.execute(select(Outlet.id))).scalars().all()
    for outlet_id in outlet_ids:
        await manager.broadcast(
            outlet_id,
            {"type": event_type, "data": payload},
        )

    return ok({**payload, "app": channel, "notifiedOutlets": len(outlet_ids)})


@router.get("/blocking-notice")
async def current_blocking_notice(
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    return ok(await get_blocking_notice(db))


@router.post("/blocking-notice")
async def publish_blocking_notice(
    body: PlatformBlockingNoticeRequest,
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    payload = await set_blocking_notice(db, body)
    await db.commit()
    notified_outlets = await _broadcast_blocking_notice(db, payload, outlet_ids=body.outletIds)
    return ok({**payload, "notifiedOutlets": notified_outlets})


@router.delete("/blocking-notice")
async def disable_blocking_notice(
    admin: PlatformAdmin = Depends(_require_platform_admin),
    db: AsyncSession = Depends(get_db),
):
    _ = admin
    payload = await clear_blocking_notice(db)
    await db.commit()
    notified_outlets = await _broadcast_blocking_notice(db, payload)
    return ok({**payload, "notifiedOutlets": notified_outlets})


async def _broadcast_blocking_notice(
    db: AsyncSession,
    payload: dict,
    outlet_ids: list[str] | None = None,
) -> int:
    if outlet_ids is None:
        outlet_ids = (await db.execute(select(Outlet.id))).scalars().all()
    for outlet_id in outlet_ids:
        await manager.broadcast(
            outlet_id,
            {"type": "admin_blocking_notice_changed", "data": payload},
        )
    return len(outlet_ids)
