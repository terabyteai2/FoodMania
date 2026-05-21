import pytest
from httpx import ASGITransport, AsyncClient

from main import app


@pytest.mark.asyncio(loop_scope="session")
async def test_health_returns_ok():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body.get("error") is None
    data = body.get("data") or {}
    assert data.get("status") in ("ok", "degraded")
    assert "database" in data
