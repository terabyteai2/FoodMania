import uuid
from datetime import datetime, timezone
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from auth import create_device_token
from database import AsyncSessionLocal, create_tables
from main import app
from models import AdminAccount, Outlet
from phone_utils import phone_to_synthetic_email


async def _manager(client: AsyncClient) -> tuple[str, str, dict]:
    suffix = uuid.uuid4()
    server_id = f"desktop-pos-{suffix}"
    boot = await client.post(
        "/tenants/bootstrap",
        json={"serverId": server_id, "restaurantName": "Desktop POS", "tableCount": 3},
    )
    outlet_id = boot.json()["data"]["outletId"]

    async with AsyncSessionLocal() as db:
        outlet = (await db.execute(select(Outlet).where(Outlet.id == outlet_id))).scalar_one()
        phone = f"+88017{suffix.hex[:8]}"
        account = AdminAccount(
            id=str(uuid4()),
            outlet_id=outlet.id,
            email=phone_to_synthetic_email(phone),
            username=phone_to_synthetic_email(phone),
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

    return outlet_id, server_id, {"Authorization": f"Bearer {token}"}


async def _staff(client: AsyncClient, outlet_id: str, server_id: str) -> dict:
    suffix = uuid.uuid4()
    async with AsyncSessionLocal() as db:
        outlet = (await db.execute(select(Outlet).where(Outlet.id == outlet_id))).scalar_one()
        phone = f"+88018{suffix.hex[:8]}"
        account = AdminAccount(
            id=str(uuid4()),
            outlet_id=outlet.id,
            email=phone_to_synthetic_email(phone),
            username=phone_to_synthetic_email(phone),
            password_hash=None,
            role="staff",
            display_name="Test Staff",
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
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio(loop_scope="session")
async def test_desktop_pos_settings_shift_kot_settlement_and_reports():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id, server_id, headers = await _manager(client)

        defaults = await client.get(f"/outlets/{outlet_id}/pos/settings", headers=headers)
        assert defaults.status_code == 200
        assert defaults.json()["data"]["vatRatePercent"] == 0
        assert defaults.json()["data"]["serviceChargePercent"] == 0
        assert len(defaults.json()["data"]["floorLayout"][0]["tables"]) == 3

        settings = await client.patch(
            f"/outlets/{outlet_id}/pos/settings",
            headers=headers,
            json={
                "floorLayout": [
                    {
                        "id": "main",
                        "name": "Main",
                        "tables": [{"id": "t1", "label": "1", "seats": 4}],
                    },
                    {
                        "id": "roof",
                        "name": "Roof",
                        "tables": [{"id": "t2", "label": "R1", "seats": 2}],
                    },
                ],
                "vatRatePercent": 5,
                "serviceChargePercent": 10,
                "discountPresets": [
                    {"id": "staff-five", "label": "Staff 5%", "kind": "percent", "value": 5}
                ],
            },
        )
        assert settings.status_code == 200
        assert settings.json()["data"]["tableCount"] == 2

        item_id = f"menu-{uuid.uuid4()}"
        await client.post(
            f"/outlets/{outlet_id}/menu",
            headers=headers,
            json={"id": item_id, "name": "Rice", "price": 100, "costPrice": 40, "category": "Main"},
        )
        order_id = f"order-{uuid.uuid4()}"
        order = {
            "id": order_id,
            "source": "desktop_pos",
            "status": "accepted",
            "shiftId": "missing",
            "totalAmount": 105,
            "subtotal": 100,
            "vatRatePercent": 5,
            "vatAmount": 5,
            "serviceType": "dine_in",
            "tableNo": "1",
            "items": [{"id": "line-1", "menuItemId": item_id, "name": "Rice", "qty": 1, "price": 100, "lineTotal": 100}],
        }
        gated = await client.post(f"/outlets/{outlet_id}/orders", headers=headers, json=order)
        assert gated.status_code == 409

        shift_id = f"shift-{uuid.uuid4()}"
        opened = await client.post(
            f"/outlets/{outlet_id}/pos/shifts/open",
            headers=headers,
            json={"id": shift_id, "openingCash": 500, "denominations": {"500": 1}},
        )
        assert opened.status_code == 200
        order["shiftId"] = shift_id
        created = await client.post(f"/outlets/{outlet_id}/orders", headers=headers, json=order)
        assert created.status_code == 200
        assert created.json()["data"]["items"][0]["costPriceSnapshot"] == 40

        kot = await client.post(
            f"/outlets/{outlet_id}/pos/orders/{order_id}/kot",
            headers=headers,
            json={"batchId": "kot-1", "itemIds": ["line-1"], "note": "No chilli"},
        )
        assert kot.status_code == 200
        assert kot.json()["data"]["items"][0]["kotBatchId"] == "kot-1"

        settlement_event_id = f"pay-{uuid.uuid4()}"
        settlement = {
            "shiftId": shift_id,
            "discountPresetId": "staff-five",
            "discountAmount": 5,
            "serviceChargeRatePercent": 10,
            "serviceChargeAmount": 10,
            "totalAmount": 110,
            "settlements": [{"eventId": settlement_event_id, "paymentMethod": "cash", "amount": 110}],
        }
        settled = await client.post(
            f"/outlets/{outlet_id}/pos/orders/{order_id}/settle",
            headers=headers,
            json=settlement,
        )
        replayed = await client.post(
            f"/outlets/{outlet_id}/pos/orders/{order_id}/settle",
            headers=headers,
            json=settlement,
        )
        assert settled.status_code == 200
        assert replayed.status_code == 200
        assert settled.json()["data"]["status"] == "served"
        assert settled.json()["data"]["discountAmount"] == 5

        staff_headers = await _staff(client, outlet_id, server_id)
        staff_settings = await client.patch(
            f"/outlets/{outlet_id}/pos/settings",
            headers=staff_headers,
            json={"vatRatePercent": 9},
        )
        assert staff_settings.status_code == 403
        staff_order_id = f"staff-order-{uuid.uuid4()}"
        staff_order = await client.post(
            f"/outlets/{outlet_id}/orders",
            headers=staff_headers,
            json={
                "id": staff_order_id,
                "source": "desktop_pos",
                "status": "accepted",
                "shiftId": shift_id,
                "totalAmount": 105,
                "subtotal": 100,
                "vatRatePercent": 5,
                "vatAmount": 5,
                "items": [{"id": "staff-line", "menuItemId": item_id, "name": "Rice", "qty": 1, "price": 100, "lineTotal": 100}],
            },
        )
        assert staff_order.status_code == 200
        staff_override = await client.post(
            f"/outlets/{outlet_id}/pos/orders/{staff_order_id}/settle",
            headers=staff_headers,
            json={
                "shiftId": shift_id,
                "discountPresetId": "staff-five",
                "discountAmount": 50,
                "totalAmount": 55,
                "settlements": [{"eventId": f"staff-pay-{uuid.uuid4()}", "paymentMethod": "cash", "amount": 55}],
            },
        )
        assert staff_override.status_code == 403

        refund = {
            "eventId": f"refund-{uuid.uuid4()}",
            "action": "refund",
            "reason": "Customer returned item",
            "shiftId": shift_id,
            "amount": 10,
            "paymentMethod": "cash",
        }
        refunded = await client.post(
            f"/outlets/{outlet_id}/pos/orders/{order_id}/audit",
            headers=headers,
            json=refund,
        )
        replayed_refund = await client.post(
            f"/outlets/{outlet_id}/pos/orders/{order_id}/audit",
            headers=headers,
            json=refund,
        )
        assert refunded.status_code == 200
        assert replayed_refund.status_code == 200
        pulled = await client.get(f"/outlets/{outlet_id}/orders", headers=headers)
        refunded_order = next(row for row in pulled.json()["data"] if row["id"] == order_id)
        assert refunded_order["status"] == "served"

        report = await client.get(f"/outlets/{outlet_id}/pos/reports", headers=headers)
        assert report.status_code == 200
        assert report.json()["data"]["paymentSplit"]["cash"] == 100
        assert report.json()["data"]["items"][0]["margin"] == 60

        closed = await client.post(
            f"/outlets/{outlet_id}/pos/shifts/{shift_id}/close",
            headers=headers,
            json={"countedCash": 600, "denominations": {"500": 1, "100": 1}},
        )
        assert closed.status_code == 200
        assert closed.json()["data"]["varianceCash"] == 0


@pytest.mark.asyncio(loop_scope="session")
async def test_split_settlement_persists_payers_and_covers_drive_footfall():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id, server_id, headers = await _manager(client)
        item_id = f"menu-{uuid.uuid4()}"
        await client.post(
            f"/outlets/{outlet_id}/menu",
            headers=headers,
            json={"id": item_id, "name": "Rice", "price": 100, "category": "Main"},
        )
        shift_id = f"shift-{uuid.uuid4()}"
        await client.post(
            f"/outlets/{outlet_id}/pos/shifts/open",
            headers=headers,
            json={"id": shift_id, "openingCash": 0, "denominations": {}},
        )

        def _order(order_id: str, table: str, covers: int, line_id: str) -> dict:
            return {
                "id": order_id,
                "source": "desktop_pos",
                "status": "accepted",
                "shiftId": shift_id,
                "totalAmount": 100,
                "subtotal": 100,
                "vatRatePercent": 0,
                "vatAmount": 0,
                "serviceType": "dine_in",
                "tableNo": table,
                "covers": covers,
                "items": [
                    {"id": line_id, "menuItemId": item_id, "name": "Rice", "qty": 1, "price": 100, "lineTotal": 100}
                ],
            }

        # dine-in order with covers → footfall is captured at creation
        order_id = f"order-{uuid.uuid4()}"
        created = await client.post(
            f"/outlets/{outlet_id}/orders", headers=headers, json=_order(order_id, "1", 4, "l1")
        )
        assert created.status_code == 200
        assert created.json()["data"]["covers"] == 4

        # split across two payers → billing snapshot carries the breakdown
        split = await client.post(
            f"/outlets/{outlet_id}/pos/orders/{order_id}/settle",
            headers=headers,
            json={
                "shiftId": shift_id,
                "totalAmount": 100,
                "settlements": [
                    {"eventId": f"p1-{uuid.uuid4()}", "paymentMethod": "cash", "amount": 60, "payerLabel": "Payer 1"},
                    {"eventId": f"p2-{uuid.uuid4()}", "paymentMethod": "bkash", "amount": 40, "payerLabel": "Payer 2"},
                ],
            },
        )
        assert split.status_code == 200
        data = split.json()["data"]
        assert data["paymentMethod"] == "split"
        snapshot = data["billingSnapshot"]
        assert snapshot["isSplit"] is True
        assert len(snapshot["payers"]) == 2
        assert {p["paymentMethod"] for p in snapshot["payers"]} == {"cash", "bkash"}
        assert sum(p["amount"] for p in snapshot["payers"]) == 100

        # footfall flows through to the reports endpoint (only this order served so far)
        report = await client.get(f"/outlets/{outlet_id}/pos/reports", headers=headers)
        assert report.json()["data"]["covers"] == 4
        assert sum(report.json()["data"]["coversByHour"].values()) == 4

        # a single-payment settle is unchanged — no split metadata added
        single_id = f"order-{uuid.uuid4()}"
        await client.post(
            f"/outlets/{outlet_id}/orders", headers=headers, json=_order(single_id, "2", 2, "l2")
        )
        single = await client.post(
            f"/outlets/{outlet_id}/pos/orders/{single_id}/settle",
            headers=headers,
            json={
                "shiftId": shift_id,
                "totalAmount": 100,
                "settlements": [{"eventId": f"s-{uuid.uuid4()}", "paymentMethod": "cash", "amount": 100}],
            },
        )
        assert single.status_code == 200
        single_snapshot = single.json()["data"]["billingSnapshot"]
        assert "payers" not in single_snapshot
        assert single_snapshot.get("isSplit") is not True
        assert single.json()["data"]["paymentMethod"] == "cash"


@pytest.mark.asyncio(loop_scope="session")
async def test_mobile_order_contract_remains_shift_free():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        outlet_id, _, headers = await _manager(client)
        order = await client.post(
            f"/outlets/{outlet_id}/orders",
            headers=headers,
            json={
                "id": f"mobile-{uuid.uuid4()}",
                "source": "manual",
                "status": "accepted",
                "totalAmount": 20,
                "items": [{"name": "Tea", "qty": 1, "price": 20, "lineTotal": 20}],
            },
        )
        assert order.status_code == 200
        assert order.json()["data"]["shiftId"] is None


@pytest.mark.asyncio(loop_scope="session")
async def test_zero_table_outlet_keeps_main_floor_without_fake_table():
    await create_tables()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        suffix = uuid.uuid4()
        server_id = f"zero-table-{suffix}"
        boot = await client.post(
            "/tenants/bootstrap",
            json={
                "serverId": server_id,
                "restaurantName": "Counter Only",
                "tableCount": 0,
            },
        )
        assert boot.status_code == 200
        outlet_id = boot.json()["data"]["outletId"]
        assert boot.json()["data"]["tableCount"] == 0
        async with AsyncSessionLocal() as db:
            outlet = (await db.execute(select(Outlet).where(Outlet.id == outlet_id))).scalar_one()
            phone = f"+88017{suffix.hex[:8]}"
            account = AdminAccount(
                id=str(uuid4()),
                outlet_id=outlet.id,
                email=phone_to_synthetic_email(phone),
                username=phone_to_synthetic_email(phone),
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
        headers = {
            "Authorization": f"Bearer {token}"
        }
        settings = await client.get(
            f"/outlets/{outlet_id}/pos/settings",
            headers=headers,
        )
        assert settings.status_code == 200
        assert settings.json()["data"]["tableCount"] == 0
        assert settings.json()["data"]["floorLayout"][0]["tables"] == []
        saved = await client.patch(
            f"/outlets/{outlet_id}/pos/settings",
            headers=headers,
            json={
                "floorLayout": [
                    {"id": "main", "name": "Main", "tables": []}
                ]
            },
        )
        assert saved.status_code == 200
        assert saved.json()["data"]["tableCount"] == 0
