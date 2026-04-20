"""Shared Pydantic schemas."""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


def validate_password_strength(v: str) -> str:
    """Validate password complexity.

    Args:
        v: Password string to validate

    Returns:
        Validated password string

    Raises:
        ValueError: If password doesn't meet complexity requirements
    """
    errors = []
    if len(v) < 8:
        errors.append("Password must be at least 8 characters long")
    if not any(c.isupper() for c in v):
        errors.append("Password must contain at least one uppercase letter (A-Z)")
    if not any(c.islower() for c in v):
        errors.append("Password must contain at least one lowercase letter (a-z)")
    if not any(c.isdigit() for c in v):
        errors.append("Password must contain at least one number (0-9)")
    if errors:
        raise ValueError(" | ".join(errors))
    return v


# Base schemas
class BaseSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class TimestampedSchema(BaseSchema):
    created_at: datetime
    updated_at: datetime | None = None


# User schemas
class UserBase(BaseSchema):
    email: EmailStr
    username: str | None = Field(None, min_length=3, max_length=50)
    account_name: str | None = Field(None, max_length=255)
    is_active: bool = True
    is_superuser: bool = False

    @field_validator("username")
    @classmethod
    def validate_username(cls, v):
        """Validate username format."""
        if v is not None and not v.replace("_", "").replace("-", "").isalnum():
            raise ValueError(
                "Username must contain only alphanumeric characters, hyphens, and underscores"
            )
        return v


class UserCreate(UserBase):
    password: str = Field(..., min_length=8, max_length=128)

    @field_validator("password")
    @classmethod
    def validate_password(cls, v):
        """Validate password strength."""
        return validate_password_strength(v)


class UserUpdate(BaseSchema):
    account_name: str | None = None
    avatar_url: str | None = None
    settings: dict[str, Any] | None = None


class UserResponse(UserBase):
    id: int
    is_verified: bool
    avatar_url: str | None = None
    account_name: str | None = None
    created_at: datetime


# Token schemas
class Token(BaseSchema):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class TokenData(BaseSchema):
    username: str | None = None


# Pagination schemas
class PaginationParams(BaseSchema):
    page: int = Field(1, ge=1)
    size: int = Field(20, ge=1, le=100)

    @property
    def skip(self) -> int:
        return (self.page - 1) * self.size


class PaginatedResponse(BaseSchema):
    items: list[Any]
    total: int
    page: int
    size: int
    pages: int

    @classmethod
    def create(
        cls,
        items: list[Any],
        total: int,
        page: int,
        size: int,
    ) -> "PaginatedResponse":
        pages = (total + size - 1) // size
        return cls(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=pages,
        )


# API Response schemas
class APIResponse(BaseSchema):
    success: bool = True
    message: str | None = None
    data: Any | None = None


class ErrorResponse(BaseSchema):
    success: bool = False
    message: str
    errors: dict[str, list[str]] | None = None


# Subscription schemas
class SubscriptionBase(BaseSchema):
    title: str
    description: str | None = None
    source_type: str
    source_url: str
    image_url: str | None = None
    config: dict[str, Any] | None = {}
    fetch_interval: int = 3600


class SubscriptionCreate(SubscriptionBase):
    pass


class SubscriptionUpdate(BaseSchema):
    title: str | None = None
    description: str | None = None
    image_url: str | None = None
    config: dict[str, Any] | None = None
    fetch_interval: int | None = None
    is_active: bool | None = None


class SubscriptionResponse(SubscriptionBase, TimestampedSchema):
    id: int
    status: str
    last_fetched_at: datetime | None = None
    latest_item_published_at: datetime | None = None
    next_update_at: datetime | None = None
    error_message: str | None = None
    item_count: int = 0


# Message schemas
class MessageBase(BaseSchema):
    content: str
    role: str


class MessageCreate(MessageBase):
    conversation_id: int


class MessageResponse(MessageBase, TimestampedSchema):
    id: int
    conversation_id: int
    tokens: int | None = None
    model_name: str | None = None
    metadata: dict[str, Any] | None = {}


# Conversation schemas
class ConversationBase(BaseSchema):
    title: str
    description: str | None = None
    model_name: str = "gpt-3.5-turbo"
    system_prompt: str | None = None
    temperature: int = 70
    settings: dict[str, Any] | None = {}


class ConversationCreate(ConversationBase):
    pass


class ConversationUpdate(BaseSchema):
    title: str | None = None
    description: str | None = None
    system_prompt: str | None = None
    temperature: int | None = None
    settings: dict[str, Any] | None = None


class ConversationResponse(ConversationBase, TimestampedSchema):
    id: int
    user_id: int
    status: str
    message_count: int | None = 0


# Password Reset schemas
class ForgotPasswordRequest(BaseSchema):
    """Forgot password request schema."""

    email: EmailStr = Field(
        ..., description="Email address associated with the account"
    )


class ResetPasswordRequest(BaseSchema):
    """Reset password request schema."""

    token: str = Field(..., description="Password reset token received via email")
    new_password: str = Field(
        ..., min_length=8, max_length=128, description="New password"
    )

    @field_validator("new_password")
    @classmethod
    def validate_password(cls, v):
        """Validate password strength."""
        return validate_password_strength(v)


class PasswordResetResponse(BaseSchema):
    """Password reset response schema."""

    message: str = Field(..., description="Response message")
    # Include token only in development for testing
    token: str | None = Field(None, description="Reset token (development only)")
    expires_at: str | None = Field(None, description="Token expiry time (ISO format)")
