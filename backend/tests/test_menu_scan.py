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
from models import AdminAccount, MenuItem, Outlet
from phone_utils import phone_to_synthetic_email
from routers import menu
from schemas import MenuScanCandidate
from services import menu_scan


async def _bootstrap_scan_tenant(server_id: str, stored_role: str = "Manager") -> tuple[str, str]:
    """Bootstrap a tenant with an active manager account; return (outlet_id, token)."""
    await create_tables()
    suffix = uuid.uuid4()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        boot = await client.post(
            "/tenants/bootstrap",
            json={
                "serverId": server_id,
                "restaurantName": "Scan Test",
                "tableCount": 4,
            },
        )
        outlet_id = boot.json()["data"]["outletId"]
    async with AsyncSessionLocal() as db:
        outlet = (
            await db.execute(select(Outlet).where(Outlet.id == outlet_id))
        ).scalar_one()
        phone = f"+88017{suffix.int % 100_000_000:08d}"
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
    return outlet_id, token


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


def test_menu_scan_prompt_lists_known_items_and_forbids_re_extraction():
    messages = menu_scan._prompt(
        ["Chicken Biryani 220\nTea 50"],
        known_items=["Chicken Biryani", "Tea", "tea"],
    )
    joined = "\n".join(message["content"] for message in messages)

    assert "ALREADY been extracted" in joined
    assert "Do NOT include any of these already-known items" in joined
    assert "Only output items that are NOT in the list above" in joined
    known_section = joined.split("ALREADY been extracted")[-1]
    assert known_section.count("Chicken Biryani") == 1
    assert known_section.count("Tea") == 1
    assert "\nChicken Biryani\nTea\n" in known_section


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
    trip_2_known: list[str] | None = None

    async def fake_ocr(pages):
        nonlocal ocr_calls
        ocr_calls += 1
        return ["Chicken 250\nTea 50\nCoffee 80"]

    async def fake_parse(page_texts, known_item_names=None):
        nonlocal llm_calls, trip_2_known
        llm_calls += 1
        if llm_calls == 2:
            trip_2_known = known_item_names
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
    assert trip_2_known == ["Chicken Curry"]
    assert len(result.items) == 2
    names = [item.nameEn for item in result.items]
    assert "Chicken Curry" in names
    assert "Tea" in names
    assert any("Deduplication" in w for w in result.warnings)


@pytest.mark.asyncio
async def test_menu_scan_known_names_reach_llm_request(monkeypatch):
    sent_known: list[str] | None = None

    async def fake_ocr(pages):
        return ["Chicken 250\nTea 50"]

    async def fake_parse(page_texts, known_item_names=None):
        nonlocal sent_known
        sent_known = known_item_names
        return menu_scan.MenuScanParseResult(
            items=[
                MenuScanCandidate(
                    nameEn="Tea",
                    nameBn="চা",
                    descriptionEn="Milk tea.",
                    descriptionBn="দুধ চা।",
                    categoryEn="Drinks",
                    categoryBn="ড্রিংকস",
                    price=50,
                    isAvailable=True,
                )
            ],
            provider="deepseek",
            warnings=[],
        )

    monkeypatch.setattr(menu_scan, "extract_menu_page_texts", fake_ocr)
    monkeypatch.setattr(menu_scan, "parse_menu_text", fake_parse)

    await menu_scan.scan_image_once(
        b"image", "image/png", known_item_names=["Chicken Curry", "Tea"]
    )

    assert sent_known == ["Chicken Curry", "Tea"]


def test_menu_scan_dedup_names_and_prompt_cap():
    assert menu_scan._dedup_names(["Tea", "tea", "", "  "]) == ["Tea"]
    joined = "\n".join(
        m["content"]
        for m in menu_scan._prompt(
            ["Tea 50"],
            known_items=[f"Item {i}" for i in range(500)],
        )
    )
    assert joined.count("Item ") == menu_scan.KNOWN_ITEMS_PROMPT_LIMIT


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
    outlet_id, token = await _bootstrap_scan_tenant(
        f"scan-role-{uuid.uuid4()}", stored_role
    )

    async def fake_scan(image_bytes, content_type, known_item_names=None):
        assert content_type == "image/png"
        if known_item_names:
            return menu_scan.MenuScanParseResult(items=[], provider="test", warnings=[])
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

    monkeypatch.setattr(menu, "scan_image_once", fake_scan)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            f"/outlets/{outlet_id}/menu/scan",
            headers={"Authorization": f"Bearer {token}"},
            files=[("files", ("menu.png", b"image", "image/png"))],
        )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["createdCount"] == 1
    assert data["skippedDuplicateCount"] == 0
    assert data["totalPages"] == 1

    async with AsyncSessionLocal() as db:
        rows = (
            await db.execute(select(MenuItem).where(MenuItem.outlet_id == outlet_id))
        ).scalars().all()
    assert len(rows) == 1
    assert rows[0].name_en == "Tea"
    assert rows[0].name_bn == "চা"
    assert rows[0].category_en == "Drinks"
    assert rows[0].price == 50
    assert rows[0].is_available is True
    assert rows[0].short_code == 1
    assert rows[0].tags_json == '["icon:general"]'


