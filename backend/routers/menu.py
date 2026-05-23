import base64
import logging
import uuid
from datetime import datetime, timedelta, timezone

import pydantic
from fastapi import APIRouter, Depends, File, Header, HTTPException, Request, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

import storage
from auth import get_current_device_payload, get_current_outlet_id
from config import settings
from database import get_db
from models import AdminAccount, MenuItem, Outlet
from routers.ws import manager
from schemas import ImageUploadRequest, MenuItemPayload, ok
from services.menu_scan import MenuScanError, extract_menu_page_texts, parse_menu_text

router = APIRouter()
logger = logging.getLogger(__name__)


def _item_to_dict(item: MenuItem) -> dict:
    return {
        "id": item.id,
        "outletId": item.outlet_id,
        "name": item.name,
        "nameEn": item.name_en or item.name,
        "nameBn": item.name_bn or "",
        "description": item.description,
        "descriptionEn": item.description_en or item.description or "",
        "descriptionBn": item.description_bn or "",
        "price": float(item.price),
        "category": item.category,
        "categoryEn": item.category_en or item.category or "General",
        "categoryBn": item.category_bn or "",
        "isAvailable": item.is_available,
        "imageUrl": item.image_url,
        "version": item.version,
        "updatedAt": item.updated_at.isoformat(),
        "deletedAt": item.deleted_at.isoformat() if item.deleted_at else None,
    }


def _clean(value: str | None) -> str | None:
    if value is None:
        return None
    cleaned = value.strip()
    return cleaned or None


def _apply_menu_payload(
    item: MenuItem, body: MenuItemPayload, image_url: str | None
) -> None:
    name_en = _clean(body.nameEn) or body.name.strip()
    name_bn = _clean(body.nameBn)
    description_en = _clean(body.descriptionEn) or _clean(body.description)
    description_bn = _clean(body.descriptionBn)
    category_en = _clean(body.categoryEn) or _clean(body.category) or "General"
    category_bn = _clean(body.categoryBn)

    item.name = name_en
    item.name_en = name_en
    item.name_bn = name_bn
    item.description = description_en
    item.description_en = description_en
    item.description_bn = description_bn
    item.price = body.price
    item.category = category_en
    item.category_en = category_en
    item.category_bn = category_bn
    item.is_available = body.isAvailable
    item.image_url = image_url
    item.version = max(item.version, body.version)
    item.updated_at = datetime.now(timezone.utc)
    item.deleted_at = None


def _ensure_outlet(current_outlet: str, outlet_id: str) -> None:
    if current_outlet != outlet_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Outlet token mismatch.",
        )


def _parse_since(value: str) -> datetime:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid since timestamp.",
        ) from exc

    dt = parsed if parsed.tzinfo is not None else parsed.replace(tzinfo=timezone.utc)
    now = datetime.now(timezone.utc)
    if dt > now + timedelta(seconds=30):
        return now - timedelta(seconds=5)
    return dt


async def _require_manager_scan_access(
    outlet_id: str,
    payload: dict,
    db: AsyncSession,
) -> None:
    token_outlet_id = str(payload.get("sub") or "")
    account_id = str(payload.get("account_id") or "")
    if token_outlet_id != outlet_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Outlet token mismatch.")
    if not account_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Manager account token required.")
    account = (
        await db.execute(select(AdminAccount).where(AdminAccount.id == account_id))
    ).scalar_one_or_none()
    if account is None or not account.is_active or account.outlet_id != outlet_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Manager account is not active.")
    if account.role != "manager":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Manager access required.")


def _save_data_url_image(image_url: str | None, request: Request) -> str | None:
    if not image_url or not image_url.startswith("data:image/"):
        return image_url
    try:
        header, encoded = image_url.split(",", 1)
        image_bytes = base64.b64decode(encoded)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid image data URL.")

    ext = "png" if "png" in header else "jpg"
    filename = f"{uuid.uuid4()}.{ext}"
    return storage.save(f"menu_images/{filename}", image_bytes, request)


