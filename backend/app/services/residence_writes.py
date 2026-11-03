"""Transactional write operations for historical residences."""

from collections.abc import Iterator
from contextlib import contextmanager
from uuid import UUID

from sqlalchemy import Engine
from sqlalchemy.orm import Session

from app.domain.residences import ResidencePeriod
from app.models.residence import Residence
from app.repositories.residences import ResidenceRepository
from app.schemas.residences import ResidenceCreate, ResidenceUpdate
from app.services.residences import (
    find_overlapping_residences,
    residence_requested_state,
    validate_residence_location,
    validate_residence_overlap_confirmation,
)


class ResidenceNotFound(Exception):
    """The requested residence does not exist or is not owned by the user."""


@contextmanager
def residence_write_session(engine: Engine) -> Iterator[Session]:
    """Open a SQLite write transaction before reading residence data.

    BEGIN IMMEDIATE serializes cooperating SQLite writers before overlap
    detection, avoiding a read-then-write race.

    The caller must not use this helper with an existing transaction.
    """

    if engine.dialect.name != "sqlite":
        raise RuntimeError("Residence write transaction requires SQLite.")

    with engine.connect() as connection:
        connection.exec_driver_sql("BEGIN IMMEDIATE")

        try:
            with Session(
                bind=connection,
                autoflush=False,
                expire_on_commit=False,
            ) as session:
                yield session

                session.flush()
                connection.commit()

        except Exception:
            connection.rollback()
            raise


def create_residence(
    *,
    engine: Engine,
    user_id: UUID,
    payload: ResidenceCreate,
) -> Residence:
    """Create a residence after validating its current overlap state."""

    with residence_write_session(engine) as session:
        repository = ResidenceRepository(session)

        validate_residence_location(
            repository=repository,
            country_code=payload.country_code,
            city_id=payload.city_id,
        )

        period = ResidencePeriod(
            started_on=payload.started_on,
            started_on_precision=payload.started_on_precision,
            ended_on=payload.ended_on,
            ended_on_precision=payload.ended_on_precision,
        )

        requested = residence_requested_state(
            country_code=payload.country_code,
            city_id=payload.city_id,
            period=period,
        )

        overlaps = find_overlapping_residences(
            repository=repository,
            user_id=user_id,
            proposed_period=period,
        )

        validate_residence_overlap_confirmation(
            requested=requested,
            overlaps=overlaps,
            confirmation=payload.overlap_confirmation,
        )

        residence = repository.create(
            user_id=user_id,
            country_code=requested.country_code,
            city_id=requested.city_id,
            started_on=period.started_on,
            started_on_precision=period.started_on_precision,
            ended_on=period.ended_on,
            ended_on_precision=period.ended_on_precision,
            commit=False,
        )

        return residence


def update_residence(
    *,
    engine: Engine,
    user_id: UUID,
    residence_id: UUID,
    payload: ResidenceUpdate,
) -> Residence:
    """Update a residence after checking ownership and current overlaps."""

    with residence_write_session(engine) as session:
        repository = ResidenceRepository(session)

        existing = repository.get_for_user(
            residence_id=residence_id,
            user_id=user_id,
        )

        if existing is None:
            raise ResidenceNotFound("Residence not found.")

        changes = payload.model_dump(
            exclude_unset=True,
            exclude={"overlap_confirmation"},
        )

        country_code = changes.get(
            "country_code",
            existing.country_code,
        )

        city_id = changes.get(
            "city_id",
            existing.city_id,
        )

        period = ResidencePeriod(
            started_on=changes.get(
                "started_on",
                existing.started_on,
            ),
            started_on_precision=changes.get(
                "started_on_precision",
                existing.started_on_precision,
            ),
            ended_on=changes.get(
                "ended_on",
                existing.ended_on,
            ),
            ended_on_precision=changes.get(
                "ended_on_precision",
                existing.ended_on_precision,
            ),
        )

        validate_residence_location(
            repository=repository,
            country_code=country_code,
            city_id=city_id,
        )

        requested = residence_requested_state(
            country_code=country_code,
            city_id=city_id,
            period=period,
        )

        overlaps = find_overlapping_residences(
            repository=repository,
            user_id=user_id,
            proposed_period=period,
            exclude_residence_id=residence_id,
        )

        validate_residence_overlap_confirmation(
            requested=requested,
            overlaps=overlaps,
            confirmation=payload.overlap_confirmation,
            existing_residence=existing,
        )

        updated = repository.update(
            residence=existing,
            country_code=country_code,
            city_id=city_id,
            started_on=period.started_on,
            started_on_precision=period.started_on_precision,
            ended_on=period.ended_on,
            ended_on_precision=period.ended_on_precision,
            commit=False,
        )

        # Persist pending changes within the current transaction.
        session.flush()

        # Load database-generated values, including updated_at,
        # before the dedicated session is closed.
        session.refresh(updated)

        return updated


def delete_residence(
    *,
    engine: Engine,
    user_id: UUID,
    residence_id: UUID,
) -> None:
    """Delete an owned residence within the SQLite write transaction."""

    with residence_write_session(engine) as session:
        repository = ResidenceRepository(session)

        deleted = repository.delete_for_user(
            residence_id=residence_id,
            user_id=user_id,
            commit=False,
        )

        if not deleted:
            raise ResidenceNotFound("Residence not found.")
