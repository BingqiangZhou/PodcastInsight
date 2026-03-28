import os
import secrets
from functools import lru_cache
from pathlib import Path

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


def get_or_generate_secret_key() -> str:
    """Get SECRET_KEY from env, or load/generate from file for persistence."""
    env_key = os.getenv("SECRET_KEY")
    if env_key:
        return env_key

    data_dir = Path(os.getenv("DATA_DIR", "data"))
    key_file = data_dir / ".secret_key"

    if key_file.exists():
        try:
            return key_file.read_text(encoding="utf-8").strip()
        except OSError:
            pass

    new_key = secrets.token_urlsafe(48)
    try:
        data_dir.mkdir(exist_ok=True, parents=True)
        key_file.write_text(new_key, encoding="utf-8")
    except OSError:
        pass
    return new_key


class Settings(BaseSettings):
    """Application settings."""

    # Basic
    PROJECT_NAME: str = "Personal AI Assistant"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    SECRET_KEY: str | None = None
    ENVIRONMENT: str = "development"

    # Database
    DATABASE_URL: str | None = None
    DATABASE_POOL_SIZE: int = 10
    DATABASE_MAX_OVERFLOW: int = 15
    DATABASE_POOL_TIMEOUT: int = 30
    DATABASE_RECYCLE: int = 3600
    DATABASE_CONNECT_TIMEOUT: int = 5
    DATABASE_STATEMENT_TIMEOUT: int = 30000
    DATABASE_POOL_WAKEUP_TIMEOUT: int = 60
    DATABASE_ECHO: bool = False
    DATABASE_ECHO_POOL: bool = True

    # Redis
    REDIS_URL: str = "redis://localhost:6379"
    REDIS_MAX_CONNECTIONS: int = 50

    # CORS
    ALLOWED_HOSTS: list[str] = []

    # Rate Limiting
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_REQUESTS_PER_MINUTE: int = 60
    RATE_LIMIT_REQUESTS_PER_HOUR: int = 1000

    # JWT
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    ALGORITHM: str = "HS256"

    # Celery
    CELERY_BROKER_URL: str = "redis://localhost:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/2"
    CELERY_WORKER_PREFETCH_MULTIPLIER: int = 4
    CELERY_WORKER_MAX_TASKS_PER_CHILD: int = 500

    # Podcast Processing Limits
    MAX_PODCAST_SUBSCRIPTIONS: int = 0
    MAX_PODCAST_EPISODE_DOWNLOAD_SIZE: int = 500 * 1024 * 1024
    RSS_POLL_INTERVAL_MINUTES: int = 60

    # Privacy & Security
    LLM_CONTENT_SANITIZE_MODE: str = "standard"

    # Frontend URL
    FRONTEND_URL: str = "http://localhost:3000"

    # Email Configuration
    SMTP_SERVER: str | None = None
    SMTP_PORT: int = 587
    SMTP_USERNAME: str | None = None
    SMTP_PASSWORD: str | None = None
    SMTP_USE_TLS: bool = True
    FROM_EMAIL: str = "noreply@personalai.com"
    FROM_NAME: str = "Personal AI Assistant"
    EMAIL_RESET_TOKEN_EXPIRE_HOURS: int = 24
    ALLOWED_AUDIO_SCHEMES: list[str] = ["http", "https"]

    # External APIs
    OPENAI_API_KEY: str | None = None
    OPENAI_API_BASE_URL: str = "https://api.openai.com/v1"

    # File storage
    MAX_FILE_SIZE: int = 10 * 1024 * 1024
    UPLOAD_DIR: str = "uploads"

    # Transcription API Configuration
    TRANSCRIPTION_API_URL: str = "https://api.siliconflow.cn/v1/audio/transcriptions"
    TRANSCRIPTION_API_KEY: str | None = None

    # Transcription File Processing Configuration
    TRANSCRIPTION_CHUNK_SIZE_MB: int = 10
    TRANSCRIPTION_TARGET_FORMAT: str = "mp3"
    TRANSCRIPTION_TEMP_DIR: str = "./temp/transcription"
    TRANSCRIPTION_STORAGE_DIR: str = "./storage/podcasts"

    # Transcription Batch Limits
    TRANSCRIPTION_BATCH_MAX_EPISODES: int = 50

    # Transcription Concurrency Control
    TRANSCRIPTION_MAX_THREADS: int = 4
    TRANSCRIPTION_QUEUE_SIZE: int = 100
    TRANSCRIPTION_BACKLOG_ENABLED: bool = True
    TRANSCRIPTION_BACKLOG_BATCH_SIZE: int = 20
    TRANSCRIPTION_BACKLOG_SCHEDULE_MINUTE: int = 5
    TRANSCRIPTION_STARTUP_RESET_TIMEOUT_SECONDS: float = 15.0

    # Admin Panel 2FA Configuration
    ADMIN_2FA_ENABLED: bool = True

    # Logging Configuration
    LOG_LEVEL: str = "INFO"
    LOG_DIR: str = "logs"
    LOG_RETENTION_DAYS: int = 30

    # Assistant and Chat Configuration
    ASSISTANT_TITLE_TRUNCATION_LENGTH: int = 50
    ASSISTANT_TEST_PROMPT: str = 'Hello, please respond with "Test successful".'

    # Pagination and Batch Processing
    PODCAST_EPISODE_BATCH_SIZE: int = 50
    PODCAST_RECENT_EPISODES_LIMIT: int = 3
    PODCAST_FEED_LIGHTWEIGHT_ENABLED: bool = True
    RSS_REFRESH_CONCURRENCY: int = 5
    TASK_ORCHESTRATION_USER_BATCH_SIZE: int = 500

    # ETag Configuration
    ETAG_ENABLED: bool = True
    ETAG_DEFAULT_TTL: int = 300

    # AI Client Configuration
    AI_CLIENT_MAX_RETRIES: int = 3
    AI_CLIENT_BASE_DELAY: int = 2
    AI_CLIENT_MAX_PROMPT_LENGTH: int = 1000000

    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=True,
        extra="ignore",
    )

    @field_validator("ALLOWED_HOSTS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v):
        if v is None or v == "" or v == []:
            return []
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",") if i.strip()]
        if isinstance(v, list):
            return v
        if isinstance(v, str) and v.startswith("["):
            import json

            try:
                parsed = json.loads(v)
                if isinstance(parsed, list):
                    return parsed
            except json.JSONDecodeError:
                pass
        raise ValueError(f"Invalid ALLOWED_HOSTS format: {v}")

    @field_validator("ADMIN_2FA_ENABLED", mode="before")
    @classmethod
    def parse_admin_2fa_enabled(cls, v):
        if isinstance(v, bool):
            return v
        if isinstance(v, str):
            return v.lower() in ("true", "1", "yes", "on")
        return bool(v)

    @field_validator("TRANSCRIPTION_BACKLOG_BATCH_SIZE")
    @classmethod
    def validate_transcription_backlog_batch_size(cls, v: int) -> int:
        if v < 1:
            raise ValueError("TRANSCRIPTION_BACKLOG_BATCH_SIZE must be >= 1")
        return v

    @field_validator("TRANSCRIPTION_BACKLOG_SCHEDULE_MINUTE")
    @classmethod
    def validate_transcription_backlog_schedule_minute(cls, v: int) -> int:
        if v < 0 or v > 59:
            raise ValueError(
                "TRANSCRIPTION_BACKLOG_SCHEDULE_MINUTE must be between 0 and 59",
            )
        return v

    @field_validator("TASK_ORCHESTRATION_USER_BATCH_SIZE")
    @classmethod
    def validate_task_orchestration_user_batch_size(cls, v: int) -> int:
        if v < 1:
            raise ValueError("TASK_ORCHESTRATION_USER_BATCH_SIZE must be >= 1")
        return v

    @field_validator("TRANSCRIPTION_STARTUP_RESET_TIMEOUT_SECONDS")
    @classmethod
    def validate_transcription_startup_reset_timeout_seconds(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("TRANSCRIPTION_STARTUP_RESET_TIMEOUT_SECONDS must be > 0")
        return v

    def require_database_url(self) -> str:
        """Return DATABASE_URL or raise a runtime error when not configured."""
        if self.DATABASE_URL:
            return self.DATABASE_URL
        raise RuntimeError(
            "DATABASE_URL is not configured. Set backend/.env or environment variables "
            "before starting the application.",
        )

    def get_secret_key(self) -> str:
        """Resolve the effective secret key lazily."""
        if self.SECRET_KEY:
            return self.SECRET_KEY
        self.SECRET_KEY = get_or_generate_secret_key()
        return self.SECRET_KEY

    def validate_production_config(self) -> list[str]:
        """Validate configuration for production environment."""
        issues = []
        if self.ENVIRONMENT == "production":
            if not self.SECRET_KEY:
                issues.append(
                    "SECRET_KEY should be explicitly set via environment variable in production"
                )
            if "*" in self.ALLOWED_HOSTS:
                issues.append(
                    "ALLOWED_HOSTS contains '*' which allows all origins. "
                    "Specify exact domains in production."
                )
            if self.DATABASE_URL and "MySecurePass2024" in self.DATABASE_URL:
                issues.append(
                    "Database password appears to be the default value. "
                    "Change POSTGRES_PASSWORD in production."
                )
        return issues


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()


def get_required_database_url() -> str:
    """Get DATABASE_URL and fail only when the runtime actually needs it."""
    return get_settings().require_database_url()


class _LazySettingsProxy:
    """Attribute proxy that resolves the cached settings instance on demand."""

    def __getattr__(self, name: str):
        settings_obj = get_settings()
        if name == "SECRET_KEY":
            return settings_obj.get_secret_key()
        return getattr(settings_obj, name)


settings = _LazySettingsProxy()
