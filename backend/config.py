from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    DATABASE_URL: str = "postgresql+asyncpg://postgres:password@localhost/rastarant"
    SECRET_KEY: str = "change-me"
    IMAGES_DIR: str = "./uploads/menu_images"
    # Unified hero media folder. Per-outlet subfolders are created at upload time:
    #   uploads/hero_media/{outlet_id}/video/   → welcome-screen video
    #   uploads/hero_media/{outlet_id}/images/  → menu-page slider images (max 5)
    HERO_MEDIA_DIR: str = "./uploads/hero_media"
    # Legacy paths kept for backward compatibility while existing files exist.
    OUTLET_IMAGES_DIR: str = "./uploads/outlet_images"
    OUTLET_VIDEOS_DIR: str = "./uploads/outlet_videos"
    VIDEO_MAX_BYTES: int = 50 * 1024 * 1024  # 50 MB
    BASE_URL: str = "http://localhost:8000"

    NGROK_AUTHTOKEN: str = ""
    NGROK_STATIC_DOMAIN: str = ""


settings = Settings()