@pytest.mark.asyncio(loop_scope="session")
async def test_menu_scan_route_hands_multiple_images_to_ocr(monkeypatch):
    outlet_id, token = await _bootstrap_scan_tenant(f"scan-pages-{uuid.uuid4()}")
    seen_calls: list[tuple[bytes, str, list[str] | None]] = []
    broadcast_calls: list[tuple[str, dict]] = []
    scan_calls = 0

    async def fake_scan(image_bytes, content_type, known_item_names=None):
        nonlocal scan_calls
        scan_calls += 1
        seen_calls.append(
            (
                image_bytes,
                content_type,
                list(known_item_names) if known_item_names else None,
            )
        )
        if scan_calls == 1:
            item = MenuScanCandidate(
                nameEn="Tea",
                nameBn="চা",
                descriptionEn="Fresh milk tea.",
                descriptionBn="তাজা দুধ চা।",
                categoryEn="Drinks",
                categoryBn="ড্রিংকস",
                price=50,
                isAvailable=True,
                iconKey="drink",
            )
        elif scan_calls == 3:
            item = MenuScanCandidate(
                nameEn="Coffee",
                nameBn="কফি",
                descriptionEn="Black coffee.",
                descriptionBn="ব্ল্যাক কফি।",
                categoryEn="Drinks",
                categoryBn="ড্রিংকস",
                price=80,
                isAvailable=True,
                iconKey="drink",
            )
        else:
            return menu_scan.MenuScanParseResult(items=[], provider="xai", warnings=[])
        return menu_scan.MenuScanParseResult(items=[item], provider="xai", warnings=[])

    async def fake_broadcast(outlet_id, event):
        broadcast_calls.append((outlet_id, event))

    monkeypatch.setattr(menu, "scan_image_once", fake_scan)
    monkeypatch.setattr(menu.manager, "broadcast", fake_broadcast)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            f"/outlets/{outlet_id}/menu/scan",
            headers={"Authorization": f"Bearer {token}"},
            files=[
                ("files", ("page-1.png", b"first", "image/png")),
                ("files", ("page-2.jpg", b"second", "image/jpeg")),
            ],
        )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["createdCount"] == 2
    assert data["skippedDuplicateCount"] == 0
    assert data["totalPages"] == 2
    assert len(seen_calls) == 4
    assert [(image, content_type) for image, content_type, _ in seen_calls] == [
        (b"first", "image/png"),
        (b"first", "image/png"),
        (b"second", "image/jpeg"),
        (b"second", "image/jpeg"),
    ]
    assert seen_calls[0][2] is None
    assert seen_calls[1][2] == ["Tea"]
    assert seen_calls[2][2] is None
    assert seen_calls[3][2] == ["Tea", "Coffee"]

    async with AsyncSessionLocal() as db:
        rows = (
            await db.execute(
                select(MenuItem)
                .where(MenuItem.outlet_id == outlet_id)
                .order_by(MenuItem.short_code)
            )
        ).scalars().all()
    assert len(rows) == 2
    assert [row.name_en for row in rows] == ["Tea", "Coffee"]
    assert [row.short_code for row in rows] == [1, 2]

    progress_events = [
        event for _, event in broadcast_calls if event["type"] == "menu_scan_progress"
    ]
    assert len(progress_events) == 4
    assert [event["data"]["pageIndex"] for event in progress_events] == [1, 1, 2, 2]
    assert [event["data"]["tripIndex"] for event in progress_events] == [1, 2, 1, 2]
    assert [event["data"]["createdCount"] for event in progress_events] == [1, 0, 1, 0]
    menu_events = [
        event for _, event in broadcast_calls if event["type"] == "menu_updated"
    ]
    assert len(menu_events) == 2
    assert {event["data"]["nameEn"] for event in menu_events} == {"Tea", "Coffee"}


@pytest.mark.asyncio(loop_scope="session")
async def test_menu_scan_route_skips_duplicate_of_existing_item(monkeypatch):
    outlet_id, token = await _bootstrap_scan_tenant(f"scan-dup-{uuid.uuid4()}")

    async with AsyncSessionLocal() as db:
        db.add(
            MenuItem(
                id=str(uuid.uuid4()),
                outlet_id=outlet_id,
                name="Tea",
                name_en="Tea",
                category="Drinks",
                category_en="Drinks",
                price=50,
                is_available=True,
                short_code=1,
                version=1,
                updated_at=datetime.now(timezone.utc),
            )
        )
        await db.commit()

    scan_calls = 0

    async def fake_scan(image_bytes, content_type, known_item_names=None):
        nonlocal scan_calls
        scan_calls += 1
        if scan_calls == 1:
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
                ],
                provider="xai",
                warnings=[],
            )
        return menu_scan.MenuScanParseResult(items=[], provider="xai", warnings=[])

    monkeypatch.setattr(menu, "scan_image_once", fake_scan)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            f"/outlets/{outlet_id}/menu/scan",
            headers={"Authorization": f"Bearer {token}"},
            files=[("files", ("menu.png", b"image", "image/png"))],
        )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["createdCount"] == 1
    assert data["skippedDuplicateCount"] == 1
    assert data["totalPages"] == 1

    async with AsyncSessionLocal() as db:
        rows = (
            await db.execute(select(MenuItem).where(MenuItem.outlet_id == outlet_id))
        ).scalars().all()
    assert len(rows) == 2
    assert {row.name_en for row in rows} == {"Tea", "Coffee"}


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
