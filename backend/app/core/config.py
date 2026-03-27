import os
import secrets
from functools import lru_cache
from pathlib import Path

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


# Secret Key Management (moved here to avoid circular imports)
class SecretKeyManager:
    """Manages SECRET_KEY generation and storage - moved to config.py to avoid circular imports"""

    def __init__(self, data_dir: str = "data"):
        self.data_dir = Path(data_dir)
        self.secret_key_file = self.data_dir / ".secret_key"
        self._secret_key: str | None = None

    def ensure_data_dir(self):
        """Ensure data directory exists"""
        self.data_dir.mkdir(exist_ok=True, parents=True)

    def generate_secret_key(self) -> str:
        """Generate a new secure SECRET_KEY"""
        return secrets.token_urlsafe(48)

    def load_secret_key(self) -> str:
        """Load existing SECRET_KEY or generate new one"""
        if self._secret_key:
            return self._secret_key

        self.ensure_data_dir()

        # Try to load existing key
        if self.secret_key_file.exists():
            try:
                with open(self.secret_key_file, encoding="utf-8") as f:
                    self._secret_key = f.read().strip()
                return self._secret_key
            except OSError:
                pass

        # Generate new key if none exists
        self._secret_key = self.generate_secret_key()
        self.save_secret_key(self._secret_key)
        return self._secret_key

    def save_secret_key(self, secret_key: str):
        """Save SECRET_KEY to file"""
        try:
            self.ensure_data_dir()
            with open(self.secret_key_file, "w", encoding="utf-8") as f:
                f.write(secret_key)
        except (OSError, PermissionError):
            # Silently fail if we can't write to disk (e.g., in Docker with read-only volume)
            # The secret key will still be available in memory for this session
            pass

    def get_secret_key(self) -> str:
        """Get the current SECRET_KEY"""
        return self.load_secret_key()


def get_or_generate_secret_key() -> str:
    """Get the SECRET_KEY for the application

    This function will:
    1. Load existing SECRET_KEY from file
    2. Generate new one if not exists
    3. Return the SECRET_KEY as a string
    """
    data_dir = os.getenv("DATA_DIR", "data")
    manager = SecretKeyManager(data_dir)
    return manager.get_secret_key()


