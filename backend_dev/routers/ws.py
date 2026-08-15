import asyncio
import json
import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from jose import JWTError, jwt
from sqlalchemy import select

from config import settings
from services.support_llm import auto_reply as support_llm_auto_reply

logger = logging.getLogger(__name__)

router = APIRouter()

ALGORITHM = "HS256"
PING_INTERVAL = 30  # seconds


class ConnectionManager:
    def __init__(self):
        self._connections: dict[str, list[WebSocket]] = {}

    def _room(self, outlet_id: str) -> list[WebSocket]:
        return self._connections.setdefault(outlet_id, [])

    async def connect(self, outlet_id: str, ws: WebSocket) -> None:
        await ws.accept()
        self._room(outlet_id).append(ws)

    def disconnect(self, outlet_id: str, ws: WebSocket) -> None:
        # Use get() (not _room/setdefault) so disconnecting never creates a
        # room, and drop the key once empty — otherwise every outlet that ever
        # connects leaves a permanent empty list in _connections (slow leak).
        room = self._connections.get(outlet_id)
        if room is None:
            return
        if ws in room:
            room.remove(ws)
        if not room:
            self._connections.pop(outlet_id, None)

    async def broadcast(self, outlet_id: str, payload: dict) -> None:
        room = self._connections.get(outlet_id)
        if not room:
            return
        payload.setdefault("timestamp", datetime.now(timezone.utc).isoformat())
        message = json.dumps(payload)
        dead: list[WebSocket] = []
        for ws in list(room):
            try:
                await ws.send_text(message)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(outlet_id, ws)


manager = ConnectionManager()


def _verify_token(token: str) -> dict | None:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        return payload if isinstance(payload, dict) else None
    except JWTError:
        return None


async def _resolve_account(outlet_id: str, account_id: str | None):
    """Best-effort lookup of the sender's AdminAccount for the outlet.

    Bootstrap/older device tokens carry no account_id -> None (management
    tool calls stay allowed, mirroring the inventory API routes). Never
    raises: a failed lookup only downgrades the reply to the default role.
    """
    from database import AsyncSessionLocal
    from models import AdminAccount

    if not account_id:
        return None
    try:
        async with AsyncSessionLocal() as session:
            return (
                await session.execute(
                    select(AdminAccount).where(
                        AdminAccount.id == account_id,
                        AdminAccount.outlet_id == outlet_id,
                        AdminAccount.is_active.is_(True),
                    )
                )
            ).scalar_one_or_none()
    except Exception:
        return None


def _support_message_dict(message) -> dict:
    return {
        "id": message.id,
        "outletId": message.outlet_id,
        "role": message.role,
        "senderName": message.sender_name,
        "text": message.text,
        "actions": message.actions_json or [],
        "steps": message.steps_json or [],
        "replyStatus": message.reply_status,
        "replyReason": message.reply_reason,
        "replyError": message.reply_error,
        "replyDetail": message.reply_detail,
        "replyLatencyMs": message.reply_latency_ms,
        "replyModel": message.reply_model,
        "replyAttemptedAt": (
            message.reply_attempted_at.isoformat() if message.reply_attempted_at else None
        ),
        "createdAt": message.created_at.isoformat() if message.created_at else None,
    }


async def _persist_support_message(
    outlet_id: str, role: str, sender_name: str | None, text: str,
    actions: list | None = None, steps: list | None = None,
):
    from database import AsyncSessionLocal
    from models import SupportChatMessage

    message = SupportChatMessage(
        id=str(uuid.uuid4()),
        outlet_id=outlet_id,
        role=role,
        sender_name=sender_name,
        text=text,
        actions_json=actions,
        steps_json=steps,
    )
    async with AsyncSessionLocal() as session:
        session.add(message)
        await session.commit()
    return message


