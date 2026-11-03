"""Concurrency tests for historical residence writes using SQLite."""

from collections.abc import Generator
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FutureTimeoutError
from datetime import date
from pathlib import Path
from uuid import UUID

import pytest
from sqlalchemy import select
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.db.base import Base
from app.db.session import create_database_engine
from app.domain.visit_dates import DatePrecision
from app.models.country import Country
from app.models.residence import Residence
from app.models.user import User
from app.repositories.residences import ResidenceRepository
from app.schemas.residences import ResidenceCreate, ResidenceOverlapConfirmation
from app.services.residence_writes import (
    create_residence,
    residence_write_session,
)
from app.services.residences import (
    ResidenceOverlapRequired,
    ResidenceOverlapStale,
)


@pytest.fixture
def database_engine(tmp_path: Path) -> Generator[Engine, None, None]:
    """Provide a file-backed SQLite database for independent connections."""

    engine = create_database_engine(f"sqlite:///{tmp_path / 'residence_concurrency.db'}")

    Base.metadata.create_all(engine)

    yield engine

    engine.dispose()


@pytest.fixture
def user_id(database_engine: Engine) -> UUID:
    """Seed a country and one user."""

    with Session(database_engine) as session:
        session.add(
            Country(
                code="PT",
                name="Portugal",
                alpha3_code="PRT",
                continent="EU",
            )
        )

        user = User(
            username="concurrency_user",
            email="concurrency@example.com",
            display_name="Concurrency User",
            password_hash=hash_password("test-password-123"),
        )

        session.add(user)
        session.commit()

        return user.id


def residence_payload(
    *,
    started_on: str,
    ended_on: str,
    confirmation: ResidenceOverlapConfirmation | None = None,
) -> ResidenceCreate:
    """Create a valid residence request."""

    return ResidenceCreate(
        country_code="PT",
        city_id=None,
        started_on=date.fromisoformat(started_on),
        started_on_precision=DatePrecision.MONTH,
        ended_on=date.fromisoformat(ended_on),
        ended_on_precision=DatePrecision.MONTH,
        overlap_confirmation=confirmation,
    )


def count_residences(engine: Engine, user_id: UUID) -> int:
    """Count persisted residences belonging to a user."""

    with Session(engine) as session:
        return len(
            session.scalars(
                select(Residence).where(
                    Residence.user_id == user_id,
                )
            ).all()
        )


def test_concurrent_overlapping_create_requires_confirmation(
    database_engine: Engine,
    user_id: UUID,
) -> None:
    """A competing writer must recheck overlaps after the first commits."""

    def second_writer() -> Residence:
        return create_residence(
            engine=database_engine,
            user_id=user_id,
            payload=residence_payload(
                started_on="2022-01-01",
                ended_on="2022-12-01",
            ),
        )

    with ThreadPoolExecutor(max_workers=2) as executor:
        # Hold the first transaction open on the main thread so the
        # second writer must wait for SQLite's write lock.
        with residence_write_session(database_engine) as session:
            repository = ResidenceRepository(session)

            first = repository.create(
                user_id=user_id,
                country_code="PT",
                city_id=None,
                started_on=date(2020, 1, 1),
                started_on_precision=DatePrecision.MONTH,
                ended_on=date(2023, 12, 1),
                ended_on_precision=DatePrecision.MONTH,
                commit=False,
            )

            assert first.id is not None

            future = executor.submit(second_writer)

            # The competing transaction cannot complete while the
            # current write transaction remains open.
            with pytest.raises(FutureTimeoutError):
                future.result(timeout=0.2)

        # The first transaction has now committed.
        # The second writer can proceed, but must detect the overlap.
        with pytest.raises(ResidenceOverlapRequired) as exc:
            future.result(timeout=10)

    assert len(exc.value.overlaps) == 1
    assert count_residences(database_engine, user_id) == 1


def test_concurrent_change_invalidates_overlap_confirmation(
    database_engine: Engine,
    user_id: UUID,
) -> None:
    """A confirmation cannot authorize an overlap whose state changed."""

    existing = create_residence(
        engine=database_engine,
        user_id=user_id,
        payload=residence_payload(
            started_on="2020-01-01",
            ended_on="2023-12-01",
        ),
    )

    requested = residence_payload(
        started_on="2022-01-01",
        ended_on="2022-12-01",
    )

    # First request obtains the exact overlap snapshot.
    with pytest.raises(ResidenceOverlapRequired) as exc:
        create_residence(
            engine=database_engine,
            user_id=user_id,
            payload=requested,
        )

    confirmation = ResidenceOverlapConfirmation(
        requested=exc.value.requested,
        overlaps=exc.value.overlaps,
        expected_target=exc.value.expected_target,
    )

    confirmed_request = requested.model_copy(update={"overlap_confirmation": confirmation})

    def confirmed_writer() -> Residence:
        return create_residence(
            engine=database_engine,
            user_id=user_id,
            payload=confirmed_request,
        )

    with ThreadPoolExecutor(max_workers=2) as executor:
        # Another writer changes the existing residence while
        # holding the SQLite write transaction.
        with residence_write_session(database_engine) as session:
            repository = ResidenceRepository(session)

            current = repository.get_for_user(
                residence_id=existing.id,
                user_id=user_id,
            )

            assert current is not None

            repository.update(
                residence=current,
                country_code="PT",
                city_id=None,
                started_on=date(2020, 1, 1),
                started_on_precision=DatePrecision.MONTH,
                ended_on=date(2024, 12, 1),
                ended_on_precision=DatePrecision.MONTH,
                commit=False,
            )

            future = executor.submit(confirmed_writer)

            with pytest.raises(FutureTimeoutError):
                future.result(timeout=0.2)

        # The new database state no longer matches the confirmation.
        with pytest.raises(ResidenceOverlapStale):
            future.result(timeout=10)

    assert count_residences(database_engine, user_id) == 1

    with Session(database_engine) as session:
        saved = session.get(Residence, existing.id)

        assert saved is not None
        assert saved.ended_on == date(2024, 12, 1)
