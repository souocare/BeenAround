"""Integration tests for transactional residence writes."""

from datetime import date
from pathlib import Path
from uuid import uuid4

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.base import Base
from app.db.session import create_database_engine
from app.models.country import Country
from app.models.residence import Residence
from app.models.user import User
from app.schemas.residences import (
    ResidenceCreate,
    ResidenceOverlapConfirmation,
    ResidenceUpdate,
)
from app.services.residence_writes import (
    ResidenceNotFound,
    create_residence,
    delete_residence,
    update_residence,
)
from app.services.residences import (
    ResidenceOverlapRequired,
    ResidenceOverlapStale,
)


@pytest.fixture
def database_engine(tmp_path: Path):
    engine = create_database_engine(f"sqlite:///{tmp_path / 'residence_writes.db'}")

    Base.metadata.create_all(engine)

    yield engine

    engine.dispose()


def seed_data(engine):
    with Session(engine) as session:
        session.add(
            Country(
                code="PT",
                name="Portugal",
                alpha3_code="PRT",
                continent="Europe",
            )
        )

        user = User(
            username="residence_writer",
            display_name="Residence Writer",
            password_hash="test-hash-not-a-real-password",
        )

        session.add(user)
        session.commit()

        return user.id


def make_create_payload(
    *,
    started_on: str = "2020-01-01",
    ended_on: str = "2023-12-01",
    confirmation=None,
) -> ResidenceCreate:
    data = {
        "country_code": "PT",
        "city_id": None,
        "started_on": started_on,
        "started_on_precision": "month",
        "ended_on": ended_on,
        "ended_on_precision": "month",
    }

    if confirmation is not None:
        data["overlap_confirmation"] = confirmation

    return ResidenceCreate.model_validate(data)


def test_create_residence_without_overlap(database_engine) -> None:
    user_id = seed_data(database_engine)

    residence = create_residence(
        engine=database_engine,
        user_id=user_id,
        payload=make_create_payload(),
    )

    with Session(database_engine) as session:
        saved = session.get(Residence, residence.id)

        assert saved is not None
        assert saved.user_id == user_id
        assert saved.country_code == "PT"
        assert saved.started_on == date(2020, 1, 1)


def test_create_with_overlap_requires_confirmation(database_engine) -> None:
    user_id = seed_data(database_engine)

    create_residence(
        engine=database_engine,
        user_id=user_id,
        payload=make_create_payload(),
    )

    with pytest.raises(ResidenceOverlapRequired) as exc:
        create_residence(
            engine=database_engine,
            user_id=user_id,
            payload=make_create_payload(
                started_on="2022-01-01",
                ended_on="2022-12-01",
            ),
        )

    assert len(exc.value.overlaps) == 1

    with Session(database_engine) as session:
        residences = session.scalars(
            select(Residence).where(
                Residence.user_id == user_id,
            )
        ).all()

        assert len(residences) == 1


def test_create_with_valid_confirmation(database_engine) -> None:
    user_id = seed_data(database_engine)

    create_residence(
        engine=database_engine,
        user_id=user_id,
        payload=make_create_payload(),
    )

    requested_payload = make_create_payload(
        started_on="2022-01-01",
        ended_on="2022-12-01",
    )

    with pytest.raises(ResidenceOverlapRequired) as exc:
        create_residence(
            engine=database_engine,
            user_id=user_id,
            payload=requested_payload,
        )

    confirmation = ResidenceOverlapConfirmation(
        requested=exc.value.requested,
        overlaps=exc.value.overlaps,
        expected_target=exc.value.expected_target,
    )

    confirmed_payload = requested_payload.model_copy(update={"overlap_confirmation": confirmation})

    created = create_residence(
        engine=database_engine,
        user_id=user_id,
        payload=confirmed_payload,
    )

    assert created.id is not None

    with Session(database_engine) as session:
        residences = session.scalars(
            select(Residence).where(
                Residence.user_id == user_id,
            )
        ).all()

        assert len(residences) == 2


