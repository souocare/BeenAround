from fastapi import APIRouter

from app.api.auth import router as auth_router
from app.api.countries import router as countries_router
from app.api.setup import router as setup_router

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(setup_router)
api_router.include_router(auth_router)
api_router.include_router(countries_router)


@api_router.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "healthy"}
