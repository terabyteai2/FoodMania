import asyncio
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import (
    get_current_device_payload,
    get_current_platform_admin_id,
)
from database import get_db
from models import PlatformAdmin, SupportChatMessage
from routers.ws import (
    _persist_support_message,
    _resolve_account,
    _support_message_dict,
)
from services.support_llm import (
    auto_reply as support_llm_auto_reply,
    diagnostics as support_llm_diagnostics,
)

router = APIRouter()


class SupportChatSendRequest(BaseModel):
    text: str


class SupportChatReplyRequest(BaseModel):
    text: str
    senderName: str | None = None
    actions: list[dict[str, Any]] | None = None
    steps: list[dict[str, Any]] | None = None


@router.get("/admin/support-chat")
async def get_support_chat_history(
    limit: int = Query(200, ge=1, le=500),
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    outlet_id = payload["sub"]
    rows = (
        await db.execute(
            select(SupportChatMessage)
            .where(SupportChatMessage.outlet_id == outlet_id)
            .order_by(SupportChatMessage.created_at.desc())
            .limit(limit)
        )
    ).scalars().all()
    messages = [_support_message_dict(m) for m in reversed(rows)]
    return {"data": {"messages": messages}, "error": None}


@router.post("/admin/support-chat")
async def send_support_chat_message(
    body: SupportChatSendRequest,
    payload: dict = Depends(get_current_device_payload),
    db: AsyncSession = Depends(get_db),
):
    text = body.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="text is required")
    message = await _persist_support_message(
        outlet_id=payload["sub"],
        role="client",
        sender_name=None,
        text=text,
    )
    from routers.ws import manager

    await manager.broadcast(
        payload["sub"],
        {"type": "support_msg", "data": _support_message_dict(message)},
    )
    account = await _resolve_account(
        payload["sub"], str(payload.get("account_id") or "")
    )
    asyncio.create_task(support_llm_auto_reply(payload["sub"], account))
    return {"data": _support_message_dict(message), "error": None}


@router.get("/admin/support-chat/diagnostics")
async def get_support_chat_diagnostics(
    payload: dict = Depends(get_current_device_payload),
):
    """Per-outlet auto-reply diagnostics: LLM config presence, in-flight /
    cooldown state, and the last messages with their recorded outcomes
    (status / reason / error / latency)."""
    outlet_id = payload["sub"]
    result = await support_llm_diagnostics(outlet_id)
    return {"data": result, "error": None}


@router.get("/platform/support-chats")
async def platform_list_support_chats(
    outlet_id: str | None = Query(None),
    limit: int = Query(100, ge=1, le=500),
    _admin_id: str = Depends(get_current_platform_admin_id),
    db: AsyncSession = Depends(get_db),
):
    query = select(SupportChatMessage)
    if outlet_id:
        query = query.where(SupportChatMessage.outlet_id == outlet_id)
    query = query.order_by(SupportChatMessage.created_at.desc()).limit(limit)
    rows = (await db.execute(query)).scalars().all()
    messages = [_support_message_dict(m) for m in reversed(rows)]
    return {"data": {"messages": messages}, "error": None}


@router.post("/platform/support-chats/{outlet_id}/reply")
async def platform_reply_to_support_chat(
    outlet_id: str,
    body: SupportChatReplyRequest,
    admin_id: str = Depends(get_current_platform_admin_id),
    db: AsyncSession = Depends(get_db),
):
    text = body.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="text is required")
    sender_name = body.senderName
    if sender_name is None:
        admin = (
            await db.execute(
                select(PlatformAdmin).where(PlatformAdmin.id == admin_id)
            )
        ).scalar_one_or_none()
        sender_name = (admin.display_name or "QuickBytes Support") if admin else "QuickBytes Support"
    message = await _persist_support_message(
        outlet_id=outlet_id,
        role="server",
        sender_name=sender_name,
        text=text,
        actions=body.actions,
        steps=body.steps,
    )
    from routers.ws import manager

    await manager.broadcast(
        outlet_id,
        {"type": "support_msg", "data": _support_message_dict(message)},
    )
    return {"data": _support_message_dict(message), "error": None}
