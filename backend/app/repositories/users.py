from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models.user import User


def any_users_exist(session: Session) -> bool:
    """Return whether at least one account exists."""
    return session.scalar(select(User.id).limit(1)) is not None


def add_user(session: Session, user: User) -> None:
    """Stage a user for persistence."""
    session.add(user)


def get_user_by_login(
    session: Session,
    login: str,
) -> User | None:
    """Find a user by normalized username or email."""
    normalized_login = login.strip().lower()

    if not normalized_login:
        return None

    return session.scalar(
        select(User).where(
            or_(
                func.lower(User.username) == normalized_login,
                func.lower(User.email) == normalized_login,
            )
        )
    )
