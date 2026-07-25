"""Outlet subscription lifecycle — tracking only (no API blocking).

5 statuses: trial → on_hold → active (→ on_hold) | paused | cancelled
3 packages: standard (500/mo), pro (700/mo), premium (1000/mo)
Addon features: inventory (199/mo), website_qr (199/mo), messenger_bot (199/mo)
"""

import json
from datetime import datetime, timedelta, timezone

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Outlet, OutletSubscription, SystemConfig, UddoktaPaySession
from services.blocking_notice import disabled_blocking_notice

TRIAL_DAYS = 10
VALID_PACKAGES = frozenset({"standard", "pro", "premium"})

BASE_FEATURES = frozenset({
    "billing_foh", "menu_management", "analytics", "sales_summary", "live",
})
ADDON_FEATURES = frozenset({"inventory", "website_qr", "messenger_bot"})
ADDON_PRICES: dict[str, int] = {
    "inventory": 199,
    "website_qr": 199,
    "messenger_bot": 199,
}

DEFAULT_SUBSCRIPTION_PRICES: dict[str, int] = {
    "standard": 500,
    "pro": 700,
    "premium": 1000,
}
DEFAULT_ADDON_PRICES: dict[str, int] = dict(ADDON_PRICES)


async def load_prices(db: AsyncSession) -> dict[str, dict[str, int]]:
    """Load subscription & addon prices from SystemConfig, falling back to defaults."""
    sub_raw = (
        await db.execute(
            select(SystemConfig).where(SystemConfig.key == "subscription_prices")
        )
    ).scalar_one_or_none()
    addon_raw = (
        await db.execute(
            select(SystemConfig).where(SystemConfig.key == "addon_prices")
        )
    ).scalar_one_or_none()

    subscription_prices = DEFAULT_SUBSCRIPTION_PRICES
    if sub_raw and sub_raw.value:
        try:
            subscription_prices = json.loads(sub_raw.value)
        except (json.JSONDecodeError, TypeError):
            pass

    addon_prices = DEFAULT_ADDON_PRICES
    if addon_raw and addon_raw.value:
        try:
            addon_prices = json.loads(addon_raw.value)
        except (json.JSONDecodeError, TypeError):
            pass

    return {
        "subscriptionPrices": subscription_prices,
        "addonPrices": addon_prices,
    }


def _now() -> datetime:
    return datetime.now(timezone.utc)


async def resolve_outlet_by_server_id(db: AsyncSession, server_id: str) -> Outlet | None:
    return (
        await db.execute(select(Outlet).where(Outlet.server_id == server_id))
    ).scalar_one_or_none()


def outlet_needs_activation(sub: OutletSubscription | None) -> bool:
    if sub is None:
        return False
    return sub.status == "on_hold"


def outlet_has_app_access(sub: OutletSubscription | None) -> bool:
    if sub is None:
        return False
    if sub.status not in ("trial", "active"):
        return False
    if sub.expires_at is not None and sub.expires_at <= _now():
        return False
    return True


def outlet_has_feature(sub: OutletSubscription | None, feature: str) -> bool:
    """Per-feature access check — trial gets everything, active checks addons."""
    if not outlet_has_app_access(sub):
        return False
    if sub.status == "trial":
        return True
    if feature in BASE_FEATURES:
        return True
    user_addons = json.loads(sub.addons or "[]")
    return feature in user_addons


def _parse_addons(sub: OutletSubscription | None) -> list[str]:
    if sub is None:
        return []
    return json.loads(sub.addons or "[]")


async def maybe_expire_subscription(
    db: AsyncSession, sub: OutletSubscription | None
) -> OutletSubscription | None:
    """Flip expired trial/active subscriptions to on_hold."""
    if sub is None:
        return None
    now = _now()
    expired = sub.expires_at is not None and sub.expires_at <= now
    if not expired:
        return sub
    if sub.status in ("trial", "active"):
        sub.status = "on_hold"
        sub.updated_at = now
        await db.flush()
    return sub


