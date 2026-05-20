from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Request, status
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import create_device_token, get_current_device_payload, hash_password, verify_password
from client_api_base import client_visible_api_base
from config import settings
from database import get_db
from models import AdminAccount, Outlet, Restaurant
from schemas import (
    AdminCreateRequest,
    AdminLoginRequest,
    GoogleAdminAuthRequest,
    StaffInviteRequest,
    StaffUpdateRequest,
    ok,
)

router = APIRouter()

MANAGER = "manager"
STAFF = "staff"


def _clean_email(value: str) -> str:
    return value.strip().lower()


def _normalize_role(value: str | None) -> str:
    role = (value or STAFF).strip().lower()
    if role not in {MANAGER, STAFF}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid account role.")
    return role


def _account_dict(account: AdminAccount) -> dict:
    return {
        "id": account.id,
        "email": account.email,
        "username": account.username,
        "role": account.role or MANAGER,
        "displayName": account.display_name,
        "authProvider": account.auth_provider or "password",
        "isActive": account.is_active,
    }


async def _auth_payload(
    *,
    db: AsyncSession,
    outlet: Outlet,
    account: AdminAccount,
    server_id: str | None = None,
    request: Request | None = None,
) -> dict:
    restaurant = (await db.execute(select(Restaurant).where(Restaurant.id == outlet.restaurant_id))).scalar_one()
    token = create_device_token(outlet.id, account.id)
    return {
        "serverId": server_id or outlet.server_id,
        "restaurantId": restaurant.id,
        "outletId": outlet.id,
        "restaurantName": restaurant.name,
        "outletName": outlet.name,
        "deviceToken": token,
        "account": _account_dict(account),
        "role": account.role or MANAGER,
        "publicApiBaseUrl": client_visible_api_base(request),
    }


async def _current_account(
    payload: dict,
    db: AsyncSession,
    *,
    require_manager: bool = False,
) -> AdminAccount:
    account_id = payload.get("account_id")
    if not account_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account token required.")
    account = (await db.execute(select(AdminAccount).where(AdminAccount.id == account_id))).scalar_one_or_none()
    if account is None or not account.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account is not active.")
    if require_manager and account.role != MANAGER:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Manager access required.")
    return account


def _verify_google_id_token(raw_token: str) -> dict:
    client_ids = [item.strip() for item in settings.GOOGLE_CLIENT_IDS.split(",") if item.strip()]
    if not client_ids:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="GOOGLE_CLIENT_IDS is not configured.",
        )
    last_error: Exception | None = None
    for client_id in client_ids:
        try:
            claims = id_token.verify_oauth2_token(raw_token, google_requests.Request(), client_id)
            email = claims.get("email", "")
            if not email or claims.get("email_verified") is False:
                raise ValueError("Google email is not verified.")
            return claims
        except Exception as error:  # pragma: no cover - depends on Google certs
            last_error = error
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=f"Invalid Google sign-in token. {last_error}",
    )


@router.post("/admin/login")
async def admin_login(
    request: Request,
    body: AdminLoginRequest,
    db: AsyncSession = Depends(get_db),
):
    outlet = (await db.execute(select(Outlet).where(Outlet.server_id == body.serverId))).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Server ID not registered.")

    identity = body.usernameOrEmail.strip()
    email_identity = _clean_email(identity)
    account = (
        await db.execute(
            select(AdminAccount).where(
                (AdminAccount.outlet_id == outlet.id)
                & (
                    (AdminAccount.email == email_identity)
                    | (AdminAccount.username == identity)
                    | (AdminAccount.username == email_identity)
                )
            )
        )
    ).scalar_one_or_none()

    if (
        account is None
        or not account.is_active
        or not account.password_hash
        or not verify_password(body.password, account.password_hash)
    ):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials.")

    return ok(
        await _auth_payload(
            db=db,
            outlet=outlet,
            account=account,
            server_id=body.serverId,
            request=request,
        )
    )


