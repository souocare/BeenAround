"""Tests for conditional country visit date updates."""

from datetime import date
from pathlib import Path

import pytest
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.db.base import Base
from app.db.session import create_database_engine
from app.domain.city_country_visit_association import VisitDateRange
from app.domain.visit_dates import DatePrecision
from app.models.country import Country
from app.models.country_visit import CountryVisit
from app.models.user import User
from app.repositories.country_visits import CountryVisitRepository


def date_range(
    start: date,
    end: date,
    *,
    start_precision: DatePrecision = DatePrecision.DAY,
    end_precision: DatePrecision = DatePrecision.DAY,
) -> VisitDateRange:
    return VisitDateRange(
        started_on=start,
        started_on_precision=start_precision,
        ended_on=end,
        ended_on_precision=end_precision,
    )


@pytest.fixture
def database_session(tmp_path: Path):
    engine = create_database_engine(f"sqlite:///{tmp_path / 'conditional_country_visits.db'}")

    Base.metadata.create_all(engine)

    with Session(engine) as session:
        session.add(
            Country(
                code="PT",
                name="Portugal",
                alpha3_code="PRT",
                continent="EU",
            )
        )

        user = User(
            username="goncalo",
            email="goncalo@example.com",
            display_name="Gonçalo",
            password_hash=hash_password("correct-password-123"),
        )

        session.add(user)
        session.flush()

        visit = CountryVisit(
            user_id=user.id,
            country_code="PT",
            started_on=date(2025, 6, 10),
            started_on_precision="day",
            ended_on=date(2025, 6, 15),
            ended_on_precision="day",
        )

        session.add(visit)
        session.commit()

        yield session, user.id, visit.id

    engine.dispose()


def test_conditional_update_succeeds_when_expected_state_matches(
    database_session,
) -> None:
    session, user_id, visit_id = database_session

    repository = CountryVisitRepository(session)

    changed = repository.update_dates_if_unchanged(
        visit_id=visit_id,
        user_id=user_id,
        expected=date_range(
            date(2025, 6, 10),
            date(2025, 6, 15),
        ),
        proposed=date_range(
            date(2025, 6, 10),
            date(2025, 6, 18),
        ),
    )

    assert changed is True

    session.commit()
    session.expire_all()

    saved = repository.get_for_user(
        visit_id=visit_id,
        user_id=user_id,
    )

    assert saved is not None
    assert saved.started_on == date(2025, 6, 10)
    assert saved.ended_on == date(2025, 6, 18)


def test_conditional_update_rejects_stale_dates(
    database_session,
) -> None:
    session, user_id, visit_id = database_session

    repository = CountryVisitRepository(session)

    changed = repository.update_dates_if_unchanged(
        visit_id=visit_id,
        user_id=user_id,
        expected=date_range(
            date(2025, 6, 10),
            date(2025, 6, 14),
        ),
        proposed=date_range(
            date(2025, 6, 10),
            date(2025, 6, 18),
        ),
    )

    assert changed is False

    session.expire_all()

    saved = repository.get_for_user(
        visit_id=visit_id,
        user_id=user_id,
    )

    assert saved is not None
    assert saved.ended_on == date(2025, 6, 15)


def test_conditional_update_rejects_stale_precision(
    database_session,
) -> None:
    session, user_id, visit_id = database_session

    repository = CountryVisitRepository(session)

    changed = repository.update_dates_if_unchanged(
        visit_id=visit_id,
        user_id=user_id,
        expected=date_range(
            date(2025, 6, 10),
            date(2025, 6, 15),
            end_precision=DatePrecision.MONTH,
        ),
        proposed=date_range(
            date(2025, 6, 10),
            date(2025, 6, 18),
        ),
    )

    assert changed is False

    session.expire_all()

    saved = repository.get_for_user(
        visit_id=visit_id,
        user_id=user_id,
    )

    assert saved is not None
    assert saved.ended_on_precision == "day"


def test_conditional_update_rejects_another_user(
    database_session,
) -> None:
    from uuid import uuid4

    session, _, visit_id = database_session

    repository = CountryVisitRepository(session)

    changed = repository.update_dates_if_unchanged(
        visit_id=visit_id,
        user_id=uuid4(),
        expected=date_range(
            date(2025, 6, 10),
            date(2025, 6, 15),
        ),
        proposed=date_range(
            date(2025, 6, 10),
            date(2025, 6, 18),
        ),
    )

    assert changed is False


def test_conditional_update_can_be_rolled_back(
    database_session,
) -> None:
    session, user_id, visit_id = database_session

    repository = CountryVisitRepository(session)

    changed = repository.update_dates_if_unchanged(
        visit_id=visit_id,
        user_id=user_id,
        expected=date_range(
            date(2025, 6, 10),
            date(2025, 6, 15),
        ),
        proposed=date_range(
            date(2025, 6, 10),
            date(2025, 6, 18),
        ),
    )

    assert changed is True

    # No commit has occurred: the entire update can still be undone.
    session.rollback()

    saved = repository.get_for_user(
        visit_id=visit_id,
        user_id=user_id,
    )

    assert saved is not None
    assert saved.ended_on == date(2025, 6, 15)

def test_conditional_update_rejects_second_writer(
    database_session,
) -> None:
    session, user_id, visit_id = database_session

    expected = date_range(
        date(2025, 6, 10),
        date(2025, 6, 15),
    )

    first_proposal = date_range(
        date(2025, 6, 10),
        date(2025, 6, 18),
    )

    second_proposal = date_range(
        date(2025, 6, 10),
        date(2025, 6, 25),
    )

    repository = CountryVisitRepository(session)

    first_update = repository.update_dates_if_unchanged(
        visit_id=visit_id,
        user_id=user_id,
        expected=expected,
        proposed=first_proposal,
    )

    assert first_update is True

    session.commit()

    second_update = repository.update_dates_if_unchanged(
        visit_id=visit_id,
        user_id=user_id,
        expected=expected,
        proposed=second_proposal,
    )

    assert second_update is False

    session.expire_all()

    saved = repository.get_for_user(
        visit_id=visit_id,
        user_id=user_id,
    )

    assert saved is not None
    assert saved.ended_on == date(2025, 6, 18)

