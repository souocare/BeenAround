from collections.abc import Awaitable, Callable

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse, Response

from app.core.auth_constants import WEB_SESSION_COOKIE
from app.core.csrf import SAFE_METHODS, is_allowed_request_origin


class CSRFMiddleware(BaseHTTPMiddleware):
    """Protect unsafe requests carrying Web session cookies."""

    def __init__(
        self,
        app,
        *,
        allowed_origins: list[str],
    ) -> None:
        super().__init__(app)
        self._allowed_origins = allowed_origins

    async def dispatch(
        self,
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        if request.method in SAFE_METHODS:
            return await call_next(request)

        if WEB_SESSION_COOKIE not in request.cookies:
            return await call_next(request)

        if not is_allowed_request_origin(
            origin=request.headers.get("origin"),
            referer=request.headers.get("referer"),
            allowed_origins=self._allowed_origins,
        ):
            return JSONResponse(
                status_code=403,
                content={"detail": "Invalid request origin."},
            )

        return await call_next(request)
