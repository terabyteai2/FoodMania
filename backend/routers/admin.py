import re
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import (
    create_device_token,
    create_signup_token,
    decode_signup_token,
    get_current_device_payload,
)
from phone_utils import (
    INVITE_ACCEPTED,
    INVITE_DECLINED,
    INVITE_PENDING,
    display_phone,
    normalize_bd_phone,
    phone_to_synthetic_email,
)
from services import phone_otp
from client_api_base import client_visible_api_base
from config import settings
from database import get_db
import storage
from models import (
    AdminAccount,
    BkashSession,
    ChatbotConversation,
    ChatbotIntegration,
    DailyStockCount,
    Device,
    InventoryItem,
    InventorySupplier,
    MenuItem,
    Order,
    Outlet,
    OutletSubscription,
    Restaurant,
    StockAdjustment,
    UddoktaPaySession,
)
from schemas import (
    DisplayNameUpdateRequest,
    OnboardingPlanRequest,
    OutletProfileUpdateRequest,
    OutletWipeRequest,
    PhoneCompleteManagerSignupRequest,
    PhoneSendOtpRequest,
    PhoneVerifyOtpRequest,
    PublicSlugUpdateRequest,
    StaffInviteRequest,
    StaffInviteRespondRequest,
    StaffUpdateRequest,
    ok,
)
from subscription_service import (
    get_or_create_subscription,
    grant_outlet_access,
    register_onboarding_plan,
    resolve_subscription_access_for_outlet,
    subscription_access_dict,
    subscription_to_dict,
)
from services.app_update import get_app_update

router = APIRouter()

OWNER = "owner"
MANAGER = "manager"
WAITER = "waiter"
STAFF = "staff"  # legacy alias for waiter (floor role)
# Elevated roles — the "manager access" gate (owner is a superset of manager).
MANAGEMENT_ROLES = (OWNER, MANAGER)
# Floor roles (waiter; staff retained so legacy rows still match).
FLOOR_ROLES = (WAITER, STAFF)
RESERVED_PUBLIC_SLUGS = {
    "admin",
    "api",
    "app",
    "assets",
    "customer",
    "docs",
    "health",
    "menu",
    "platform",
    "pos",
    "static",
    "uploads",
    "www",
}
def _normalize_role(value: str | None) -> str:
    role = (value or WAITER).strip().lower()
    if role == STAFF:
        role = WAITER  # legacy alias
    if role not in {OWNER, MANAGER, WAITER}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid account role.")
    return role


def _account_dict(account: AdminAccount) -> dict:
    return {
        "id": account.id,
        "email": account.email,
        "username": account.username,
        "phone": display_phone(account.phone),
        "role": account.role or MANAGER,
        "displayName": account.display_name,
        "invitedByName": account.invited_by_name,
        "authProvider": account.auth_provider or "phone",
        "isActive": account.is_active,
        "inviteStatus": account.invite_status,
    }


def _parse_phone_param(raw: str) -> str:
    try:
        return normalize_bd_phone(raw)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error


def _normalize_public_slug(value: str) -> str:
    slug = value.strip().lower()
    slug = re.sub(r"[^a-z0-9-]+", "-", slug)
    slug = re.sub(r"-+", "-", slug).strip("-")
    if len(slug) < 3:
        raise HTTPException(status_code=422, detail="URL name must be at least 3 characters.")
    if len(slug) > 63:
        raise HTTPException(status_code=422, detail="URL name must be 63 characters or less.")
    if slug in RESERVED_PUBLIC_SLUGS:
        raise HTTPException(status_code=422, detail="That URL name is reserved.")
    if not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])?", slug):
        raise HTTPException(status_code=422, detail="Use letters, numbers, and hyphens only.")
    return slug


def _public_menu_url(slug: str | None) -> str | None:
    clean = (slug or "").strip().lower()
    if not clean:
        return None
    return f"https://{clean}.quickbytes.buzz"


