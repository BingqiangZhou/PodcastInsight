from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
    )

    APP_NAME: str = "PodDigest"
    DEBUG: bool = False

    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/poddigest"

    REDIS_URL: str = "redis://localhost:6379/0"

    CELERY_BROKER_URL: str = "redis://localhost:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/2"

    ENCRYPTION_KEY: str = ""

    WHISPER_MODEL_SIZE: str = "large-v3-turbo"
    WHISPER_DEVICE: str = "cuda"
    WHISPER_COMPUTE_TYPE: str = "float16"
    WHISPER_BATCH_SIZE: int = 8
    WHISPER_MODEL_DIR: str = "data/whisper_models"
    AUDIO_STORAGE_DIR: str = "data/audio"
    AUDIO_CLEANUP_AGE_HOURS: int = 24

    XYZRANK_API_URL: str = "https://xyzrank.com/api/podcasts"

    CORS_ORIGINS: list[str] = ["http://localhost:3000", "http://localhost:3001", "http://localhost:8000"]


@lru_cache
def get_settings() -> Settings:
    return Settings()
