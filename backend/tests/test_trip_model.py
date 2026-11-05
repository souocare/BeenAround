"""Database integrity tests for the Trip model."""

from datetime import date
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.base import Base
from app.models.trip import Trip
from app.models.user import User


@pytest.fixture
def session():
    """Create an isolated SQLite database with foreign keys enabled."""

    engine = create_engine("sqlite:///:memory:")

    @event.listens_for(engine, "connect")
    def enable_foreign_keys(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    Base.metadata.create_all(engine)

    with Session(engine) as db:
        user = User(
            username="triptester",
            display_name="Trip Tester",
            password_hash="test-hash",
        )

        db.add(user)
        db.commit()

        yield db, user.id

    engine.dispose()


def test_create_trip_without_dates(session):
    db, user_id = session

    trip = Trip(
        user_id=user_id,
        name="Japan 2027",
    )

    db.add(trip)
    db.commit()
    db.refresh(trip)

    assert trip.id is not None
    assert trip.user_id == user_id
    assert trip.name == "Japan 2027"
    assert trip.description is None
    assert trip.started_on is None
    assert trip.ended_on is None
    assert trip.created_at is not None
    assert trip.updated_at is not None


def test_create_trip_with_dates(session):
    db, user_id = session

    trip = Trip(
        user_id=user_id,
        name="Japan 2027",
        description="Spring trip to Japan",
        started_on=date(2027, 4, 10),
        started_on_precision="day",
        ended_on=date(2027, 4, 25),
        ended_on_precision="day",
    )

    db.add(trip)
    db.commit()

    assert trip.started_on == date(2027, 4, 10)
    assert trip.ended_on == date(2027, 4, 25)


@pytest.mark.parametrize(
    "name",
    [
        "",
        "   ",
    ],
)
def test_reject_blank_trip_name(session, name):
    db, user_id = session

    db.add(
        Trip(
            user_id=user_id,
            name=name,
        )
    )

    with pytest.raises(IntegrityError):
        db.commit()


def test_reject_trip_without_user(session):
    db, _ = session

    db.add(
        Trip(
            user_id=uuid4(),
            name="Invalid Trip",
        )
    )

    with pytest.raises(IntegrityError):
        db.commit()


@pytest.mark.parametrize(
    "started_on,started_precision,ended_on,ended_precision",
    [
        (date(2027, 4, 10), None, None, None),
        (None, "day", None, None),
        (None, None, date(2027, 4, 20), None),
        (None, None, None, "month"),
        (date(2027, 4, 15), "month", None, None),
        (date(2027, 4, 15), "year", None, None),
    ],
)
def test_reject_invalid_date_precision(
    session,
    started_on,
    started_precision,
    ended_on,
    ended_precision,
):
    db, user_id = session

    db.add(
        Trip(
            user_id=user_id,
            name="Invalid Dates",
            started_on=started_on,
            started_on_precision=started_precision,
            ended_on=ended_on,
            ended_on_precision=ended_precision,
        )
    )

    with pytest.raises(IntegrityError):
        db.commit()


def test_reject_invalid_date_range(session):
    db, user_id = session

    db.add(
        Trip(
            user_id=user_id,
            name="Invalid Range",
            started_on=date(2027, 5, 1),
            started_on_precision="day",
            ended_on=date(2027, 4, 1),
            ended_on_precision="month",
        )
    )

    with pytest.raises(IntegrityError):
        db.commit()


@pytest.mark.parametrize(
    "started_on,started_precision,ended_on,ended_precision",
    [
        (None, None, None, None),
        (date(2027, 4, 10), "day", None, None),
        (None, None, date(2027, 4, 20), "day"),
        (
            date(2027, 4, 20),
            "day",
            date(2027, 4, 1),
            "month",
        ),
    ],
)
def test_accept_valid_optional_date_ranges(
    session,
    started_on,
    started_precision,
    ended_on,
    ended_precision,
):
    db, user_id = session

    db.add(
        Trip(
            user_id=user_id,
            name="Valid Dates",
            started_on=started_on,
            started_on_precision=started_precision,
            ended_on=ended_on,
            ended_on_precision=ended_precision,
        )
    )

    db.commit()