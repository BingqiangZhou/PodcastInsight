"""Fernet and AES-GCM encryption for data security."""

import base64
import hashlib
import logging
import os
import threading

from cryptography.fernet import Fernet, InvalidToken

from app.core.config import get_or_generate_secret_key


logger = logging.getLogger(__name__)


# === Data Encryption/Decryption for API Keys and Sensitive Data ===

# Global encryption key cache (initialized once)
_fernet_key = None
_fernet = None
_fernet_lock = threading.Lock()


def _get_fernet():
    """Get or create Fernet cipher instance with key caching."""
    global _fernet_key, _fernet

    if _fernet is not None:
        return _fernet
    with _fernet_lock:
        if _fernet is None:
            # Use the SECRET_KEY from settings for encryption
            # Generate a Fernet-compatible key from SECRET_KEY
            secret = get_or_generate_secret_key().encode()

            # Fernet requires a 32-byte URL-safe base64-encoded key
            # Derive a 32-byte key from SECRET_KEY using SHA256
            key_hash = hashlib.sha256(secret).digest()
            _fernet_key = base64.urlsafe_b64encode(key_hash)

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
    """Decrypt sensitive data that was encrypted using encrypt_data()."""
    if not ciphertext:
        return ""

    fernet = _get_fernet()
    try:
        decrypted_bytes = fernet.decrypt(ciphertext.encode("utf-8"))
        return decrypted_bytes.decode("utf-8")
    except InvalidToken as err:
        logger.debug(
            "Decryption failed for key prefix %s",
            ciphertext[:10] if len(ciphertext) >= 10 else ciphertext,
        )
        raise ValueError(
            "Decryption failed: The encrypted data was likely encrypted "
            "with a different SECRET_KEY. To fix this, you need to either: "
            "1) Re-enter the API key through the edit page, or "
            "2) Ensure all environments use the same SECRET_KEY from data/.secret_key. "
            f"Data info: length={len(ciphertext)}",
        ) from err


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
