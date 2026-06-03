"""Outlet subscription lifecycle — tracking only (no API blocking)."""

from datetime import datetime, timedelta, timezone

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Outlet, OutletSubscription, UddoktaPaySession

TRIAL_DAYS = 7
PLAN_DAYS = {"trial": TRIAL_DAYS, "monthly": 30, "annual": 365}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def subscription_period_days(plan: str | None) -> int:
    return PLAN_DAYS.get((plan or "monthly").lower(), 30)


async def resolve_outlet_by_server_id(db: AsyncSession, server_id: str) -> Outlet | None:
    return (
        await db.execute(select(Outlet).where(Outlet.server_id == server_id))
    ).scalar_one_or_none()


def outlet_needs_activation(sub: OutletSubscription | None) -> bool:
    """True when the mobile admin app should stay locked until platform approval."""
    return not outlet_has_app_access(sub)


def outlet_has_app_access(sub: OutletSubscription | None) -> bool:
    """True when the outlet subscription allows using the admin app."""
    if sub is None:
        return False
    if sub.status != "active":
        return False
    if sub.expires_at is not None and sub.expires_at <= _now():
        return False
    return True


async def maybe_expire_subscription(db: AsyncSession, sub: OutletSubscription | None) -> OutletSubscription | None:
    """If an active subscription has passed its expiry date, flip it back to pending.
    The restaurant's admin must manually re-activate it. Returns the (possibly updated) sub."""
    if sub is None:
        return None
    if sub.status == "active" and sub.expires_at is not None and sub.expires_at <= _now():
        sub.status = "pending"
        sub.updated_at = _now()
        await db.flush()
    return sub


def subscription_access_dict(sub: OutletSubscription | None) -> dict:
    return {
        "hasAppAccess": outlet_has_app_access(sub),
        "subscriptionStatus": sub.status if sub else None,
        "subscriptionPlan": sub.plan if sub else None,
        "subscriptionExpiresAt": sub.expires_at.isoformat() if sub and sub.expires_at else None,
    }


async def grant_outlet_access(
    db: AsyncSession,
    outlet_id: str,
    *,
    plan: str = "monthly",
    extend_days: int | None = None,
) -> OutletSubscription:
    """Platform admin: mark outlet subscription active so the mobile app can unlock."""
    days = extend_days if extend_days is not None else subscription_period_days(plan)
    now = _now()
    sub = await get_or_create_subscription(db, outlet_id)
    sub.plan = plan if plan in PLAN_DAYS else sub.plan
    sub.status = "active"
    sub.starts_at = now
    sub.expires_at = now + timedelta(days=days)
    sub.updated_at = now
    await db.flush()
    return sub


async def resolve_subscription_access_for_outlet(
    db: AsyncSession,
    outlet_id: str,
) -> dict:
    """
    Access for the admin app: active subscription, or auto-activate from a paid payment
    linked to this outlet (by outlet_id or server_id).
    Expired active subscriptions are automatically moved back to pending so the platform
    admin must manually re-activate the restaurant.
    """
    sub = (
        await db.execute(
            select(OutletSubscription).where(OutletSubscription.outlet_id == outlet_id)
        )
    ).scalar_one_or_none()
    # Flip expired active subs to pending before checking access
    sub = await maybe_expire_subscription(db, sub)
    if outlet_has_app_access(sub):
        return subscription_access_dict(sub)

    outlet = (
        await db.execute(select(Outlet).where(Outlet.id == outlet_id))
    ).scalar_one_or_none()
    if outlet is None:
        return subscription_access_dict(sub)

    paid_session = (
        await db.execute(
            select(UddoktaPaySession)
            .where(
                UddoktaPaySession.status.in_(["paid", "verified"]),
                or_(
                    UddoktaPaySession.outlet_id == outlet_id,
                    UddoktaPaySession.server_id == outlet.server_id,
                ),
            )
            .order_by(UddoktaPaySession.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    if paid_session is not None:
        activated = await activate_subscription_from_payment(db, paid_session)
        if activated is not None:
            await db.commit()
            await db.refresh(activated)
            return subscription_access_dict(activated)

    return subscription_access_dict(sub)


def subscription_to_dict(sub: OutletSubscription, *, outlet_name: str | None = None) -> dict:
    return {
        "id": sub.id,
        "outletId": sub.outlet_id,
        "outletName": outlet_name,
        "plan": sub.plan,
        "status": sub.status,
        "startsAt": sub.starts_at.isoformat(),
        "expiresAt": sub.expires_at.isoformat() if sub.expires_at else None,
        "lastPaymentSessionId": sub.last_payment_session_id,
        "updatedAt": sub.updated_at.isoformat(),
    }


async def get_or_create_subscription(db: AsyncSession, outlet_id: str) -> OutletSubscription:
    sub = (
        await db.execute(
            select(OutletSubscription).where(OutletSubscription.outlet_id == outlet_id)
        )
    ).scalar_one_or_none()
    if sub is not None:
        return sub
    now = _now()
    sub = OutletSubscription(
        outlet_id=outlet_id,
        plan="trial",
        status="active",
        starts_at=now,
        expires_at=now + timedelta(days=TRIAL_DAYS),
    )
    db.add(sub)
    await db.flush()
    return sub


async def register_onboarding_plan(
    db: AsyncSession,
    outlet_id: str,
    *,
    plan: str,
) -> OutletSubscription:
    """Manager chose a plan in the app — queue for platform admin activation."""
    clean_plan = (plan or "monthly").strip().lower()
    if clean_plan not in PLAN_DAYS:
        clean_plan = "monthly"
    now = _now()
    sub = await get_or_create_subscription(db, outlet_id)
    sub.plan = clean_plan
    sub.status = "pending"
    sub.updated_at = now
    await db.flush()
    return sub


async def activate_subscription_from_payment(
    db: AsyncSession,
    session: UddoktaPaySession,
) -> OutletSubscription | None:
    """Upsert active subscription when a payment completes."""
    outlet: Outlet | None = None
    if session.outlet_id:
        outlet = (
            await db.execute(select(Outlet).where(Outlet.id == session.outlet_id))
        ).scalar_one_or_none()
    if outlet is None:
        outlet = await resolve_outlet_by_server_id(db, session.server_id)
    if outlet is None:
        return None

    if not session.outlet_id:
        session.outlet_id = outlet.id

    plan = (session.plan or "monthly").lower()
    days = subscription_period_days(plan)
    now = _now()
    expires = now + timedelta(days=days)

    sub = await get_or_create_subscription(db, outlet.id)
    sub.plan = plan
    sub.status = "active"
    sub.starts_at = now
    sub.expires_at = expires
    sub.last_payment_session_id = session.id
    sub.updated_at = now
    await db.flush()
    return sub
