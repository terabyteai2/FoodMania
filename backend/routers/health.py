from fastapi import APIRouter
from config import settings
from schemas import ok

router = APIRouter()


@router.get("/health")
async def health():
    return ok({
        "status": "ok",
        "realtime": {
            "enabled": False,
            "supabaseUrl": "",
            "publishableKey": "",
            "channelPrefix": "pos:outlet:",
        },
        "staffDevBypassEnabled": bool(settings.STAFF_DEV_BYPASS_SECRET.strip()),
    })
