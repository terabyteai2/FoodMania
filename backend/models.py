import uuid
from datetime import date, datetime, timezone

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Integer, Numeric, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database import Base


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _uuid() -> str:
    return str(uuid.uuid4())


class Restaurant(Base):
    __tablename__ = "restaurants"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    outlets: Mapped[list["Outlet"]] = relationship(back_populates="restaurant")


class Outlet(Base):
    __tablename__ = "outlets"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    restaurant_id: Mapped[str] = mapped_column(ForeignKey("restaurants.id"), nullable=False)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    server_id: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    table_count: Mapped[int] = mapped_column(Integer, default=10)
    status: Mapped[str] = mapped_column(String, default="active")
    public_slug: Mapped[str | None] = mapped_column(String, unique=True, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    banner_url: Mapped[str | None] = mapped_column(Text)
    logo_url: Mapped[str | None] = mapped_column(Text)
    logo_bitmap_url: Mapped[str | None] = mapped_column(Text)
    video_url: Mapped[str | None] = mapped_column(Text)
    gallery_images: Mapped[list] = mapped_column(JSONB, nullable=True, default=list)
    menu_theme: Mapped[str] = mapped_column(String, default="sultans_hearth")
    delivery_charge: Mapped[float] = mapped_column(Numeric(10, 2), default=0)
    pos_floor_layout: Mapped[list] = mapped_column(JSONB, nullable=True, default=list)
    pos_vat_rate_percent: Mapped[float] = mapped_column(Numeric(5, 2), default=0)
    pos_service_charge_percent: Mapped[float] = mapped_column(Numeric(5, 2), default=0)
    pos_discount_presets: Mapped[list] = mapped_column(JSONB, nullable=True, default=list)
    # Nullable by design: NULL = "not configured" so Control Tower falls back to
    # its built-in default and existing logic is unaffected (null-safe invariant).
    pos_daily_sales_target: Mapped[float | None] = mapped_column(
        Numeric(10, 2), nullable=True
    )
    # Restaurant contact phone shown to customers; nullable, not OTP-validated, not
    # unique — distinct from AdminAccount.phone (the account holder's own login phone).
    phone: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    restaurant: Mapped[Restaurant] = relationship(back_populates="outlets")
    admin_accounts: Mapped[list["AdminAccount"]] = relationship(back_populates="outlet")
    devices: Mapped[list["Device"]] = relationship(back_populates="outlet")
    menu_items: Mapped[list["MenuItem"]] = relationship(back_populates="outlet")
    orders: Mapped[list["Order"]] = relationship(back_populates="outlet")
    inventory_items: Mapped[list["InventoryItem"]] = relationship(back_populates="outlet")
    inventory_suppliers: Mapped[list["InventorySupplier"]] = relationship(back_populates="outlet")
    subscription: Mapped["OutletSubscription | None"] = relationship(
        back_populates="outlet", uselist=False
    )
    chatbot_integrations: Mapped[list["ChatbotIntegration"]] = relationship(
        back_populates="outlet"
    )


class AdminAccount(Base):
    __tablename__ = "admin_accounts"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    outlet_id: Mapped[str] = mapped_column(ForeignKey("outlets.id"), nullable=False)
    email: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    username: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    password_hash: Mapped[str | None] = mapped_column(Text, nullable=True)
    role: Mapped[str] = mapped_column(String, default="manager")
    google_sub: Mapped[str | None] = mapped_column(String, unique=True, nullable=True)
    phone: Mapped[str | None] = mapped_column(String, unique=True, nullable=True)
    phone_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    invite_status: Mapped[str | None] = mapped_column(String, nullable=True)
    display_name: Mapped[str | None] = mapped_column(Text, nullable=True)
    invited_by_name: Mapped[str | None] = mapped_column(Text, nullable=True)
    auth_provider: Mapped[str] = mapped_column(String, default="password")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    outlet: Mapped[Outlet] = relationship(back_populates="admin_accounts")


class Device(Base):
    __tablename__ = "devices"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    outlet_id: Mapped[str] = mapped_column(ForeignKey("outlets.id"), nullable=False)
    server_id: Mapped[str] = mapped_column(String, nullable=False)
    fcm_token: Mapped[str | None] = mapped_column(Text, nullable=True)
    push_platform: Mapped[str | None] = mapped_column(String, nullable=True)
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    registered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    outlet: Mapped[Outlet] = relationship(back_populates="devices")


class MenuItem(Base):
    __tablename__ = "menu_items"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    outlet_id: Mapped[str] = mapped_column(ForeignKey("outlets.id"), nullable=False)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    name_en: Mapped[str | None] = mapped_column(Text)
    name_bn: Mapped[str | None] = mapped_column(Text)
    description: Mapped[str | None] = mapped_column(Text)
    description_en: Mapped[str | None] = mapped_column(Text)
    description_bn: Mapped[str | None] = mapped_column(Text)
    price: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    cost_price: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)
    # Short code — serial-by-default, editable; powers fast numeric item lookup
    # in the POS (the ⚡ search toggle). NULL = not yet assigned.
    short_code: Mapped[int | None] = mapped_column(Integer, nullable=True)
    # Outlet-wide favourite flag — favourited items float to the top of the POS
    # item picker. NULL/false = not favourited.
    is_favorite: Mapped[bool] = mapped_column(Boolean, default=False, nullable=True)
    category: Mapped[str | None] = mapped_column(Text)
    category_en: Mapped[str | None] = mapped_column(Text)
    category_bn: Mapped[str | None] = mapped_column(Text)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    image_url: Mapped[str | None] = mapped_column(Text)
    video_url: Mapped[str | None] = mapped_column(Text)
    tags_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    version: Mapped[int] = mapped_column(Integer, default=1)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    outlet: Mapped[Outlet] = relationship(back_populates="menu_items")


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    outlet_id: Mapped[str] = mapped_column(ForeignKey("outlets.id"), nullable=False)
    serial_number: Mapped[int] = mapped_column(Integer, default=0)
    source: Mapped[str] = mapped_column(String, default="pos")
    status: Mapped[str] = mapped_column(String, default="pending")
    total_amount: Mapped[float] = mapped_column(Numeric(10, 2), default=0)
    subtotal: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)
    vat_rate_percent: Mapped[float | None] = mapped_column(
        Numeric(5, 2), nullable=True
    )
    vat_amount: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)
    delivery_charge: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)
    service_type: Mapped[str | None] = mapped_column(String, nullable=True)
    covers: Mapped[int | None] = mapped_column(Integer, nullable=True)
    payment_method: Mapped[str | None] = mapped_column(String, nullable=True)
    table_no: Mapped[str | None] = mapped_column(String, nullable=True)
    items: Mapped[dict] = mapped_column(JSONB, default=list)
    notes: Mapped[str | None] = mapped_column(Text)
    customer_name: Mapped[str | None] = mapped_column(Text, nullable=True)
    delivery_address: Mapped[str | None] = mapped_column(Text, nullable=True)
    mobile_number: Mapped[str | None] = mapped_column(String, nullable=True)
    created_by_account_id: Mapped[str | None] = mapped_column(String, nullable=True)
    created_by_role: Mapped[str | None] = mapped_column(String, nullable=True)
    shift_id: Mapped[str | None] = mapped_column(String, nullable=True)
    discount_label: Mapped[str | None] = mapped_column(String, nullable=True)
    discount_amount: Mapped[float] = mapped_column(Numeric(10, 2), default=0)
    service_charge_rate_percent: Mapped[float] = mapped_column(Numeric(5, 2), default=0)
    service_charge_amount: Mapped[float] = mapped_column(Numeric(10, 2), default=0)
    billing_snapshot: Mapped[dict] = mapped_column(JSONB, nullable=True, default=dict)
    kot_batches: Mapped[list] = mapped_column(JSONB, nullable=True, default=list)
    settled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    order_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    outlet: Mapped[Outlet] = relationship(back_populates="orders")


