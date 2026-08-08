"""Source-aware order serial number helpers.

Order serial numbers are sequential per outlet per day, but split into
independent counter groups so online channels and waiter-taken orders get
their own numbering with a distinguishing letter prefix:

- "W"  website orders          (source: customer_web / cloud / online / ...)
- "M"  Facebook Messenger      (source: facebook_messenger / facebook / ...)
- "WA" WhatsApp                (source: whatsapp / wa)
- "S"  waiter-taken orders     (created_by_role: waiter / staff, local POS)
- ""   manager/owner POS       (everything else, no prefix)

The DB column `serial_number` stays an Integer; the prefix is a display
concern derived deterministically from source + role.
"""

from sqlalchemy import and_, or_

from models import Order


# Source values that map to each prefixed counter group.
WEB_SOURCES = frozenset(
    {
        "customer_web",
        "cloud",
        "cloud_customer",
        "customer_cloud",
        "online",
        "web_cloud",
    }
)

MESSENGER_SOURCES = frozenset(
    {
        "facebook_messenger",
        "facebook",
        "messenger",
        "fb_messenger",
    }
)

WHATSAPP_SOURCES = frozenset(
    {
        "whatsapp",
        "wa",
        "whatsapp_business",
    }
)

WAITER_ROLES = frozenset({"waiter", "staff"})


def serial_prefix(source: str | None, created_by_role: str | None = None) -> str:
    """Return the display prefix for an order ("" for the default POS group)."""
    src = (source or "").strip().lower()
    if src in WEB_SOURCES:
        return "W"
    if src in MESSENGER_SOURCES:
        return "M"
    if src in WHATSAPP_SOURCES:
        return "WA"
    role = (created_by_role or "").strip().lower()
    if role in WAITER_ROLES:
        return "S"
    return ""


def serial_group_filter(source: str | None, created_by_role: str | None = None):
    """Return a SQLAlchemy expression matching orders in the same serial group.

    Used in the `MAX(serial_number) + 1` query so each group keeps its own
    independent per-outlet, per-day counter.
    """
    src = (source or "").strip().lower()
    role = (created_by_role or "").strip().lower()
    online_sources = list(WEB_SOURCES | MESSENGER_SOURCES | WHATSAPP_SOURCES)
    if src in WEB_SOURCES:
        return Order.source.in_(list(WEB_SOURCES))
    if src in MESSENGER_SOURCES:
        return Order.source.in_(list(MESSENGER_SOURCES))
    if src in WHATSAPP_SOURCES:
        return Order.source.in_(list(WHATSAPP_SOURCES))
    if role in WAITER_ROLES:
        return and_(
            Order.source.notin_(online_sources),
            Order.created_by_role.in_(list(WAITER_ROLES)),
        )
    return and_(
        Order.source.notin_(online_sources),
        or_(
            Order.created_by_role.is_(None),
            Order.created_by_role.notin_(list(WAITER_ROLES)),
        ),
    )


def format_serial(
    serial_number: int | None,
    source: str | None,
    created_by_role: str | None = None,
) -> str:
    """Render an order serial as ``#N``, ``#W1``, ``#M1``, ``#WA1``, ``#S1`` or ``#-``."""
    if not serial_number:
        return "#-"
    return f"#{serial_prefix(source, created_by_role)}{serial_number}"
