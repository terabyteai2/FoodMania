import re
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Request, status
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token
import requests as http_requests
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import (
    create_device_token,
    create_signup_token,
    decode_signup_token,
    get_current_device_payload,
    hash_password,
    verify_password,
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
    DailyStockCount,
    Device,
    InventoryItem,
    MenuItem,
    Order,
    Outlet,
    OutletSubscription,
    Restaurant,
    StockAdjustment,
    UddoktaPaySession,
)
from schemas import (
    AdminCreateRequest,
    AdminLoginRequest,
    GoogleAdminAuthRequest,
    OnboardingPlanRequest,
    OutletWipeRequest,
    PhoneCompleteManagerSignupRequest,
    PhoneSendOtpRequest,
    PhoneVerifyOtpRequest,
    PublicSlugUpdateRequest,
    StaffDevBypassLoginRequest,
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

MANAGER = "manager"
STAFF = "staff"
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
GOOGLE_VERIFY_TIMEOUT_SECONDS = 5.0
_google_verify_transport = google_requests.Request(session=http_requests.Session())


class _GoogleVerifyRequestWithTimeout:
    """Inject a short timeout so Google verify does not hang client requests."""

    def __call__(self, *args, **kwargs):
        # google-auth passes its own default timeout (120s); force ours.
        kwargs["timeout"] = GOOGLE_VERIFY_TIMEOUT_SECONDS
        return _google_verify_transport(*args, **kwargs)


_google_verify_request = _GoogleVerifyRequestWithTimeout()

DEMO_PHONE = "+8801700000000"


def _demo_manager_login_enabled() -> bool:
    explicit = settings.DEMO_MANAGER_LOGIN_ENABLED.strip().lower()
    if explicit in ("1", "true", "yes", "on"):
        return True
    if explicit in ("0", "false", "no", "off"):
        return False
    return settings.APP_ENV.strip().lower() == "development"


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
        "phone": display_phone(account.phone),
        "role": account.role or MANAGER,
        "displayName": account.display_name,
        "authProvider": account.auth_provider or "password",
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
    for value in [outlet.banner_url, outlet.video_url]:
        if value:
            urls.append(value)
    for value in outlet.gallery_images or []:
        if isinstance(value, str) and value:
            urls.append(value)
    for item in menu_items:
        if item.image_url:
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
    for prefix in (f"hero_media/{outlet_id}/images", f"hero_media/{outlet_id}/video"):
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
        "publicSlug": outlet.public_slug,
        "customerMenuUrl": _public_menu_url(outlet.public_slug),
        "tableCount": outlet.table_count or 10,
        "deviceToken": token,
        "account": _account_dict(account),
        "role": account.role or MANAGER,
        "publicApiBaseUrl": client_visible_api_base(request),
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
    sub = await register_onboarding_plan(db, outlet_id, plan=body.plan)
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


@router.get("/admin/app-update")
async def admin_app_update(
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    _ = payload
    return ok(await get_app_update(db))


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
            claims = id_token.verify_oauth2_token(raw_token, _google_verify_request, client_id)
            email = claims.get("email", "")
            if not email or claims.get("email_verified") is False:
                raise ValueError("Google email is not verified.")
            return claims
        except http_requests.exceptions.Timeout:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=(
                    "google_verify_timeout:Timed out while contacting Google auth "
                    "verification service. Please try again."
                ),
            )
        except http_requests.exceptions.RequestException as error:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=(
                    "google_verify_unreachable:Google auth verification service is "
                    f"currently unreachable. {error}"
                ),
            )
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


