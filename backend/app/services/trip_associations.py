"""Application services for Trip visit associations."""

from uuid import UUID

from sqlalchemy import Engine
from sqlalchemy.orm import Session

from app.db.write_transactions import sqlite_write_session

from app.models.city_visit import CityVisit
from app.models.country_visit import CountryVisit

from app.repositories.city_visits import CityVisitRepository
from app.repositories.country_visits import CountryVisitRepository
from app.repositories.trip_associations import (
    CityVisitAssociationRow,
    TripAssociationRepository,
)
from app.repositories.trips import TripRepository

from app.services.trips import TripNotFound


class VisitNotFound(Exception):
    """The visit does not exist or is not owned by the user."""


class TripAssociationNotFound(Exception):
    """The requested Trip visit association does not exist."""


# ---------------------------------------------------------
# Shared authorization
# ---------------------------------------------------------


def _require_owned_trip(
    *,
    session: Session,
    user_id: UUID,
    trip_id: UUID,
) -> None:
    """Require an existing Trip belonging to the user."""

    repository = TripRepository(session)

    trip = repository.get_for_user(
        trip_id=trip_id,
        user_id=user_id,
    )

    if trip is None:
        raise TripNotFound("Trip not found.")


def _require_owned_country_visit(
    *,
    session: Session,
    user_id: UUID,
    visit_id: UUID,
) -> None:
    """Require a country visit belonging to the user."""

    repository = CountryVisitRepository(session)

    visit = repository.get_for_user(
        visit_id=visit_id,
        user_id=user_id,
    )

    if visit is None:
        raise VisitNotFound("Country visit not found.")


def _require_owned_city_visit(
    *,
    session: Session,
    user_id: UUID,
    visit_id: UUID,
) -> None:
    """Require a city visit belonging to the user."""

    repository = CityVisitRepository(session)

    visit = repository.get_for_user(
        visit_id=visit_id,
        user_id=user_id,
    )

    if visit is None:
        raise VisitNotFound("City visit not found.")


# ---------------------------------------------------------
# Country visit associations
# ---------------------------------------------------------


def list_trip_country_visits(
    *,
    session: Session,
    user_id: UUID,
    trip_id: UUID,
) -> list[CountryVisit]:
    """List country visits belonging to an owned Trip."""

    _require_owned_trip(
        session=session,
        user_id=user_id,
        trip_id=trip_id,
    )

    repository = TripAssociationRepository(session)

    return repository.list_country_visits(
        trip_id=trip_id,
    )


def add_trip_country_visit(
    *,
    engine: Engine,
    user_id: UUID,
    trip_id: UUID,
    visit_id: UUID,
) -> bool:
    """Associate an existing owned country visit with an owned Trip.

    Returns True if created and False if already associated.
    """

    with sqlite_write_session(engine) as session:
        _require_owned_trip(
            session=session,
            user_id=user_id,
            trip_id=trip_id,
        )

        _require_owned_country_visit(
            session=session,
            user_id=user_id,
            visit_id=visit_id,
        )

        repository = TripAssociationRepository(session)

        created = repository.add_country_visit(
            trip_id=trip_id,
            visit_id=visit_id,
        )

        return created


def remove_trip_country_visit(
    *,
    engine: Engine,
    user_id: UUID,
    trip_id: UUID,
    visit_id: UUID,
) -> None:
    """Remove a country visit association without deleting the visit."""

    with sqlite_write_session(engine) as session:
        _require_owned_trip(
            session=session,
            user_id=user_id,
            trip_id=trip_id,
        )

        _require_owned_country_visit(
            session=session,
            user_id=user_id,
            visit_id=visit_id,
        )

        repository = TripAssociationRepository(session)

        removed = repository.remove_country_visit(
            trip_id=trip_id,
            visit_id=visit_id,
        )

        if not removed:
            raise TripAssociationNotFound("Trip country visit association not found.")


# ---------------------------------------------------------
# City visit associations
# ---------------------------------------------------------


def list_trip_city_visits(
    *,
    session: Session,
    user_id: UUID,
    trip_id: UUID,
) -> list[CityVisitAssociationRow]:
    """List city visits belonging to an owned Trip."""

    _require_owned_trip(
        session=session,
        user_id=user_id,
        trip_id=trip_id,
    )

    repository = TripAssociationRepository(session)

    return repository.list_city_visits(
        trip_id=trip_id,
    )


def add_trip_city_visit(
    *,
    engine: Engine,
    user_id: UUID,
    trip_id: UUID,
    visit_id: UUID,
) -> bool:
    """Associate an existing owned city visit with an owned Trip."""

    with sqlite_write_session(engine) as session:
        _require_owned_trip(
            session=session,
            user_id=user_id,
            trip_id=trip_id,
        )

        _require_owned_city_visit(
            session=session,
            user_id=user_id,
            visit_id=visit_id,
        )

        repository = TripAssociationRepository(session)

        created = repository.add_city_visit(
            trip_id=trip_id,
            visit_id=visit_id,
        )

        return created


def remove_trip_city_visit(
    *,
    engine: Engine,
    user_id: UUID,
    trip_id: UUID,
    visit_id: UUID,
) -> None:
    """Remove a city visit association without deleting the visit."""

    with sqlite_write_session(engine) as session:
        _require_owned_trip(
            session=session,
            user_id=user_id,
            trip_id=trip_id,
        )

        _require_owned_city_visit(
            session=session,
            user_id=user_id,
            visit_id=visit_id,
        )

        repository = TripAssociationRepository(session)

        removed = repository.remove_city_visit(
            trip_id=trip_id,
            visit_id=visit_id,
        )

        if not removed:
            raise TripAssociationNotFound("Trip city visit association not found.")
