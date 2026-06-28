import asyncio
import json
from datetime import datetime, timezone

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from jose import JWTError, jwt

from config import settings

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
                # Keep alive — client messages are ignored but connection stays open
                await ws.receive_text()
        finally:
            ping_task.cancel()
    except WebSocketDisconnect:
        pass
    finally:
        manager.disconnect(outlet_id, ws)


async def _ping_loop(ws: WebSocket) -> None:
    try:
        while True:
            await asyncio.sleep(PING_INTERVAL)
            await ws.send_text(json.dumps({"type": "ping"}))
    except Exception:
        pass
