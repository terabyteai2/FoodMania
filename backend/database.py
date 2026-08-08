from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from config import settings

engine = create_async_engine(settings.DATABASE_URL, echo=False, pool_pre_ping=True)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        yield session


async def create_tables() -> None:
    async with engine.begin() as conn:
        from models import Base as ModelBase  # noqa: F401 – registers models
        await conn.run_sync(ModelBase.metadata.create_all)
        await _ensure_auth_columns(conn)
        await _ensure_menu_columns(conn)
        await _ensure_order_columns(conn)
        await _ensure_device_push_columns(conn)
        await _ensure_platform_columns(conn)
        await _ensure_outlet_theme_column(conn)
        await _ensure_delivery_charge_columns(conn)
        await _ensure_inventory_redesign_columns(conn)
        await _ensure_pos_columns(conn)
        await _ensure_chatbot_columns(conn)
        await _ensure_support_chat_columns(conn)
        await _ensure_role_migration(conn)
        await _ensure_subscription_columns(conn)
    await seed_platform_admin()
    await seed_system_config()


async def _ensure_role_migration(conn) -> None:
    """One-time migration to the QuickBytes 3-role model (owner/manager/waiter).

    Every pre-existing ``manager`` account is a tenant creator, so it becomes
    ``owner``; legacy ``staff`` becomes ``waiter``. Guarded by a
    ``system_configs`` flag so genuine mid-tier managers created after the
    migration are never re-mapped on subsequent startups.
    """
    flag = "role_model_v2_migrated"
    done = (
        await conn.execute(
            text("SELECT value FROM system_configs WHERE key = :k"), {"k": flag}
        )
    ).scalar_one_or_none()
    if done:
        return
    await conn.execute(
        text("UPDATE admin_accounts SET role = 'owner' WHERE role = 'manager'")
    )
    await conn.execute(
        text("UPDATE admin_accounts SET role = 'waiter' WHERE role = 'staff'")
    )
    await conn.execute(
        text(
            "INSERT INTO system_configs (key, value, updated_at) "
            "VALUES (:k, 'true', CURRENT_TIMESTAMP) "
            "ON CONFLICT (key) DO UPDATE SET value = 'true', "
            "updated_at = CURRENT_TIMESTAMP"
        ),
        {"k": flag},
    )


async def _ensure_auth_columns(conn) -> None:
    """Small compatibility migration for deployments that only use create_all."""
    dialect = conn.dialect.name
    if dialect == "sqlite":
        statements = [
            "ALTER TABLE admin_accounts ADD COLUMN role VARCHAR DEFAULT 'manager'",
            "ALTER TABLE admin_accounts ADD COLUMN google_sub VARCHAR",
            "ALTER TABLE admin_accounts ADD COLUMN display_name TEXT",
            "ALTER TABLE admin_accounts ADD COLUMN auth_provider VARCHAR DEFAULT 'password'",
            "ALTER TABLE admin_accounts ADD COLUMN is_active BOOLEAN DEFAULT TRUE",
            "ALTER TABLE orders ADD COLUMN created_by_account_id VARCHAR",
            "ALTER TABLE orders ADD COLUMN created_by_role VARCHAR",
        ]
        for statement in statements:
            try:
                await conn.execute(text(statement))
            except Exception:
                pass
        await conn.execute(
            text("CREATE UNIQUE INDEX IF NOT EXISTS ix_admin_accounts_google_sub ON admin_accounts(google_sub)")
        )
        for statement in [
            "ALTER TABLE admin_accounts ADD COLUMN phone VARCHAR",
            "ALTER TABLE admin_accounts ADD COLUMN phone_verified_at TIMESTAMP",
            "ALTER TABLE admin_accounts ADD COLUMN invite_status VARCHAR",
        ]:
            try:
                await conn.execute(text(statement))
            except Exception:
                pass
        await conn.execute(
            text("CREATE UNIQUE INDEX IF NOT EXISTS ix_admin_accounts_phone ON admin_accounts(phone)")
        )
        return

    statements = [
        "ALTER TABLE admin_accounts ADD COLUMN IF NOT EXISTS role VARCHAR DEFAULT 'manager'",
        "ALTER TABLE admin_accounts ADD COLUMN IF NOT EXISTS google_sub VARCHAR",
        "ALTER TABLE admin_accounts ADD COLUMN IF NOT EXISTS display_name TEXT",
        "ALTER TABLE admin_accounts ADD COLUMN IF NOT EXISTS auth_provider VARCHAR DEFAULT 'password'",
        "ALTER TABLE admin_accounts ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE",
        "ALTER TABLE orders ADD COLUMN IF NOT EXISTS created_by_account_id VARCHAR",
        "ALTER TABLE orders ADD COLUMN IF NOT EXISTS created_by_role VARCHAR",
        "CREATE UNIQUE INDEX IF NOT EXISTS ix_admin_accounts_google_sub ON admin_accounts(google_sub)",
        "ALTER TABLE admin_accounts ADD COLUMN IF NOT EXISTS phone VARCHAR",
        "ALTER TABLE admin_accounts ADD COLUMN IF NOT EXISTS phone_verified_at TIMESTAMPTZ",
        "ALTER TABLE admin_accounts ADD COLUMN IF NOT EXISTS invite_status VARCHAR",
        "ALTER TABLE admin_accounts ADD COLUMN IF NOT EXISTS invited_by_name TEXT",
        "CREATE UNIQUE INDEX IF NOT EXISTS ix_admin_accounts_phone ON admin_accounts(phone)",
        "ALTER TABLE admin_accounts ALTER COLUMN password_hash DROP NOT NULL",
    ]
    for statement in statements:
        await conn.execute(text(statement))


