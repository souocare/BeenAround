"""Tests for the city visit persistence model."""

from datetime import date
from pathlib import Path
from uuid import uuid4

import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.base import Base
from app.db.session import create_database_engine
from app.models.city import City
from app.models.city_visit import CityVisit
from app.models.country import Country
from app.models.user import User


CITY_ID = 2267057


@pytest.fixture
def database_engine(tmp_path: Path):
    engine = create_database_engine(f"sqlite:///{tmp_path / 'city_visits.db'}")

    Base.metadata.create_all(engine)

    yield engine

    engine.dispose()


def make_user(username: str) -> User:
    return User(
        username=username,
        display_name=username,
        password_hash="test-hash-not-a-real-password",
    )


def seed_city(session: Session) -> None:
    session.add(
        Country(
            code="PT",
            name="Portugal",
            alpha3_code="PRT",
            continent="Europe",
        )
    )

    session.flush()

    session.add(
        City(
            id=CITY_ID,
            country_code="PT",
            name="Lisbon",
            ascii_name="Lisbon",
            latitude=38.71667,
            longitude=-9.13333,
            population=517802,
            feature_code="PPLC",
        )
    )

    session.commit()


def test_city_visit_can_be_persisted(database_engine) -> None:
    with Session(database_engine) as session:
        seed_city(session)

        user = make_user("goncalo")
        session.add(user)
        session.flush()

        visit = CityVisit(
            user_id=user.id,
            city_id=CITY_ID,
            started_on=date(2026, 9, 1),
            started_on_precision="day",
            ended_on=date(2026, 9, 7),
            ended_on_precision="day",
        )

        session.add(visit)
        session.commit()

        visit_id = visit.id

    with Session(database_engine) as session:
        saved = session.get(CityVisit, visit_id)

        assert saved is not None
        assert saved.city_id == CITY_ID
        assert saved.started_on == date(2026, 9, 1)
        assert saved.ended_on == date(2026, 9, 7)
        assert saved.created_at is not None
        assert saved.updated_at is not None


def test_multiple_visits_to_same_city_are_allowed(database_engine) -> None:
    with Session(database_engine) as session:
        seed_city(session)

        user = make_user("goncalo")
        session.add(user)
        session.flush()

        session.add_all(
            [
                CityVisit(
                    user_id=user.id,
                    city_id=CITY_ID,
                    started_on=date(2022, 8, 10),
                    started_on_precision="day",
                    ended_on=date(2022, 8, 20),
                    ended_on_precision="day",
                ),
                CityVisit(
                    user_id=user.id,
                    city_id=CITY_ID,
                    started_on=date(2024, 6, 1),
                    started_on_precision="day",
                    ended_on=date(2024, 6, 7),
                    ended_on_precision="day",
                ),
                CityVisit(
                    user_id=user.id,
                    city_id=CITY_ID,
                ),
            ]
        )

        session.commit()

        visits = session.scalars(
            select(CityVisit).where(
                CityVisit.user_id == user.id,
                CityVisit.city_id == CITY_ID,
            )
        ).all()

        assert len(visits) == 3


def test_visit_without_dates_is_allowed(database_engine) -> None:
    with Session(database_engine) as session:
        seed_city(session)

        user = make_user("goncalo")
        session.add(user)
        session.flush()

        session.add(
            CityVisit(
                user_id=user.id,
                city_id=CITY_ID,
            )
        )

        session.commit()

        visit = session.scalar(select(CityVisit))

        assert visit is not None
        assert visit.started_on is None
        assert visit.ended_on is None
        assert visit.started_on_precision is None
        assert visit.ended_on_precision is None


def test_visit_with_only_start_date_is_allowed(database_engine) -> None:
    with Session(database_engine) as session:
        seed_city(session)

        user = make_user("goncalo")
        session.add(user)
        session.flush()

        session.add(
            CityVisit(
                user_id=user.id,
                city_id=CITY_ID,
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
        seed_city(session)

        user = make_user("goncalo")
        session.add(user)
        session.flush()

        session.add(
            CityVisit(
                user_id=user.id,
                city_id=CITY_ID,
                started_on=started_on,
                started_on_precision="day" if started_on is not None else None,
                ended_on=ended_on,
                ended_on_precision="day" if ended_on is not None else None,
            )
        )

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()


def test_visit_requires_existing_city(database_engine) -> None:
    with Session(database_engine) as session:
        user = make_user("goncalo")
        session.add(user)
        session.flush()

        session.add(
            CityVisit(
                user_id=user.id,
                city_id=999999999,
            )
        )

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()


def test_visit_requires_existing_user(database_engine) -> None:
    with Session(database_engine) as session:
        seed_city(session)

        session.add(
            CityVisit(
                user_id=uuid4(),
                city_id=CITY_ID,
            )
        )

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()


def test_different_users_can_visit_same_city(database_engine) -> None:
    with Session(database_engine) as session:
        seed_city(session)

        user_a = make_user("user_a")
        user_b = make_user("user_b")

        session.add_all([user_a, user_b])
        session.flush()

        session.add_all(
            [
                CityVisit(
                    user_id=user_a.id,
                    city_id=CITY_ID,
                ),
                CityVisit(
                    user_id=user_b.id,
                    city_id=CITY_ID,
                ),
            ]
        )

        session.commit()

        visits_a = session.scalars(
            select(CityVisit).where(
                CityVisit.user_id == user_a.id,
            )
        ).all()

        visits_b = session.scalars(
            select(CityVisit).where(
                CityVisit.user_id == user_b.id,
            )
        ).all()

        assert len(visits_a) == 1
        assert len(visits_b) == 1
        assert visits_a[0].user_id == user_a.id
        assert visits_b[0].user_id == user_b.id


def test_deleting_user_deletes_city_visits(database_engine) -> None:
    with Session(database_engine) as session:
        seed_city(session)

        user = make_user("goncalo")
        session.add(user)
        session.flush()

        visit = CityVisit(
            user_id=user.id,
            city_id=CITY_ID,
        )

        session.add(visit)
        session.commit()

        visit_id = visit.id

        session.delete(user)
        session.commit()

    with Session(database_engine) as session:
        assert session.get(CityVisit, visit_id) is None


def test_city_with_visits_cannot_be_deleted(database_engine) -> None:
    with Session(database_engine) as session:
        seed_city(session)

        user = make_user("goncalo")
        session.add(user)
        session.flush()

        session.add(
            CityVisit(
                user_id=user.id,
                city_id=CITY_ID,
            )
        )

        session.commit()

        city = session.get(City, CITY_ID)
        assert city is not None

        session.delete(city)

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()
