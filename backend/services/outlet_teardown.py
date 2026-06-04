"""Shared cascade teardown for an outlet's data and uploaded media.

Used by the manager self-service wipe (``routers/admin``) and the platform-admin
restaurant deletion (``routers/platform``). Deletes every row that references an
outlet — directly or through its orders / accounts / inventory / chatbot rows —
plus the outlet's media files, in foreign-key-safe order.

The caller owns the transaction: ``teardown_outlet`` issues the deletes but does
not commit, so several outlets can be torn down inside one transaction before the
restaurant row itself is removed.
"""
from collections.abc import Iterable

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

import storage
from models import (
    AdminAccount,
    BkashSession,
    ChatbotConversation,
    ChatbotIntegration,
    ChatbotOAuthSession,
    DailyStockCount,
    Device,
    InventoryItem,
    InventorySupplier,
    MenuItem,
    Order,
    Outlet,
    OutletSubscription,
    PosAuditEvent,
    PosSettlement,
    PosShift,
    StockAdjustment,
    UddoktaPaySession,
)


def media_urls_for_outlet(outlet: Outlet, menu_items: Iterable[MenuItem]) -> list[str]:
    """Collect every uploaded media URL owned by an outlet, de-duplicated.

    Shared menu placeholders are skipped — they are not per-outlet uploads.
    """
    urls: list[str] = []
    for value in (outlet.banner_url, outlet.logo_url, outlet.video_url):
        if value:
            urls.append(value)
    for value in outlet.gallery_images or []:
        if isinstance(value, str) and value:
            urls.append(value)
    for item in menu_items:
        if item.image_url and "/uploads/menu_placeholders/" not in item.image_url:
            urls.append(item.image_url)
        if item.video_url:
            urls.append(item.video_url)
    return list(dict.fromkeys(urls))


def delete_media_for_outlet(outlet_id: str, urls: list[str]) -> dict[str, int]:
    """Best-effort delete of an outlet's media URLs and hero-media prefixes."""
    deleted_urls = 0
    deleted_keys = 0
    for url in urls:
        storage.delete_by_url(url)
        deleted_urls += 1
    for prefix in (
        f"hero_media/{outlet_id}/images",
        f"hero_media/{outlet_id}/logo",
        f"hero_media/{outlet_id}/video",
    ):
        for key in storage.list_keys(prefix):
            storage.delete_key(key)
            deleted_keys += 1
    return {"mediaUrls": deleted_urls, "mediaKeys": deleted_keys}


async def teardown_outlet(db: AsyncSession, outlet: Outlet) -> dict[str, int]:
    """Delete the outlet, all rows tied to it, and its media. Does not commit.

    Returns a per-table count of deleted rows (plus ``mediaUrls`` / ``mediaKeys``).
    Deletion order respects foreign keys so it succeeds on Postgres where they are
    enforced: child ledgers (settlements, audit events) before orders and shifts,
    chatbot OAuth sessions before the accounts they reference, and inventory
    adjustments/counts before items and suppliers.
    """
    outlet_id = outlet.id
    server_id = outlet.server_id

    menu_items = (
        await db.execute(select(MenuItem).where(MenuItem.outlet_id == outlet_id))
    ).scalars().all()
    counts = delete_media_for_outlet(
        outlet_id, media_urls_for_outlet(outlet, list(menu_items))
    )

    async def delete_rows(model, *conditions) -> int:
        result = await db.execute(delete(model).where(*conditions))
        return max(result.rowcount or 0, 0)

    integration_ids = select(ChatbotIntegration.id).where(
        ChatbotIntegration.outlet_id == outlet_id
    )

    counts.update(
        {
            # POS ledgers reference orders + shifts, so they go first.
            "posSettlements": await delete_rows(
                PosSettlement, PosSettlement.outlet_id == outlet_id
            ),
            "posAuditEvents": await delete_rows(
                PosAuditEvent, PosAuditEvent.outlet_id == outlet_id
            ),
            "posShifts": await delete_rows(PosShift, PosShift.outlet_id == outlet_id),
            # Inventory: adjustments/counts reference items + suppliers.
            "stockAdjustments": await delete_rows(
                StockAdjustment, StockAdjustment.outlet_id == outlet_id
            ),
            "dailyStockCounts": await delete_rows(
                DailyStockCount, DailyStockCount.outlet_id == outlet_id
            ),
            "inventoryItems": await delete_rows(
                InventoryItem, InventoryItem.outlet_id == outlet_id
            ),
            "inventorySuppliers": await delete_rows(
                InventorySupplier, InventorySupplier.outlet_id == outlet_id
            ),
            "orders": await delete_rows(Order, Order.outlet_id == outlet_id),
            "menuItems": await delete_rows(MenuItem, MenuItem.outlet_id == outlet_id),
            "devices": await delete_rows(Device, Device.outlet_id == outlet_id),
            # Chatbot: conversations reference integrations; OAuth sessions
            # reference both the outlet and the admin accounts deleted below.
            "chatbotConversations": await delete_rows(
                ChatbotConversation,
                ChatbotConversation.integration_id.in_(integration_ids),
            ),
            "chatbotIntegrations": await delete_rows(
                ChatbotIntegration, ChatbotIntegration.outlet_id == outlet_id
            ),
            "chatbotOauthSessions": await delete_rows(
                ChatbotOAuthSession, ChatbotOAuthSession.outlet_id == outlet_id
            ),
            "subscriptions": await delete_rows(
                OutletSubscription, OutletSubscription.outlet_id == outlet_id
            ),
            "adminAccounts": await delete_rows(
                AdminAccount, AdminAccount.outlet_id == outlet_id
            ),
            # Payment sessions are keyed by server_id (uddokta also by outlet_id).
            "uddoktaPaySessions": await delete_rows(
                UddoktaPaySession,
                (UddoktaPaySession.outlet_id == outlet_id)
                | (UddoktaPaySession.server_id == server_id),
            ),
            "bkashSessions": await delete_rows(
                BkashSession, BkashSession.server_id == server_id
            ),
            "outlets": await delete_rows(Outlet, Outlet.id == outlet_id),
        }
    )
    return counts
