import os
import time
from contextlib import asynccontextmanager
from pathlib import Path

import uvicorn
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from config import settings
from database import create_tables
from routers import admin, customer, devices, health, menu, orders, payments, platform, tenants, ws

FRONTEND_DIST = Path(__file__).parent / "frontend_dist"


def _start_ngrok() -> str | None:
    token = settings.NGROK_AUTHTOKEN.strip()
    domain = settings.NGROK_STATIC_DOMAIN.strip()
    if not token or not domain:
        return None

    port = settings.PORT
    last_err: Exception | None = None
    for attempt in range(1, 4):
        try:
            from pyngrok import conf, ngrok

            conf.get_default().auth_token = token
            tunnel = ngrok.connect(
                addr=port,
                proto="http",
                domain=domain,
            )
            public_url: str = tunnel.public_url
            if public_url.startswith("http://"):
                public_url = "https://" + public_url[len("http://") :]
            return public_url
        except Exception as e:
            last_err = e
            print(f"[ngrok] Tunnel attempt {attempt}/3 failed: {e}")
            if attempt < 3:
                time.sleep(1.2 * attempt)

    print(
        "\n[ngrok] All tunnel attempts failed. Check:\n"
        "  • NGROK_AUTHTOKEN is valid (https://dashboard.ngrok.com/get-started/your-authtoken)\n"
        f"  • NGROK_STATIC_DOMAIN matches your reserved domain exactly: {domain!r}\n"
        f"  • Port {port} is not used by another process (this app binds there)\n"
        "  • Free plan: run `ngrok http 8000` from CLI once if pyngrok agent is stuck\n"
        f"  • Last error: {last_err}\n"
    )
    return None


@asynccontextmanager
async def lifespan(app: FastAPI):
    await create_tables()
    os.makedirs(settings.IMAGES_DIR, exist_ok=True)
    os.makedirs(settings.HERO_MEDIA_DIR, exist_ok=True)
    os.makedirs(settings.OUTLET_IMAGES_DIR, exist_ok=True)
    os.makedirs(settings.OUTLET_VIDEOS_DIR, exist_ok=True)

    public_url = _start_ngrok()
    if public_url:
        settings.BASE_URL = public_url
        print(f"\n  🌐 Public URL (ngrok):  {public_url}")
        print(f"  📋 API docs:            {public_url}/docs")
        print(f"  🍽️  Customer menu:       {public_url}/menu/YOUR_OUTLET_ID\n")
    else:
        if settings.NGROK_AUTHTOKEN.strip() and settings.NGROK_STATIC_DOMAIN.strip():
            print(
                "\n  ⚠️  NGROK_* is configured but tunnel startup failed — "
                "phones using HTTPS ngrok will be offline until you fix it "
                "(see messages above). For same-Wi‑Fi testing use "
                "`./start.sh` and `flutter run --dart-define=POS_CLOUD_API_URL=http://YOUR_LAN_IP:8000`.\n"
            )
        print(f"\n  Local URL:  {settings.BASE_URL}")
        print(f"  API docs:   {settings.BASE_URL}/docs\n")

    yield


app = FastAPI(title="Rastarant POS API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Static file mounts (uploads) ───────────────────────────────────────────────
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# ── API Routers (registered before the SPA catch-all) ─────────────────────────
app.include_router(health.router)
app.include_router(tenants.router)
app.include_router(admin.router)
app.include_router(devices.router)
app.include_router(menu.router)
app.include_router(orders.router)
app.include_router(payments.router)
app.include_router(platform.router)
app.include_router(ws.router)
app.include_router(customer.router)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(status_code=500, content={"error": str(exc)})


# ── React SPA — serves frontend_dist at /assets and catch-all for SPA routes ──
# Mount Vite's compiled assets (JS/CSS chunks) under /assets
if (FRONTEND_DIST / "assets").exists():
    app.mount("/assets", StaticFiles(directory=str(FRONTEND_DIST / "assets")), name="assets")


@app.get("/menu/{full_path:path}", include_in_schema=False)
async def serve_menu_spa(full_path: str):
    """Serve the customer React SPA for all /menu/* routes."""
    index = FRONTEND_DIST / "index.html"
    if index.exists():
        return FileResponse(
            str(index),
            headers={"Cache-Control": "no-store, max-age=0"},
        )
    return JSONResponse(status_code=503, content={"error": "Customer menu not built yet. Run: bash build_frontend.sh"})


@app.get("/", include_in_schema=False)
async def serve_root():
    """Redirect root to docs in dev; serve index.html if built."""
    index = FRONTEND_DIST / "index.html"
    if index.exists():
        return FileResponse(
            str(index),
            headers={"Cache-Control": "no-store, max-age=0"},
        )
    from fastapi.responses import RedirectResponse
    return RedirectResponse(url="/docs")


if __name__ == "__main__":
    port = settings.PORT
    use_ngrok = bool(
        settings.NGROK_AUTHTOKEN.strip() and settings.NGROK_STATIC_DOMAIN.strip()
    )
    # --reload spawns a child process; a second lifespan can try to open the same
    # reserved ngrok domain and fail, or leave a broken tunnel. Disable reload
    # whenever ngrok credentials are present.
    reload = os.environ.get("RENDER") is None and not use_ngrok
    if use_ngrok and os.environ.get("RENDER") is None:
        print(
            "[ngrok] Uvicorn reload is OFF (stable tunnel). "
            "Restart the process after code changes.\n"
        )
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=reload)