@router.get("/outlets/{outlet_id}/menu")
async def pull_menu(
    outlet_id: str,
    since: str | None = None,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
    query = select(MenuItem).where(MenuItem.outlet_id == outlet_id)
    if since:
        dt = _parse_since(since)
        query = query.where(MenuItem.updated_at > dt)
    items = (await db.execute(query)).scalars().all()
    return ok([_item_to_dict(i) for i in items])


@router.post("/outlets/{outlet_id}/menu")
async def push_menu_item(
    outlet_id: str,
    body: MenuItemPayload,
    request: Request,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
    idempotency_key: str | None = Header(None, alias="Idempotency-Key"),
):
    _ensure_outlet(current_outlet, outlet_id)
    image_url = _save_data_url_image(body.imageUrl, request)
    existing = (await db.execute(select(MenuItem).where(MenuItem.id == body.id))).scalar_one_or_none()
    if existing:
        existing.outlet_id = outlet_id
        _apply_menu_payload(existing, body, image_url)
        await db.commit()
        await db.refresh(existing)
        await manager.broadcast(outlet_id, {"type": "menu_updated", "data": _item_to_dict(existing)})
        return ok(_item_to_dict(existing))

    item = MenuItem(
        id=body.id,
        outlet_id=outlet_id,
        version=body.version,
        updated_at=datetime.now(timezone.utc),
    )
    _apply_menu_payload(item, body, image_url)
    db.add(item)
    await db.commit()
    await db.refresh(item)

    await manager.broadcast(outlet_id, {"type": "menu_updated", "data": _item_to_dict(item)})
    return ok(_item_to_dict(item))


@router.patch("/outlets/{outlet_id}/menu/{item_id}")
async def update_menu_item(
    outlet_id: str,
    item_id: str,
    body: MenuItemPayload,
    request: Request,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
    idempotency_key: str | None = Header(None, alias="Idempotency-Key"),
):
    _ensure_outlet(current_outlet, outlet_id)
    image_url = _save_data_url_image(body.imageUrl, request)
    item = (await db.execute(select(MenuItem).where(MenuItem.id == item_id))).scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Menu item not found.")

    _apply_menu_payload(item, body, image_url)
    item.version = body.version
    await db.commit()
    await db.refresh(item)

    await manager.broadcast(outlet_id, {"type": "menu_updated", "data": _item_to_dict(item)})
    return ok(_item_to_dict(item))


@router.delete("/outlets/{outlet_id}/menu/{item_id}")
async def delete_menu_item(
    outlet_id: str,
    item_id: str,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
    idempotency_key: str | None = Header(None, alias="Idempotency-Key"),
):
    _ensure_outlet(current_outlet, outlet_id)
    item = (await db.execute(select(MenuItem).where(MenuItem.id == item_id))).scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Menu item not found.")

    item.deleted_at = datetime.now(timezone.utc)
    item.updated_at = datetime.now(timezone.utc)
    await db.commit()

    await manager.broadcast(outlet_id, {"type": "menu_updated", "data": _item_to_dict(item)})
    return ok({"deleted": True})


@router.post("/outlets/{outlet_id}/menu/images")
async def upload_menu_image(
    outlet_id: str,
    body: ImageUploadRequest,
    request: Request,
    current_outlet: str = Depends(get_current_outlet_id),
):
    _ensure_outlet(current_outlet, outlet_id)
    # Parse data URL:  data:image/jpeg;base64,<data>
    try:
        header, encoded = body.dataUrl.split(",", 1)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid dataUrl format.")

    image_bytes = base64.b64decode(encoded)
    ext = "jpg"
    if "png" in header:
        ext = "png"

    filename = f"{uuid.uuid4()}.{ext}"
    public_url = storage.save(f"menu_images/{filename}", image_bytes, request)
    return ok({"publicUrl": public_url})


@router.post("/outlets/{outlet_id}/menu/scan")
async def scan_menu_pages(
    outlet_id: str,
    files: list[UploadFile] = File(...),
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    await _require_manager_scan_access(outlet_id, payload, db)
    if not files:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Select at least one menu image.")

    pages: list[tuple[bytes, str]] = []
    for file in files:
        content_type = (file.content_type or "").lower()
        if not content_type.startswith("image/"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"{file.filename or 'Uploaded file'} is not an image.",
            )
        image_bytes = await file.read()
        if not image_bytes:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"{file.filename or 'Uploaded file'} is empty.",
            )
        pages.append((image_bytes, content_type))

    logger.info(
        "menu scan request accepted outlet=%s pages=%s bytes=%s content_types=%s",
        outlet_id,
        len(pages),
        sum(len(image_bytes) for image_bytes, _ in pages),
        [content_type for _, content_type in pages],
    )

    try:
        page_texts = await extract_menu_page_texts(pages)
        logger.info(
            "menu scan ocr complete outlet=%s pages=%s chars=%s",
            outlet_id,
            len(page_texts),
            [len(text) for text in page_texts],
        )
        parsed = await parse_menu_text(page_texts)
    except MenuScanError as error:
        logger.warning("menu scan failed outlet=%s error=%s", outlet_id, error)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(error),
        ) from error

    logger.info(
        "menu scan parsed outlet=%s provider=%s items=%s warnings=%s",
        outlet_id,
        parsed.provider,
        len(parsed.items),
        len(parsed.warnings),
    )
    return ok(
        {
            "items": [item.model_dump() for item in parsed.items],
            "provider": parsed.provider,
            "pageCount": len(pages),
            "warnings": parsed.warnings,
        }
    )


