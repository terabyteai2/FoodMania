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
    outletName: str | None = None
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
    outletName: str | None = None
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


class PublicSlugUpdateRequest(BaseModel):
    publicSlug: str


class OutletWipeRequest(BaseModel):
    confirmation: str = Field(min_length=1)


class FacebookChatbotConfigRequest(BaseModel):
    pageAccessToken: str | None = None
    isEnabled: bool = True
    orderingEnabled: bool = True


class FacebookChatbotConfigResponse(BaseModel):
    isConfigured: bool
    isEnabled: bool
    orderingEnabled: bool
    pageId: str | None = None
    pageName: str | None = None
    tokenPreview: str | None = None
    lastError: str | None = None


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
    nameEn: str | None = None
    nameBn: str | None = None
    description: str | None = None
    descriptionEn: str | None = None
    descriptionBn: str | None = None
    price: float
    category: str | None = None
    categoryEn: str | None = None
    categoryBn: str | None = None
    isAvailable: bool = True
    imageUrl: str | None = None
    tags: list[str] | None = None
    version: int = 1


class ImageUploadRequest(BaseModel):
    dataUrl: str
    fileName: str = "menu_image.jpg"


class MenuSubItem(BaseModel):
    nameEn: str = Field(min_length=1)
    nameBn: str = ""


class MenuAddOnCandidate(BaseModel):
    nameEn: str = Field(min_length=1)
    nameBn: str = ""
    price: float = Field(gt=0)


class MenuScanCandidate(BaseModel):
    nameEn: str = Field(min_length=1)
    nameBn: str = Field(min_length=1)
    descriptionEn: str = Field(min_length=1)
    descriptionBn: str = Field(min_length=1)
    categoryEn: str = Field(default="General", min_length=1)
    categoryBn: str = Field(default="সাধারণ", min_length=1)
    price: float = Field(gt=0)
    isAvailable: bool = True
    iconKey: str = Field(default="general", min_length=1)
    imageUrl: str | None = None
    subItems: list[MenuSubItem] = Field(default_factory=list)
    addOns: list[MenuAddOnCandidate] = Field(default_factory=list)


class ReceiptScanCandidate(BaseModel):
    nameEn: str = Field(min_length=1)
    nameBn: str = Field(min_length=1)
    qty: float = Field(gt=0)
    unit: str = Field(default="pcs", min_length=1)
    unitPriceBdt: float = Field(ge=0)
    totalBdt: float = Field(gt=0)


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

class OrderLineItemPayload(BaseModel):
    id: str | None = None
    orderId: str | None = None
    menuItemId: str | None = None
    name: str = Field(min_length=1)
    nameEn: str | None = None
    nameBn: str | None = None
    qty: int = Field(default=1, ge=1)
    price: float = 0
    lineTotal: float = 0


class OrderPayload(BaseModel):
    id: str
    serialNumber: int = 0
    source: str = "pos"
    status: str = "pending"
    totalAmount: float = 0
    subtotal: float | None = None
    vatRatePercent: float | None = None
    vatAmount: float | None = None
    serviceType: str | None = None
    covers: int | None = None
    paymentMethod: str | None = None
    items: list[OrderLineItemPayload] = Field(default_factory=list)
    notes: str | None = None
    customerName: str | None = None
    deliveryAddress: str | None = None
    mobileNumber: str | None = None
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


class PlatformAppUpdateRequest(BaseModel):
    versionName: str
    versionCode: int = Field(..., ge=1)
    apkUrl: str
    releaseNotes: str | None = None
    required: bool = False
    enabled: bool = True


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