def _media_urls_for_wipe(outlet: Outlet, menu_items: list[MenuItem]) -> list[str]:
    urls: list[str] = []
    for value in [outlet.banner_url, outlet.logo_url, outlet.logo_bitmap_url, outlet.video_url]:
        if value:
            urls.append(value)
    for value in outlet.gallery_images or []:
        if isinstance(value, str) and value:
            urls.append(value)
    for item in menu_items:
        if item.image_url:
            if "/uploads/menu_placeholders/" not in item.image_url:
                urls.append(item.image_url)
        if item.video_url:
            urls.append(item.video_url)
    return list(dict.fromkeys(urls))


def _delete_media_for_outlet(outlet_id: str, urls: list[str]) -> dict[str, int]:
    deleted_urls = 0
    deleted_keys = 0
    for url in urls:
        storage.delete_by_url(url)
        deleted_urls += 1
    for prefix in (
        f"hero_media/{outlet_id}/images",
        f"hero_media/{outlet_id}/logo",
        f"hero_media/{outlet_id}/video",
    ):
        for key in storage.list_keys(prefix):
            storage.delete_key(key)
            deleted_keys += 1
    return {"mediaUrls": deleted_urls, "mediaKeys": deleted_keys}


async def _accounts_by_phone(db: AsyncSession, phone: str) -> list[AdminAccount]:
    rows = (await db.execute(select(AdminAccount).where(AdminAccount.phone == phone))).scalars().all()
    return list(rows)


async def _auth_payload(
    *,
    db: AsyncSession,
    outlet: Outlet,
    account: AdminAccount,
    server_id: str | None = None,
    request: Request | None = None,
) -> dict:
    restaurant = (await db.execute(select(Restaurant).where(Restaurant.id == outlet.restaurant_id))).scalar_one()
    sub = (
        await db.execute(
            select(OutletSubscription).where(OutletSubscription.outlet_id == outlet.id)
        )
    ).scalar_one_or_none()
    token = create_device_token(outlet.id, account.id)
    return {
        "serverId": server_id or outlet.server_id,
        "restaurantId": restaurant.id,
        "outletId": outlet.id,
        "restaurantName": restaurant.name,
        "outletName": outlet.name,
        "outletPhone": outlet.phone,
        "publicSlug": outlet.public_slug,
        "customerMenuUrl": _public_menu_url(outlet.public_slug),
        "tableCount": outlet.table_count if outlet.table_count is not None else 10,
        "deviceToken": token,
        "account": _account_dict(account),
        "role": account.role or MANAGER,
        "publicApiBaseUrl": client_visible_api_base(request),
        "logoUrl": outlet.logo_url,
        "logoBitmapUrl": outlet.logo_bitmap_url,
        **subscription_access_dict(sub),
    }


