import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from database import create_tables
from main import app
from routers import customer as customer_router


class _FakeGoogleResponse:
    def __init__(self, payload):
        self._payload = payload

    def raise_for_status(self):
        return None

    def json(self):
        return self._payload


def _mock_google_geocode(monkeypatch, payload):
    calls = []

    class FakeGoogleClient:
        def __init__(self, **kwargs):
            self.kwargs = kwargs

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, url, params):
            calls.append({"url": url, "params": params, "kwargs": self.kwargs})
            return _FakeGoogleResponse(payload)

    monkeypatch.setattr(customer_router.httpx, "AsyncClient", FakeGoogleClient)
    return calls


async def _create_outlet(client):
    bootstrap = await client.post(
        "/tenants/bootstrap",
        json={
            "serverId": f"customer-geocode-{uuid.uuid4()}",
            "restaurantName": "Geocode Test",
            "tableCount": 4,
        },
    )
    assert bootstrap.status_code == 200
    return bootstrap.json()["data"]["outletId"]


@pytest.mark.asyncio(loop_scope="session")
async def test_customer_reverse_geocode_returns_address(monkeypatch):
    await create_tables()
    monkeypatch.setattr(customer_router.settings, "GOOGLE_GEOCODING_API_KEY", "server-key")
    calls = _mock_google_geocode(
        monkeypatch,
        {
            "status": "OK",
            "results": [
                {"formatted_address": "Banani, Dhaka 1213, Bangladesh"},
            ],
        },
    )
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id = await _create_outlet(client)
        response = await client.post(
            f"/customer/{outlet_id}/geocode/reverse",
            json={"lat": 23.7937, "lng": 90.4066},
        )

    assert response.status_code == 200
    assert response.json() == {"address": "Banani, Dhaka 1213, Bangladesh"}
    assert calls[0]["params"]["latlng"] == "23.7937,90.4066"
    assert calls[0]["params"]["key"] == "server-key"
    assert calls[0]["params"]["language"] == "en"


@pytest.mark.asyncio(loop_scope="session")
async def test_customer_reverse_geocode_requires_server_key(monkeypatch):
    await create_tables()
    monkeypatch.setattr(customer_router.settings, "GOOGLE_GEOCODING_API_KEY", "")
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id = await _create_outlet(client)
        response = await client.post(
            f"/customer/{outlet_id}/geocode/reverse",
            json={"lat": 23.7937, "lng": 90.4066},
        )

    assert response.status_code == 503
    assert response.json()["detail"] == "Address lookup is not configured."


@pytest.mark.asyncio(loop_scope="session")
async def test_customer_reverse_geocode_rejects_invalid_coordinates(monkeypatch):
    await create_tables()
    monkeypatch.setattr(customer_router.settings, "GOOGLE_GEOCODING_API_KEY", "server-key")
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id = await _create_outlet(client)
        response = await client.post(
            f"/customer/{outlet_id}/geocode/reverse",
            json={"lat": 91, "lng": 90.4066},
        )

    assert response.status_code == 422


@pytest.mark.asyncio(loop_scope="session")
async def test_customer_reverse_geocode_handles_google_denial(monkeypatch):
    await create_tables()
    monkeypatch.setattr(customer_router.settings, "GOOGLE_GEOCODING_API_KEY", "server-key")
    _mock_google_geocode(
        monkeypatch,
        {
            "status": "REQUEST_DENIED",
            "error_message": "API key cannot use this API.",
            "results": [],
        },
    )
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id = await _create_outlet(client)
        response = await client.post(
            f"/customer/{outlet_id}/geocode/reverse",
            json={"lat": 23.7937, "lng": 90.4066},
        )

    assert response.status_code == 502
    assert response.json()["detail"] == "Address lookup failed."
