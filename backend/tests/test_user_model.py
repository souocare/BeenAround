from pathlib import Path

import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.base import Base
from app.db.session import create_database_engine
from app.models.user import User


@pytest.fixture
def database_engine(tmp_path: Path):
    engine = create_database_engine(f"sqlite:///{tmp_path / 'users.db'}")
    Base.metadata.create_all(engine)

    yield engine

    engine.dispose()


def make_user(username: str, email: str | None = None) -> User:
    return User(
        username=username,
        email=email,
        display_name=username,
        password_hash="test-hash-not-a-real-password",
    )


def test_user_can_be_persisted(database_engine) -> None:
    with Session(database_engine) as session:
        user = make_user("goncalo", "goncalo@example.com")
        session.add(user)
        session.commit()

        user_id = user.id

    with Session(database_engine) as session:
        saved_user = session.get(User, user_id)

        assert saved_user is not None
        assert saved_user.username == "goncalo"
        assert saved_user.email == "goncalo@example.com"
        assert saved_user.is_active is True
        assert saved_user.is_admin is False
        assert saved_user.created_at is not None
        assert saved_user.updated_at is not None


def test_username_must_be_unique(database_engine) -> None:
    with Session(database_engine) as session:
        session.add(make_user("goncalo"))
        session.commit()

    with Session(database_engine) as session:
        session.add(make_user("goncalo"))

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()


def test_email_must_be_unique(database_engine) -> None:
    with Session(database_engine) as session:
        session.add(make_user("user1", "shared@example.com"))
        session.commit()

    with Session(database_engine) as session:
        session.add(make_user("user2", "shared@example.com"))

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()


def test_multiple_users_can_have_no_email(database_engine) -> None:
    with Session(database_engine) as session:
        session.add_all(
            [
                make_user("user1"),
                make_user("user2"),
            ]
        )
        session.commit()

        users = session.scalars(select(User)).all()

        assert len(users) == 2


def test_admin_flag_can_be_persisted(database_engine) -> None:
    with Session(database_engine) as session:
        user = make_user("admin")
        user.is_admin = True

        session.add(user)
        session.commit()

        user_id = user.id

    with Session(database_engine) as session:
        saved_user = session.get(User, user_id)

        assert saved_user is not None
        assert saved_user.is_admin is True
