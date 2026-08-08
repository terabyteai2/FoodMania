import asyncio
import json
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from jose import JWTError, jwt

from config import settings
from services.support_llm import auto_reply as support_llm_auto_reply

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


def _verify_token(token: str) -> str | None:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        return payload.get("sub")
    except JWTError:
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
    verified_id = _verify_token(token)
    if verified_id != outlet_id:
        await ws.close(code=4001)
        return

    await manager.connect(outlet_id, ws)
    try:
        ping_task = asyncio.create_task(_ping_loop(ws))
        try:
            while True:
                raw = await ws.receive_text()
                # Client -> server messages are handled; keepalives are ignored.
                await _handle_client_message(ws, outlet_id, raw)
        finally:
            ping_task.cancel()
    except WebSocketDisconnect:
        pass
    finally:
        manager.disconnect(outlet_id, ws)


async def _handle_client_message(ws: WebSocket, outlet_id: str, raw: str) -> None:
    try:
        payload = json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return
    if not isinstance(payload, dict) or payload.get("type") != "support_msg":
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
        asyncio.create_task(support_llm_auto_reply(outlet_id))
    except Exception:
        # Never let a chat send kill the outlet's realtime connection.
        pass


async def _ping_loop(ws: WebSocket) -> None:
    try:
        while True:
            await asyncio.sleep(PING_INTERVAL)
            await ws.send_text(json.dumps({"type": "ping"}))
    except Exception:
        pass
