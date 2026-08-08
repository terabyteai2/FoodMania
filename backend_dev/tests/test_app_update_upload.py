import io
import uuid
import zipfile

import pytest
from httpx import ASGITransport, AsyncClient

from auth import create_platform_token, hash_password
from config import settings
from database import AsyncSessionLocal, create_tables
from main import app
from models import PlatformAdmin


async def _platform_headers() -> dict:
    admin_id = None
    async with AsyncSessionLocal() as db:
        admin = PlatformAdmin(
            email=f"apk-{uuid.uuid4()}@example.com",
            password_hash=hash_password("password"),
            display_name="APK Tester",
            role="super_admin",
            is_active=True,
        )
        db.add(admin)
        await db.commit()
        await db.refresh(admin)
        admin_id = admin.id
    return {"Authorization": f"Bearer {create_platform_token(admin_id)}"}


def _valid_apk_bytes(marker: bytes = b"dummy-apk-bytes") -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        # A real APK has a binary AndroidManifest.xml; pyaxmlparser will not
        # parse this placeholder, so manual version fallback remains covered.
        for name, data in {
            "AndroidManifest.xml": b"\x03\x00placeholder-manifest",
            "classes.dex": marker,
        }.items():
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            archive.writestr(info, data)
    return buffer.getvalue()


def _apk_file(content: bytes | None = None):
    content = content if content is not None else _valid_apk_bytes()
    return {"file": ("app-release.apk", content, "application/vnd.android.package-archive")}


@pytest.mark.asyncio(loop_scope="session")
async def test_apk_upload_publishes_and_serves_and_guards_version():
    await create_tables()
    headers = await _platform_headers()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Start from a clean slate (the test DB persists across runs).
        await client.delete("/platform/app-update", headers=headers)

        # First upload (manual version fallback) publishes the update.
        published = await client.post(
            "/platform/app-update/upload",
            headers=headers,
            files=_apk_file(_valid_apk_bytes()),
            data={
                "versionName": "1.4.0",
                "versionCode": "5",
                "releaseNotes": "Faster sync",
                "required": "true",
            },
        )
        assert published.status_code == 200, published.text
        data = published.json()["data"]
        assert data["enabled"] is True
        assert data["versionName"] == "1.4.0"
        assert data["versionCode"] == 5
        assert data["required"] is True
        assert data["apkUrl"] == f"{settings.BASE_URL.rstrip('/')}/app-download/app-release.apk?v=5"
        assert data["autoDetectedVersion"] is False

        # The platform read reflects it (the device-facing GET /admin/app-update
        # reads the same SystemConfig key via get_app_update).
        platform_read = await client.get("/platform/app-update", headers=headers)
        assert platform_read.json()["data"]["versionCode"] == 5
        assert platform_read.json()["data"]["apkUrl"] == data["apkUrl"]

        # The APK is downloadable, unauthenticated, with the right content type.
        download = await client.get("/app-download/app-release.apk")
        assert download.status_code == 200
        assert download.content == _valid_apk_bytes()
        assert download.headers["content-type"] == "application/vnd.android.package-archive"

        # Version guard: re-publishing the same (or lower) code is rejected.
        same = await client.post(
            "/platform/app-update/upload",
            headers=headers,
            files=_apk_file(_valid_apk_bytes(b"should-not-replace")),
            data={"versionName": "1.4.0", "versionCode": "5"},
        )
        assert same.status_code == 409
        # The rejected upload must NOT clobber the published APK.
        unchanged = await client.get("/app-download/app-release.apk")
        assert unchanged.content == _valid_apk_bytes()

        # A higher version publishes and bumps the cache-busting URL.
        higher = await client.post(
            "/platform/app-update/upload",
            headers=headers,
            files=_apk_file(_valid_apk_bytes(b"newer-build")),
            data={"versionName": "1.5.0", "versionCode": "6"},
        )
        assert higher.status_code == 200
        assert higher.json()["data"]["apkUrl"].endswith("?v=6")
        assert (await client.get("/app-download/app-release.apk")).content == _valid_apk_bytes(b"newer-build")


@pytest.mark.asyncio(loop_scope="session")
async def test_apk_upload_requires_a_resolvable_version():
    await create_tables()
    headers = await _platform_headers()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # No manual version + unparseable file → 422 (and nothing published).
        missing = await client.post(
            "/platform/app-update/upload",
            headers=headers,
            files=_apk_file(_valid_apk_bytes()),
            data={"releaseNotes": "no version"},
        )
        assert missing.status_code == 422

        invalid = await client.post(
            "/platform/app-update/upload",
            headers=headers,
            files=_apk_file(b"not-an-apk"),
            data={"versionName": "9.9.9", "versionCode": "99"},
        )
        assert invalid.status_code == 422
        assert "valid APK ZIP" in invalid.text

        # Unauthenticated upload is rejected.
        anon = await client.post(
            "/platform/app-update/upload",
            files=_apk_file(_valid_apk_bytes()),
            data={"versionName": "9.9.9", "versionCode": "99"},
        )
        assert anon.status_code in (401, 403)