@router.websocket("/ws/{outlet_id}")
async def websocket_endpoint(ws: WebSocket, outlet_id: str, token: str = ""):
    payload = _verify_token(token)
    verified_id = payload.get("sub") if payload else None
    if verified_id != outlet_id:
        await ws.close(code=4001)
        return
    account_id = payload.get("account_id") if payload else None

    await manager.connect(outlet_id, ws)
    try:
        ping_task = asyncio.create_task(_ping_loop(ws))
        try:
            while True:
                raw = await ws.receive_text()
                # Client -> server messages are handled; keepalives are ignored.
                await _handle_client_message(ws, outlet_id, raw, account_id)
        finally:
            ping_task.cancel()
    except WebSocketDisconnect:
        pass
    finally:
        manager.disconnect(outlet_id, ws)


async def _handle_client_message(
    ws: WebSocket, outlet_id: str, raw: str, account_id: str | None = None
) -> None:
    try:
        payload = json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return
    if not isinstance(payload, dict):
        return
    mtype = payload.get("type")
    if mtype == "support_tts_mute":
        data = payload.get("data")
        if isinstance(data, dict):
            from services.support_tts import set_muted

            set_muted(outlet_id, bool(data.get("muted")))
        return
    if mtype == "support_stt":
        data = payload.get("data")
        if not isinstance(data, dict):
            return
        audio = str(data.get("audio") or "")
        if not audio:
            return
        sender_name = (
            str(data["senderName"]).strip() if data.get("senderName") else None
        )
        asyncio.create_task(_handle_support_stt(outlet_id, audio, sender_name, account_id))
        return
    if mtype != "support_msg":
        return
    data = payload.get("data")
    if not isinstance(data, dict):
        return
    text = str(data.get("text") or "").strip()
    if not text:
        return
    sender_name = (
        str(data["senderName"]).strip() if data.get("senderName") else None
    )
    try:
        message = await _persist_support_message(
            outlet_id=outlet_id,
            role="client",
            sender_name=sender_name,
            text=text,
        )
        await manager.broadcast(
            outlet_id,
            {
                "type": "support_msg",
                "data": _support_message_dict(message),
            },
        )
        account = await _resolve_account(outlet_id, account_id)
        asyncio.create_task(support_llm_auto_reply(outlet_id, account))
    except Exception as exc:
        # Never let a chat send kill the outlet's realtime connection, but do
        # log it — a silent failure here loses the message AND its auto-reply
        # trigger with no trace.
        logger.error(
            "[ws] failed to persist support message for outlet %s: %s",
            outlet_id,
            exc,
            exc_info=True,
        )


async def _handle_support_stt(
    outlet_id: str, audio: str, sender_name: str | None, account_id: str | None = None
) -> None:
    """Transcribe a support-chat voice clip and post it as a client message.

    Runs off the socket loop. On success the transcript is persisted and
    broadcast exactly like a typed ``support_msg`` (which also triggers the
    assistant auto-reply + TTS). Always acks the outlet with
    ``support_stt_result`` so the client can clear its sending state.
    """
    from services.support_stt import transcribe_audio

    status = "ok"
    transcript = ""
    try:
        transcript = await transcribe_audio(audio)
    except Exception as exc:
        status = "error"
        logger.error(
            "[ws] support_stt transcription failed outlet=%s: %s",
            outlet_id,
            exc,
            exc_info=True,
        )
    if not transcript:
        status = "empty" if status == "ok" else "error"
    if transcript:
        try:
            message = await _persist_support_message(
                outlet_id=outlet_id,
                role="client",
                sender_name=sender_name,
                text=transcript,
            )
            await manager.broadcast(
                outlet_id,
                {
                    "type": "support_msg",
                    "data": _support_message_dict(message),
                },
            )
            account = await _resolve_account(outlet_id, account_id)
            asyncio.create_task(support_llm_auto_reply(outlet_id, account))
        except Exception as exc:
            status = "error"
            logger.error(
                "[ws] failed to persist support_stt message for outlet %s: %s",
                outlet_id,
                exc,
                exc_info=True,
            )
    await manager.broadcast(
        outlet_id,
        {
            "type": "support_stt_result",
            "data": {"status": status, "transcript": transcript},
        },
    )


async def _ping_loop(ws: WebSocket) -> None:
    try:
        while True:
            await asyncio.sleep(PING_INTERVAL)
            await ws.send_text(json.dumps({"type": "ping"}))
    except Exception:
        pass
