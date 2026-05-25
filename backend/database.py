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
        await _ensure_platform_columns(conn)
        await _ensure_outlet_theme_column(conn)
    await seed_platform_admin()
    await seed_system_config()


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
        "ALTER TABLE outlets ADD COLUMN IF NOT EXISTS table_count INTEGER DEFAULT 10",
        "ALTER TABLE uddoktapay_sessions ADD COLUMN IF NOT EXISTS outlet_id VARCHAR",
    ]
    for statement in statements:
        await conn.execute(text(statement))


async def _ensure_outlet_theme_column(conn) -> None:
    """Add menu_theme column for customer-menu visual templates."""
    dialect = conn.dialect.name
    if dialect == "sqlite":
        try:
            await conn.execute(
                text(
                    "ALTER TABLE outlets ADD COLUMN menu_theme VARCHAR DEFAULT 'napoli_trattoria'"
                )
            )
        except Exception:
            pass
        return
    await conn.execute(
        text(
            "ALTER TABLE outlets ADD COLUMN IF NOT EXISTS menu_theme VARCHAR DEFAULT 'napoli_trattoria'"
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
        ("customer_name", "TEXT"),
        ("delivery_address", "TEXT"),
        ("mobile_number", "VARCHAR"),
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


async def seed_system_config() -> None:
    """Seed default system configuration values if not already present."""
    from models import SystemConfig
    from sqlalchemy import select

    defaults = {
        "bkash_enabled": "false",
        "maintenance_mode": "false",
        "support_email": "",
        "admin_app_update": "",
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
