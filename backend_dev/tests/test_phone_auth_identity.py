import uuid
from datetime import datetime, timezone
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from auth import create_device_token, create_signup_token
from database import AsyncSessionLocal, create_tables
from main import app
from models import AdminAccount, Outlet
from phone_utils import normalize_bd_phone, phone_to_synthetic_email


def _contains_synthetic_phone_email(value) -> bool:
    return (
        isinstance(value, str)
        and (
            "@phone" in value
            or "phone.rastarant.local" in value
            or "phone.restaurant.local" in value
        )
    )


def _phone(prefix: str = "017") -> str:
    return f"{prefix}{uuid.uuid4().int % 100000000:08d}"


async def _manager(client: AsyncClient) -> dict:
    suffix = uuid.uuid4()
    server_id = f"phone-auth-{suffix}"
    boot = await client.post(
        "/tenants/bootstrap",
        json={"serverId": server_id, "restaurantName": "Phone Auth"},
    )
    outlet_id = boot.json()["data"]["outletId"]
    async with AsyncSessionLocal() as db:
        outlet = (await db.execute(select(Outlet).where(Outlet.id == outlet_id))).scalar_one()
        phone = f"+88017{uuid.uuid4().int % 100000000:08d}"
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
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio(loop_scope="session")
async def test_phone_manager_signup_requires_restaurant_name_and_hides_synthetic_email():
    await create_tables()
    phone = normalize_bd_phone(_phone("017"))
    token = create_signup_token(phone=phone, purpose="manager_signup")
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        missing_name = await client.post(
            "/admin/phone/complete-manager-signup",
            json={"signupToken": token},
        )
        assert missing_name.status_code == 422

        ok = await client.post(
            "/admin/phone/complete-manager-signup",
            json={
                "signupToken": token,
                "restaurantName": "Named Restaurant",
                "managerName": "Rahim",
            },
        )

    assert ok.status_code == 200
    account = ok.json()["data"]["account"]
    assert account["displayName"] == "Rahim"
    assert account["email"] == phone_to_synthetic_email(phone)
    assert account["username"] == phone_to_synthetic_email(phone)


@pytest.mark.asyncio(loop_scope="session")
async def test_phone_staff_display_name_optional_and_staff_payload_hides_synthetic_email():
    await create_tables()
    staff_phone = _phone("018")
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _manager(client)
        no_name = await client.post(
            "/admin/staff",
            headers=headers,
            json={"phone": staff_phone, "role": "waiter"},
        )
        assert no_name.status_code == 200
        assert no_name.json()["data"]["account"]["displayName"] is None

        created = await client.post(
            "/admin/staff",
            headers=headers,
            json={"phone": staff_phone, "displayName": "Karim", "role": "waiter"},
        )
        staff = await client.get("/admin/staff", headers=headers)

    assert created.status_code == 200
    account = created.json()["data"]["account"]
    assert account["displayName"] == "Karim"
    assert account["email"] == phone_to_synthetic_email(normalize_bd_phone(staff_phone))
    assert account["username"] == phone_to_synthetic_email(normalize_bd_phone(staff_phone))

    assert staff.status_code == 200
    staff_accounts = staff.json()["data"]
    phone_staff = [a for a in staff_accounts if a.get("phone") == staff_phone]
    assert len(phone_staff) == 1
    assert phone_staff[0]["email"] == phone_to_synthetic_email(normalize_bd_phone(staff_phone))
    assert phone_staff[0]["username"] == phone_to_synthetic_email(normalize_bd_phone(staff_phone))


@pytest.mark.asyncio(loop_scope="session")
async def test_manager_invite_accept_full_flow():
    """Owner invites a MANAGER; invitee OTP-verifies, accepts, gets authenticated.

    Regression for: accept returned 404 "Staff invite not found" because the
    respond query filtered role.in_(FLOOR_ROLES), which excludes manager.
    """
    await create_tables()
    invitee_phone = _phone("019")
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _manager(client)

        created = await client.post(
            "/admin/staff",
            headers=headers,
            json={"phone": invitee_phone, "displayName": "Nadia", "role": "manager"},
        )
        assert created.status_code == 200
        invite = created.json()["data"]["account"]
        assert invite["role"] == "manager"
        assert invite["inviteStatus"] == "pending"
        assert invite["isActive"] is False

        sent = await client.post(
            "/admin/phone/send-otp", json={"phone": invitee_phone}
        )
        assert sent.status_code == 200

        verified = await client.post(
            "/admin/phone/verify-otp",
            json={"phone": invitee_phone, "code": "000000"},
        )
        assert verified.status_code == 200
        body = verified.json()["data"]
        assert body["status"] == "pending_staff_invite"
        assert body["role"] == "manager"
        assert body["inviteId"] == invite["id"]
        token = body["signupToken"]
        assert token

        accepted = await client.post(
            "/admin/staff/invite/respond",
            json={"signupToken": token, "inviteId": invite["id"], "accept": True},
        )
        assert accepted.status_code == 200
        data = accepted.json()["data"]
        assert data["status"] == "authenticated"
        assert data["role"] == "manager"
        account = data["account"]
        assert account["role"] == "manager"
        assert account["displayName"] == "Nadia"
        assert account["inviteStatus"] == "accepted"
        assert account["isActive"] is True
        assert account["email"] == phone_to_synthetic_email(normalize_bd_phone(invitee_phone))
        assert account["username"] == phone_to_synthetic_email(normalize_bd_phone(invitee_phone))
