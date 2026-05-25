import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from database import create_tables
from main import app


@pytest.mark.asyncio(loop_scope="session")
async def test_public_customer_menu_returns_icon_key_from_tags():
    await create_tables()
    server_id = f"customer-menu-icons-{uuid.uuid4()}"
    menu_item_id = f"menu-{uuid.uuid4()}"
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        bootstrap = await client.post(
            "/tenants/bootstrap",
            json={
                "serverId": server_id,
                "restaurantName": "Icon Test",
                "tableCount": 8,
            },
        )
        data = bootstrap.json()["data"]
        outlet_id = data["outletId"]
        headers = {"Authorization": f"Bearer {data['deviceToken']}"}

        created = await client.post(
            f"/outlets/{outlet_id}/menu",
            headers=headers,
            json={
                "id": menu_item_id,
                "name": "Margherita Pizza",
                "price": 1299,
                "category": "Pizza",
                "tags": ["icon:pizza"],
            },
        )
        public_menu = await client.get(f"/customer/{outlet_id}/menu")

    assert bootstrap.status_code == 200
    assert created.status_code == 200
    assert public_menu.status_code == 200
    item = next(i for i in public_menu.json()["data"] if i["id"] == menu_item_id)
    assert item["iconKey"] == "pizza"
    assert item["imageUrl"] == "http://test/uploads/menu_placeholders/beverages.png"


@pytest.mark.asyncio(loop_scope="session")
async def test_public_customer_menu_infers_placeholder_image_without_photo_or_icon_tag():
    await create_tables()
    server_id = f"customer-menu-placeholder-{uuid.uuid4()}"
    menu_item_id = f"menu-{uuid.uuid4()}"
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        bootstrap = await client.post(
            "/tenants/bootstrap",
            json={
                "serverId": server_id,
                "restaurantName": "Placeholder Test",
                "tableCount": 8,
            },
        )
        data = bootstrap.json()["data"]
        outlet_id = data["outletId"]
        headers = {"Authorization": f"Bearer {data['deviceToken']}"}

        created = await client.post(
            f"/outlets/{outlet_id}/menu",
            headers=headers,
            json={
                "id": menu_item_id,
                "name": "Chicken Biryani",
                "price": 320,
                "category": "Biryani",
            },
        )
        public_menu = await client.get(f"/customer/{outlet_id}/menu")

    assert bootstrap.status_code == 200
    assert created.status_code == 200
    assert public_menu.status_code == 200
    item = next(i for i in public_menu.json()["data"] if i["id"] == menu_item_id)
    assert item["iconKey"] == "biryani"
    assert item["imageUrl"] == "http://test/uploads/menu_placeholders/biryani-1.png"
