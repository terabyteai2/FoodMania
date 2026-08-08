"""Unified file storage: local filesystem (dev) or Cloudflare R2 (production).

Switches automatically based on R2_* env vars. All upload routers use this
module instead of writing to disk directly, so the deploy target can be
swapped without code changes.
"""
import os
from typing import Optional

from config import settings


def use_r2() -> bool:
    return bool(
        settings.R2_ENDPOINT
        and settings.R2_ACCESS_KEY_ID
        and settings.R2_SECRET_ACCESS_KEY
        and settings.R2_BUCKET
    )


# ── Local filesystem implementation ──────────────────────────────────────────
def _local_save(rel_path: str, content: bytes) -> None:
    full_path = os.path.join("uploads", rel_path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "wb") as f:
        f.write(content)


def _local_delete(rel_path: str) -> None:
    full_path = os.path.realpath(os.path.join("uploads", rel_path))
    uploads_root = os.path.realpath("uploads")
    if full_path.startswith(uploads_root + os.sep) and os.path.isfile(full_path):
        try:
            os.remove(full_path)
        except OSError:
            pass


def _local_url(request, rel_path: str) -> str:
    base = str(request.base_url).rstrip("/")
    return f"{base}/uploads/{rel_path}"


# ── R2 (S3-compatible) implementation ────────────────────────────────────────
_r2_client = None


def _get_r2_client():
    global _r2_client
    if _r2_client is None:
        import boto3
        from botocore.config import Config
        _r2_client = boto3.client(
            "s3",
            endpoint_url=settings.R2_ENDPOINT,
            aws_access_key_id=settings.R2_ACCESS_KEY_ID,
            aws_secret_access_key=settings.R2_SECRET_ACCESS_KEY,
            config=Config(signature_version="s3v4"),
            region_name="auto",
        )
    return _r2_client


def _guess_content_type(rel_path: str) -> str:
    ext = rel_path.rsplit(".", 1)[-1].lower() if "." in rel_path else ""
    return {
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "webp": "image/webp",
        "gif": "image/gif",
        "mp4": "video/mp4",
        "mov": "video/quicktime",
        "webm": "video/webm",
        "m4v": "video/x-m4v",
    }.get(ext, "application/octet-stream")


def _r2_save(rel_path: str, content: bytes) -> None:
    client = _get_r2_client()
    client.put_object(
        Bucket=settings.R2_BUCKET,
        Key=rel_path,
        Body=content,
        ContentType=_guess_content_type(rel_path),
    )


def _r2_delete(rel_path: str) -> None:
    client = _get_r2_client()
    try:
        client.delete_object(Bucket=settings.R2_BUCKET, Key=rel_path)
    except Exception:
        pass


def _r2_url(_request, rel_path: str) -> str:
    base = settings.R2_PUBLIC_BASE_URL.rstrip("/")
    return f"{base}/{rel_path}"


# ── Public API used by routers ───────────────────────────────────────────────
def save(rel_path: str, content: bytes, request) -> str:
    """Save bytes at ``rel_path`` (under uploads/) and return the public URL."""
    if use_r2():
        _r2_save(rel_path, content)
        return _r2_url(request, rel_path)
    _local_save(rel_path, content)
    return _local_url(request, rel_path)


def delete_by_url(public_url: Optional[str]) -> None:
    """Best-effort delete of a previously-saved file given its public URL."""
    if not public_url:
        return
    marker = "/uploads/"
    if marker in public_url:
        rel = public_url.split(marker, 1)[1]
    elif use_r2() and settings.R2_PUBLIC_BASE_URL and public_url.startswith(settings.R2_PUBLIC_BASE_URL):
        rel = public_url[len(settings.R2_PUBLIC_BASE_URL):].lstrip("/")
    else:
        return
    if use_r2():
        _r2_delete(rel)
    else:
        _local_delete(rel)


def list_keys(prefix: str) -> list[str]:
    """List object keys under ``prefix`` (used for cleanup of old hero videos)."""
    if use_r2():
        client = _get_r2_client()
        resp = client.list_objects_v2(Bucket=settings.R2_BUCKET, Prefix=prefix)
        return [obj["Key"] for obj in resp.get("Contents", [])]
    full_dir = os.path.join("uploads", prefix)
    if not os.path.isdir(full_dir):
        return []
    return [os.path.join(prefix, name) for name in os.listdir(full_dir)]


def delete_key(key: str) -> None:
    if use_r2():
        _r2_delete(key)
    else:
        _local_delete(key)
