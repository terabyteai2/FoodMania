from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


def ok(data: Any) -> dict:
    return {"data": data, "error": None}


def err(message: str) -> dict:
    return {"error": message}


# ── Tenants ──────────────────────────────────────────────────────────────────

class BootstrapRequest(BaseModel):
    serverId: str
    restaurantName: str
    outletName: str
    restaurantId: str | None = None
    outletId: str | None = None
    tableCount: int | None = Field(default=None, ge=1, le=200)


class BootstrapResponse(BaseModel):
    serverId: str
    restaurantId: str
    outletId: str
    restaurantName: str
    outletName: str
    deviceToken: str
    tableCount: int = Field(default=10, ge=1, le=200)


# ── Admin ─────────────────────────────────────────────────────────────────────

class AdminLoginRequest(BaseModel):
    usernameOrEmail: str
    password: str
    serverId: str


class AdminCreateRequest(BaseModel):
    outletId: str
    email: str
    username: str
    password: str | None = None
    role: str = "manager"
    googleSub: str | None = None
    displayName: str | None = None


class GoogleAdminAuthRequest(BaseModel):
    idToken: str
    role: str = "staff"
    serverId: str | None = None
    restaurantName: str | None = None
    outletName: str | None = None
    restaurantId: str | None = None
    outletId: str | None = None
    tableCount: int | None = Field(default=None, ge=1, le=200)


class PhoneSendOtpRequest(BaseModel):
    phone: str
    """Android SMS Retriever 11-char hash from SmsAutoFill().getAppSignature — enables auto-read OTP."""
    appSignature: str | None = None


class PhoneVerifyOtpRequest(BaseModel):
    phone: str
    code: str


class PhoneCompleteManagerSignupRequest(BaseModel):
    signupToken: str
    restaurantName: str
    outletName: str | None = "Main Outlet"
    serverId: str | None = None
    outletId: str | None = None
    tableCount: int | None = Field(default=None, ge=1, le=200)


class StaffInviteRespondRequest(BaseModel):
    signupToken: str
    inviteId: str
    accept: bool


class StaffInviteRequest(BaseModel):
    phone: str | None = None
    email: str | None = None
    displayName: str | None = None


class StaffUpdateRequest(BaseModel):
    isActive: bool | None = None
    displayName: str | None = None


class StaffDevBypassLoginRequest(BaseModel):
    """Local/dev staff login without Google; server must set STAFF_DEV_BYPASS_SECRET."""

    email: str
    serverId: str
    bypassSecret: str


# ── Devices ───────────────────────────────────────────────────────────────────

class DeviceRegisterRequest(BaseModel):
    serverId: str
    restaurantId: str
    outletId: str
    restaurantName: str
    outletName: str
    tableCount: int | None = Field(default=None, ge=1, le=200)


# ── Menu ──────────────────────────────────────────────────────────────────────

class MenuItemPayload(BaseModel):
    id: str
    name: str
    description: str | None = None
    price: float
    category: str | None = None
    isAvailable: bool = True
    imageUrl: str | None = None
    version: int = 1


class ImageUploadRequest(BaseModel):
    dataUrl: str
    fileName: str = "menu_image.jpg"


class MenuScanCandidate(BaseModel):
    name: str = Field(min_length=1)
    description: str = Field(min_length=1)
    category: str = Field(default="General", min_length=1)
    price: float = Field(gt=0)
    isAvailable: bool = True


# ── Inventory ─────────────────────────────────────────────────────────────────

class InventoryItemPayload(BaseModel):
    id: str
    name: str
    category: str | None = ""
    unit: str | None = "pcs"
    quantity: float = 0
    minThreshold: float = 0
    costPerUnit: float = 0
    notes: str | None = ""
    createdAt: str | None = None
    updatedAt: str | None = None


class StockAdjustmentPayload(BaseModel):
    id: str | None = None
    inventoryItemId: str
    delta: float
    type: str = "correction"
    note: str | None = ""
    totalCostBdt: float = 0
    createdAt: str | None = None


class DailyStockCountPayload(BaseModel):
    id: str | None = None
    inventoryItemId: str
    countDate: str
    quantity: float
    createdAt: str | None = None


# ── Orders ────────────────────────────────────────────────────────────────────

class OrderPayload(BaseModel):
    id: str
    serialNumber: int = 0
    source: str = "pos"
    status: str = "pending"
    totalAmount: float = 0
    items: list[Any] = []
    notes: str | None = None
    createdByAccountId: str | None = None
    createdByRole: str | None = None
    createdAt: str | None = None
    updatedAt: str | None = None


class OrderStatusUpdate(BaseModel):
    status: str
    updatedAt: str | None = None


# ── BKash ─────────────────────────────────────────────────────────────────────

class BkashCreateRequest(BaseModel):
    serverId: str
    amount: float
    currency: str = "BDT"
    purpose: str = "admin_activation"


class UddoktaPayCreateRequest(BaseModel):
    serverId: str
    amount: float
    currency: str = "BDT"
    purpose: str = "admin_activation"
    plan: str = "monthly"
    fullName: str = "Restaurant Manager"
    email: str = "manager@example.com"


class UddoktaPayVerifyRequest(BaseModel):
    invoiceId: str | None = None


# ── Platform admin ────────────────────────────────────────────────────────────

class PlatformLoginRequest(BaseModel):
    email: str
    password: str


class PlatformOutletPatchRequest(BaseModel):
    name: str | None = None
    status: str | None = None
    notes: str | None = None


class PlatformAccountPatchRequest(BaseModel):
    isActive: bool | None = None
    role: str | None = None
    displayName: str | None = None


class OnboardingPlanRequest(BaseModel):
    plan: str = "monthly"


class PlatformSubscriptionRequest(BaseModel):
    plan: str = "monthly"
    status: str = "active"
    extendDays: int | None = None
    expiresAt: str | None = None  # ISO date string — takes priority over extendDays


class PlatformPaymentStatusPatchRequest(BaseModel):
    status: str
    activateSubscription: bool = True


class PlatformAdminCreateRequest(BaseModel):
    email: str
    password: str
    displayName: str | None = None


class PlatformAdminPatchRequest(BaseModel):
    isActive: bool | None = None
    displayName: str | None = None
    password: str | None = None


class SystemConfigPatchRequest(BaseModel):
    baseUrl: str | None = None
    bkashEnabled: bool | None = None
    maintenanceMode: bool | None = None
    supportEmail: str | None = None


class OutletCreateRequest(BaseModel):
    restaurantId: str | None = None
    restaurantName: str
    outletName: str
    serverId: str


class OutletAccountCreateRequest(BaseModel):
    email: str
    username: str
    password: str
    displayName: str | None = None
    role: str = "manager"
