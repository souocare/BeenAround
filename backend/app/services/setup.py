from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.models.user import User
from app.repositories.users import add_user, any_users_exist
from app.schemas.setup import SetupRequest


class SetupAlreadyCompletedError(Exception):
    """Raised when the initial administrator already exists."""


def is_setup_required(session: Session) -> bool:
    return not any_users_exist(session)


def create_initial_admin(session: Session, data: SetupRequest) -> User:
    """Create the first administrator atomically on SQLite."""

    # Acquire SQLite's write reservation before checking for users.
    # This serializes concurrent first-run setup attempts.
    session.execute(text("BEGIN IMMEDIATE"))

    try:
        if any_users_exist(session):
            raise SetupAlreadyCompletedError

        user = User(
            username=data.username,
            email=data.email,
            display_name=data.display_name,
            password_hash=hash_password(data.password),
            is_active=True,
            is_admin=True,
        )

        add_user(session, user)

        session.flush()
        session.commit()

        return user

    except Exception:
        session.rollback()
        raise
