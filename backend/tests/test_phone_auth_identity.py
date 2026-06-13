import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from auth import create_signup_token
from database import create_tables
from main import app
from phone_utils import normalize_bd_phone


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
    email = f"phone-auth-{suffix}@example.com"
    await client.post(
        "/admin/create",
        json={
            "outletId": outlet_id,
            "email": email,
            "username": email,
            "password": "password",
            "role": "manager",
            "displayName": "Manager",
        },
    )
    login = await client.post(
        "/admin/login",
        json={
            "serverId": server_id,
            "usernameOrEmail": email,
            "password": "password",
        },
    )
    return {"Authorization": f"Bearer {login.json()['data']['deviceToken']}"}


@pytest.mark.asyncio(loop_scope="session")
async def test_phone_manager_signup_requires_manager_name_and_hides_synthetic_email():
    await create_tables()
    phone = normalize_bd_phone(_phone("017"))
    token = create_signup_token(phone=phone, purpose="manager_signup")
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        missing_name = await client.post(
            "/admin/phone/complete-manager-signup",
            json={"signupToken": token, "restaurantName": "No Name"},
        )
        assert missing_name.status_code == 400

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
    assert account["email"] is None
    assert account["username"] is None
    assert not any(_contains_synthetic_phone_email(v) for v in account.values())


@pytest.mark.asyncio(loop_scope="session")
async def test_phone_staff_requires_name_and_staff_payload_hides_synthetic_email():
    await create_tables()
    staff_phone = _phone("018")
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _manager(client)
        missing_name = await client.post(
            "/admin/staff",
            headers=headers,
            json={"phone": staff_phone, "role": "waiter"},
        )
        assert missing_name.status_code == 400

        created = await client.post(
            "/admin/staff",
            headers=headers,
            json={"phone": staff_phone, "displayName": "Karim", "role": "waiter"},
        )
        staff = await client.get("/admin/staff", headers=headers)

    assert created.status_code == 200
    account = created.json()["data"]["account"]
    assert account["displayName"] == "Karim"
    assert account["email"] is None
    assert account["username"] is None
    assert not any(_contains_synthetic_phone_email(v) for v in account.values())

    assert staff.status_code == 200
    staff_accounts = staff.json()["data"]
    phone_staff = [a for a in staff_accounts if a.get("phone") == staff_phone]
    assert len(phone_staff) == 1
    assert phone_staff[0]["email"] is None
    assert phone_staff[0]["username"] is None
    assert not any(_contains_synthetic_phone_email(v) for v in phone_staff[0].values())
