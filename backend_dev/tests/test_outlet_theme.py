import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from database import create_tables
from main import app


async def _bootstrap_outlet(client: AsyncClient, label: str):
    server_id = f"{label}-{uuid.uuid4()}"
    bootstrap = await client.post(
        "/tenants/bootstrap",
        json={"serverId": server_id, "restaurantName": label, "tableCount": 4},
    )
    assert bootstrap.status_code == 200
    data = bootstrap.json()["data"]
    return data["outletId"], {"Authorization": f"Bearer {data['deviceToken']}"}


@pytest.mark.asyncio(loop_scope="session")
async def test_customer_info_returns_default_menu_theme():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id, _ = await _bootstrap_outlet(client, "theme-default")
        info = await client.get(f"/customer/{outlet_id}/info")

    assert info.status_code == 200
    assert info.json()["data"]["menuTheme"] == "sultans_hearth"


@pytest.mark.asyncio(loop_scope="session")
async def test_patch_media_updates_menu_theme():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id, headers = await _bootstrap_outlet(client, "theme-update")

        patch = await client.patch(
            f"/outlets/{outlet_id}/media",
            headers=headers,
            json={"menuTheme": "brick"},
        )
        info = await client.get(f"/customer/{outlet_id}/info")

    assert patch.status_code == 200
    assert patch.json()["data"]["menuTheme"] == "brick"
    assert info.json()["data"]["menuTheme"] == "brick"


@pytest.mark.asyncio(loop_scope="session")
async def test_patch_media_rejects_unknown_theme():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id, headers = await _bootstrap_outlet(client, "theme-reject")
        patch = await client.patch(
            f"/outlets/{outlet_id}/media",
            headers=headers,
            json={"menuTheme": "not_a_real_theme"},
        )

    assert patch.status_code == 400


@pytest.mark.asyncio(loop_scope="session")
async def test_patch_media_theme_only_preserves_video_url():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id, headers = await _bootstrap_outlet(client, "theme-preserve")

        seed = await client.patch(
            f"/outlets/{outlet_id}/media",
            headers=headers,
            json={"videoUrl": "https://example.com/clip.mp4"},
        )
        assert seed.status_code == 200
        assert seed.json()["data"]["videoUrl"] == "https://example.com/clip.mp4"

        theme_only = await client.patch(
            f"/outlets/{outlet_id}/media",
            headers=headers,
            json={"menuTheme": "lantern"},
        )

    assert theme_only.status_code == 200
    assert theme_only.json()["data"]["menuTheme"] == "lantern"
    assert theme_only.json()["data"]["videoUrl"] == "https://example.com/clip.mp4"


@pytest.mark.asyncio(loop_scope="session")
async def test_patch_media_updates_public_logo_url():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id, headers = await _bootstrap_outlet(client, "logo-media")

        patch = await client.patch(
            f"/outlets/{outlet_id}/media",
            headers=headers,
            json={"logoUrl": "https://example.com/logo.png"},
        )
        info = await client.get(f"/customer/{outlet_id}/info")
        clear = await client.patch(
            f"/outlets/{outlet_id}/media",
            headers=headers,
            json={"logoUrl": None},
        )
        cleared_info = await client.get(f"/customer/{outlet_id}/info")

    assert patch.status_code == 200
    assert patch.json()["data"]["logoUrl"] == "https://example.com/logo.png"
    assert info.json()["data"]["logoUrl"] == "https://example.com/logo.png"
    assert clear.status_code == 200
    assert clear.json()["data"]["logoUrl"] is None
    assert cleared_info.json()["data"]["logoUrl"] is None


@pytest.mark.asyncio(loop_scope="session")
async def test_patch_media_updates_public_delivery_charge():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id, headers = await _bootstrap_outlet(client, "delivery-charge")

        patch = await client.patch(
            f"/outlets/{outlet_id}/media",
            headers=headers,
            json={"deliveryCharge": 60},
        )
        info = await client.get(f"/customer/{outlet_id}/info")
        invalid = await client.patch(
            f"/outlets/{outlet_id}/media",
            headers=headers,
            json={"deliveryCharge": -1},
        )

    assert patch.status_code == 200
    assert patch.json()["data"]["deliveryCharge"] == 60
    assert info.json()["data"]["deliveryCharge"] == 60
    assert invalid.status_code == 422
