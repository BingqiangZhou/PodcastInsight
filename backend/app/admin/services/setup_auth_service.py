"""Admin authentication service helpers (API key mode)."""

from fastapi import Request, status
from fastapi.responses import RedirectResponse


class AdminSetupAuthService:
    """Template rendering helpers for admin auth (simplified for API key mode)."""

    @staticmethod
    def build_template_response(
        *,
        templates,
        template_name: str,
        request: Request,
        messages: list[dict] | None = None,
        status_code: int = status.HTTP_200_OK,
        **context,
    ):
        """Render a template response."""
        return templates.TemplateResponse(
            request,
            template_name,
            {
                "request": request,
                "messages": messages or [],
                **context,
            },
            status_code=status_code,
        )

    @staticmethod
    def build_csrf_template_response(
        *,
        templates,
        template_name: str,
        request: Request,
        messages: list[dict] | None = None,
        status_code: int = status.HTTP_200_OK,
        **context,
    ):
        """Render a template (same as build_template_response without CSRF)."""
        return AdminSetupAuthService.build_template_response(
            templates=templates,
            template_name=template_name,
            request=request,
            messages=messages,
            status_code=status_code,
            **context,
        )
