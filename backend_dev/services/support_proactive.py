"""Proactive assistant messages (low-stock alerts, end-of-day summary).

A background loop (started in main.py) periodically checks each active
outlet's triggers. Per-trigger cooldowns keep suggestions useful without
spam; the LLM itself stays DeepSeek and Sarvam is used only for TTS.
"""

import asyncio
import logging
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import func, or_, select

from config import settings
from database import AsyncSessionLocal
from models import InventoryItem, Order, Outlet
from services.support_llm import proactive_message as support_llm_proactive_message

logger = logging.getLogger(__name__)

BDT_OFFSET = timedelta(hours=6)
BDT_TZ = timezone(BDT_OFFSET)

LOW_STOCK_NAMES_LIMIT = 8

# outlet_id -> monotonic time of the last low-stock alert
_last_low_stock_at: dict[str, float] = {}
# outlet_id -> BDT date string of the last end-of-day summary
_last_eod_date: dict[str, str] = {}


def _now_bdt() -> datetime:
    return datetime.now(BDT_TZ)


async def proactive_loop() -> None:
    """Background scheduler: runs scan_proactive_triggers on a cadence."""
    while True:
        try:
            await asyncio.sleep(settings.SUPPORT_PROACTIVE_SCAN_SECONDS)
            await scan_proactive_triggers()
        except asyncio.CancelledError:
            break
        except Exception as exc:
            logger.error(
                "[support_proactive] scan error: %s", exc, exc_info=True
            )


async def scan_proactive_triggers() -> None:
    if not settings.SUPPORT_PROACTIVE_ENABLED:
        return
    try:
        async with AsyncSessionLocal() as session:
            outlets = (
                (await session.execute(
                    select(Outlet.id).where(Outlet.status == "active")
                )).scalars().all()
            )
        for outlet_id in outlets:
            try:
                await _maybe_low_stock(outlet_id)
                await _maybe_eod_summary(outlet_id)
            except Exception as exc:
                logger.error(
                    "[support_proactive] outlet %s trigger check failed: %s",
                    outlet_id,
                    exc,
                    exc_info=True,
                )
    except Exception as exc:
        logger.error("[support_proactive] scan failed: %s", exc, exc_info=True)


async def _maybe_low_stock(outlet_id: str) -> None:
    """Fire a low-stock alert when reorder-worthy items exist and the
    per-outlet cooldown has elapsed."""
    import time

    now = time.monotonic()
    cooldown_seconds = settings.SUPPORT_PROACTIVE_LOW_STOCK_COOLDOWN_HOURS * 3600
    if now - _last_low_stock_at.get(outlet_id, 0.0) < cooldown_seconds:
        return
    async with AsyncSessionLocal() as session:
        items = (
            await session.execute(
                select(InventoryItem)
                .where(
                    InventoryItem.outlet_id == outlet_id,
                    InventoryItem.deleted_at.is_(None),
                    or_(
                        InventoryItem.quantity <= InventoryItem.min_threshold,
                        InventoryItem.quantity <= 0,
                    ),
                )
                .order_by(InventoryItem.quantity.asc())
                .limit(LOW_STOCK_NAMES_LIMIT + 1)
            )
        ).scalars().all()
    if not items:
        return
    names = [
        f"{item.name} ({float(item.quantity):g}/{float(item.min_threshold):g} {item.unit})"
        for item in items[:LOW_STOCK_NAMES_LIMIT]
    ]
    truncated = len(items) > LOW_STOCK_NAMES_LIMIT
    context = "Low-stock inventory items: " + ", ".join(names)
    if truncated:
        context += " (and more)"
    await support_llm_proactive_message(outlet_id, "low_stock", context)
    _last_low_stock_at[outlet_id] = time.monotonic()


async def _maybe_eod_summary(outlet_id: str) -> None:
    """Fire the end-of-day summary once per BDT day after the configured hour,
    but only when the outlet actually had orders today."""
    now = _now_bdt()
    today = now.date()
    if now.hour < settings.SUPPORT_PROACTIVE_EOD_HOUR:
        return
    if _last_eod_date.get(outlet_id) == today.isoformat():
        return
    async with AsyncSessionLocal() as session:
        order_count = (
            await session.execute(
                select(func.count(Order.id)).where(
                    Order.outlet_id == outlet_id,
                    Order.order_date == today,
                )
            )
        ).scalar_one_or_none() or 0
    if not order_count:
        return
    context = f"The outlet closed {order_count} orders today. Give a short end-of-day summary."
    await support_llm_proactive_message(outlet_id, "eod_summary", context)
    _last_eod_date[outlet_id] = today.isoformat()