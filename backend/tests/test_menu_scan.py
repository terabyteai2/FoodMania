import json

import httpx
import pytest
from httpx import ASGITransport, AsyncClient

from auth import get_current_device_payload
from database import get_db
from main import app
from routers import menu
from schemas import MenuScanCandidate
from services import menu_scan


def test_menu_scan_validation_accepts_generated_description_and_rejects_bad_price():
    items = menu_scan._validated_items(
        json.dumps(
            {
                "items": [
                    {
                        "name": "Beef Burger",
                        "description": "Juicy grilled beef burger.",
                        "category": "Burgers",
                        "price": 320,
                        "isAvailable": True,
                    },
                    {
                        "name": "Free Water",
                        "description": "Water.",
                        "category": "Drinks",
                        "price": 0,
                        "isAvailable": True,
                    },
                ]
            }
        )
    )

    assert [item.name for item in items] == ["Beef Burger"]
    assert items[0].description == "Juicy grilled beef burger."


@pytest.mark.asyncio
async def test_menu_scan_llm_falls_back_after_invalid_schema(monkeypatch):
    calls = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(str(request.url))
        if "api.x.ai" in str(request.url):
            return httpx.Response(
                200,
                json={"choices": [{"message": {"content": '{"items":[]}'}}]},
            )
        return httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "items": [
                                        {
                                            "name": "Lassi",
                                            "description": "Cool yogurt drink.",
                                            "category": "Drinks",
                                            "price": 120,
                                            "isAvailable": True,
                                        }
                                    ]
                                }
                            )
                        }
                    }
                ]
            },
        )

    real_async_client = httpx.AsyncClient

    def mock_client(*, timeout):
        return real_async_client(
            transport=httpx.MockTransport(handler),
            timeout=timeout,
        )

    monkeypatch.setattr(menu_scan.settings, "XAI_API_KEY", "xai-test")
    monkeypatch.setattr(menu_scan.settings, "DEEPSEEK_API_KEY", "deepseek-test")
    monkeypatch.setattr(menu_scan.settings, "OPENAI_API_KEY", "openai-test")
    monkeypatch.setattr(menu_scan.httpx, "AsyncClient", mock_client)

    parsed = await menu_scan.parse_menu_text(["Drinks\nLassi 120"])

    assert parsed.provider == "deepseek"
    assert [item.name for item in parsed.items] == ["Lassi"]
    assert calls[:2] == [
        "https://api.x.ai/v1/chat/completions",
        "https://api.deepseek.com/chat/completions",
    ]
    assert parsed.warnings and parsed.warnings[0].startswith("xai:")


@pytest.mark.asyncio
async def test_menu_scan_route_requires_auth():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/outlets/outlet/menu/scan",
            files=[("files", ("menu.png", b"image", "image/png"))],
        )

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_menu_scan_route_hands_multiple_images_to_ocr(monkeypatch):
    seen_pages = []
    seen_texts = []

    async def fake_manager_access(outlet_id, payload, db):
        assert outlet_id == "outlet-1"
        assert payload["account_id"] == "manager-1"

    async def fake_ocr(pages):
        seen_pages.extend(pages)
        return ["first page OCR", "second page OCR"]

    async def fake_parse(page_texts):
        seen_texts.extend(page_texts)
        return menu_scan.MenuScanParseResult(
            items=[
                MenuScanCandidate(
                    name="Tea",
                    description="Fresh milk tea.",
                    category="Drinks",
                    price=50,
                    isAvailable=True,
                )
            ],
            provider="xai",
            warnings=[],
        )

    async def fake_db():
        yield object()

    app.dependency_overrides[get_current_device_payload] = lambda: {
        "sub": "outlet-1",
        "account_id": "manager-1",
    }
    app.dependency_overrides[get_db] = fake_db
    monkeypatch.setattr(menu, "_require_manager_scan_access", fake_manager_access)
    monkeypatch.setattr(menu, "extract_menu_page_texts", fake_ocr)
    monkeypatch.setattr(menu, "parse_menu_text", fake_parse)

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/outlets/outlet-1/menu/scan",
                files=[
                    ("files", ("page-1.png", b"first", "image/png")),
                    ("files", ("page-2.jpg", b"second", "image/jpeg")),
                ],
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert seen_pages == [(b"first", "image/png"), (b"second", "image/jpeg")]
    assert seen_texts == ["first page OCR", "second page OCR"]
    assert response.json()["data"]["items"][0]["name"] == "Tea"
