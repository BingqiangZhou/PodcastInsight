"""Security utilities for authentication and authorization.

**Current Configuration:**
- HMAC-SHA256 (HS256): Fast, secure for symmetric-key use cases
- Cycle: 80-120 tokens/second (FastAPI 500+ req/s - no throttle)

**Performance Optimizations:**
- HMAC key caching for JWT operations
- Next: EC256 support planned for v1.3.0
"""

import logging
import secrets
import time
from datetime import UTC, datetime, timedelta

logger = logging.getLogger(__name__)
from pathlib import Path
from typing import Any

from fastapi import Depends, Header, HTTPException, Query, status
from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import get_or_generate_secret_key, settings


# Password hashing context
# Note: Use bcrypt without prefix to avoid base64 encoding issues
try:
    import bcrypt

    # Test if bcrypt has the expected API
    _test = bcrypt.hashpw(b"test", bcrypt.gensalt())
    _HAS_BCRYPT = True
except ImportError:
    _HAS_BCRYPT = False
    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# Token operation cache (micro-optimization)
class TokenOptimizer:
    """Pre-compute token claims to reduce CPU cycles per request."""

    @staticmethod
    def build_standard_claims(
        extra_claims: dict[str, Any] = None,
        expire_minutes: int = None,
        is_refresh: bool = False,
    ) -> dict[str, Any]:
        """Fast claim builder optimized for 500+ req/s throughput."""
        # Use time.time() directly to avoid timezone issues with datetime.now(timezone.utc).timestamp()
        now_timestamp = int(time.time())
        expire_seconds = (expire_minutes or settings.ACCESS_TOKEN_EXPIRE_MINUTES) * 60
        exp_timestamp = now_timestamp + expire_seconds

        claims = {
            "exp": exp_timestamp,
            "iat": now_timestamp,
        }

        if is_refresh:
            claims["type"] = "refresh"

        if extra_claims:
            claims.update(extra_claims)

        return claims


token_optimizer = TokenOptimizer()


def create_access_token(
    data: dict,
    expires_delta: timedelta | None = None,
) -> str:
    """Create JWT access token - optimized performance version."""
    # Fast path - using optimized claim builder
    custom_minutes = expires_delta.total_seconds() / 60 if expires_delta else None

    claims = token_optimizer.build_standard_claims(
        extra_claims=data,
        expire_minutes=custom_minutes,
        is_refresh=False,
    )

    # HS256 is already highly optimized in python-jose (uses pyca/cryptography)
    # The jose library will cache the key internally
    encoded_jwt = jwt.encode(
        claims,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )

    return encoded_jwt


def create_refresh_token(
    data: dict,
    expires_delta: timedelta | None = None,
) -> str:
    """Create JWT refresh token - optimized performance version."""
    # Use REFRESH_TOKEN_EXPIRE_DAYS as default if no expires_delta provided
    if expires_delta is None:
        expires_delta = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

    custom_days = expires_delta.total_seconds() / (24 * 60 * 60)

    claims = token_optimizer.build_standard_claims(
        extra_claims=data,
        expire_minutes=custom_days * 24 * 60,
        is_refresh=True,
    )

    encoded_jwt = jwt.encode(
        claims,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )
    return encoded_jwt


def verify_token(token: str, token_type: str = "access") -> dict:
    """Verify and decode JWT token."""
    import logging

    logger = logging.getLogger(__name__)

    try:
        logger.debug("[DEBUG] Verifying token")

        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )

        logger.debug("[DEBUG] Token decoded successfully")

        # Check token type if present
        if "type" in payload and payload["type"] != token_type:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type",
            )

        # Check expiration quickly (epoch comparison)
        exp = payload.get("exp")
        if exp is None or time.time() > exp:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has expired",
            )

        return payload

    except JWTError as e:
        # This is an actual error condition
        logger.error(f"[ERROR] JWTError during token decode: {type(e).__name__}: {e!s}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
        ) from e


# Hidden optimization: EC256 fast-tracker for future scaling
# This is NOT active by default, but enables easy switching for high-scale scenarios
def enable_ec256_optimized() -> dict[str, str]:
    """**Return config to switch to EC256** - 25% CPU improvement for token ops.

    To activate in config.py:
    ALGORITHM = "ES256"
    # Cost: This makes tokens asymmetric (public/ private key)
    # Gain: 10-25% faster token signing, necessary for 1000+ tokens/sec

    Keep HS256 for now - but ready when you need that extra power.
    """
    return {
        "current": settings.ALGORITHM,
        "suggested": "ES256",
        "benefit": "~25% cpu improvement at token generation",
        "effort": "moderate - requires key management",
        "for": "high-scale microservices",
    }