class Settings(BaseSettings):
    """Application settings."""

    # Basic
    PROJECT_NAME: str = "Personal AI Assistant"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    SECRET_KEY: str | None = None
    ENVIRONMENT: str = "development"

    # Database - Pool sizing optimized for stability and performance
    # With 8 worker processes (4 gunicorn + 4 celery), increased pool size for better throughput
    # Total capacity: 8 workers × (10 + 15) = 200 connections (100% of PostgreSQL limit)
    # Note: Monitored via OBS_ALERT_DB_POOL_OCCUPANCY_RATIO to prevent exhaustion
    DATABASE_URL: str | None = None
    READ_DATABASE_URL: str | None = None  # Read replica URL (optional, defaults to DATABASE_URL)
    DATABASE_POOL_SIZE: int = 10  # Increased from 5 for better connection availability
    DATABASE_MAX_OVERFLOW: int = 15  # Increased from 10 to handle traffic spikes

    # Database timeout settings
    DATABASE_POOL_TIMEOUT: int = 30  # Max wait for connection (seconds)
    DATABASE_RECYCLE: int = 3600  # Recycle connections after 1 hour
    DATABASE_CONNECT_TIMEOUT: int = 5  # Fast fail for connection issues
    DATABASE_STATEMENT_TIMEOUT: int = 30000  # 30 seconds in milliseconds - prevent long-running queries
    DATABASE_POOL_WAKEUP_TIMEOUT: int = 60  # Timeout for connection pool warming on startup

    # Database query logging (for development/performance debugging)
    DATABASE_ECHO: bool = False  # Echo SQL queries to logs (enable in development)
    DATABASE_ECHO_POOL: bool = True  # Echo connection pool events

    # Read replica pool settings (can be larger than primary for read-heavy workloads)
    DATABASE_READ_POOL_SIZE: int | None = None  # Defaults to DATABASE_POOL_SIZE
    DATABASE_READ_MAX_OVERFLOW: int | None = None  # Defaults to DATABASE_MAX_OVERFLOW

    # Redis
    REDIS_URL: str = "redis://localhost:6379"
    REDIS_MAX_CONNECTIONS: int = 50

    # CORS - Default to empty for security, set ALLOWED_HOSTS=* for development
    ALLOWED_HOSTS: list[str] = []

    # Rate Limiting
    RATE_LIMIT_ENABLED: bool = True  # Enable rate limiting for API protection
    RATE_LIMIT_REQUESTS_PER_MINUTE: int = 60
    RATE_LIMIT_REQUESTS_PER_HOUR: int = 1000

    # JWT
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = (
        7  # Sliding session: refresh extends to 7 days from now
    )
    ALGORITHM: str = "HS256"

    # Celery
    CELERY_BROKER_URL: str = "redis://localhost:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/2"
    CELERY_WORKER_PREFETCH_MULTIPLIER: int = 4
    CELERY_WORKER_MAX_TASKS_PER_CHILD: int = 500

    # Podcast Processing Limits
    MAX_PODCAST_SUBSCRIPTIONS: int = 999999  # Per user (unlimited)
    MAX_PODCAST_EPISODE_DOWNLOAD_SIZE: int = 500 * 1024 * 1024  # 500MB
    RSS_POLL_INTERVAL_MINUTES: int = 60  # Default polling interval

    # Privacy & Security
    LLM_CONTENT_SANITIZE_MODE: str = "standard"  # 'strict' | 'standard' | 'none'

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
    MAX_FILE_SIZE: int = 10 * 1024 * 1024  # 10MB
    UPLOAD_DIR: str = "uploads"

    # Transcription API Configuration
    TRANSCRIPTION_API_URL: str = "https://api.siliconflow.cn/v1/audio/transcriptions"
    TRANSCRIPTION_API_KEY: str | None = None

    # Transcription File Processing Configuration
    TRANSCRIPTION_CHUNK_SIZE_MB: int = 10  # 10MB per chunk
    TRANSCRIPTION_TARGET_FORMAT: str = "mp3"
    TRANSCRIPTION_TEMP_DIR: str = "./temp/transcription"
    TRANSCRIPTION_STORAGE_DIR: str = "./storage/podcasts"

    # Transcription Concurrency Control
    TRANSCRIPTION_MAX_THREADS: int = 4  # Maximum concurrent transcription requests
    TRANSCRIPTION_QUEUE_SIZE: int = 100  # Maximum queue size for pending tasks
    TRANSCRIPTION_BACKLOG_ENABLED: bool = True
    TRANSCRIPTION_BACKLOG_BATCH_SIZE: int = 20
    TRANSCRIPTION_BACKLOG_SCHEDULE_MINUTE: int = 5
    TRANSCRIPTION_STARTUP_RESET_TIMEOUT_SECONDS: float = 15.0

    # Admin Panel 2FA Configuration
    ADMIN_2FA_ENABLED: bool = True  # Admin panel 2FA toggle (default: enabled)

    # Assistant and Chat Configuration
    ASSISTANT_TITLE_TRUNCATION_LENGTH: int = (
        50  # Max length for auto-generated conversation titles
    )
    ASSISTANT_TEST_PROMPT: str = 'Hello, please respond with "Test successful".'

    # Pagination and Batch Processing
    PODCAST_EPISODE_BATCH_SIZE: int = 50  # Default batch size for episode processing
    PODCAST_RECENT_EPISODES_LIMIT: int = (
        3  # Number of recent episodes to fetch by default
    )
    PODCAST_FEED_LIGHTWEIGHT_ENABLED: bool = (
        True  # Enable lightweight feed payload/query path
    )
    RSS_REFRESH_CONCURRENCY: int = 5
    TASK_ORCHESTRATION_USER_BATCH_SIZE: int = 500

    # ETag Configuration
    ETAG_ENABLED: bool = True  # Enable ETag caching for GET endpoints
    ETAG_DEFAULT_TTL: int = 300  # Default max-age for ETag responses (5 minutes)
    ETAG_CACHE_IN_REDIS: bool = (
        True  # Cache ETags in Redis for cross-instance validation
    )
    ETAG_REDIS_PREFIX: str = "etag:"  # Redis key prefix for ETag storage

    # Observability alert thresholds
    OBS_ALERT_API_P95_MS: float = 800.0
    OBS_ALERT_API_ERROR_RATE: float = 0.05
    OBS_ALERT_DB_POOL_OCCUPANCY_RATIO: float = 0.9
    OBS_ALERT_REDIS_COMMAND_AVG_MS: float = 20.0
    OBS_ALERT_REDIS_COMMAND_MAX_MS: float = 100.0
    OBS_ALERT_REDIS_CACHE_HIT_RATE_MIN: float = 0.5
    OBS_ALERT_REDIS_CACHE_LOOKUPS_MIN: int = 20
    # Circuit breaker observability
    OBS_ALERT_CIRCUIT_BREAKER_OPEN_MAX: int = 0  # Alert if any breakers open
    OBS_ALERT_CIRCUIT_BREAKER_REJECTED_MAX: int = 10
    OBS_SUCCESS_LOG_SAMPLE_RATE: float = 0.1

    # AI Client Configuration (used by app.core.ai_client)
    AI_CLIENT_MAX_RETRIES: int = 3  # Maximum retry attempts for AI API calls
    AI_CLIENT_BASE_DELAY: int = 2  # Base delay in seconds for exponential backoff
    AI_CLIENT_MAX_PROMPT_LENGTH: int = 1000000  # Maximum prompt length before truncation (1 million characters)

    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=True,
        extra="ignore",  # Allow extra environment variables from Docker compose
    )

    @field_validator("ALLOWED_HOSTS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v):
        """Parse CORS allowed hosts from environment variable.

        Supports:
        - Empty string or empty list -> empty list (secure default)
        - "*" -> ["*"] (development mode, allows all origins)
        - Comma-separated string -> list of origins
        - JSON array string -> parsed list
        """
        if v is None or v == "" or v == []:
            return []
        if isinstance(v, str) and not v.startswith("["):
            # Handle comma-separated string
            origins = [i.strip() for i in v.split(",") if i.strip()]
            return origins
        if isinstance(v, list):
            return v
        if isinstance(v, str) and v.startswith("["):
            # Try to parse as JSON array
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
        """Parse ADMIN_2FA_ENABLED from string to bool."""
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

    @field_validator("OBS_SUCCESS_LOG_SAMPLE_RATE")
    @classmethod
    def validate_obs_success_log_sample_rate(cls, v: float) -> float:
        if v < 0 or v > 1:
            raise ValueError("OBS_SUCCESS_LOG_SAMPLE_RATE must be between 0 and 1")
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
        """Validate configuration for production environment.

        Returns a list of warnings/errors. Empty list means all checks passed.
        """
        issues = []

        if self.ENVIRONMENT == "production":
            # Check SECRET_KEY is set (not auto-generated)
            if not self.SECRET_KEY:
                issues.append(
                    "SECRET_KEY should be explicitly set via environment variable "
                    "in production (currently using auto-generated key)"
                )

            # Check CORS is not open
            if "*" in self.ALLOWED_HOSTS:
                issues.append(
                    "ALLOWED_HOSTS contains '*' which allows all origins. "
                    "Specify exact domains in production."
                )

            # Check database password is not default
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
