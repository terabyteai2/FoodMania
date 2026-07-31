import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from config import settings
from database import AsyncSessionLocal
from models import MenuItem, Outlet
from routers.ws import _verify_token
from services.voice_agent import VoiceAgentSession

logger = logging.getLogger(__name__)

router = APIRouter()


@router.websocket("/ws/voice/{outlet_id}")
async def voice_agent_ws(ws: WebSocket, outlet_id: str, token: str = ""):
    logger.info("[voice] Connection attempt outlet=%s token_present=%s", outlet_id, bool(token))

    verified_id = _verify_token(token)
    if verified_id != outlet_id:
        logger.warning("[voice] Auth failed outlet=%s verified=%s", outlet_id, verified_id)
        await ws.close(code=4001)
        return

    logger.info("[voice] JWT verified outlet=%s", outlet_id)

    if not settings.ELEVENLABS_API_KEY.strip():
        logger.error("[voice] ElevenLabs API key not configured")
        await ws.close(code=4003, reason="ElevenLabs API key not configured")
        return

    logger.info("[voice] ElevenLabs key present, accepting connection")
    await ws.accept()

    async with AsyncSessionLocal() as db:
        outlet = await db.get(Outlet, outlet_id, options=[selectinload(Outlet.restaurant)])
        if not outlet:
            logger.warning("[voice] Outlet not found outlet=%s", outlet_id)
            await ws.close(code=4004)
            return

        logger.info("[voice] Outlet found outlet=%s name=%s", outlet_id, outlet.name)

        menu_items = (
            (await db.execute(
                select(MenuItem).where(
                    MenuItem.outlet_id == outlet_id,
                    MenuItem.is_available == True,
                    MenuItem.deleted_at == None,
                ).order_by(MenuItem.category, MenuItem.name).limit(300)
            )).scalars().all()
        )
        logger.info("[voice] Loaded %d menu items for outlet=%s", len(menu_items), outlet_id)

        session = VoiceAgentSession(ws, outlet, list(menu_items))
        try:
            logger.info("[voice] Starting session for outlet=%s", outlet_id)
            await session.run()
            logger.info("[voice] Session ended normally for outlet=%s", outlet_id)
        except WebSocketDisconnect:
            logger.info("[voice] Browser disconnected outlet=%s", outlet_id)
        except Exception as e:
            logger.error("[voice] Session error outlet=%s error=%s", outlet_id, e, exc_info=True)
        finally:
            await session.close()
            logger.info("[voice] Session closed outlet=%s", outlet_id)