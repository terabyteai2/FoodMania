import base64
import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from database import create_tables
from main import app
from routers import menu


@pytest.mark.asyncio(loop_scope="session")
async def test_menu_image_upload_accepts_jpeg_data_url(monkeypatch):
    await create_tables()
    saved: dict[str, object] = {}

    def fake_save(path, data, request):
        saved["path"] = path
        saved["data"] = data
        return f"{request.base_url}uploads/{path}"

    monkeypatch.setattr(menu.storage, "save", fake_save)
    server_id = f"menu-image-{uuid.uuid4()}"
    image_bytes = b"jpeg-menu-photo"
    data_url = f"data:image/jpeg;base64,{base64.b64encode(image_bytes).decode()}"

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        bootstrap = await client.post(
            "/tenants/bootstrap",
            json={"serverId": server_id, "restaurantName": "Image Test"},
        )
        data = bootstrap.json()["data"]
        response = await client.post(
            f"/outlets/{data['outletId']}/menu/images",
            headers={"Authorization": f"Bearer {data['deviceToken']}"},
            json={"dataUrl": data_url, "fileName": "photo.jpg"},
        )

    assert bootstrap.status_code == 200
    assert response.status_code == 200
    payload = response.json()["data"]
    assert payload["publicUrl"].endswith(f"uploads/{saved['path']}")
    assert saved["path"].startswith("menu_images/")
    assert saved["path"].endswith(".jpg")
    assert saved["data"] == image_bytes