# ── Hero media endpoints (welcome-screen video + menu-page slider images) ─────
#
# Files are stored under:
#   hero_media/{outlet_id}/images/{uuid}.{ext}   ← menu-page slider
#   hero_media/{outlet_id}/video/{uuid}.{ext}    ← welcome-screen video


class OutletMediaPatch(pydantic.BaseModel):
    videoUrl: str | None = None


def _hero_images_prefix(outlet_id: str) -> str:
    return f"hero_media/{outlet_id}/images"


def _hero_video_prefix(outlet_id: str) -> str:
    return f"hero_media/{outlet_id}/video"


@router.post("/outlets/{outlet_id}/images")
async def upload_outlet_image(
    outlet_id: str,
    body: ImageUploadRequest,
    request: Request,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
    outlet = (await db.execute(select(Outlet).where(Outlet.id == outlet_id))).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Outlet not found.")

    gallery = list(outlet.gallery_images or [])
    if len(gallery) >= 5:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Maximum 5 hero images allowed.")

    try:
        header, encoded = body.dataUrl.split(",", 1)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid dataUrl format.")

    image_bytes = base64.b64decode(encoded)
    ext = "png" if "png" in header else "jpg"
    filename = f"{uuid.uuid4()}.{ext}"
    public_url = storage.save(f"{_hero_images_prefix(outlet_id)}/{filename}", image_bytes, request)
    gallery.append(public_url)
    outlet.gallery_images = gallery
    await db.commit()
    return ok({"publicUrl": public_url, "galleryImages": gallery})


@router.delete("/outlets/{outlet_id}/images/{index}")
async def delete_outlet_image(
    outlet_id: str,
    index: int,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
    outlet = (await db.execute(select(Outlet).where(Outlet.id == outlet_id))).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Outlet not found.")

    gallery = list(outlet.gallery_images or [])
    if index < 0 or index >= len(gallery):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Image index out of range.")

    removed_url = gallery.pop(index)
    outlet.gallery_images = gallery
    await db.commit()

    storage.delete_by_url(removed_url)

    return ok({"galleryImages": gallery})


@router.post("/outlets/{outlet_id}/video")
async def upload_outlet_video(
    outlet_id: str,
    request: Request,
    file: UploadFile = File(...),
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
    content = await file.read()
    if len(content) > settings.VIDEO_MAX_BYTES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,
                            detail=f"Video too large. Maximum {settings.VIDEO_MAX_BYTES // 1024 // 1024} MB allowed.")

    outlet = (await db.execute(select(Outlet).where(Outlet.id == outlet_id))).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Outlet not found.")

    name = file.filename or "video.mp4"
    ext = name.rsplit(".", 1)[-1].lower() if "." in name else "mp4"
    if ext not in ("mp4", "mov", "webm", "m4v"):
        ext = "mp4"
    filename = f"{uuid.uuid4()}.{ext}"
    prefix = _hero_video_prefix(outlet_id)
    new_key = f"{prefix}/{filename}"
    public_url = storage.save(new_key, content, request)

    # Only one welcome video per outlet — purge any previously stored clips
    # so storage doesn't grow unboundedly.
    for old_key in storage.list_keys(prefix):
        if old_key != new_key:
            storage.delete_key(old_key)

    outlet.video_url = public_url
    await db.commit()
    return ok({"videoUrl": public_url})


@router.patch("/outlets/{outlet_id}/media")
async def update_outlet_media(
    outlet_id: str,
    body: OutletMediaPatch,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    _ensure_outlet(current_outlet, outlet_id)
    outlet = (await db.execute(select(Outlet).where(Outlet.id == outlet_id))).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Outlet not found.")

    previous_url = outlet.video_url
    outlet.video_url = body.videoUrl
    await db.commit()

    if previous_url and previous_url != body.videoUrl:
        storage.delete_by_url(previous_url)

    return ok({"videoUrl": outlet.video_url})
