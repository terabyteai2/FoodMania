import hashlib
import html
import hmac
import json
from datetime import datetime, timezone
from urllib.parse import urlencode

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_device_payload
from config import settings
from database import get_db
from models import ChatbotConversation, ChatbotIntegration
from routers.admin import _current_account
from schemas import (
    ChatReplyRequest,
    FacebookChatbotConfigRequest,
    FacebookChatbotNativeOAuthRequest,
    FacebookChatbotOAuthCompleteRequest,
    ok,
)
from services.facebook_chatbot import (
    CHAT_HISTORY_APP_LIMIT,
    ChatbotError,
    append_chat_history,
    broadcast_chat_update,
    complete_facebook_native_oauth,
    complete_facebook_oauth_page_selection,
    complete_facebook_oauth,
    create_facebook_oauth_url,
    get_facebook_config,
    get_latest_facebook_oauth_pages,
    get_facebook_oauth_pages,
    handle_facebook_webhook,
    recent_chat_history,
    save_facebook_config,
    _send_message,
)

router = APIRouter()
CHATBOT_ADMIN_ROLES = {"manager", "owner"}
_CHAT_FROM = {
    "user": "customer",
    "bot": "bot",
    "manager": "manager",
    "system": "system",
}


def _chat_now() -> datetime:
    return datetime.now(timezone.utc)


def _chat_status(state: dict) -> str:
    value = str((state or {}).get("status") or "").strip().lower()
    return value if value in {"needs", "replied", "bot"} else "bot"


def _chat_dict(conv: ChatbotConversation) -> dict:
    state = conv.state_json or {}
    history = recent_chat_history(conv.history_json, limit=CHAT_HISTORY_APP_LIMIT)
    messages = [
        {
            "from": _CHAT_FROM.get(str(entry.get("role") or ""), "system"),
            "text": str(entry.get("text") or ""),
            "kind": entry.get("kind"),
            "at": entry.get("at") or entry.get("time") or entry.get("createdAt"),
        }
        for entry in history
        if isinstance(entry, dict)
    ]
    return {
        "id": conv.id,
        "psid": conv.psid,
        "name": state.get("customerName") or "Messenger customer",
        "handle": conv.psid[-6:] if conv.psid else "",
        "status": _chat_status(state),
        "reason": state.get("reason"),
        "lastUserMessage": conv.last_user_message,
        "lastBotMessage": conv.last_bot_message,
        "unread": int(state.get("unread") or 0),
        "updatedAt": conv.updated_at.isoformat(),
        "messages": messages,
    }


async def _integration_for_account(account, db: AsyncSession) -> ChatbotIntegration | None:
    return (
        await db.execute(
            select(ChatbotIntegration).where(
                ChatbotIntegration.outlet_id == account.outlet_id
            )
        )
    ).scalar_one_or_none()


async def _conversation_for_account(
    conversation_id: str, account, db: AsyncSession
) -> tuple[ChatbotConversation, ChatbotIntegration]:
    conv = (
        await db.execute(
            select(ChatbotConversation).where(ChatbotConversation.id == conversation_id)
        )
    ).scalar_one_or_none()
    if conv is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chat not found.")
    integration = (
        await db.execute(
            select(ChatbotIntegration).where(ChatbotIntegration.id == conv.integration_id)
        )
    ).scalar_one_or_none()
    if integration is None or integration.outlet_id != account.outlet_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Chat not in this outlet.")
    return conv, integration


@router.get("/admin/chatbot/chats")
async def list_chats(
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    account = await _current_chatbot_admin(payload, db)
    integration = await _integration_for_account(account, db)
    if integration is None:
        return ok({"chats": []})
    conversations = (
        await db.execute(
            select(ChatbotConversation)
            .where(ChatbotConversation.integration_id == integration.id)
            .order_by(ChatbotConversation.updated_at.desc())
            .limit(100)
        )
    ).scalars().all()
    return ok({"chats": [_chat_dict(c) for c in conversations]})


@router.post("/admin/chatbot/chats/{conversation_id}/reply")
async def reply_to_chat(
    conversation_id: str,
    body: ChatReplyRequest,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    account = await _current_chatbot_admin(payload, db)
    conv, integration = await _conversation_for_account(conversation_id, account, db)
    text = (body.text or "").strip()
    if not text:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Reply text required."
        )
    try:
        await _send_message(integration, conv.psid, text)
    except ChatbotError as error:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(error))
    append_chat_history(conv, role="manager", text=text)
    state = dict(conv.state_json or {})
    state["status"] = "replied"
    state["unread"] = 0
    conv.state_json = state
    conv.last_bot_message = text
    conv.updated_at = _chat_now()
    await db.commit()
    await db.refresh(conv)
    await broadcast_chat_update(integration, conv)
    return ok(_chat_dict(conv))


@router.post("/admin/chatbot/chats/{conversation_id}/handback")
async def hand_chat_back_to_bot(
    conversation_id: str,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    account = await _current_chatbot_admin(payload, db)
    conv, integration = await _conversation_for_account(conversation_id, account, db)
    append_chat_history(conv, role="system", text="Handed back to bot")
    state = dict(conv.state_json or {})
    state["status"] = "bot"
    state.pop("reason", None)
    conv.state_json = state
    conv.updated_at = _chat_now()
    await db.commit()
    await db.refresh(conv)
    await broadcast_chat_update(integration, conv)
    return ok(_chat_dict(conv))


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


@router.get("/admin/chatbot/facebook/oauth/latest-pages")
async def get_latest_facebook_chatbot_oauth_pages(
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    account = await _current_chatbot_admin(payload, db)
    data = await get_latest_facebook_oauth_pages(
        db, outlet_id=account.outlet_id, account_id=account.id
    )
    if data is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Facebook Login is not complete yet.",
        )
    return ok(data)


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
