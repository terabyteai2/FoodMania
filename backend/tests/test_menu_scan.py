import json
import logging
import uuid
from datetime import datetime, timezone

import httpx
import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from auth import create_device_token, get_current_device_payload
from database import AsyncSessionLocal, create_tables, get_db
from main import app
from models import AdminAccount, Outlet
from phone_utils import phone_to_synthetic_email
from routers import menu
from schemas import MenuScanCandidate
from services import menu_scan


def test_menu_scan_validation_accepts_generated_description_and_rejects_bad_price():
    items = menu_scan._validated_items(
        json.dumps(
            {
                "items": [
                    {
                        "nameEn": "Beef Burger",
                        "nameBn": "বিফ বার্গার",
                        "descriptionEn": "Juicy grilled beef burger.",
                        "descriptionBn": "রসালো গ্রিলড বিফ বার্গার।",
                        "categoryEn": "Burgers",
                        "categoryBn": "বার্গার",
                        "price": 320,
                        "isAvailable": True,
                        "iconKey": "burger",
                    },
                    {
                        "nameEn": "Free Water",
                        "nameBn": "ফ্রি পানি",
                        "descriptionEn": "Water.",
                        "descriptionBn": "পানি।",
                        "categoryEn": "Drinks",
                        "categoryBn": "ড্রিংকস",
                        "price": 0,
                        "isAvailable": True,
                        "iconKey": "drink",
                    },
                ]
            }
        )
    )

    assert [item.nameEn for item in items] == ["Beef Burger"]
    assert items[0].nameBn == "বিফ বার্গার"
    assert items[0].descriptionEn == "Juicy grilled beef burger."
    assert items[0].iconKey == "burger"


def test_menu_scan_validation_defaults_unknown_icon_key_to_general():
    items = menu_scan._validated_items(
        json.dumps(
            {
                "items": [
                    {
                        "nameEn": "Mystery Wrap",
                        "nameBn": "মিস্ট্রি র‍্যাপ",
                        "descriptionEn": "Surprise wrap of the day.",
                        "descriptionBn": "দিনের চমক র‍্যাপ।",
                        "categoryEn": "Wraps",
                        "categoryBn": "র‍্যাপ",
                        "price": 180,
                        "isAvailable": True,
                    }
                ]
            }
        )
    )

    assert items[0].iconKey == "general"


def test_menu_scan_validation_keeps_only_positive_add_ons():
    items = menu_scan._validated_items(
        json.dumps(
            {
                "items": [
                    {
                        "nameEn": "Chicken Platter",
                        "nameBn": "চিকেন প্ল্যাটার",
                        "descriptionEn": "Grilled chicken platter.",
                        "descriptionBn": "গ্রিলড চিকেন প্ল্যাটার।",
                        "categoryEn": "Grill",
                        "categoryBn": "গ্রিল",
                        "price": 450,
                        "isAvailable": True,
                        "iconKey": "grill",
                        "subItems": [
                            {"nameEn": "Rice", "nameBn": "ভাত"},
                        ],
                        "addOns": [
                            {"nameEn": "Extra naan", "nameBn": "অতিরিক্ত নান", "price": 20},
                            {"nameEn": "Free salad", "nameBn": "সালাদ", "price": 0},
                            {"nameEn": "Bad price", "nameBn": "খারাপ দাম", "price": -5},
                        ],
                    }
                ]
            }
        )
    )

    assert items[0].iconKey == "grill"
    assert [sub.nameEn for sub in items[0].subItems] == ["Rice"]
    assert [(addon.nameEn, addon.price) for addon in items[0].addOns] == [
        ("Extra naan", 20)
    ]


def test_menu_scan_dedup_by_name_en():
    from services.menu_scan import _dedup_items

    items = [
        MenuScanCandidate(
            nameEn="Tea",
            nameBn="চা",
            descriptionEn="Milk tea.",
            descriptionBn="দুধ চা।",
            categoryEn="Drinks",
            categoryBn="ড্রিংকস",
            price=50,
            isAvailable=True,
        ),
        MenuScanCandidate(
            nameEn="Coffee",
            nameBn="কফি",
            descriptionEn="Black coffee.",
            descriptionBn="ব্ল্যাক কফি।",
            categoryEn="Drinks",
            categoryBn="ড্রিংকস",
            price=80,
            isAvailable=True,
        ),
        MenuScanCandidate(
            nameEn="tea",
            nameBn="চা",
            descriptionEn="Duplicate tea.",
            descriptionBn="ডুপ্লিকেট চা।",
            categoryEn="Drinks",
            categoryBn="ড্রিংকস",
            price=50,
            isAvailable=True,
        ),
    ]

    deduped = _dedup_items(items)

    assert len(deduped) == 2
    assert deduped[0].nameEn == "Tea"
    assert deduped[1].nameEn == "Coffee"


