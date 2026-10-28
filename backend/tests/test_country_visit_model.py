from datetime import date
from pathlib import Path
from uuid import uuid4
import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.base import Base
from app.db.session import create_database_engine
from app.models.country import Country
from app.models.country_visit import CountryVisit
from app.models.user import User


@pytest.fixture
def database_engine(tmp_path: Path):
    engine = create_database_engine(f"sqlite:///{tmp_path / 'country_visits.db'}")

    Base.metadata.create_all(engine)

    yield engine

    engine.dispose()


def make_user(username: str) -> User:
    return User(
        username=username,
        display_name=username,
        password_hash="test-hash-not-a-real-password",
    )


def seed_country(session: Session) -> None:
    session.add(
        Country(
            code="PT",
            name="Portugal",
            alpha3_code="PRT",
            continent="Europe",
        )
    )
    session.commit()


def make_country_visit(
    user_id,
    *,
    country_code: str = "PT",
    started_on: date = date(2026, 9, 28),
    ended_on: date = date(2026, 10, 3),
) -> CountryVisit:
    """Create a country visit with a complete date range."""

    return CountryVisit(
        user_id=user_id,
        country_code=country_code,
        started_on=started_on,
        started_on_precision="day",
        ended_on=ended_on,
        ended_on_precision="day",
    )


def test_country_visit_can_be_persisted(database_engine) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        user = make_user("goncalo")
        session.add(user)
        session.flush()

        visit = CountryVisit(
            user_id=user.id,
            country_code="PT",
            started_on=date(2026, 9, 1),
            started_on_precision="day",
            ended_on=date(2026, 9, 7),
            ended_on_precision="day",
        )

        session.add(visit)
        session.commit()

        visit_id = visit.id

    with Session(database_engine) as session:
        saved_visit = session.get(CountryVisit, visit_id)

        assert saved_visit is not None
        assert saved_visit.country_code == "PT"
        assert saved_visit.started_on == date(2026, 9, 1)
        assert saved_visit.ended_on == date(2026, 9, 7)
        assert saved_visit.created_at is not None
        assert saved_visit.updated_at is not None


def test_multiple_visits_to_same_country_are_allowed(database_engine) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        user = make_user("goncalo")
        session.add(user)
        session.flush()

        session.add_all(
            [
                make_country_visit(
                    user.id,
                    started_on=date(2022, 8, 10),
                    ended_on=date(2022, 8, 20),
                ),
                make_country_visit(
                    user.id,
                    started_on=date(2024, 6, 1),
                    ended_on=date(2024, 6, 7),
                ),
                make_country_visit(
                    user.id,
                    started_on=date(2026, 9, 28),
                    ended_on=date(2026, 10, 3),
                ),
            ]
        )

        session.commit()

        visits = session.scalars(
            select(CountryVisit).where(
                CountryVisit.user_id == user.id,
                CountryVisit.country_code == "PT",
            )
        ).all()

        assert len(visits) == 3


@pytest.mark.parametrize(
    ("started_on", "started_on_precision", "ended_on", "ended_on_precision"),
    [
        (None, None, None, None),
        (date(2026, 10, 1), "day", None, None),
        (None, None, date(2026, 10, 3), "day"),
        (date(2026, 10, 1), None, date(2026, 10, 3), "day"),
        (date(2026, 10, 1), "day", date(2026, 10, 3), None),
    ],
)
def test_country_visit_requires_complete_dates(
    database_engine,
    started_on,
    started_on_precision,
    ended_on,
    ended_on_precision,
) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        user = make_user("goncalo")
        session.add(user)
        session.flush()

        session.add(
            CountryVisit(
                user_id=user.id,
                country_code="PT",
                started_on=started_on,
                started_on_precision=started_on_precision,
                ended_on=ended_on,
                ended_on_precision=ended_on_precision,
            )
        )

        with pytest.raises(IntegrityError):
            session.flush()

        session.rollback()


@pytest.mark.parametrize(
    ("started_on", "ended_on"),
    [
        (date(2026, 10, 5), date(2026, 10, 1)),
        (None, date(2026, 10, 5)),
    ],
)
def test_invalid_visit_dates_are_rejected(
    database_engine,
    started_on,
    ended_on,
) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        user = make_user("goncalo")
        session.add(user)
        session.flush()

        session.add(
            CountryVisit(
                user_id=user.id,
                country_code="PT",
                started_on=started_on,
                started_on_precision="day" if started_on is not None else None,
                ended_on=ended_on,
                ended_on_precision="day" if ended_on is not None else None,
            )
        )

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()


def test_visit_requires_existing_country(database_engine) -> None:
    with Session(database_engine) as session:
        user = make_user("goncalo")
        session.add(user)
        session.flush()

        session.add(
            make_country_visit(
                user.id,
                country_code="XX",
            )
        )

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()


def test_visit_requires_existing_user(database_engine) -> None:
    from uuid import uuid4

    with Session(database_engine) as session:
        seed_country(session)

        session.add(make_country_visit(uuid4()))

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()


def test_different_users_can_visit_same_country(database_engine) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        user_a = make_user("user_a")
        user_b = make_user("user_b")

        session.add_all([user_a, user_b])
        session.flush()

        session.add_all(
            [
                make_country_visit(user_a.id),
                make_country_visit(user_b.id),
            ]
        )

        session.commit()

        assert (
            session.scalar(select(CountryVisit).where(CountryVisit.user_id == user_a.id))
            is not None
        )

        assert (
            session.scalar(select(CountryVisit).where(CountryVisit.user_id == user_b.id))
            is not None
        )


def test_deleting_user_deletes_country_visits(database_engine) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        user = make_user("goncalo")
        session.add(user)
        session.flush()

        visit = make_country_visit(user.id)

        session.add(visit)
        session.commit()

        visit_id = visit.id

        session.delete(user)
        session.commit()

    with Session(database_engine) as session:
        assert session.get(CountryVisit, visit_id) is None
