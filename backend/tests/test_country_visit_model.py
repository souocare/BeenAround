from datetime import date
from pathlib import Path

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
                CountryVisit(
                    user_id=user.id,
                    country_code="PT",
                    started_on=date(2022, 8, 10),
                    started_on_precision="day",
                    ended_on=date(2022, 8, 20),
                    ended_on_precision="day",
                ),
                CountryVisit(
                    user_id=user.id,
                    country_code="PT",
                    started_on=date(2024, 6, 1),
                    started_on_precision="day",
                    ended_on=date(2024, 6, 7),
                    ended_on_precision="day",
                ),
                CountryVisit(
                    user_id=user.id,
                    country_code="PT",
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


def test_visit_without_dates_is_allowed(database_engine) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        user = make_user("goncalo")
        session.add(user)
        session.flush()

        session.add(
            CountryVisit(
                user_id=user.id,
                country_code="PT",
            )
        )

        session.commit()

        visit = session.scalar(select(CountryVisit))

        assert visit is not None
        assert visit.started_on is None
        assert visit.ended_on is None
        assert visit.started_on_precision is None
        assert visit.ended_on_precision is None


def test_visit_with_only_start_date_is_allowed(database_engine) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        user = make_user("goncalo")
        session.add(user)
        session.flush()

        session.add(
            CountryVisit(
                user_id=user.id,
                country_code="PT",
                started_on=date(2026, 10, 1),
                started_on_precision="day",
            )
        )

        session.commit()


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
            CountryVisit(
                user_id=user.id,
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

        session.add(
            CountryVisit(
                user_id=uuid4(),
                country_code="PT",
            )
        )

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
                CountryVisit(
                    user_id=user_a.id,
                    country_code="PT",
                ),
                CountryVisit(
                    user_id=user_b.id,
                    country_code="PT",
                ),
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

        visit = CountryVisit(
            user_id=user.id,
            country_code="PT",
        )

        session.add(visit)
        session.commit()

        visit_id = visit.id

        session.delete(user)
        session.commit()

    with Session(database_engine) as session:
        assert session.get(CountryVisit, visit_id) is None