def test_menu_scan_prompt_requests_bilingual_items_and_ignores_noise():
    messages = menu_scan._prompt(
        [
            "Scan Cafe\nMirpur, Dhaka\nChicken Biryani 220\nVAT 5%",
            "চা ২০\nFree Wi-Fi",
        ]
    )
    joined = "\n".join(message["content"] for message in messages)

    assert "English and Bangla" in joined
    assert "nameEn, nameBn, descriptionEn, descriptionBn" in joined
    assert "around 40 words" in joined
    assert "restaurant names" in joined
    assert "VAT" in joined
    assert "not a sellable menu item" in joined
    assert "iconKey" in joined
    assert "subItems" in joined
    assert "addOns" in joined
    assert "dal" in joined
    assert "sandwich" in joined


def test_menu_scan_uses_json_object_mode_for_deepseek():
    deepseek = next(provider for provider in menu_scan._providers() if provider.name == "deepseek")

    payload = menu_scan._request_payload(deepseek, ["Tea 50"])

    assert payload["response_format"] == {"type": "json_object"}


@pytest.mark.asyncio
async def test_menu_scan_ocr_space_sends_image_and_keeps_json_for_llm(monkeypatch):
    calls = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        return httpx.Response(
            200,
            json={
                "ParsedResults": [
                    {
                        "FileParseExitCode": 1,
                        "ParsedText": "Tea 50\nচা ৫০",
                    }
                ],
                "OCRExitCode": 1,
                "IsErroredOnProcessing": False,
            },
        )

    real_async_client = httpx.AsyncClient

    def mock_client(*, timeout):
        assert timeout == menu_scan.OCR_TIMEOUT_SECONDS
        return real_async_client(
            transport=httpx.MockTransport(handler),
            timeout=timeout,
        )

    monkeypatch.setattr(menu_scan.settings, "OCR_SPACE_API_KEY", "ocr-space-test")
    monkeypatch.setattr(menu_scan.httpx, "AsyncClient", mock_client)

    pages = await menu_scan.extract_menu_page_texts([(b"menu-image", "image/png")])
    payload = json.loads(pages[0])

    assert payload["ParsedResults"][0]["ParsedText"] == "Tea 50\nচা ৫০"
    assert calls[0].headers["apikey"] == "ocr-space-test"
    assert "multipart/form-data" in calls[0].headers["content-type"]
    assert b"menu-page.png" in calls[0].content


@pytest.mark.asyncio
async def test_menu_scan_ocr_keeps_good_pages_when_one_page_fails(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        if b"bad" in request.content:
            return httpx.Response(
                200,
                json={
                    "IsErroredOnProcessing": True,
                    "ErrorMessage": "unreadable",
                    "ParsedResults": [],
                },
            )
        return httpx.Response(
            200,
            json={
                "ParsedResults": [
                    {"FileParseExitCode": 1, "ParsedText": "Tea 50"}
                ],
                "IsErroredOnProcessing": False,
            },
        )

    real_async_client = httpx.AsyncClient

    def mock_client(*, timeout):
        return real_async_client(
            transport=httpx.MockTransport(handler),
            timeout=timeout,
        )

    monkeypatch.setattr(menu_scan.settings, "OCR_SPACE_API_KEY", "ocr-space-test")
    monkeypatch.setattr(menu_scan.httpx, "AsyncClient", mock_client)

    texts = await menu_scan.extract_menu_page_texts(
        [(b"good", "image/png"), (b"bad", "image/png")]
    )

    assert len(texts) == 1
    assert json.loads(texts[0])["ParsedResults"][0]["ParsedText"] == "Tea 50"


@pytest.mark.asyncio
async def test_menu_scan_ocr_raises_when_every_page_fails(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "IsErroredOnProcessing": True,
                "ErrorMessage": "unreadable",
                "ParsedResults": [],
            },
        )

    real_async_client = httpx.AsyncClient

    def mock_client(*, timeout):
        return real_async_client(
            transport=httpx.MockTransport(handler),
            timeout=timeout,
        )

    monkeypatch.setattr(menu_scan.settings, "OCR_SPACE_API_KEY", "ocr-space-test")
    monkeypatch.setattr(menu_scan.httpx, "AsyncClient", mock_client)

    with pytest.raises(menu_scan.MenuScanError):
        await menu_scan.extract_menu_page_texts(
            [(b"a", "image/png"), (b"b", "image/png")]
        )


