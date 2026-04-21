"""Admin authentication service helpers (API key mode)."""

from fastapi import Request, status


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
