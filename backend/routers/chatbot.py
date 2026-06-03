import hashlib
import html
import hmac
import json
from urllib.parse import urlencode

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_device_payload
from config import settings
from database import get_db
from routers.admin import _current_account
from schemas import (
    FacebookChatbotConfigRequest,
    FacebookChatbotNativeOAuthRequest,
    FacebookChatbotOAuthCompleteRequest,
    ok,
)
from services.facebook_chatbot import (
    complete_facebook_native_oauth,
    complete_facebook_oauth_page_selection,
    complete_facebook_oauth,
    create_facebook_oauth_url,
    get_facebook_config,
    get_facebook_oauth_pages,
    handle_facebook_webhook,
    save_facebook_config,
)

router = APIRouter()
CHATBOT_ADMIN_ROLES = {"manager", "owner"}


async def _current_chatbot_admin(payload: dict, db: AsyncSession):
    account = await _current_account(payload, db)
    if (account.role or "").strip().lower() not in CHATBOT_ADMIN_ROLES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Manager or owner access required.",
        )
    return account


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
    account = await _current_chatbot_admin(payload, db)
    return ok(await get_facebook_config(db, account.outlet_id))


@router.put("/admin/chatbot/facebook")
async def update_facebook_chatbot_config(
    body: FacebookChatbotConfigRequest,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    account = await _current_chatbot_admin(payload, db)
    data = await save_facebook_config(
        db=db,
        outlet_id=account.outlet_id,
        page_access_token=body.pageAccessToken,
        is_enabled=body.isEnabled,
        ordering_enabled=body.orderingEnabled,
    )
    return ok(data)


@router.post("/admin/chatbot/facebook/oauth/start")
async def start_facebook_chatbot_oauth(
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    account = await _current_chatbot_admin(payload, db)
    return ok(create_facebook_oauth_url(outlet_id=account.outlet_id, account_id=account.id))


@router.get("/admin/chatbot/facebook/oauth/callback", include_in_schema=False)
async def facebook_chatbot_oauth_callback(
    code: str | None = Query(None),
    state: str | None = Query(None),
    error: str | None = Query(None),
    error_description: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    if error:
        return _facebook_oauth_done_redirect(error_description or error, success=False)
    if not code or not state:
        return _facebook_oauth_done_redirect("Facebook Login did not return a code.", success=False)
    try:
        data = await complete_facebook_oauth(db=db, state_token=state, code=code)
    except HTTPException as exc:
        return _facebook_oauth_done_redirect(str(exc.detail), success=False)
    return _facebook_oauth_done_redirect(
        "Choose the Facebook Page to connect.",
        success=True,
        session_id=str(data["sessionId"]),
    )


@router.get("/admin/chatbot/facebook/oauth/pages")
async def get_facebook_chatbot_oauth_pages(
    session_id: str = Query(..., alias="sessionId"),
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    account = await _current_chatbot_admin(payload, db)
    return ok(
        await get_facebook_oauth_pages(
            db, session_id=session_id, outlet_id=account.outlet_id, account_id=account.id
        )
    )


@router.post("/admin/chatbot/facebook/oauth/native")
async def complete_facebook_chatbot_native_oauth(
    body: FacebookChatbotNativeOAuthRequest,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    account = await _current_chatbot_admin(payload, db)
    return ok(
        await complete_facebook_native_oauth(
            db=db,
            outlet_id=account.outlet_id,
            account_id=account.id,
            user_access_token=body.userAccessToken,
        )
    )


@router.post("/admin/chatbot/facebook/oauth/complete")
async def complete_facebook_chatbot_oauth(
    body: FacebookChatbotOAuthCompleteRequest,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    account = await _current_chatbot_admin(payload, db)
    return ok(
        await complete_facebook_oauth_page_selection(
            db,
            session_id=body.sessionId,
            page_id=body.pageId,
            outlet_id=account.outlet_id,
            account_id=account.id,
        )
    )


@router.get("/admin/chatbot/facebook/oauth/done", include_in_schema=False)
async def facebook_chatbot_oauth_done(
    status_value: str = Query("error", alias="status"),
    message: str = "",
):
    success = status_value == "success"
    title = "Facebook Messenger connected" if success else "Facebook connection failed"
    body = (
        "Your Facebook Page is connected. Return to Terafoods to continue."
        if success
        else (message or "Facebook Login could not be completed.")
    )
    color = "#3D7A5A" if success else "#A32D2D"
    escaped_title = html.escape(title)
    escaped_body = html.escape(body)
    return HTMLResponse(
        f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{escaped_title}</title>
  <style>
    body {{
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #F7F4EE;
      color: #1C1A17;
    }}
    main {{
      width: min(440px, calc(100vw - 32px));
      background: #FFFFFF;
      border: 1px solid #E8E4DC;
      border-radius: 12px;
      padding: 24px;
    }}
    .mark {{
      width: 44px;
      height: 44px;
      border-radius: 999px;
      display: grid;
      place-items: center;
      background: {color};
      color: #FFFFFF;
      font-size: 16px;
      font-weight: 600;
      margin-bottom: 14px;
    }}
    h1 {{ font-size: 22px; margin: 0 0 8px; font-weight: 600; }}
    p {{ font-size: 15px; line-height: 1.5; margin: 0; color: #55514A; }}
  </style>
</head>
<body>
  <main>
    <div class="mark">{"OK" if success else "!"}</div>
    <h1>{escaped_title}</h1>
    <p>{escaped_body}</p>
  </main>
</body>
</html>"""
    )


def _facebook_oauth_done_redirect(
    message: str, *, success: bool, session_id: str | None = None
) -> RedirectResponse:
    params = {"status": "success" if success else "error", "message": message}
    if session_id:
        params["sessionId"] = session_id
    return RedirectResponse(
        url=f"/admin/chatbot/facebook/oauth/done?{urlencode(params)}",
        status_code=status.HTTP_303_SEE_OTHER,
    )


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
