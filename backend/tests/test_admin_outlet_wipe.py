import uuid
from datetime import datetime, timezone
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import func, select

from auth import create_device_token
from database import AsyncSessionLocal, create_tables
from main import app
from models import (
    AdminAccount,
    DailyStockCount,
    InventoryItem,
    MenuItem,
    Order,
    Outlet,
    Restaurant,
    StockAdjustment,
)
from phone_utils import phone_to_synthetic_email
from routers import admin


@pytest.mark.asyncio(loop_scope="session")
async def test_manager_can_wipe_current_outlet_database_and_media(monkeypatch):
    await create_tables()
    deleted_urls: list[str] = []
    deleted_keys: list[str] = []

    monkeypatch.setattr(admin.storage, "delete_by_url", deleted_urls.append)
    monkeypatch.setattr(
        admin.storage,
        "list_keys",
        lambda prefix: [f"{prefix}/asset.jpg"],
    )
    monkeypatch.setattr(admin.storage, "delete_key", deleted_keys.append)

    suffix = uuid.uuid4()
    server_id = f"wipe-{suffix}"

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        bootstrap = await client.post(
            "/tenants/bootstrap",
            json={"serverId": server_id, "restaurantName": "Wipe Test"},
        )
        boot = bootstrap.json()["data"]
        outlet_id = boot["outletId"]
        restaurant_id = boot["restaurantId"]
        async with AsyncSessionLocal() as db:
            outlet = (await db.execute(select(Outlet).where(Outlet.id == outlet_id))).scalar_one()
            phone = f"+88017{uuid.uuid4().int % 100000000:08d}"
            email = phone_to_synthetic_email(phone)
            account = AdminAccount(
                id=str(uuid4()),
                outlet_id=outlet.id,
                email=email,
                username=email,
                password_hash=None,
                role="owner",
                display_name="Test Manager",
                auth_provider="phone",
                phone=phone,
                phone_verified_at=datetime.now(timezone.utc),
                invite_status="accepted",
                is_active=True,
            )
            db.add(account)
            await db.commit()
            await db.refresh(account)
            token = create_device_token(outlet.id, account.id)

        menu_image_url = "http://test/uploads/menu_images/wipe-menu.jpg"
        gallery_url = (
            f"http://test/uploads/hero_media/{outlet_id}/images/gallery.jpg"
        )
        video_url = (
            f"http://test/uploads/hero_media/{outlet_id}/video/intro.mp4"
        )
        inventory_id = f"inv-{suffix}"
        async with AsyncSessionLocal() as db:
            outlet = (
                await db.execute(select(Outlet).where(Outlet.id == outlet_id))
            ).scalar_one()
            outlet.gallery_images = [gallery_url]
            outlet.video_url = video_url
            db.add_all(
                [
                    MenuItem(
                        id=f"menu-{suffix}",
                        outlet_id=outlet_id,
                        name="Tea",
                        price=25,
                        image_url=menu_image_url,
                    ),
                    Order(
                        id=f"order-{suffix}",
                        outlet_id=outlet_id,
                        serial_number=7,
                        total_amount=25,
                        items=[{"name": "Tea", "qty": 1}],
                    ),
                    InventoryItem(
                        id=inventory_id,
                        outlet_id=outlet_id,
                        name="Milk",
                    ),
                    StockAdjustment(
                        outlet_id=outlet_id,
                        inventory_item_id=inventory_id,
                        delta=2,
                        type="stock_in",
                    ),
                    DailyStockCount(
                        outlet_id=outlet_id,
                        inventory_item_id=inventory_id,
                        count_date="2026-05-24",
                        quantity=2,
                    ),
                ]
            )
            await db.commit()

        rejected = await client.post(
            f"/admin/outlets/{outlet_id}/wipe",
            headers={"Authorization": f"Bearer {token}"},
            json={"confirmation": "wrong"},
        )
        wiped = await client.post(
            f"/admin/outlets/{outlet_id}/wipe",
            headers={"Authorization": f"Bearer {token}"},
            json={"confirmation": outlet_id},
        )

    assert bootstrap.status_code == 200
    assert rejected.status_code == 400
    assert wiped.status_code == 200
    payload = wiped.json()["data"]
    assert payload["outletId"] == outlet_id
    assert payload["restaurantId"] == restaurant_id
    assert payload["restaurantDeleted"] is True
    assert payload["deleted"]["menuItems"] == 1
    assert payload["deleted"]["orders"] == 1
    assert payload["deleted"]["inventoryItems"] == 1
    assert menu_image_url in deleted_urls
    assert gallery_url in deleted_urls
    assert video_url in deleted_urls
    assert deleted_keys == [
        f"hero_media/{outlet_id}/images/asset.jpg",
        f"hero_media/{outlet_id}/logo/asset.jpg",
        f"hero_media/{outlet_id}/video/asset.jpg",
    ]

    async with AsyncSessionLocal() as db:
        checks = [
            select(func.count()).select_from(Outlet).where(Outlet.id == outlet_id),
            select(func.count())
            .select_from(Restaurant)
            .where(Restaurant.id == restaurant_id),
            select(func.count())
            .select_from(AdminAccount)
            .where(AdminAccount.email == email),
            select(func.count())
            .select_from(MenuItem)
            .where(MenuItem.outlet_id == outlet_id),
            select(func.count()).select_from(Order).where(Order.outlet_id == outlet_id),
            select(func.count())
            .select_from(InventoryItem)
            .where(InventoryItem.outlet_id == outlet_id),
            select(func.count())
            .select_from(StockAdjustment)
            .where(StockAdjustment.outlet_id == outlet_id),
            select(func.count())
            .select_from(DailyStockCount)
            .where(DailyStockCount.outlet_id == outlet_id),
        ]
        for statement in checks:
            remaining = (await db.execute(statement)).scalar()
            assert remaining == 0