@pytest.mark.asyncio
async def test_menu_scan_llm_returns_items_from_deepseek(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
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
                                            "nameEn": "Lassi",
                                            "nameBn": "লাচ্ছি",
                                            "descriptionEn": "Cool yogurt drink.",
                                            "descriptionBn": "ঠান্ডা দইয়ের পানীয়।",
                                            "categoryEn": "Drinks",
                                            "categoryBn": "ড্রিংকস",
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

    monkeypatch.setattr(menu_scan.settings, "DEEPSEEK_API_KEY", "deepseek-test")
    monkeypatch.setattr(menu_scan.httpx, "AsyncClient", mock_client)

    parsed = await menu_scan.parse_menu_text(["Drinks\nLassi 120"])

    assert parsed.provider == "deepseek"
    assert [item.nameEn for item in parsed.items] == ["Lassi"]


@pytest.mark.asyncio
async def test_menu_scan_llm_raises_on_deepseek_rejection(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            400,
            json={"error": {"message": "bad request"}},
        )

    real_async_client = httpx.AsyncClient

    def mock_client(*, timeout):
        return real_async_client(
            transport=httpx.MockTransport(handler),
            timeout=timeout,
        )

    monkeypatch.setattr(menu_scan.settings, "DEEPSEEK_API_KEY", "deepseek-test")
    monkeypatch.setattr(menu_scan.httpx, "AsyncClient", mock_client)

    with pytest.raises(menu_scan.MenuScanError):
        await menu_scan.parse_menu_text(["Drinks\nCoffee 90"])


@pytest.mark.asyncio
async def test_menu_scan_single_image_two_trips_dedup(monkeypatch):
    ocr_calls = 0
    llm_calls = 0

    async def fake_ocr(pages):
        nonlocal ocr_calls
        ocr_calls += 1
        return ["Chicken 250\nTea 50\nCoffee 80"]

    async def fake_parse(page_texts):
        nonlocal llm_calls
        llm_calls += 1
        if llm_calls == 1:
            items = [
                MenuScanCandidate(
                    nameEn="Chicken Curry",
                    nameBn="চিকেন কারি",
                    descriptionEn="Spicy chicken.",
                    descriptionBn="মসলাদার চিকেন।",
                    categoryEn="Mains",
                    categoryBn="মেইনস",
                    price=250,
                    isAvailable=True,
                ),
            ]
        else:
            items = [
                MenuScanCandidate(
                    nameEn="Chicken Curry",
                    nameBn="চিকেন কারি",
                    descriptionEn="Spicy chicken.",
                    descriptionBn="মসলাদার চিকেন।",
                    categoryEn="Mains",
                    categoryBn="মেইনস",
                    price=250,
                    isAvailable=True,
                ),
                MenuScanCandidate(
                    nameEn="Tea",
                    nameBn="চা",
                    descriptionEn="Milk tea.",
                    descriptionBn="দুধ চা।",
                    categoryEn="Drinks",
                    categoryBn="ড্রিংকস",
                    price=50,
                    isAvailable=True,
                ),
            ]
        return menu_scan.MenuScanParseResult(
            items=items,
            provider="deepseek",
            warnings=[],
        )

    monkeypatch.setattr(menu_scan, "extract_menu_page_texts", fake_ocr)
    monkeypatch.setattr(menu_scan, "parse_menu_text", fake_parse)

    result = await menu_scan.scan_single_image_with_dedup(b"image", "image/png")

    assert ocr_calls == 2
    assert llm_calls == 2
    assert len(result.items) == 2
    names = [item.nameEn for item in result.items]
    assert "Chicken Curry" in names
    assert "Tea" in names
    assert any("Deduplication" in w for w in result.warnings)


@pytest.mark.asyncio
async def test_menu_scan_route_requires_auth():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/outlets/outlet/menu/scan",
            files=[("files", ("menu.png", b"image", "image/png"))],
        )

    assert response.status_code == 401


