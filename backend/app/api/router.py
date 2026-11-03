from fastapi import APIRouter

from app.api.auth import router as auth_router
from app.api.countries import router as countries_router
from app.api.country_visits import router as country_visits_router
from app.api.setup import router as setup_router
from app.api.cities import router as cities_router
from app.api.city_visits import router as city_visits_router
from app.api.residences import router as residences_router
from app.api.wishlist_entries import router as wishlist_router


api_router = APIRouter(prefix="/api/v1")

api_router.include_router(setup_router)
api_router.include_router(auth_router)
api_router.include_router(countries_router)
api_router.include_router(country_visits_router)
api_router.include_router(cities_router)
api_router.include_router(city_visits_router)
api_router.include_router(residences_router)
api_router.include_router(wishlist_router)


@api_router.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "healthy"}