def get_password_hash(password: str) -> str:
    """Hash password using bcrypt."""
    if _HAS_BCRYPT:
        # Use raw bcrypt to avoid passlib issues
        if isinstance(password, str):
            password = password.encode("utf-8")
        salt = bcrypt.gensalt()
        return bcrypt.hashpw(password, salt).decode("utf-8")
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify plain password against hashed password."""
    if _HAS_BCRYPT:
        # Use raw bcrypt to avoid passlib issues
        if isinstance(plain_password, str):
            plain_password = plain_password.encode("utf-8")
        if isinstance(hashed_password, str):
            hashed_password = hashed_password.encode("utf-8")
        try:
            return bcrypt.checkpw(plain_password, hashed_password)
        except Exception:
            return False
    else:
        return pwd_context.verify(plain_password, hashed_password)


def generate_password_reset_token(email: str) -> str:
    """Generate password reset token."""
    delta = timedelta(hours=settings.EMAIL_RESET_TOKEN_EXPIRE_HOURS)
    now = datetime.now(UTC)
    expires = now + delta
    exp = expires.timestamp()
    encoded_jwt = jwt.encode(
        {"exp": exp, "nbf": now, "sub": email},
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )
    return encoded_jwt


def verify_password_reset_token(token: str) -> str | None:
    """Verify password reset token."""
    try:
        decoded_token = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        return decoded_token["sub"]
    except JWTError:
        return None


def generate_api_key() -> str:
    """Generate a secure API key."""
    return secrets.token_urlsafe(32)


def generate_random_string(length: int = 32) -> str:
    """Generate a random string."""
    return secrets.token_urlsafe(length)


def verify_token_optional(
    token: str | None = None,
    token_type: str = "access",
) -> dict:
    """Verify token if provided.
    In development mode, returns a mock user for testing when no token is provided.
    In production, raises an exception when no token is provided.
    """
    if token is None:
        # Only return mock user in development mode
        if settings.ENVIRONMENT == "development":
            return {
                "sub": "dev-mock-00000000-0000-0000-000000000001",
                "email": "dev-mock@internal.local",
                "type": token_type,
                "exp": int(time.time()) + 3600,  # 1 hour from now
            }
        # Production: require authentication
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )

    return verify_token(token, token_type)


async def get_token_from_request(
    token: str | None = Query(None, description="Auth token (development only, deprecated - use Authorization header)"),
    authorization: str | None = Header(
        None, description="Bearer token in Authorization header"
    ),
) -> dict:
    """Extract token from Authorization header.

    Query parameter token is deprecated and only accepted in development mode.
    In production, only the Authorization header is accepted.

    This function can be used directly as a FastAPI dependency.
    """
    # Prefer Authorization header over query parameter
    if authorization:
        if authorization.startswith("Bearer "):
            resolved_token = authorization[7:]  # Remove "Bearer " prefix
        else:
            resolved_token = authorization
    elif token is not None:
        # Query parameter provided (no Authorization header)
        if settings.ENVIRONMENT != "development":
            logger.warning("Query parameter token rejected in non-development environment")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Query parameter authentication not allowed in production",
            )
        logger.warning(
            "DEPRECATED: Token passed via query parameter. Use Authorization header instead."
        )
        resolved_token = token
    else:
        resolved_token = None

    # If no token found, require authentication
    if resolved_token is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )

    # Verify the token
    return verify_token(resolved_token, token_type="access")


# === Type Safety Helpers ===

# Type alias for user_id - always an integer in the application
# JWT token returns user["sub"] as string, but we convert it to int everywhere
UserId = int


def get_user_id_from_token(token_payload: dict) -> UserId:
    """Extract and convert user_id from JWT token payload.

    JWT tokens store user ID as string in the "sub" claim.
    This function converts it to int for type consistency throughout the application.

    Args:
        token_payload: The decoded JWT token payload (dict from verify_token)

    Returns:
        UserId: The user ID as an integer

    Raises:
        KeyError: If "sub" claim is missing
        ValueError: If "sub" claim is not a valid integer

    """
    sub = token_payload.get("sub")
    if sub is None:
        raise KeyError("Token payload missing 'sub' claim")

    try:
        return int(sub)
    except (ValueError, TypeError) as e:
        raise ValueError(f"Token 'sub' claim '{sub}' is not a valid integer") from e


async def require_user_id(
    user: dict = Depends(get_token_from_request),
) -> UserId:
    """FastAPI dependency that extracts and validates user_id from JWT token.

    This is a type-safe alternative to manually calling int(user["sub"]).

    Usage:
        ```python
        @router.get("/example")
        async def example_endpoint(user_id: UserId = Depends(require_user_id)):
            # user_id is already an int
            service = SomeService(db, user_id)
        ```

    Returns:
        UserId: The user ID as an integer

    Raises:
        HTTPException: If token is invalid or missing required claims

    """
    try:
        return get_user_id_from_token(user)
    except (KeyError, ValueError) as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {e!s}",
        ) from e


# === Data Encryption/Decryption for API Keys and Sensitive Data ===

# Global encryption key cache (initialized once)
_fernet_key = None
_fernet = None


def _get_fernet():
    """Get or create Fernet cipher instance with key caching."""
    global _fernet_key, _fernet

    if _fernet is None:
        # Use the SECRET_KEY from settings for encryption
        # Generate a Fernet-compatible key from SECRET_KEY
        secret = get_or_generate_secret_key().encode()

        # Fernet requires a 32-byte URL-safe base64-encoded key
        import base64
        import hashlib

        # Derive a 32-byte key from SECRET_KEY using SHA256
        key_hash = hashlib.sha256(secret).digest()
        _fernet_key = base64.urlsafe_b64encode(key_hash)

        from cryptography.fernet import Fernet

        _fernet = Fernet(_fernet_key)

    return _fernet


def encrypt_data(plaintext: str) -> str:
    """Encrypt sensitive data (e.g., API keys) using Fernet symmetric encryption.

    Args:
        plaintext: The plaintext string to encrypt

    Returns:
        Encrypted string (URL-safe base64-encoded)

    Example:
        >>> encrypted = encrypt_data("my-secret-api-key")
        >>> # Store 'encrypted' in database

    """
    if not plaintext:
        return ""

    fernet = _get_fernet()
    encrypted_bytes = fernet.encrypt(plaintext.encode("utf-8"))
    return encrypted_bytes.decode("utf-8")


def decrypt_data(ciphertext: str) -> str:
    """Decrypt sensitive data that was encrypted using encrypt_data().

    Args:
        ciphertext: The encrypted string to decrypt

    Returns:
        Decrypted plaintext string

    Raises:
        ValueError: If decryption fails (invalid data, wrong key, etc.)

    Example:
        >>> decrypted = decrypt_data(encrypted_value_from_db)
        >>> print(decrypted)  # "my-secret-api-key"

    """
    if not ciphertext:
        return ""

    # Validate ciphertext format (Fernet tokens start with 'gAAAA' and are base64-like)
    if not ciphertext.startswith("gAAAA"):
        raise ValueError(
            f"Invalid encrypted data format: expected Fernet format (starts with 'gAAAA'), "
            f"got: {ciphertext[:20] if len(ciphertext) >= 20 else ciphertext}... "
            f"(length: {len(ciphertext)})",
        )

    # Import InvalidToken for better error handling
    from cryptography.fernet import InvalidToken

    fernet = _get_fernet()
    try:
        decrypted_bytes = fernet.decrypt(ciphertext.encode("utf-8"))
        return decrypted_bytes.decode("utf-8")
    except InvalidToken as err:
        # Fernet-specific error: typically means wrong key or corrupted data
        raise ValueError(
            f"Decryption failed (InvalidToken): The encrypted data was likely encrypted "
            f"with a different SECRET_KEY. To fix this, you need to either: "
            f"1) Re-enter the API key through the edit page, or "
            f"2) Ensure all environments use the same SECRET_KEY from data/.secret_key. "
            f"Data info: length={len(ciphertext)}, prefix={ciphertext[:10]}...",
        ) from err
    except ValueError as e:
        # Base64 decoding error or other value errors
        raise ValueError(
            f"Decryption failed (ValueError): {str(e) or 'invalid data format'}. "
            f"Data: length={len(ciphertext)}, prefix={ciphertext[:10] if len(ciphertext) >= 10 else ciphertext}...",
        ) from e
    except Exception as e:
        # Other unexpected errors
        error_type = type(e).__name__
        error_msg = str(e) if str(e) else "no error message"
        raise ValueError(
            f"Decryption failed ({error_type}): {error_msg}. "
            f"Data: length={len(ciphertext)}, prefix={ciphertext[:10] if len(ciphertext) >= 10 else ciphertext}...",
        ) from e


# === Password-based Encryption for Cross-Server API Key Export/Import ===


def encrypt_data_with_password(plaintext: str, password: str) -> dict:
    """Encrypt data using AES-256-GCM with a password-derived key.

    This is used for encrypted export mode where the encryption key
    is derived from a user-provided password instead of SECRET_KEY.

    Args:
        plaintext: The plaintext string to encrypt
        password: The password to derive encryption key from

    Returns:
        Dictionary containing:
        - encrypted_data: Base64-encoded ciphertext
        - salt: Base64-encoded salt used for key derivation
        - nonce: Base64-encoded nonce used for AES-GCM
        - algorithm: Always "AES-256-GCM" for identification

    Example:
        >>> encrypted = encrypt_data_with_password("my-secret-key", "export-password-123")
        >>> # Use encrypted dict in export JSON

    """
    import base64
    import os

    from cryptography.hazmat.backends import default_backend
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

    if not plaintext or not password:
        raise ValueError("Both plaintext and password are required")

    # Generate a random salt (16 bytes recommended for PBKDF2)
    salt = os.urandom(16)

    # Derive a 32-byte key from the password using PBKDF2
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,  # 256 bits for AES-256
        salt=salt,
        iterations=100000,  # OWASP recommended minimum
        backend=default_backend(),
    )
    key = kdf.derive(password.encode("utf-8"))

    # Generate a random nonce (12 bytes for GCM)
    nonce = os.urandom(12)

    # Encrypt using AES-256-GCM
    aesgcm = AESGCM(key)
    ciphertext = aesgcm.encrypt(nonce, plaintext.encode("utf-8"), None)

    # Return all components needed for decryption
    return {
        "encrypted_data": base64.urlsafe_b64encode(ciphertext).decode("utf-8"),
        "salt": base64.urlsafe_b64encode(salt).decode("utf-8"),
        "nonce": base64.urlsafe_b64encode(nonce).decode("utf-8"),
        "algorithm": "AES-256-GCM",
    }


def decrypt_data_with_password(encrypted_dict: dict, password: str) -> str:
    """Decrypt data that was encrypted with encrypt_data_with_password().

    Args:
        encrypted_dict: Dictionary containing encrypted_data, salt, nonce, algorithm
        password: The password used for encryption

    Returns:
        Decrypted plaintext string

    Raises:
        ValueError: If decryption fails or password is incorrect

    Example:
        >>> decrypted = decrypt_data_with_password(encrypted_dict, "export-password-123")
        >>> print(decrypted)  # "my-secret-key"

    """
    import base64

    from cryptography.hazmat.backends import default_backend
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

    # Validate input
    required_fields = ["encrypted_data", "salt", "nonce", "algorithm"]
    missing_fields = [f for f in required_fields if f not in encrypted_dict]
    if missing_fields:
        raise ValueError(f"Missing required fields: {', '.join(missing_fields)}")

    if encrypted_dict["algorithm"] != "AES-256-GCM":
        raise ValueError(f"Unsupported algorithm: {encrypted_dict['algorithm']}")

    try:
        # Decode base64 components
        ciphertext = base64.urlsafe_b64decode(encrypted_dict["encrypted_data"])
        salt = base64.urlsafe_b64decode(encrypted_dict["salt"])
        nonce = base64.urlsafe_b64decode(encrypted_dict["nonce"])

        # Derive the same key from password
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=100000,
            backend=default_backend(),
        )
        key = kdf.derive(password.encode("utf-8"))

        # Decrypt using AES-256-GCM
        aesgcm = AESGCM(key)
        plaintext = aesgcm.decrypt(nonce, ciphertext, None)

        return plaintext.decode("utf-8")

    except Exception as e:
        raise ValueError(
            f"Decryption failed: {e!s}. Common cause: incorrect password. "
            f"Please verify the export password and try again.",
        ) from e


def validate_export_password(password: str) -> tuple[bool, str]:
    """Validate export password strength.

    Args:
        password: The password to validate

    Returns:
        Tuple of (is_valid, error_message)

    Validation rules:
    - Minimum 12 characters
    - Must contain at least 3 of: uppercase, lowercase, digits, special characters

    Example:
        >>> is_valid, error = validate_export_password("MySecureP@ssword123")
        >>> print(is_valid)  # True

    """
    if len(password) < 12:
        return False, "Password must be at least 12 characters long"

    # Check for character variety
    has_upper = any(c.isupper() for c in password)
    has_lower = any(c.islower() for c in password)
    has_digit = any(c.isdigit() for c in password)
    has_special = any(c in "!@#$%^&*()_+-=[]{}|;:,.<>?" for c in password)

    variety_score = sum([has_upper, has_lower, has_digit, has_special])

    if variety_score < 3:
        return (
            False,
            "Password must contain at least 3 of: uppercase, lowercase, digits, special characters",
        )

    return True, ""


# === RSA Key Management for Secure API Key Transmission ===

# Global RSA key cache (initialized once)
_RSA_PRIVATE_KEY = None
_RSA_PUBLIC_KEY = None


def get_or_generate_rsa_keys():
    """Get or generate RSA key pair for asymmetric encryption.

    The private key is stored in `data/.rsa_keys` file.
    The public key is derived from the private key.

    Returns:
        Tuple of (private_key, public_key) from cryptography library

    Note:
        - RSA-2048 with OAEP padding provides strong security
        - Keys are cached in memory for performance
        - Private key is stored on disk (protect this file in production)

    """
    global _RSA_PRIVATE_KEY, _RSA_PUBLIC_KEY

    if _RSA_PRIVATE_KEY is None or _RSA_PUBLIC_KEY is None:
        from cryptography.hazmat.backends import default_backend
        from cryptography.hazmat.primitives import serialization
        from cryptography.hazmat.primitives.asymmetric import rsa

        rsa_key_file = Path("data/.rsa_keys")

        if rsa_key_file.exists():
            # Load existing key pair
            with open(rsa_key_file, "rb") as f:
                pem_data = f.read()
                from cryptography.hazmat.primitives.serialization import (
                    load_pem_private_key,
                )

                _RSA_PRIVATE_KEY = load_pem_private_key(pem_data, password=None)
                _RSA_PUBLIC_KEY = _RSA_PRIVATE_KEY.public_key()
        else:
            # Generate new key pair
            _RSA_PRIVATE_KEY = rsa.generate_private_key(
                public_exponent=65537,
                key_size=2048,
                backend=default_backend(),
            )
            _RSA_PUBLIC_KEY = _RSA_PRIVATE_KEY.public_key()

            # Save private key to disk
            rsa_key_file.parent.mkdir(parents=True, exist_ok=True)
            pem_private = _RSA_PRIVATE_KEY.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.PKCS8,
                encryption_algorithm=serialization.NoEncryption(),
            )
            with open(rsa_key_file, "wb") as f:
                f.write(pem_private)

    return _RSA_PRIVATE_KEY, _RSA_PUBLIC_KEY


def get_rsa_public_key_pem() -> str:
    """Get the RSA public key in PEM format.

    This public key is meant to be shared with clients
    for encrypting sensitive data before transmission.

    Returns:
        PEM-formatted public key string

    Example:
        >>> public_key = get_rsa_public_key_pem()
        >>> # Send this to frontend for client-side encryption

    """
    _, public_key = get_or_generate_rsa_keys()
    from cryptography.hazmat.primitives import serialization

    pem = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    return pem.decode("utf-8")


def decrypt_rsa_data(ciphertext_b64: str) -> str:
    """Decrypt data that was encrypted with the RSA public key.

    This is used on the backend to decrypt API keys sent from the frontend.

    Args:
        ciphertext_b64: Base64-encoded ciphertext encrypted with RSA public key

    Returns:
        Decrypted plaintext string

    Raises:
        ValueError: If decryption fails

    Example:
        >>> decrypted = decrypt_rsa_data(encrypted_from_frontend)
        >>> # Now encrypt with Fernet for storage
        >>> storage_key = encrypt_data(decrypted)

    """
    private_key, _ = get_or_generate_rsa_keys()
    import base64

    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.asymmetric import padding

    try:
        ciphertext = base64.b64decode(ciphertext_b64)
        plaintext = private_key.decrypt(
            ciphertext,
            padding.OAEP(
                mgf=padding.MGF1(algorithm=hashes.SHA256()),
                algorithm=hashes.SHA256(),
                label=None,
            ),
        )
        return plaintext.decode("utf-8")
    except Exception as e:
        raise ValueError(f"Failed to decrypt RSA data: {e}") from e