@router.post("/admin/google/start-or-login")
async def google_start_or_login(
    request: Request,
    body: GoogleAdminAuthRequest,
    db: AsyncSession = Depends(get_db),
):
    claims = _verify_google_id_token(body.idToken)
    email = _clean_email(claims["email"])
    google_sub = claims["sub"]
    display_name = claims.get("name") or email.split("@")[0]
    requested_role = _normalize_role(body.role)

    account = (
        await db.execute(
            select(AdminAccount).where(
                (AdminAccount.google_sub == google_sub) | (AdminAccount.email == email)
            )
        )
    ).scalar_one_or_none()

    if account is not None:
        if not account.is_active:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Staff account is disabled.")
        if not account.google_sub:
            account.google_sub = google_sub
        account.display_name = account.display_name or display_name
        account.auth_provider = "google"
        await db.commit()
        await db.refresh(account)
        outlet = (await db.execute(select(Outlet).where(Outlet.id == account.outlet_id))).scalar_one()
        return ok(
            await _auth_payload(
                db=db,
                outlet=outlet,
                account=account,
                server_id=outlet.server_id,
                request=request,
            )
        )

    if requested_role != MANAGER:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Ask the restaurant manager to add your Google email first.",
        )

    restaurant_name = (body.restaurantName or "").strip()
    outlet_name = (body.outletName or "Main Outlet").strip()
    if not restaurant_name:
        # No restaurant name → this is a login attempt for a Google email
        # that has never signed up. Surface a 404 the app can recognize and
        # route the user into the create-restaurant flow instead of failing
        # with a confusing 400.
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="account_not_found:No restaurant account is linked to this Google email. Please sign up to create your restaurant.",
        )

    restaurant = Restaurant(name=restaurant_name)
    db.add(restaurant)
    await db.flush()
    server_id = (body.serverId or str(uuid4())).strip()
    server_taken = (
        await db.execute(select(Outlet).where(Outlet.server_id == server_id))
    ).scalar_one_or_none()
    if server_taken is not None:
        server_id = str(uuid4())

    # Same defensive pattern as /tenants/bootstrap: if the client-supplied
    # outletId already exists (from a wiped install / different tenant),
    # generate a fresh one so we don't violate outlets_pkey.
    requested_outlet_id = (body.outletId or "").strip()
    if requested_outlet_id:
        conflict = (
            await db.execute(select(Outlet).where(Outlet.id == requested_outlet_id))
        ).scalar_one_or_none()
        if conflict is not None:
            requested_outlet_id = ""
    outlet_id_to_use = requested_outlet_id or str(uuid4())

    outlet = Outlet(
        id=outlet_id_to_use,
        restaurant_id=restaurant.id,
        name=outlet_name,
        server_id=server_id,
    )
    db.add(outlet)
    await db.flush()
    account = AdminAccount(
        outlet_id=outlet.id,
        email=email,
        username=email,
        password_hash=None,
        role=MANAGER,
        google_sub=google_sub,
        display_name=display_name,
        auth_provider="google",
        is_active=True,
    )
    db.add(account)
    await db.commit()
    await db.refresh(outlet)
    await db.refresh(account)
    return ok(
        await _auth_payload(
            db=db,
            outlet=outlet,
            account=account,
            server_id=server_id,
            request=request,
        )
    )


@router.post("/admin/create")
async def create_admin(body: AdminCreateRequest, db: AsyncSession = Depends(get_db)):
    outlet = (await db.execute(select(Outlet).where(Outlet.id == body.outletId))).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Outlet not found.")

    email = _clean_email(body.email)
    username = body.username.strip() or email
    role = _normalize_role(body.role)
    existing = (
        await db.execute(
            select(AdminAccount).where(
                (AdminAccount.email == email) | (AdminAccount.username == username)
            )
        )
    ).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email or username already in use.")

    account = AdminAccount(
        outlet_id=body.outletId,
        email=email,
        username=username,
        password_hash=hash_password(body.password) if body.password else None,
        role=role,
        google_sub=body.googleSub,
        display_name=body.displayName,
        auth_provider="google" if body.googleSub else "password",
        is_active=True,
    )
    db.add(account)
    await db.commit()
    await db.refresh(account)
    return ok({"created": True, "account": _account_dict(account)})


@router.get("/admin/me")
async def admin_me(
    request: Request,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    account = await _current_account(payload, db)
    outlet = (await db.execute(select(Outlet).where(Outlet.id == account.outlet_id))).scalar_one()
    return ok(
        await _auth_payload(
            db=db,
            outlet=outlet,
            account=account,
            server_id=outlet.server_id,
            request=request,
        )
    )


@router.get("/admin/staff")
async def list_staff(
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    manager = await _current_account(payload, db, require_manager=True)
    rows = (
        await db.execute(
            select(AdminAccount)
            .where((AdminAccount.outlet_id == manager.outlet_id) & (AdminAccount.role == STAFF))
            .order_by(AdminAccount.created_at.desc())
        )
    ).scalars().all()
    return ok([_account_dict(account) for account in rows])


@router.post("/admin/staff")
async def add_staff(
    body: StaffInviteRequest,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    manager = await _current_account(payload, db, require_manager=True)
    email = _clean_email(body.email)
    existing = (await db.execute(select(AdminAccount).where(AdminAccount.email == email))).scalar_one_or_none()
    if existing:
        if existing.outlet_id != manager.outlet_id:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email is already used by another outlet.")
        existing.role = STAFF
        existing.display_name = body.displayName or existing.display_name
        existing.is_active = True
        await db.commit()
        await db.refresh(existing)
        return ok({"account": _account_dict(existing)})

    account = AdminAccount(
        outlet_id=manager.outlet_id,
        email=email,
        username=email,
        password_hash=None,
        role=STAFF,
        display_name=body.displayName,
        auth_provider="google",
        is_active=True,
    )
    db.add(account)
    await db.commit()
    await db.refresh(account)
    return ok({"account": _account_dict(account)})


@router.patch("/admin/staff/{account_id}")
async def update_staff(
    account_id: str,
    body: StaffUpdateRequest,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    manager = await _current_account(payload, db, require_manager=True)
    account = (
        await db.execute(
            select(AdminAccount).where(
                (AdminAccount.id == account_id)
                & (AdminAccount.outlet_id == manager.outlet_id)
                & (AdminAccount.role == STAFF)
            )
        )
    ).scalar_one_or_none()
    if account is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Staff account not found.")
    if body.isActive is not None:
        account.is_active = body.isActive
    if body.displayName is not None:
        account.display_name = body.displayName
    await db.commit()
    await db.refresh(account)
    return ok({"account": _account_dict(account)})