@router.post("/admin/subscription/onboarding")
async def admin_register_onboarding_plan(
    body: OnboardingPlanRequest,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    """Record plan choice from the app so platform admin can activate the outlet."""
    outlet_id = payload.get("sub") or payload.get("outlet_id")
    if not outlet_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token.")
    sub = await register_onboarding_plan(db, outlet_id, plan=body.plan, package=body.package)
    await db.commit()
    await db.refresh(sub)
    return ok(
        {
            **subscription_access_dict(sub),
            **subscription_to_dict(sub),
        }
    )


@router.get("/admin/access")
async def admin_app_access(
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    """Outlet subscription access — used by the admin app to unlock after platform payment approval."""
    outlet_id = payload.get("sub") or payload.get("outlet_id")
    if not outlet_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token.")
    return ok(await resolve_subscription_access_for_outlet(db, outlet_id))


@router.post("/admin/subscription/addon")
async def admin_request_addon(
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    """Stub — platform admin will implement addon purchase logic later."""
    outlet_id = payload.get("sub") or payload.get("outlet_id")
    if not outlet_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token.")
    return ok({"message": "Addon purchase endpoint — not yet implemented."})


@router.get("/admin/app-update")
async def admin_app_update(
    app: str = Query("admin"),
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    _ = payload
    return ok(await get_app_update(db, app=app))


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
    if require_manager and account.role not in MANAGEMENT_ROLES:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Manager access required.")
    return account


@router.post("/admin/phone/send-otp")
async def phone_send_otp(body: PhoneSendOtpRequest):
    phone = _parse_phone_param(body.phone)
    await phone_otp.send_verification(phone, app_signature=body.appSignature)
    mode = phone_otp.phone_otp_mode()
    sms_sent = mode == "onecodesoft"
    payload: dict = {
        "sent": True,
        "smsSent": sms_sent,
        "phoneOtpMode": mode,
        "phone": display_phone(phone),
    }
    if mode in {"dev_fallback", "dev_bypass"}:
        payload["message"] = (
            "SMS was not sent (dev mode). Enter the test code shown in the app."
        )
        payload["devOtpCode"] = phone_otp.dev_otp_bypass_code()
    else:
        payload["message"] = "Verification code sent by SMS."
    return ok(payload)


@router.post("/admin/phone/verify-otp")
async def phone_verify_otp(
    request: Request,
    body: PhoneVerifyOtpRequest,
    db: AsyncSession = Depends(get_db),
):
    phone = _parse_phone_param(body.phone)
    await phone_otp.check_verification(phone, body.code)
    verified_at = datetime.now(timezone.utc)
    accounts = await _accounts_by_phone(db, phone)

    def _can_login(account: AdminAccount) -> bool:
        if not account.is_active:
            return False
        if account.role in MANAGEMENT_ROLES:
            return True
        return account.invite_status in {None, INVITE_ACCEPTED}

    login_candidates = [a for a in accounts if _can_login(a)]
    if login_candidates:
        login_candidates.sort(key=lambda a: a.created_at, reverse=True)
        account = login_candidates[0]
        account.phone_verified_at = verified_at
        await db.commit()
        await db.refresh(account)
        outlet = (
            await db.execute(select(Outlet).where(Outlet.id == account.outlet_id))
        ).scalar_one()
        auth_data = await _auth_payload(
            db=db,
            outlet=outlet,
            account=account,
            server_id=outlet.server_id,
            request=request,
        )
        return ok({"status": "authenticated", **auth_data})

    pending_staff = [
        a
        for a in accounts
        if a.role in {MANAGER, *FLOOR_ROLES} and a.invite_status == INVITE_PENDING
    ]
    if pending_staff:
        pending_staff.sort(key=lambda a: a.created_at, reverse=True)
        invite = pending_staff[0]
        outlet = (
            await db.execute(select(Outlet).where(Outlet.id == invite.outlet_id))
        ).scalar_one()
        restaurant = (
            await db.execute(select(Restaurant).where(Restaurant.id == outlet.restaurant_id))
        ).scalar_one()
        token = create_signup_token(
            phone=phone,
            purpose="staff_invite",
            invite_id=invite.id,
        )
        return ok(
            {
                "status": "pending_staff_invite",
                "inviteId": invite.id,
                "restaurantName": restaurant.name,
                "outletName": outlet.name,
                "role": invite.role,
                "invitedBy": invite.invited_by_name,
                "signupToken": token,
                "phone": display_phone(phone),
            }
        )

    if not accounts:
        token = create_signup_token(phone=phone, purpose="manager_signup")
        return ok(
            {
                "status": "needs_restaurant_setup",
                "signupToken": token,
                "phone": display_phone(phone),
            }
        )

    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="not_registered:This phone is not registered. Ask your manager to add you as staff.",
    )


@router.post("/admin/phone/complete-manager-signup")
async def phone_complete_manager_signup(
    request: Request,
    body: PhoneCompleteManagerSignupRequest,
    db: AsyncSession = Depends(get_db),
):
    claims = decode_signup_token(body.signupToken, expected_purpose="manager_signup")
    phone = claims["phone"]
    existing = await _accounts_by_phone(db, phone)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account already exists for this phone.",
        )

    restaurant_name = (body.restaurantName or "").strip()
    if not restaurant_name:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Restaurant name is required.")

    outlet_name = (body.outletName or restaurant_name).strip() or restaurant_name
    restaurant = Restaurant(name=restaurant_name)
    db.add(restaurant)
    await db.flush()

    server_id = (body.serverId or str(uuid4())).strip()
    server_taken = (
        await db.execute(select(Outlet).where(Outlet.server_id == server_id))
    ).scalar_one_or_none()
    if server_taken is not None:
        server_id = str(uuid4())

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
        table_count=body.tableCount if body.tableCount is not None else 10,
    )
    db.add(outlet)
    await db.flush()

    synthetic_email = phone_to_synthetic_email(phone)
    account = AdminAccount(
        outlet_id=outlet.id,
        email=synthetic_email,
        username=synthetic_email,
        password_hash=None,
        role=OWNER,
        phone=phone,
        phone_verified_at=datetime.now(timezone.utc),
        display_name=(body.managerName or "").strip() or None,
        auth_provider="phone",
        is_active=True,
        invite_status=None,
    )
    db.add(account)
    await db.flush()
    await get_or_create_subscription(db, outlet.id)
    await db.commit()
    await db.refresh(outlet)
    await db.refresh(account)
    payload = await _auth_payload(
        db=db,
        outlet=outlet,
        account=account,
        server_id=server_id,
        request=request,
    )
    return ok({"status": "authenticated", **payload})


@router.post("/admin/staff/invite/respond")
async def staff_invite_respond(
    request: Request,
    body: StaffInviteRespondRequest,
    db: AsyncSession = Depends(get_db),
):
    claims = decode_signup_token(body.signupToken, expected_purpose="staff_invite")
    phone = claims["phone"]
    invite_id = claims.get("invite_id") or body.inviteId
    if invite_id != body.inviteId:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invite mismatch.")

    account = (
        await db.execute(
            select(AdminAccount).where(
                (AdminAccount.id == body.inviteId)
                & (AdminAccount.phone == phone)
                & (AdminAccount.role.in_(FLOOR_ROLES))
            )
        )
    ).scalar_one_or_none()
    if account is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Staff invite not found.")
    if account.invite_status != INVITE_PENDING:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invite is no longer pending.")

    if not body.accept:
        account.invite_status = INVITE_DECLINED
        account.is_active = False
        await db.commit()
        return ok({"status": "declined", "inviteId": account.id})

    account.invite_status = INVITE_ACCEPTED
    account.is_active = True
    account.phone_verified_at = datetime.now(timezone.utc)
    account.auth_provider = "phone"
    await db.commit()
    await db.refresh(account)
    outlet = (await db.execute(select(Outlet).where(Outlet.id == account.outlet_id))).scalar_one()
    payload = await _auth_payload(
        db=db,
        outlet=outlet,
        account=account,
        server_id=outlet.server_id,
        request=request,
    )
    return ok({"status": "authenticated", **payload})


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


@router.patch("/admin/public-url")
async def update_public_url(
    body: PublicSlugUpdateRequest,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    manager = await _current_account(payload, db, require_manager=True)
    outlet = (
        await db.execute(select(Outlet).where(Outlet.id == manager.outlet_id))
    ).scalar_one()
    slug = _normalize_public_slug(body.publicSlug)
    existing = (
        await db.execute(
            select(Outlet).where(
                (
                    (Outlet.public_slug == slug)
                    | (Outlet.server_id == slug)
                )
                & (Outlet.id != outlet.id)
            )
        )
    ).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="That URL is already taken. Try adding a number.",
        )
    outlet.public_slug = slug
    await db.commit()
    return ok({"publicSlug": slug, "customerMenuUrl": _public_menu_url(slug)})


@router.patch("/admin/outlet-profile")
async def update_outlet_profile(
    body: OutletProfileUpdateRequest,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    manager = await _current_account(payload, db, require_manager=True)
    outlet = (
        await db.execute(select(Outlet).where(Outlet.id == manager.outlet_id))
    ).scalar_one()
    restaurant = (
        await db.execute(select(Restaurant).where(Restaurant.id == outlet.restaurant_id))
    ).scalar_one()
    if body.restaurantName is not None:
        name = body.restaurantName.strip()
        if not name:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Restaurant name can't be empty.",
            )
        restaurant.name = name
    if body.phone is not None:
        # Plain trim only: this is a customer-facing contact number, not the OTP-
        # validated/unique AdminAccount.phone, so it doesn't go through normalize_bd_phone.
        outlet.phone = body.phone.strip() or None
    await db.commit()
    return ok({"restaurantName": restaurant.name, "outletPhone": outlet.phone})


@router.patch("/admin/me")
async def update_my_account(
    body: DisplayNameUpdateRequest,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    # Self-edit only — touches the caller's own row, so it deliberately doesn't run
    # the owner/manager-editing-*other*-accounts checks in update_staff below.
    account = await _current_account(payload, db)
    account.display_name = body.displayName.strip() or None
    await db.commit()
    await db.refresh(account)
    return ok({"account": _account_dict(account)})


@router.post("/admin/outlets/{outlet_id}/wipe")
async def wipe_outlet_data(
    outlet_id: str,
    body: OutletWipeRequest,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    manager = await _current_account(payload, db, require_manager=True)
    token_outlet_id = str(payload.get("sub") or payload.get("outlet_id") or "")
    if token_outlet_id != outlet_id or manager.outlet_id != outlet_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Outlet access required.",
        )
    if body.confirmation.strip() != outlet_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type the outlet ID exactly to wipe this restaurant.",
        )

    outlet = (
        await db.execute(select(Outlet).where(Outlet.id == outlet_id))
    ).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Outlet not found.",
        )

    restaurant_id = outlet.restaurant_id
    server_id = outlet.server_id
    menu_items = (
        await db.execute(select(MenuItem).where(MenuItem.outlet_id == outlet_id))
    ).scalars().all()
    media_counts = _delete_media_for_outlet(
        outlet_id,
        _media_urls_for_wipe(outlet, list(menu_items)),
    )

    async def delete_rows(model, *conditions) -> int:
        result = await db.execute(delete(model).where(*conditions))
        return max(result.rowcount or 0, 0)

    deleted: dict[str, int] = {
        **media_counts,
        "stockAdjustments": await delete_rows(
            StockAdjustment,
            StockAdjustment.outlet_id == outlet_id,
        ),
        "dailyStockCounts": await delete_rows(
            DailyStockCount,
            DailyStockCount.outlet_id == outlet_id,
        ),
        "inventoryItems": await delete_rows(
            InventoryItem,
            InventoryItem.outlet_id == outlet_id,
        ),
        "inventorySuppliers": await delete_rows(
            InventorySupplier,
            InventorySupplier.outlet_id == outlet_id,
        ),
        "orders": await delete_rows(Order, Order.outlet_id == outlet_id),
        "menuItems": await delete_rows(MenuItem, MenuItem.outlet_id == outlet_id),
        "devices": await delete_rows(Device, Device.outlet_id == outlet_id),
        "chatbotConversations": await delete_rows(
            ChatbotConversation,
            ChatbotConversation.integration_id.in_(
                select(ChatbotIntegration.id).where(ChatbotIntegration.outlet_id == outlet_id)
            ),
        ),
        "chatbotIntegrations": await delete_rows(
            ChatbotIntegration,
            ChatbotIntegration.outlet_id == outlet_id,
        ),
        "subscriptions": await delete_rows(
            OutletSubscription,
            OutletSubscription.outlet_id == outlet_id,
        ),
        "adminAccounts": await delete_rows(
            AdminAccount,
            AdminAccount.outlet_id == outlet_id,
        ),
        "uddoktaPaySessions": await delete_rows(
            UddoktaPaySession,
            (UddoktaPaySession.outlet_id == outlet_id)
            | (UddoktaPaySession.server_id == server_id),
        ),
        "bkashSessions": await delete_rows(
            BkashSession,
            BkashSession.server_id == server_id,
        ),
    }

    remaining_outlets = (
        await db.execute(
            select(func.count())
            .select_from(Outlet)
            .where(Outlet.restaurant_id == restaurant_id, Outlet.id != outlet_id)
        )
    ).scalar() or 0
    deleted["outlets"] = await delete_rows(Outlet, Outlet.id == outlet_id)
    restaurant_deleted = False
    if remaining_outlets == 0:
        deleted["restaurants"] = await delete_rows(
            Restaurant,
            Restaurant.id == restaurant_id,
        )
        restaurant_deleted = bool(deleted["restaurants"])
    else:
        deleted["restaurants"] = 0

    await db.commit()
    return ok(
        {
            "outletId": outlet_id,
            "restaurantId": restaurant_id,
            "restaurantDeleted": restaurant_deleted,
            "deleted": deleted,
        }
    )