class PosShift(Base):
    __tablename__ = "pos_shifts"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    outlet_id: Mapped[str] = mapped_column(ForeignKey("outlets.id"), nullable=False)
    status: Mapped[str] = mapped_column(String, default="open")
    opening_cash: Mapped[float] = mapped_column(Numeric(10, 2), default=0)
    expected_cash: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)
    counted_cash: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)
    variance_cash: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)
    opening_denominations: Mapped[dict] = mapped_column(JSONB, nullable=True, default=dict)
    closing_denominations: Mapped[dict] = mapped_column(JSONB, nullable=True, default=dict)
    opened_by_account_id: Mapped[str | None] = mapped_column(String, nullable=True)
    closed_by_account_id: Mapped[str | None] = mapped_column(String, nullable=True)
    opened_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class PosSettlement(Base):
    __tablename__ = "pos_settlements"
    __table_args__ = (
        UniqueConstraint("event_id", name="uq_pos_settlements_event_id"),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    event_id: Mapped[str] = mapped_column(String, nullable=False)
    outlet_id: Mapped[str] = mapped_column(ForeignKey("outlets.id"), nullable=False)
    order_id: Mapped[str] = mapped_column(ForeignKey("orders.id"), nullable=False)
    shift_id: Mapped[str | None] = mapped_column(ForeignKey("pos_shifts.id"), nullable=True)
    kind: Mapped[str] = mapped_column(String, default="payment")
    payment_method: Mapped[str] = mapped_column(String, default="cash")
    amount: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    payer_label: Mapped[str | None] = mapped_column(String, nullable=True)
    created_by_account_id: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class PosAuditEvent(Base):
    __tablename__ = "pos_audit_events"
    __table_args__ = (
        UniqueConstraint("event_id", name="uq_pos_audit_events_event_id"),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    event_id: Mapped[str] = mapped_column(String, nullable=False)
    outlet_id: Mapped[str] = mapped_column(ForeignKey("outlets.id"), nullable=False)
    order_id: Mapped[str | None] = mapped_column(ForeignKey("orders.id"), nullable=True)
    shift_id: Mapped[str | None] = mapped_column(ForeignKey("pos_shifts.id"), nullable=True)
    action: Mapped[str] = mapped_column(String, nullable=False)
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    metadata_json: Mapped[dict] = mapped_column(JSONB, nullable=True, default=dict)
    created_by_account_id: Mapped[str | None] = mapped_column(String, nullable=True)
    created_by_role: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class PlatformAdmin(Base):
    __tablename__ = "platform_admins"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    email: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)
    display_name: Mapped[str | None] = mapped_column(Text, nullable=True)
    role: Mapped[str] = mapped_column(String, default="super_admin")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class OutletSubscription(Base):
    __tablename__ = "outlet_subscriptions"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    outlet_id: Mapped[str] = mapped_column(ForeignKey("outlets.id"), unique=True, nullable=False)
    plan: Mapped[str] = mapped_column(String, default="trial")
    status: Mapped[str] = mapped_column(String, default="active")
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_payment_session_id: Mapped[str | None] = mapped_column(String, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    outlet: Mapped[Outlet] = relationship(back_populates="subscription")


class BkashSession(Base):
    __tablename__ = "bkash_sessions"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    server_id: Mapped[str] = mapped_column(String, nullable=False)
    amount: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String, default="BDT")
    purpose: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[str] = mapped_column(String, default="pending")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class UddoktaPaySession(Base):
    __tablename__ = "uddoktapay_sessions"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    outlet_id: Mapped[str | None] = mapped_column(ForeignKey("outlets.id"), nullable=True)
    server_id: Mapped[str] = mapped_column(String, nullable=False)
    amount: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String, default="BDT")
    purpose: Mapped[str] = mapped_column(String, nullable=False)
    plan: Mapped[str | None] = mapped_column(String, nullable=True)
    status: Mapped[str] = mapped_column(String, default="pending")
    invoice_id: Mapped[str | None] = mapped_column(String, nullable=True)
    transaction_id: Mapped[str | None] = mapped_column(String, nullable=True)
    payment_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    customer_name: Mapped[str | None] = mapped_column(Text, nullable=True)
    customer_email: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class InventoryItem(Base):
    __tablename__ = "inventory_items"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    outlet_id: Mapped[str] = mapped_column(ForeignKey("outlets.id"), nullable=False)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[str] = mapped_column(Text, default="")
    unit: Mapped[str] = mapped_column(String, default="pcs")
    quantity: Mapped[float] = mapped_column(Numeric(12, 4), default=0)
    min_threshold: Mapped[float] = mapped_column(Numeric(12, 4), default=0)
    cost_per_unit: Mapped[float] = mapped_column(Numeric(12, 4), default=0)
    notes: Mapped[str] = mapped_column(Text, default="")
    default_supplier_id: Mapped[str | None] = mapped_column(
        ForeignKey("inventory_suppliers.id"), nullable=True
    )
    default_reorder_qty: Mapped[float] = mapped_column(Numeric(12, 4), default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    outlet: Mapped[Outlet] = relationship(back_populates="inventory_items")
    adjustments: Mapped[list["StockAdjustment"]] = relationship(back_populates="item")
    daily_counts: Mapped[list["DailyStockCount"]] = relationship(back_populates="item")


class InventorySupplier(Base):
    __tablename__ = "inventory_suppliers"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    outlet_id: Mapped[str] = mapped_column(ForeignKey("outlets.id"), nullable=False)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    phone: Mapped[str] = mapped_column(String, default="")
    notes: Mapped[str] = mapped_column(Text, default="")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    outlet: Mapped[Outlet] = relationship(back_populates="inventory_suppliers")


class StockAdjustment(Base):
    __tablename__ = "stock_adjustments"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    outlet_id: Mapped[str] = mapped_column(ForeignKey("outlets.id"), nullable=False)
    inventory_item_id: Mapped[str] = mapped_column(
        ForeignKey("inventory_items.id", ondelete="CASCADE"), nullable=False
    )
    delta: Mapped[float] = mapped_column(Numeric(12, 4), nullable=False)
    type: Mapped[str] = mapped_column(String, nullable=False)
    note: Mapped[str] = mapped_column(Text, default="")
    total_cost_bdt: Mapped[float] = mapped_column(Numeric(12, 2), default=0)
    supplier_id: Mapped[str | None] = mapped_column(
        ForeignKey("inventory_suppliers.id"), nullable=True
    )
    supplier_name: Mapped[str] = mapped_column(Text, default="")
    reason: Mapped[str] = mapped_column(String, default="")
    bill_ref: Mapped[str] = mapped_column(String, default="")
    invoice_ref: Mapped[str] = mapped_column(String, default="")
    created_by_account_id: Mapped[str | None] = mapped_column(String, nullable=True)
    created_by_role: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    item: Mapped[InventoryItem] = relationship(back_populates="adjustments")


class DailyStockCount(Base):
    __tablename__ = "daily_stock_counts"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    outlet_id: Mapped[str] = mapped_column(ForeignKey("outlets.id"), nullable=False)
    inventory_item_id: Mapped[str] = mapped_column(
        ForeignKey("inventory_items.id", ondelete="CASCADE"), nullable=False
    )
    count_date: Mapped[str] = mapped_column(String, nullable=False)
    quantity: Mapped[float] = mapped_column(Numeric(12, 4), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    item: Mapped[InventoryItem] = relationship(back_populates="daily_counts")


class SystemConfig(Base):
    __tablename__ = "system_configs"

    key: Mapped[str] = mapped_column(String, primary_key=True)
    value: Mapped[str] = mapped_column(Text, nullable=False, default="")
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class ChatbotIntegration(Base):
    __tablename__ = "chatbot_integrations"
    __table_args__ = (
        UniqueConstraint("provider", "outlet_id", name="uq_chatbot_provider_outlet"),
        UniqueConstraint("provider", "page_id", name="uq_chatbot_provider_page"),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    outlet_id: Mapped[str] = mapped_column(ForeignKey("outlets.id"), nullable=False)
    provider: Mapped[str] = mapped_column(String, default="facebook", nullable=False)
    page_id: Mapped[str] = mapped_column(String, nullable=False)
    page_name: Mapped[str | None] = mapped_column(Text, nullable=True)
    page_access_token: Mapped[str] = mapped_column(Text, nullable=False)
    is_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    ordering_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    last_error: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    outlet: Mapped[Outlet] = relationship(back_populates="chatbot_integrations")
    conversations: Mapped[list["ChatbotConversation"]] = relationship(
        back_populates="integration"
    )


class ChatbotOAuthSession(Base):
    __tablename__ = "chatbot_oauth_sessions"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    outlet_id: Mapped[str] = mapped_column(ForeignKey("outlets.id"), nullable=False)
    account_id: Mapped[str] = mapped_column(ForeignKey("admin_accounts.id"), nullable=False)
    provider: Mapped[str] = mapped_column(String, default="facebook", nullable=False)
    pages_json: Mapped[list] = mapped_column(JSONB, nullable=False, default=list)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class ChatbotConversation(Base):
    __tablename__ = "chatbot_conversations"
    __table_args__ = (
        UniqueConstraint("integration_id", "psid", name="uq_chatbot_conversation_psid"),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    integration_id: Mapped[str] = mapped_column(
        ForeignKey("chatbot_integrations.id"), nullable=False
    )
    page_id: Mapped[str] = mapped_column(String, nullable=False)
    psid: Mapped[str] = mapped_column(String, nullable=False)
    state_json: Mapped[dict] = mapped_column(JSONB, nullable=True, default=dict)
    history_json: Mapped[list] = mapped_column(JSONB, nullable=True, default=list)
    last_user_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    last_bot_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    integration: Mapped[ChatbotIntegration] = relationship(back_populates="conversations")