async def _ensure_platform_columns(conn) -> None:
    """Compatibility migration for platform admin tables and outlet columns."""
    dialect = conn.dialect.name
    if dialect == "sqlite":
        statements = [
            "ALTER TABLE outlets ADD COLUMN status VARCHAR DEFAULT 'active'",
            "ALTER TABLE outlets ADD COLUMN public_slug VARCHAR",
            "ALTER TABLE outlets ADD COLUMN notes TEXT",
            "ALTER TABLE outlets ADD COLUMN logo_url TEXT",
            "ALTER TABLE outlets ADD COLUMN logo_bitmap_url TEXT",
            "ALTER TABLE outlets ADD COLUMN table_count INTEGER DEFAULT 10",
            "ALTER TABLE uddoktapay_sessions ADD COLUMN outlet_id VARCHAR",
        ]
        for statement in statements:
            try:
                await conn.execute(text(statement))
            except Exception:
                pass
        await conn.execute(
            text("CREATE UNIQUE INDEX IF NOT EXISTS ix_outlets_public_slug ON outlets(public_slug)")
        )
        return

    statements = [
        "ALTER TABLE outlets ADD COLUMN IF NOT EXISTS status VARCHAR DEFAULT 'active'",
        "ALTER TABLE outlets ADD COLUMN IF NOT EXISTS public_slug VARCHAR",
        "CREATE UNIQUE INDEX IF NOT EXISTS ix_outlets_public_slug ON outlets(public_slug)",
        "ALTER TABLE outlets ADD COLUMN IF NOT EXISTS notes TEXT",
        "ALTER TABLE outlets ADD COLUMN IF NOT EXISTS logo_url TEXT",
        "ALTER TABLE outlets ADD COLUMN IF NOT EXISTS logo_bitmap_url TEXT",
        "ALTER TABLE outlets ADD COLUMN IF NOT EXISTS table_count INTEGER DEFAULT 10",
        "ALTER TABLE uddoktapay_sessions ADD COLUMN IF NOT EXISTS outlet_id VARCHAR",
    ]
    for statement in statements:
        await conn.execute(text(statement))


