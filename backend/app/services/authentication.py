from sqlalchemy.orm import Session

from app.core.security import verify_password
from app.models.user import User
from app.repositories.users import get_user_by_login


class InvalidCredentialsError(Exception):
    """Raised when authentication credentials are invalid."""


class AuthenticationService:
    """Authenticate BeenAround users using their credentials."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def authenticate(
        self,
        *,
        login: str,
        password: str,
    ) -> User:
        """Authenticate a user by username or email and password."""
        user = get_user_by_login(self._session, login)

        if user is None:
            raise InvalidCredentialsError("Invalid credentials.")

        if not verify_password(password, user.password_hash):
            raise InvalidCredentialsError("Invalid credentials.")

        if not user.is_active:
            raise InvalidCredentialsError("Invalid credentials.")

        return user
