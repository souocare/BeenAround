from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from datetime import UTC, datetime

from fastapi import FastAPI

from app.api.router import api_router
from app.core.config import Settings, get_settings
from app.middleware.csrf import CSRFMiddleware


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    app.state.started_at = datetime.now(UTC)
    yield


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings if settings is not None else get_settings()

    app = FastAPI(
        title=f"{settings.app_name} API",
        description="Self-hosted travel history API.",
        version="0.1.0",
        debug=settings.debug,
        lifespan=lifespan,
    )

    app.add_middleware(
        CSRFMiddleware,
        allowed_origins=settings.csrf_allowed_origins,
    )

    app.include_router(api_router)

    return app


app = create_app()
