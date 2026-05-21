import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from database import create_tables
from main import app


@pytest.mark.asyncio(loop_scope="session")
async def test_table_count_round_trips_through_bootstrap_and_device_register():
    await create_tables()
    server_id = f"table-count-{uuid.uuid4()}"
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        bootstrap = await client.post(
            "/tenants/bootstrap",
            json={
                "serverId": server_id,
                "restaurantName": "Table Test",
                "outletName": "Main Outlet",
                "tableCount": 24,
            },
        )
        data = bootstrap.json()["data"]
        registered = await client.post(
            "/devices/register",
            headers={"Authorization": f"Bearer {data['deviceToken']}"},
            json={
                "serverId": server_id,
                "restaurantId": data["restaurantId"],
                "outletId": data["outletId"],
                "restaurantName": data["restaurantName"],
                "outletName": data["outletName"],
                "tableCount": 31,
            },
        )

    assert bootstrap.status_code == 200
    assert data["tableCount"] == 24
    assert registered.status_code == 200
    assert registered.json()["data"]["tableCount"] == 31
