import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from config import settings
from database import AsyncSessionLocal
from models import MenuItem, Outlet
from routers.ws import _verify_token
from services.sarvam_voice_agent import SarvamVoiceAgentSession

logger = logging.getLogger(__name__)

router = APIRouter()


@router.websocket("/ws/sarvam-voice/{outlet_id}")
async def sarvam_voice_agent_ws(ws: WebSocket, outlet_id: str, token: str = ""):
    logger.info("[sarvam-voice] Connection attempt outlet=%s token_present=%s", outlet_id, bool(token))

    verified_id = _verify_token(token)
    if verified_id != outlet_id:
        logger.warning("[sarvam-voice] Auth failed outlet=%s verified=%s", outlet_id, verified_id)
        await ws.close(code=4001)
        return

    logger.info("[sarvam-voice] JWT verified outlet=%s", outlet_id)

    if not settings.SARVAM_API_KEY.strip():
        logger.error("[sarvam-voice] Sarvam API key not configured")
        await ws.close(code=4003, reason="Sarvam API key not configured")
        return

    logger.info("[sarvam-voice] Sarvam key present, accepting connection")
    await ws.accept()

    async with AsyncSessionLocal() as db:
        outlet = await db.get(Outlet, outlet_id, options=[selectinload(Outlet.restaurant)])
        if not outlet:
            logger.warning("[sarvam-voice] Outlet not found outlet=%s", outlet_id)
            await ws.close(code=4004)
            return

        logger.info("[sarvam-voice] Outlet found outlet=%s name=%s", outlet_id, outlet.name)

        menu_items = (
            (await db.execute(
                select(MenuItem).where(
                    MenuItem.outlet_id == outlet_id,
                    MenuItem.is_available == True,
                    MenuItem.deleted_at == None,
                ).order_by(MenuItem.category, MenuItem.name).limit(300)
            )).scalars().all()
        )
        logger.info("[sarvam-voice] Loaded %d menu items for outlet=%s", len(menu_items), outlet_id)

        session = SarvamVoiceAgentSession(ws, outlet, list(menu_items))
        try:
            logger.info("[sarvam-voice] Starting session for outlet=%s", outlet_id)
            await session.run()
            logger.info("[sarvam-voice] Session ended normally for outlet=%s", outlet_id)
        except WebSocketDisconnect:
            logger.info("[sarvam-voice] Browser disconnected outlet=%s", outlet_id)
        except Exception as e:
            logger.error("[sarvam-voice] Session error outlet=%s error=%s", outlet_id, e, exc_info=True)
        finally:
            await session.close()
            logger.info("[sarvam-voice] Session closed outlet=%s", outlet_id)