async def _ensure_device_push_columns(conn) -> None:
    """Compatibility migration for admin-app push registrations."""
    dialect = conn.dialect.name
    columns = [
        ("fcm_token", "TEXT"),
        ("push_platform", "VARCHAR"),
        ("last_seen_at", "TIMESTAMP" if dialect == "sqlite" else "TIMESTAMPTZ"),
    ]
    if dialect == "sqlite":
        for column, column_type in columns:
            try:
                await conn.execute(
                    text(f"ALTER TABLE devices ADD COLUMN {column} {column_type}")
                )
            except Exception:
                pass
        return

    for column, column_type in columns:
        await conn.execute(
            text(f"ALTER TABLE devices ADD COLUMN IF NOT EXISTS {column} {column_type}")
        )


async def _ensure_outlet_theme_column(conn) -> None:
    """Add menu_theme column for customer-menu visual templates."""
    dialect = conn.dialect.name
    if dialect == "sqlite":
        try:
            await conn.execute(
                text(
                    "ALTER TABLE outlets ADD COLUMN menu_theme VARCHAR DEFAULT 'sultans_hearth'"
                )
            )
        except Exception:
            pass
        await conn.execute(
            text(
                "UPDATE outlets SET menu_theme = 'sultans_hearth' "
                "WHERE menu_theme IS NULL OR menu_theme NOT IN "
                "('sultans_hearth', 'brick', 'lantern', 'marble')"
            )
        )
        return
    await conn.execute(
        text(
            "ALTER TABLE outlets ADD COLUMN IF NOT EXISTS menu_theme VARCHAR DEFAULT 'sultans_hearth'"
        )
    )
    await conn.execute(
        text(
            "UPDATE outlets SET menu_theme = 'sultans_hearth' "
            "WHERE menu_theme IS NULL OR menu_theme NOT IN "
            "('sultans_hearth', 'brick', 'lantern', 'marble')"
        )
    )


async def _ensure_delivery_charge_columns(conn) -> None:
    """Add outlet delivery pricing and retain the applied charge on orders."""
    dialect = conn.dialect.name
    if dialect == "sqlite":
        statements = [
            "ALTER TABLE outlets ADD COLUMN delivery_charge NUMERIC(10, 2) DEFAULT 0",
            "ALTER TABLE orders ADD COLUMN delivery_charge NUMERIC(10, 2) DEFAULT 0",
        ]
        for statement in statements:
            try:
                await conn.execute(text(statement))
            except Exception:
                pass
    else:
        await conn.execute(
            text(
                "ALTER TABLE outlets ADD COLUMN IF NOT EXISTS "
                "delivery_charge NUMERIC(10, 2) DEFAULT 0"
            )
        )
        await conn.execute(
            text(
                "ALTER TABLE orders ADD COLUMN IF NOT EXISTS "
                "delivery_charge NUMERIC(10, 2) DEFAULT 0"
            )
        )
    await conn.execute(
        text("UPDATE outlets SET delivery_charge = 0 WHERE delivery_charge IS NULL")
    )
    await conn.execute(
        text("UPDATE orders SET delivery_charge = 0 WHERE delivery_charge IS NULL")
    )


