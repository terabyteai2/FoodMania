from fastapi import APIRouter
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
    })