@pytest.mark.asyncio(loop_scope="session")
@pytest.mark.parametrize("stored_role", ["Manager ", "owner"])
async def test_menu_scan_route_accepts_manager_access_variants(
    monkeypatch,
    stored_role,
):
    await create_tables()
    suffix = uuid.uuid4()
    server_id = f"scan-role-{suffix}"

    async def fake_scan(image_bytes, content_type):
        assert content_type == "image/png"
        return menu_scan.MenuScanParseResult(
            items=[
                MenuScanCandidate(
                    nameEn="Tea",
                    nameBn="চা",
                    descriptionEn="Fresh milk tea.",
                    descriptionBn="তাজা দুধ চা।",
                    categoryEn="Drinks",
                    categoryBn="ড্রিংকস",
                    price=50,
                    isAvailable=True,
                )
            ],
            provider="test",
            warnings=[],
        )

    monkeypatch.setattr(menu, "scan_single_image_with_dedup", fake_scan)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        boot = await client.post(
            "/tenants/bootstrap",
            json={
                "serverId": server_id,
                "restaurantName": "Scan Role",
                "tableCount": 4,
            },
        )
        outlet_id = boot.json()["data"]["outletId"]
        async with AsyncSessionLocal() as db:
            outlet = (await db.execute(select(Outlet).where(Outlet.id == outlet_id))).scalar_one()
            phone = f"+88017{suffix.hex[:8]}"
            account = AdminAccount(
                id=str(uuid.uuid4()),
                outlet_id=outlet.id,
                email=phone_to_synthetic_email(phone),
                username=phone_to_synthetic_email(phone),
                password_hash=None,
                role=stored_role,
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
        response = await client.post(
            f"/outlets/{outlet_id}/menu/scan",
            headers={"Authorization": f"Bearer {token}"},
            files=[("files", ("menu.png", b"image", "image/png"))],
        )

    assert response.status_code == 200
    assert response.json()["data"]["images"][0]["items"][0]["nameEn"] == "Tea"


@pytest.mark.asyncio
async def test_menu_scan_route_hands_multiple_images_to_ocr(monkeypatch):
    seen_calls: list[tuple[bytes, str]] = []

    async def fake_manager_access(outlet_id, payload, db):
        assert outlet_id == "outlet-1"
        assert payload["account_id"] == "manager-1"

    async def fake_scan(image_bytes, content_type):
        seen_calls.append((image_bytes, content_type))
        return menu_scan.MenuScanParseResult(
            items=[
                MenuScanCandidate(
                    nameEn="Tea",
                    nameBn="চা",
                    descriptionEn="Fresh milk tea.",
                    descriptionBn="তাজা দুধ চা।",
                    categoryEn="Drinks",
                    categoryBn="ড্রিংকস",
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
    monkeypatch.setattr(menu, "scan_single_image_with_dedup", fake_scan)

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
    assert seen_calls == [(b"first", "image/png"), (b"second", "image/jpeg")]
    assert len(response.json()["data"]["images"]) == 2
    assert response.json()["data"]["images"][0]["items"][0]["nameEn"] == "Tea"
    assert response.json()["data"]["images"][0]["items"][0]["nameBn"] == "চা"


@pytest.mark.asyncio
async def test_menu_scan_route_rejects_too_many_images(monkeypatch):
    async def fake_manager_access(outlet_id, payload, db):
        return None

    async def fake_db():
        yield object()

    app.dependency_overrides[get_current_device_payload] = lambda: {
        "sub": "outlet-1",
        "account_id": "manager-1",
    }
    app.dependency_overrides[get_db] = fake_db
    monkeypatch.setattr(menu, "_require_manager_scan_access", fake_manager_access)

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/outlets/outlet-1/menu/scan",
                files=[
                    ("files", (f"page-{i}.png", b"image", "image/png"))
                    for i in range(menu.MAX_MENU_SCAN_PAGES + 1)
                ],
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 400
    assert f"up to {menu.MAX_MENU_SCAN_PAGES}" in response.json()["detail"]


@pytest.mark.asyncio
async def test_menu_scan_route_rejects_oversized_image(monkeypatch):
    async def fake_manager_access(outlet_id, payload, db):
        return None

    async def fake_db():
        yield object()

    app.dependency_overrides[get_current_device_payload] = lambda: {
        "sub": "outlet-1",
        "account_id": "manager-1",
    }
    app.dependency_overrides[get_db] = fake_db
    monkeypatch.setattr(menu, "_require_manager_scan_access", fake_manager_access)

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/outlets/outlet-1/menu/scan",
                files=[
                    (
                        "files",
                        (
                            "large-page.png",
                            b"x" * (menu.MAX_MENU_SCAN_PAGE_BYTES + 1),
                            "image/png",
                        ),
                    )
                ],
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 413
    assert "too large" in response.json()["detail"]