def test_stale_confirmation_does_not_create_residence(
    database_engine,
) -> None:
    user_id = seed_data(database_engine)

    existing = create_residence(
        engine=database_engine,
        user_id=user_id,
        payload=make_create_payload(),
    )

    requested_payload = make_create_payload(
        started_on="2022-01-01",
        ended_on="2022-12-01",
    )

    with pytest.raises(ResidenceOverlapRequired) as exc:
        create_residence(
            engine=database_engine,
            user_id=user_id,
            payload=requested_payload,
        )

    confirmation = ResidenceOverlapConfirmation(
        requested=exc.value.requested,
        overlaps=exc.value.overlaps,
    )

    update_residence(
        engine=database_engine,
        user_id=user_id,
        residence_id=existing.id,
        payload=ResidenceUpdate.model_validate(
            {
                "ended_on": "2024-12-01",
                "ended_on_precision": "month",
            }
        ),
    )

    confirmed_payload = requested_payload.model_copy(update={"overlap_confirmation": confirmation})

    with pytest.raises(ResidenceOverlapStale):
        create_residence(
            engine=database_engine,
            user_id=user_id,
            payload=confirmed_payload,
        )


def test_update_residence_without_overlap(database_engine) -> None:
    user_id = seed_data(database_engine)

    existing = create_residence(
        engine=database_engine,
        user_id=user_id,
        payload=make_create_payload(),
    )

    updated = update_residence(
        engine=database_engine,
        user_id=user_id,
        residence_id=existing.id,
        payload=ResidenceUpdate.model_validate(
            {
                "ended_on": "2024-06-01",
                "ended_on_precision": "month",
            }
        ),
    )

    assert updated.id == existing.id
    assert updated.ended_on == date(2024, 6, 1)


def test_update_does_not_find_itself_as_overlap(database_engine) -> None:
    user_id = seed_data(database_engine)

    existing = create_residence(
        engine=database_engine,
        user_id=user_id,
        payload=make_create_payload(),
    )

    update_residence(
        engine=database_engine,
        user_id=user_id,
        residence_id=existing.id,
        payload=ResidenceUpdate.model_validate(
            {
                "ended_on": "2024-06-01",
                "ended_on_precision": "month",
            }
        ),
    )


def test_update_requires_ownership(database_engine) -> None:
    user_id = seed_data(database_engine)

    existing = create_residence(
        engine=database_engine,
        user_id=user_id,
        payload=make_create_payload(),
    )

    with pytest.raises(ResidenceNotFound):
        update_residence(
            engine=database_engine,
            user_id=uuid4(),
            residence_id=existing.id,
            payload=ResidenceUpdate.model_validate({"city_id": None}),
        )


def test_failed_write_does_not_persist_changes(database_engine) -> None:
    user_id = seed_data(database_engine)

    create_residence(
        engine=database_engine,
        user_id=user_id,
        payload=make_create_payload(),
    )

    with pytest.raises(ResidenceOverlapRequired):
        create_residence(
            engine=database_engine,
            user_id=user_id,
            payload=make_create_payload(
                started_on="2022-01-01",
                ended_on="2022-12-01",
            ),
        )

    with Session(database_engine) as session:
        count = len(
            session.scalars(
                select(Residence).where(
                    Residence.user_id == user_id,
                )
            ).all()
        )

        assert count == 1


def test_update_returns_loaded_timestamps(database_engine) -> None:
    """Updated records retain database-generated timestamps after session closure."""

    user_id = seed_data(database_engine)

    existing = create_residence(
        engine=database_engine,
        user_id=user_id,
        payload=make_create_payload(),
    )

    updated = update_residence(
        engine=database_engine,
        user_id=user_id,
        residence_id=existing.id,
        payload=ResidenceUpdate.model_validate(
            {
                "ended_on": "2024-06-01",
                "ended_on_precision": "month",
            }
        ),
    )

    assert updated.updated_at is not None
    assert updated.created_at is not None
    assert updated.ended_on == date(2024, 6, 1)