@router.post("/admin/demo/manager-login")
async def demo_manager_login(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """One-tap demo manager session without Twilio. Enabled in development by default."""
    if not _demo_manager_login_enabled():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    server_id = settings.DEMO_MANAGER_SERVER_ID.strip() or "DEMO-MANAGER"
    outlet = (
        await db.execute(select(Outlet).where(Outlet.server_id == server_id))
    ).scalar_one_or_none()

    if outlet is None:
        restaurant = Restaurant(name="Demo Restaurant")
        db.add(restaurant)
        await db.flush()
        outlet = Outlet(
            id=str(uuid4()),
            restaurant_id=restaurant.id,
            name="Demo Outlet",
            server_id=server_id,
        )
        db.add(outlet)
        await db.flush()

    phone = DEMO_PHONE
    email = phone_to_synthetic_email(phone)
    account = (
        await db.execute(
            select(AdminAccount).where(
                AdminAccount.outlet_id == outlet.id,
                AdminAccount.role == MANAGER,
            )
        )
    ).scalar_one_or_none()

    now = datetime.now(timezone.utc)
    if account is None:
        account = AdminAccount(
            id=str(uuid4()),
            outlet_id=outlet.id,
            email=email,
            username="demo-manager",
            password_hash=None,
            role=MANAGER,
            display_name="Demo Manager",
            auth_provider="phone",
            phone=phone,
            phone_verified_at=now,
            invite_status=INVITE_ACCEPTED,
            is_active=True,
        )
        db.add(account)
    else:
        account.phone = phone
        account.phone_verified_at = now
        account.invite_status = INVITE_ACCEPTED
        account.is_active = True
        if not account.display_name:
            account.display_name = "Demo Manager"

    await grant_outlet_access(db, outlet.id, plan="annual", extend_days=365)
    await db.commit()
    await db.refresh(outlet)
    await db.refresh(account)

    return ok(
        {
            "status": "authenticated",
            **await _auth_payload(
                db=db,
                outlet=outlet,
                account=account,
                server_id=outlet.server_id,
                request=request,
            ),
        }
    )


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
        if account.role == MANAGER:
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
        if a.role == STAFF and a.invite_status == INVITE_PENDING
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
        table_count=body.tableCount or 10,
    )
    db.add(outlet)
    await db.flush()

    synthetic_email = phone_to_synthetic_email(phone)
    account = AdminAccount(
        outlet_id=outlet.id,
        email=synthetic_email,
        username=synthetic_email,
        password_hash=None,
        role=MANAGER,
        phone=phone,
        phone_verified_at=datetime.now(timezone.utc),
        display_name=None,
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
                & (AdminAccount.role == STAFF)
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


@router.post("/admin/staff/dev-bypass-login")
async def staff_dev_bypass_login(
    request: Request,
    body: StaffDevBypassLoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """Dev-only staff login without Google. Disabled unless STAFF_DEV_BYPASS_SECRET is set."""
    configured = settings.STAFF_DEV_BYPASS_SECRET.strip()
    if not configured:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    if body.bypassSecret.strip() != configured:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid bypass credential.",
        )
    sid = body.serverId.strip()
    if not sid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="serverId is required.",
        )
    outlet = (
        await db.execute(select(Outlet).where(Outlet.server_id == sid))
    ).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Server ID not registered.")
    email = _clean_email(body.email)
    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="email is required.",
        )
    account = (
        await db.execute(
            select(AdminAccount).where(
                (AdminAccount.outlet_id == outlet.id)
                & (AdminAccount.role == STAFF)
                & (AdminAccount.email == email)
            )
        )
    ).scalar_one_or_none()
    if account is None or not account.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Staff email not found for this outlet.",
        )
    return ok(
        await _auth_payload(
            db=db,
            outlet=outlet,
            account=account,
            server_id=outlet.server_id,
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
    requested_server_id = (body.serverId or "").strip()

    account = (
        await db.execute(
            select(AdminAccount).where(
                (AdminAccount.google_sub == google_sub) | (AdminAccount.email == email)
            )
        )
    ).scalar_one_or_none()

    if account is not None:
        resolved_outlet: Outlet | None = None
        if requested_role != MANAGER:
            if requested_server_id:
                resolved_outlet = (
                    await db.execute(select(Outlet).where(Outlet.server_id == requested_server_id))
                ).scalar_one_or_none()
                if resolved_outlet is None:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail="Server ID not registered. Ask your manager for the correct server link.",
                    )
            elif account.role != MANAGER:
                # Existing staff accounts can sign in without retyping serverId.
                # Keep them bound to their current outlet for shared manager/staff
                # sync when the app did not supply serverId.
                resolved_outlet = (
                    await db.execute(select(Outlet).where(Outlet.id == account.outlet_id))
                ).scalar_one_or_none()
                if resolved_outlet is None:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail=(
                            "Staff account outlet is missing. Ask your manager for the "
                            "correct server link and sign in again."
                        ),
                    )
            # Keep staff and manager apps on the same outlet. If this Google
            # staff account was previously attached elsewhere, rebind it to
            # the manager's serverId outlet to restore shared order sync.
            if (
                resolved_outlet is not None
                and account.role != MANAGER
                and account.outlet_id != resolved_outlet.id
            ):
                account.outlet_id = resolved_outlet.id
                account.role = STAFF
        if not account.is_active:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Staff account is disabled.")
        if not account.google_sub:
            account.google_sub = google_sub
        account.display_name = account.display_name or display_name
        account.auth_provider = "google"
        await db.commit()
        await db.refresh(account)
        outlet = resolved_outlet or (
            await db.execute(select(Outlet).where(Outlet.id == account.outlet_id))
        ).scalar_one()
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
        # Staff one-tap onboarding requires manager's serverId so both apps
        # attach to the same outlet and share the same order stream.
        if not requested_server_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "serverId is required for staff sign-up. "
                    "Use the same server ID/link configured by your manager."
                ),
            )
        target_outlet = (
            await db.execute(select(Outlet).where(Outlet.server_id == requested_server_id))
        ).scalar_one_or_none()
        if target_outlet is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Server ID not registered. Ask your manager for the correct server link.",
            )
        account = AdminAccount(
            outlet_id=target_outlet.id,
            email=email,
            username=email,
            password_hash=None,
            role=STAFF,
            google_sub=google_sub,
            display_name=display_name,
            auth_provider="google",
            is_active=True,
        )
        db.add(account)
        await db.commit()
        await db.refresh(account)
        return ok(
            await _auth_payload(
                db=db,
                outlet=target_outlet,
                account=account,
                server_id=target_outlet.server_id,
                request=request,
            )
        )

    restaurant_name = (body.restaurantName or "").strip()
    outlet_name = (body.outletName or restaurant_name).strip() or restaurant_name
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
        table_count=body.tableCount or 10,
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
    await db.flush()
    await get_or_create_subscription(db, outlet.id)
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
        "orders": await delete_rows(Order, Order.outlet_id == outlet_id),
        "menuItems": await delete_rows(MenuItem, MenuItem.outlet_id == outlet_id),
        "devices": await delete_rows(Device, Device.outlet_id == outlet_id),
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

    phone: str | None = None
    email: str | None = None
    if body.phone and body.phone.strip():
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
            existing.role = STAFF
            existing.display_name = body.displayName or existing.display_name
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
            role=STAFF,
            phone=phone,
            display_name=body.displayName,
            auth_provider="phone",
            is_active=False,
            invite_status=INVITE_PENDING,
        )
        db.add(account)
        await db.commit()
        await db.refresh(account)
        return ok({"account": _account_dict(account)})

    if body.email and body.email.strip():
        email = _clean_email(body.email)
        existing = (await db.execute(select(AdminAccount).where(AdminAccount.email == email))).scalar_one_or_none()
        if existing:
            if existing.outlet_id != manager.outlet_id:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Email is already used by another outlet.",
                )
            existing.role = STAFF
            existing.display_name = body.displayName or existing.display_name
            existing.is_active = True
            existing.invite_status = INVITE_ACCEPTED
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
            invite_status=INVITE_ACCEPTED,
        )
        db.add(account)
        await db.commit()
        await db.refresh(account)
        return ok({"account": _account_dict(account)})

    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Phone or email is required.")


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
