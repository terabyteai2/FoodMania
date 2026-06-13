"""Public (unauthenticated) download of packaged software releases.

Files are served from ./uploads/software_downloads/ on the VPS.
Drop files there manually — this route returns 404 until they exist.
"""

import mimetypes
from pathlib import Path

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import FileResponse

router = APIRouter()
_DIR = Path("./uploads/software_downloads")


@router.get("/software-downloads/{filename}", include_in_schema=False)
async def download_software(filename: str):
    if "/" in filename or ".." in filename:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,
                            detail="Invalid filename.")
    path = _DIR / filename
    if not path.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                            detail="File not found.")
    media_type, _ = mimetypes.guess_type(filename)
    return FileResponse(
        str(path),
        filename=filename,
        media_type=media_type or "application/octet-stream",
        headers={"Cache-Control": "no-store, max-age=0"},
    )
