"""Alembic environment configuration."""

import asyncio
import os
import sys
import types
from datetime import timedelta
from functools import lru_cache
from logging.config import fileConfig

from pydantic_settings import BaseSettings
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from alembic import context


# Add the app directory to Python path
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

# Mock Header class for security functions
class Header:
    def __init__(self, default=None, **kwargs):
        self.default = default

    def __call__(self, *args, **kwargs):
        return self.default


class MinimalSettings(BaseSettings):
    DATABASE_URL: str = (
        "postgresql+asyncpg://user:password@localhost:5432/personal_ai_assistant"
    )

    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"


@lru_cache
def get_minimal_settings():
    return MinimalSettings()


minimal_settings = get_minimal_settings()


# Complete mock config to avoid importing app.core.config
class MockConfig:
    PROJECT_NAME = "Personal AI Assistant"
    VERSION = "1.0.0"
    API_V1_STR = "/api/v1"
    SECRET_KEY = "migration-secret-key-placeholder"
    ENVIRONMENT = "production"
    DATABASE_URL = minimal_settings.DATABASE_URL
    DATABASE_POOL_SIZE = 20
    DATABASE_MAX_OVERFLOW = 40
    DATABASE_POOL_TIMEOUT = 30
    DATABASE_RECYCLE = 3600
    DATABASE_CONNECT_TIMEOUT = 5
    REDIS_URL = "redis://localhost:6379"
    ALLOWED_HOSTS = ["*"]
    ACCESS_TOKEN_EXPIRE_MINUTES = 30
    REFRESH_TOKEN_EXPIRE_DAYS = 7
    ALGORITHM = "HS256"
    CELERY_BROKER_URL = "redis://localhost:6379/0"
    CELERY_RESULT_BACKEND = "redis://localhost:6379/0"
    MAX_PODCAST_SUBSCRIPTIONS = 50
    MAX_PODCAST_EPISODE_DOWNLOAD_SIZE = 500 * 1024 * 1024
    RSS_POLL_INTERVAL_MINUTES = 60
    LLM_CONTENT_SANITIZE_MODE = "standard"
    FRONTEND_URL = "http://localhost:3000"
    SMTP_SERVER = None
    SMTP_PORT = 587
    SMTP_USERNAME = None
    SMTP_PASSWORD = None
    SMTP_USE_TLS = True
    FROM_EMAIL = "noreply@personalai.com"
    FROM_NAME = "Personal AI Assistant"
    ALLOWED_AUDIO_SCHEMES = ["http", "https"]
    OPENAI_API_KEY = None
    OPENAI_API_BASE_URL = "https://api.openai.com/v1"
    MAX_FILE_SIZE = 10 * 1024 * 1024
    UPLOAD_DIR = "uploads"
    TRANSCRIPTION_API_URL = "https://api.siliconflow.cn/v1/audio/transcriptions"
    TRANSCRIPTION_API_KEY = None
    TRANSCRIPTION_CHUNK_SIZE_MB = 10
    TRANSCRIPTION_TARGET_FORMAT = "mp3"
    TRANSCRIPTION_TEMP_DIR = "./temp/transcription"
    TRANSCRIPTION_STORAGE_DIR = "./storage/podcasts"
    TRANSCRIPTION_MAX_THREADS = 4
    TRANSCRIPTION_QUEUE_SIZE = 100


# Mock config module
mock_config_module = types.ModuleType("app.core.config")
mock_config_module.settings = MockConfig()
mock_config_module.get_settings = lambda: mock_config_module.settings
sys.modules["app.core.config"] = mock_config_module


# Mock security module
class MockSecurity:
    @staticmethod
    def get_or_generate_secret_key():
        return "migration-secret-key-placeholder"

    @staticmethod
    def verify_password(plain_password, hashed_password):
        return True

    @staticmethod
    def get_password_hash(password):
        return "mock_hash"

    @staticmethod
    def create_access_token(data: dict, expires_delta: timedelta = None):
        return "mock_access_token"

    @staticmethod
    def create_refresh_token(data: dict, expires_delta: timedelta = None):
        return "mock_refresh_token"

    @staticmethod
    def verify_token(token: str, token_type: str = "access"):
        return {"sub": "1", "email": "test@example.com"}

    @staticmethod
    async def get_current_user(token: str, db):
        return None

    @staticmethod
    async def get_current_active_user(token: str, db):
        return None

    @staticmethod
    async def get_current_superuser(token: str, db):
        return None

    @staticmethod
    def verify_token_optional(token: str, token_type: str = "access"):
        return {"sub": "1", "email": "test@example.com"} if token else None

    @staticmethod
    async def get_token_from_request(
        authorization: str = None, api_key: str = Header(None)
    ):
        return "mock_token"

    @staticmethod
    def generate_password_reset_token(email: str):
        return "mock_reset_token"

    @staticmethod
    def verify_password_reset_token(token: str):
        return "test@example.com"

    @staticmethod
    def generate_api_key():
        return "mock_api_key"

    @staticmethod
    def generate_random_string(length: int = 32):
        return "mock_random_string"

    @staticmethod
    def enable_ec256_optimized():
        return {"public_key": "mock_public_key", "private_key": "mock_private_key"}


mock_security_module = types.ModuleType("app.core.security")
mock_security_module.settings = MockConfig()
mock_security_module.get_or_generate_secret_key = (
    MockSecurity.get_or_generate_secret_key
)
mock_security_module.verify_password = MockSecurity.verify_password
mock_security_module.get_password_hash = MockSecurity.get_password_hash
mock_security_module.create_access_token = MockSecurity.create_access_token
mock_security_module.create_refresh_token = MockSecurity.create_refresh_token
mock_security_module.verify_token = MockSecurity.verify_token
mock_security_module.get_current_user = MockSecurity.get_current_user
mock_security_module.get_current_active_user = MockSecurity.get_current_active_user
mock_security_module.get_current_superuser = MockSecurity.get_current_superuser
mock_security_module.verify_token_optional = MockSecurity.verify_token_optional
mock_security_module.get_token_from_request = MockSecurity.get_token_from_request
mock_security_module.generate_password_reset_token = (
    MockSecurity.generate_password_reset_token
)
mock_security_module.verify_password_reset_token = (
    MockSecurity.verify_password_reset_token
)
mock_security_module.generate_api_key = MockSecurity.generate_api_key
mock_security_module.generate_random_string = MockSecurity.generate_random_string
mock_security_module.enable_ec256_optimized = MockSecurity.enable_ec256_optimized
mock_security_module.OAuth2PasswordBearer = lambda token_url: None
sys.modules["app.core.security"] = mock_security_module

# === STEP 2: Import database module to get Base ===
# Import after mocking config and security to avoid circular imports
from app.core.database import Base, register_orm_models  # noqa: E402


# === STEP 3: Register all models ===
register_orm_models()


# === STEP 4: Configure Alembic ===
config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def get_url():
    """Get database URL from settings."""
    return minimal_settings.DATABASE_URL


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode.

    This configures the context with just a URL
    and not an Engine, though an Engine is acceptable
    here as well.  By skipping the Engine creation
    we don't even need a DBAPI to be available.

    Calls to context.execute() here emit the given string to the
    script output.

    """
    url = get_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
        compare_server_default=True,
    )

    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    """Run migrations with the given connection."""
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        compare_type=True,
        compare_server_default=True,
    )

    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """Run migrations in async mode."""
    configuration = config.get_section(config.config_ini_section)
    configuration["sqlalchemy.url"] = get_url()

    connectable = async_engine_from_config(
        configuration,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
