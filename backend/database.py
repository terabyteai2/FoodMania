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
        await _ensure_platform_columns(conn)
    await seed_platform_admin()


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
            "ALTER TABLE outlets ADD COLUMN notes TEXT",
            "ALTER TABLE uddoktapay_sessions ADD COLUMN outlet_id VARCHAR",
        ]
        for statement in statements:
            try:
                await conn.execute(text(statement))
            except Exception:
                pass
        return

    statements = [
        "ALTER TABLE outlets ADD COLUMN IF NOT EXISTS status VARCHAR DEFAULT 'active'",
        "ALTER TABLE outlets ADD COLUMN IF NOT EXISTS notes TEXT",
        "ALTER TABLE uddoktapay_sessions ADD COLUMN IF NOT EXISTS outlet_id VARCHAR",
    ]
    for statement in statements:
        await conn.execute(text(statement))


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
