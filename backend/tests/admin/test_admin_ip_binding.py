"""Tests for admin API key authentication."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from app.admin.auth import AdminAuthRequired, _compute_session_hash


class TestAdminApiKeyAuth:
    @pytest.mark.asyncio
    async def test_valid_api_key_via_x_api_key_header(self):
        """Test X-API-Key header with valid key."""
        admin_auth = AdminAuthRequired()
        mock_request = MagicMock()
        mock_request.headers.get.return_value = "admin-key-123"
        mock_request.headers.get.side_effect = lambda k, default=None: {
            "Authorization": None,
            "X-API-Key": "admin-key-123",
        }.get(k, default)

        with patch("app.admin.auth.get_settings") as mock_settings:
            mock_settings.return_value.API_KEY = "admin-key-123"
            result = await admin_auth.__call__(mock_request, None)
            assert result == 1

    @pytest.mark.asyncio
    async def test_valid_api_key_via_bearer_header(self):
        """Test Authorization Bearer header with valid key."""
        admin_auth = AdminAuthRequired()
        mock_request = MagicMock()
        mock_request.headers.get.side_effect = lambda k, default=None: {
            "Authorization": "Bearer admin-key-123",
            "X-API-Key": None,
        }.get(k, default)

        with patch("app.admin.auth.get_settings") as mock_settings:
            mock_settings.return_value.API_KEY = "admin-key-123"
            result = await admin_auth.__call__(mock_request, None)
            assert result == 1

    @pytest.mark.asyncio
    async def test_valid_api_key_via_cookie(self):
        """Test admin_session cookie with valid HMAC hash."""
        admin_auth = AdminAuthRequired()
        mock_request = MagicMock()
        mock_request.headers.get.side_effect = lambda k, default=None: {
            "Authorization": None,
            "X-API-Key": None,
        }.get(k, default)

        with patch("app.admin.auth.get_settings") as mock_settings:
            mock_settings.return_value.API_KEY = "admin-key-123"
            mock_settings.return_value.SECRET_KEY = "test-secret"
            session_hash = _compute_session_hash("admin-key-123")
            result = await admin_auth.__call__(mock_request, session_hash)
            assert result == 1

    @pytest.mark.asyncio
    async def test_invalid_api_key_returns_401(self):
        """Test invalid API key raises 401."""
        from fastapi import HTTPException

        admin_auth = AdminAuthRequired()
        mock_request = MagicMock()
        mock_request.headers.get.side_effect = lambda k, default=None: {
            "Authorization": None,
            "X-API-Key": "wrong-key",
        }.get(k, default)

        with patch("app.admin.auth.get_settings") as mock_settings:
            mock_settings.return_value.API_KEY = "correct-key"
            with pytest.raises(HTTPException) as exc_info:
                await admin_auth.__call__(mock_request, None)
            assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_no_key_returns_401_when_configured(self):
        """Test missing API key raises 401 when API_KEY is configured."""
        from fastapi import HTTPException

        admin_auth = AdminAuthRequired()
        mock_request = MagicMock()
        mock_request.headers.get.side_effect = lambda k, default=None: {
            "Authorization": None,
            "X-API-Key": None,
        }.get(k, default)

        with patch("app.admin.auth.get_settings") as mock_settings:
            mock_settings.return_value.API_KEY = "configured-key"
            with pytest.raises(HTTPException) as exc_info:
                await admin_auth.__call__(mock_request, None)
            assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_no_key_allowed_when_empty(self):
        """Test requests allowed when API_KEY is empty (development mode)."""
        admin_auth = AdminAuthRequired()
        mock_request = MagicMock()
        mock_request.headers.get.side_effect = lambda k, default=None: {
            "Authorization": None,
            "X-API-Key": None,
        }.get(k, default)

        with patch("app.admin.auth.get_settings") as mock_settings:
            mock_settings.return_value.API_KEY = ""
            result = await admin_auth.__call__(mock_request, None)
            assert result == 1