@router.get("/admin/staff")
async def list_staff(
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    manager = await _current_account(payload, db, require_manager=True)
    # Show managers + floor staff (role badges), excluding owner accounts.
    rows = (
        await db.execute(
            select(AdminAccount)
            .where(
                (AdminAccount.outlet_id == manager.outlet_id)
                & (AdminAccount.role.in_((MANAGER, *FLOOR_ROLES)))
            )
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

    # Role-gated invites (spec §4.10): owner may invite a waiter or a manager;
    # a manager may invite waiters only. A manager seat is owner-only and may be
    # granted only when no active manager already exists.
    requested_role = _normalize_role(body.role)
    if requested_role == OWNER:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Owners cannot be invited."
        )
    if requested_role == MANAGER:
        if manager.role != OWNER:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only an owner can invite a manager.",
            )
        active_manager = (
            await db.execute(
                select(AdminAccount).where(
                    (AdminAccount.outlet_id == manager.outlet_id)
                    & (AdminAccount.role == MANAGER)
                    & (AdminAccount.is_active.is_(True))
                )
            )
        ).scalar_one_or_none()
        if active_manager is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="An active manager already exists.",
            )

    phone = _parse_phone_param(body.phone)
    synthetic_email = phone_to_synthetic_email(phone)
    existing = (
        await db.execute(select(AdminAccount).where(AdminAccount.phone == phone))
    ).scalar_one_or_none()
    if existing:
        if existing.outlet_id != manager.outlet_id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Phone is already used by another outlet.",
            )
        existing.role = requested_role
        existing.display_name = body.displayName or existing.display_name
        existing.invited_by_name = manager.display_name
        existing.invite_status = INVITE_PENDING
        existing.is_active = False
        existing.auth_provider = "phone"
        existing.email = synthetic_email
        existing.username = synthetic_email
        await db.commit()
        await db.refresh(existing)
        return ok({"account": _account_dict(existing)})

    account = AdminAccount(
        outlet_id=manager.outlet_id,
        email=synthetic_email,
        username=synthetic_email,
        password_hash=None,
        role=requested_role,
        phone=phone,
        display_name=body.displayName,
        invited_by_name=manager.display_name,
        auth_provider="phone",
        is_active=False,
        invite_status=INVITE_PENDING,
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
                & (AdminAccount.role.in_((MANAGER, *FLOOR_ROLES)))
            )
        )
    ).scalar_one_or_none()
    if account is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Staff account not found.")
    # Only an owner may toggle/edit a manager seat.
    if account.role == MANAGER and manager.role != OWNER:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only an owner can manage a manager.",
        )
    if body.isActive is not None:
        account.is_active = body.isActive
    if body.displayName is not None:
        account.display_name = body.displayName
    await db.commit()
    await db.refresh(account)
    return ok({"account": _account_dict(account)})