async def _ensure_inventory_redesign_columns(conn) -> None:
    """Add supplier-aware inventory fields while retaining legacy adjustment rows."""
    dialect = conn.dialect.name
    item_columns = [
        ("default_supplier_id", "VARCHAR"),
        ("default_reorder_qty", "NUMERIC(12, 4) DEFAULT 0"),
    ]
    adjustment_columns = [
        ("supplier_id", "VARCHAR"),
        ("supplier_name", "TEXT DEFAULT ''"),
        ("reason", "VARCHAR DEFAULT ''"),
        ("bill_ref", "VARCHAR DEFAULT ''"),
        ("invoice_ref", "VARCHAR DEFAULT ''"),
        ("created_by_account_id", "VARCHAR"),
        ("created_by_role", "VARCHAR"),
    ]
    if dialect == "sqlite":
        for table, columns in (
            ("inventory_items", item_columns),
            ("stock_adjustments", adjustment_columns),
        ):
            for column, column_type in columns:
                try:
                    await conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {column_type}"))
                except Exception:
                    pass
    else:
        for table, columns in (
            ("inventory_items", item_columns),
            ("stock_adjustments", adjustment_columns),
        ):
            for column, column_type in columns:
                await conn.execute(
                    text(f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {column} {column_type}")
                )
    await conn.execute(
        text("UPDATE inventory_items SET default_reorder_qty = 0 WHERE default_reorder_qty IS NULL")
    )
    await conn.execute(
        text("UPDATE stock_adjustments SET supplier_name = '' WHERE supplier_name IS NULL")
    )
    await conn.execute(text("UPDATE stock_adjustments SET reason = '' WHERE reason IS NULL"))
    await conn.execute(text("UPDATE stock_adjustments SET bill_ref = '' WHERE bill_ref IS NULL"))
    await conn.execute(text("UPDATE stock_adjustments SET invoice_ref = '' WHERE invoice_ref IS NULL"))


async def _ensure_pos_columns(conn) -> None:
    """Add desktop-POS settings and bill snapshots without changing mobile contracts."""
    dialect = conn.dialect.name
    json_type = "JSON" if dialect == "sqlite" else "JSONB"
    timestamp_type = "TIMESTAMP" if dialect == "sqlite" else "TIMESTAMPTZ"
    outlet_columns = [
        ("pos_floor_layout", json_type),
        ("pos_vat_rate_percent", "NUMERIC(5, 2) DEFAULT 0"),
        ("pos_service_charge_percent", "NUMERIC(5, 2) DEFAULT 0"),
        ("pos_discount_presets", json_type),
        # Nullable, no default/backfill: NULL = "not configured" (null-safe invariant).
        ("pos_daily_sales_target", "NUMERIC(10, 2)"),
        # Nullable, no default/backfill: restaurant contact phone (null-safe invariant).
        ("phone", "VARCHAR"),
    ]
    order_columns = [
        ("shift_id", "VARCHAR"),
        ("discount_label", "VARCHAR"),
        ("discount_amount", "NUMERIC(10, 2) DEFAULT 0"),
        ("service_charge_rate_percent", "NUMERIC(5, 2) DEFAULT 0"),
        ("service_charge_amount", "NUMERIC(10, 2) DEFAULT 0"),
        ("billing_snapshot", json_type),
        ("kot_batches", json_type),
        ("settled_at", timestamp_type),
    ]
    for table, columns in (("outlets", outlet_columns), ("orders", order_columns)):
        for column, column_type in columns:
            try:
                if dialect == "sqlite":
                    await conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {column_type}"))
                else:
                    await conn.execute(
                        text(f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {column} {column_type}")
                    )
            except Exception:
                if dialect != "sqlite":
                    raise
    await conn.execute(
        text("UPDATE outlets SET pos_vat_rate_percent = 0 WHERE pos_vat_rate_percent IS NULL")
    )
    await conn.execute(
        text(
            "UPDATE outlets SET pos_service_charge_percent = 0 "
            "WHERE pos_service_charge_percent IS NULL"
        )
    )
    await conn.execute(
        text("UPDATE orders SET discount_amount = 0 WHERE discount_amount IS NULL")
    )
    await conn.execute(
        text(
            "UPDATE orders SET service_charge_rate_percent = 0 "
            "WHERE service_charge_rate_percent IS NULL"
        )
    )
    await conn.execute(
        text(
            "UPDATE orders SET service_charge_amount = 0 "
            "WHERE service_charge_amount IS NULL"
        )
    )


async def _ensure_menu_columns(conn) -> None:
    """Compatibility migration for bilingual menu item text."""
    dialect = conn.dialect.name
    columns = [
        ("name_en", "TEXT"),
        ("name_bn", "TEXT"),
        ("description_en", "TEXT"),
        ("description_bn", "TEXT"),
        ("category_en", "TEXT"),
        ("category_bn", "TEXT"),
        ("tags_json", "TEXT"),
        ("cost_price", "NUMERIC(10, 2)"),
        ("short_code", "INTEGER"),
        ("is_favorite", "BOOLEAN DEFAULT FALSE"),
    ]
    if dialect == "sqlite":
        for column, column_type in columns:
            try:
                await conn.execute(
                    text(f"ALTER TABLE menu_items ADD COLUMN {column} {column_type}")
                )
            except Exception:
                pass
        return

    for column, column_type in columns:
        await conn.execute(
            text(
                f"ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS {column} {column_type}"
            )
        )


async def _ensure_order_columns(conn) -> None:
    """Compatibility migration for Terafoods order metadata."""
    dialect = conn.dialect.name
    columns = [
        ("subtotal", "NUMERIC(10, 2)"),
        ("vat_rate_percent", "NUMERIC(5, 2)"),
        ("vat_amount", "NUMERIC(10, 2)"),
        ("service_type", "VARCHAR"),
        ("covers", "INTEGER"),
        ("payment_method", "VARCHAR"),
        ("table_no", "VARCHAR"),
        ("customer_name", "TEXT"),
        ("delivery_address", "TEXT"),
        ("mobile_number", "VARCHAR"),
        ("order_date", "DATE"),
    ]
    if dialect == "sqlite":
        for column, column_type in columns:
            try:
                await conn.execute(
                    text(f"ALTER TABLE orders ADD COLUMN {column} {column_type}")
                )
            except Exception:
                pass
    else:
        for column, column_type in columns:
            await conn.execute(
                text(
                    f"ALTER TABLE orders ADD COLUMN IF NOT EXISTS {column} {column_type}"
                )
            )
    await conn.execute(text("UPDATE orders SET subtotal = total_amount WHERE subtotal IS NULL"))
    await conn.execute(text("UPDATE orders SET vat_rate_percent = 0 WHERE vat_rate_percent IS NULL"))
    await conn.execute(text("UPDATE orders SET vat_amount = 0 WHERE vat_amount IS NULL"))
    await conn.execute(text("UPDATE orders SET order_date = created_at::date WHERE order_date IS NULL"))


async def _ensure_chatbot_columns(conn) -> None:
    """Add history_json column to chatbot_conversations for micro-batching + LLM session fields."""
    dialect = conn.dialect.name
    json_type = "JSON" if dialect == "sqlite" else "JSONB"
    if dialect == "sqlite":
        for col in [
            f"ALTER TABLE chatbot_conversations ADD COLUMN history_json {json_type}",
            "ALTER TABLE chatbot_integrations ADD COLUMN llm_session_started_at TIMESTAMP",
            "ALTER TABLE chatbot_integrations ADD COLUMN llm_batch_count INTEGER DEFAULT 0",
        ]:
            try:
                await conn.execute(text(col))
            except Exception:
                pass
    else:
        for col in [
            f"ALTER TABLE chatbot_conversations ADD COLUMN IF NOT EXISTS "
            f"history_json {json_type} DEFAULT '[]'::{json_type}",
            "ALTER TABLE chatbot_integrations ADD COLUMN IF NOT EXISTS "
            "llm_session_started_at TIMESTAMPTZ",
            "ALTER TABLE chatbot_integrations ADD COLUMN IF NOT EXISTS "
            "llm_batch_count INTEGER DEFAULT 0",
        ]:
            await conn.execute(text(col))


async def _ensure_support_chat_columns(conn) -> None:
    """Add auto-reply outcome columns to support_chat_messages (diagnostics).

    Recorded by services/support_llm.py on client rows so every message that
    did or did not get a reply carries a machine-readable outcome.
    """
    dialect = conn.dialect.name
    timestamp_type = "TIMESTAMP" if dialect == "sqlite" else "TIMESTAMPTZ"
    json_type = "JSON" if dialect == "sqlite" else "JSONB"
    columns = [
        ("reply_status", "VARCHAR"),
        ("reply_reason", "VARCHAR"),
        ("reply_error", "TEXT"),
        ("reply_detail", json_type),
        ("reply_latency_ms", "INTEGER"),
        ("reply_model", "VARCHAR"),
        ("reply_attempted_at", timestamp_type),
    ]
    for column, column_type in columns:
        try:
            if dialect == "sqlite":
                await conn.execute(
                    text(f"ALTER TABLE support_chat_messages ADD COLUMN {column} {column_type}")
                )
            else:
                await conn.execute(
                    text(
                        f"ALTER TABLE support_chat_messages ADD COLUMN IF NOT EXISTS {column} {column_type}"
                    )
                )
        except Exception:
            if dialect != "sqlite":
                raise


async def _ensure_subscription_columns(conn) -> None:
    """Add package column and migrate old statuses to the new 5-status model.

    Before: plan=(trial|monthly|annual), status=(active|pending|expired|cancelled)
    After:  package=(null|standard|pro|premium), status=(trial|active|on_hold|paused|cancelled)
    """
    dialect = conn.dialect.name
    if dialect == "sqlite":
        try:
            await conn.execute(
                text("ALTER TABLE outlet_subscriptions ADD COLUMN package VARCHAR")
            )
        except Exception:
            pass
    else:
        await conn.execute(
            text(
                "ALTER TABLE outlet_subscriptions ADD COLUMN IF NOT EXISTS package VARCHAR"
            )
        )

    # Migrate status values
    await conn.execute(
        text(
            "UPDATE outlet_subscriptions SET status = 'trial' "
            "WHERE plan = 'trial' AND status = 'active'"
        )
    )
    await conn.execute(
        text(
            "UPDATE outlet_subscriptions SET status = 'on_hold' "
            "WHERE status IN ('pending', 'expired')"
        )
    )
    # Set default package for active subscriptions that were on a paid plan
    await conn.execute(
        text(
            "UPDATE outlet_subscriptions SET package = 'standard' "
            "WHERE status = 'active' AND package IS NULL"
        )
    )

    # Add addons column
    if dialect == "sqlite":
        try:
            await conn.execute(
                text("ALTER TABLE outlet_subscriptions ADD COLUMN addons VARCHAR DEFAULT '[]'")
            )
        except Exception:
            pass
    else:
        await conn.execute(
            text(
                "ALTER TABLE outlet_subscriptions ADD COLUMN IF NOT EXISTS addons VARCHAR "
                "DEFAULT '[]'"
            )
        )


async def seed_system_config() -> None:
    """Seed default system configuration values if not already present."""
    from models import SystemConfig
    from sqlalchemy import select

    defaults = {
        "bkash_enabled": "false",
        "maintenance_mode": "false",
        "support_email": "",
        "admin_app_update": "",
        "terminal_app_update": "",
        "admin_blocking_notice": "",
        "subscription_prices": '{"standard":500,"pro":700,"premium":1000}',
        "addon_prices": '{"inventory":199,"website_qr":199,"messenger_bot":199}',
    }
    async with AsyncSessionLocal() as db:
        for key, value in defaults.items():
            existing = (
                await db.execute(select(SystemConfig).where(SystemConfig.key == key))
            ).scalar_one_or_none()
            if existing is None:
                db.add(SystemConfig(key=key, value=value))
        await db.commit()


async def seed_platform_admin() -> None:
    """Create the first platform admin from env if none exist."""
    from auth import hash_password
    from config import settings
    from models import PlatformAdmin
    from sqlalchemy import select

    email = settings.PLATFORM_ADMIN_EMAIL.strip().lower()
    password = settings.PLATFORM_ADMIN_PASSWORD
    if not email or not password:
        return

    async with AsyncSessionLocal() as db:
        existing = (
            await db.execute(select(PlatformAdmin).where(PlatformAdmin.email == email))
        ).scalar_one_or_none()
        if existing is not None:
            # Keep env password in sync when you change PLATFORM_ADMIN_PASSWORD
            existing.password_hash = hash_password(password)
            existing.is_active = True
            await db.commit()
            return
        admin = PlatformAdmin(
            email=email,
            password_hash=hash_password(password),
            display_name="Platform Admin",
            role="super_admin",
            is_active=True,
        )
        db.add(admin)
        await db.commit()