def subscription_access_dict(
    sub: OutletSubscription | None,
    *,
    subscription_prices: dict[str, int] | None = None,
    addon_prices: dict[str, int] | None = None,
) -> dict:
    return {
        "hasAppAccess": outlet_has_app_access(sub),
        "subscriptionStatus": sub.status if sub else None,
        "subscriptionPlan": sub.plan if sub else None,
        "subscriptionPackage": sub.package if sub else None,
        "subscriptionExpiresAt": (
            sub.expires_at.isoformat() if sub and sub.expires_at else None
        ),
        "addons": _parse_addons(sub),
        "subscriptionPrices": subscription_prices or DEFAULT_SUBSCRIPTION_PRICES,
        "addonPrices": addon_prices or DEFAULT_ADDON_PRICES,
    }


async def grant_outlet_access(
    db: AsyncSession,
    outlet_id: str,
    *,
    package: str = "standard",
    grant_days: int | None = None,
) -> OutletSubscription:
    """Platform admin: activate an outlet for the given period."""
    days = grant_days if grant_days is not None else 30
    now = _now()
    sub = await get_or_create_subscription(db, outlet_id)
    sub.package = package if package in VALID_PACKAGES else "standard"
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
    sub = (
        await db.execute(
            select(OutletSubscription).where(OutletSubscription.outlet_id == outlet_id)
        )
    ).scalar_one_or_none()
    sub = await maybe_expire_subscription(db, sub)
    prices = await load_prices(db)
    return subscription_access_dict(
        sub,
        subscription_prices=prices["subscriptionPrices"],
        addon_prices=prices["addonPrices"],
    )


def subscription_to_dict(
    sub: OutletSubscription, *, outlet_name: str | None = None
) -> dict:
    return {
        "id": sub.id,
        "outletId": sub.outlet_id,
        "outletName": outlet_name,
        "plan": sub.plan,
        "package": sub.package,
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
        status="trial",
        starts_at=now,
        expires_at=now + timedelta(days=TRIAL_DAYS),
    )
    db.add(sub)
    await db.flush()
    return sub


BLOCKING_STATUSES = frozenset({"on_hold", "paused", "cancelled"})


async def blocking_notice_for_subscription(
    db: AsyncSession, sub: OutletSubscription | None
) -> dict:
    if sub is None or sub.status not in BLOCKING_STATUSES:
        return disabled_blocking_notice()

    prices = await load_prices(db)
    sub_prices = prices["subscriptionPrices"]

    status_label = sub.status.replace("_", " ").title()
    pkg = (sub.package or "standard").lower()
    price = sub_prices.get(pkg, 500)

    return {
        "enabled": True,
        "title": f"Subscription {status_label}",
        "message": (
            f"Your {pkg.title()} plan is {status_label.lower()}. "
            f"Pay ৳{price} to bKash 01575873000 to reactivate."
        ),
        "imageUrl": None,
        "inputField": True,
        "inputLabel": "Your bKash number (if different from account phone)",
        "updatedAt": datetime.now(timezone.utc).isoformat(),
        "type": "subscription",
        "ctaLabel": None,
        "ctaUrl": None,
        "dismissible": False,
    }


async def register_onboarding_plan(
    db: AsyncSession,
    outlet_id: str,
    *,
    plan: str = "monthly",
    package: str | None = None,
) -> OutletSubscription:
    """Manager chose a plan in the app — queue for platform admin activation.

    Accepts the legacy `plan` field (from admin_app) for backward compat.
    If `package` is provided it takes precedence; otherwise `plan` is mapped.
    """
    if package:
        clean = package.strip().lower()
        if clean not in VALID_PACKAGES:
            clean = "standard"
    else:
        # Legacy mapping: monthly/annual → standard
        clean = "standard"
    now = _now()
    sub = await get_or_create_subscription(db, outlet_id)
    sub.package = clean
    sub.status = "on_hold"
    sub.updated_at = now
    await db.flush()
    return sub


async def activate_subscription_from_payment(
    db: AsyncSession,
    session: UddoktaPaySession,
) -> OutletSubscription | None:
    """Legacy payment activation — kept for backward compat but no longer the primary path."""
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

    now = _now()
    sub = await get_or_create_subscription(db, outlet.id)
    sub.package = "standard"
    sub.status = "active"
    sub.starts_at = now
    sub.expires_at = now + timedelta(days=30)
    sub.last_payment_session_id = session.id
    sub.updated_at = now
    await db.flush()
    return sub
