import hashlib
import hmac
import json

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_device_payload
from config import settings
from database import get_db
from routers.admin import _current_account
from schemas import FacebookChatbotConfigRequest, ok
from services.facebook_chatbot import (
    get_facebook_config,
    handle_facebook_webhook,
    save_facebook_config,
)

router = APIRouter()


@router.get("/webhooks/facebook", include_in_schema=False)
async def verify_facebook_webhook(
    hub_mode: str | None = Query(None, alias="hub.mode"),
    hub_verify_token: str | None = Query(None, alias="hub.verify_token"),
    hub_challenge: str | None = Query(None, alias="hub.challenge"),
):
    expected = settings.FACEBOOK_WEBHOOK_VERIFY_TOKEN.strip()
    if (
        hub_mode == "subscribe"
        and expected
        and (hub_verify_token or "").strip() == expected
        and hub_challenge is not None
    ):
        return Response(content=hub_challenge, media_type="text/plain")
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid webhook token.")


@router.post("/webhooks/facebook", include_in_schema=False)
async def receive_facebook_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    raw = await request.body()
    _verify_signature(raw, request.headers.get("X-Hub-Signature-256"))
    try:
        payload = json.loads(raw.decode("utf-8") or "{}")
    except json.JSONDecodeError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid JSON.") from error
    await handle_facebook_webhook(db, payload)
    return {"success": True}


@router.get("/admin/chatbot/facebook")
async def get_facebook_chatbot_config(
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    account = await _current_account(payload, db, require_manager=True)
    return ok(await get_facebook_config(db, account.outlet_id))


@router.put("/admin/chatbot/facebook")
async def update_facebook_chatbot_config(
    body: FacebookChatbotConfigRequest,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    account = await _current_account(payload, db, require_manager=True)
    data = await save_facebook_config(
        db=db,
        outlet_id=account.outlet_id,
        page_access_token=body.pageAccessToken,
        is_enabled=body.isEnabled,
        ordering_enabled=body.orderingEnabled,
    )
    return ok(data)


def _verify_signature(raw_body: bytes, signature: str | None) -> None:
    secret = settings.FACEBOOK_APP_SECRET.strip()
    if not secret:
        return
    if not signature or not signature.startswith("sha256="):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid signature.")
    expected = hmac.new(secret.encode("utf-8"), raw_body, hashlib.sha256).hexdigest()
    actual = signature.split("=", 1)[1]
    if not hmac.compare_digest(expected, actual):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid signature.")
