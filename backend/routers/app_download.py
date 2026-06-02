"""Public (unauthenticated) download of the latest admin APK.

The Android app's AppUpdateInstallerService.downloadApk() does a plain
http.get(apkUrl) with no auth header, so this route must be open. The file is
the app binary, not sensitive data.
"""

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import FileResponse

from services.app_update import apk_path

router = APIRouter()


@router.get("/app-download/app-release.apk", include_in_schema=False)
async def download_admin_apk():
    path = apk_path()
    if not path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No APK has been published yet.",
        )
    return FileResponse(
        str(path),
        media_type="application/vnd.android.package-archive",
        filename="app-release.apk",
        headers={"Cache-Control": "no-store, max-age=0"},
    )
