from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.user import User


def any_users_exist(session: Session) -> bool:
    """Return whether at least one account exists."""
    return session.scalar(select(User.id).limit(1)) is not None


def add_user(session: Session, user: User) -> None:
    """Stage a user for persistence."""
    session.add(user)
