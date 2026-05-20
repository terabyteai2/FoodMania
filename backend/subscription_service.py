"""Outlet subscription lifecycle — tracking only (no API blocking)."""

from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Outlet, OutletSubscription, UddoktaPaySession

PLAN_DAYS = {"monthly": 30, "annual": 365}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def subscription_period_days(plan: str | None) -> int:
    return PLAN_DAYS.get((plan or "monthly").lower(), 30)


async def resolve_outlet_by_server_id(db: AsyncSession, server_id: str) -> Outlet | None:
    return (
        await db.execute(select(Outlet).where(Outlet.server_id == server_id))
    ).scalar_one_or_none()


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
        plan="monthly",
        status="trial",
        starts_at=now,
        expires_at=None,
    )
    db.add(sub)
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
