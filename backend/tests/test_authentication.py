from collections.abc import Generator
from pathlib import Path

import pytest
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.db.base import Base
from app.db.session import create_database_engine
from app.models.user import User
from app.services.authentication import (
    AuthenticationService,
    InvalidCredentialsError,
)


@pytest.fixture
def authentication_environment(
    tmp_path: Path,
) -> Generator[Session, None, None]:
    engine = create_database_engine(f"sqlite:///{tmp_path / 'authentication.db'}")

    Base.metadata.create_all(engine)

    with Session(engine) as session:
        user = User(
            username="goncalo",
            email="goncalo@example.com",
            display_name="Gonçalo",
            password_hash=hash_password("correct-password-123"),
        )

        session.add(user)
        session.commit()

        yield session

    engine.dispose()


def test_authenticate_with_username(
    authentication_environment: Session,
) -> None:
    service = AuthenticationService(authentication_environment)

    user = service.authenticate(
        login="goncalo",
        password="correct-password-123",
    )

    assert user.username == "goncalo"


def test_authenticate_with_email(
    authentication_environment: Session,
) -> None:
    service = AuthenticationService(authentication_environment)

    user = service.authenticate(
        login="goncalo@example.com",
        password="correct-password-123",
    )

    assert user.username == "goncalo"


def test_authenticate_normalizes_login(
    authentication_environment: Session,
) -> None:
    service = AuthenticationService(authentication_environment)

    user = service.authenticate(
        login="  GONCALO@EXAMPLE.COM  ",
        password="correct-password-123",
    )

    assert user.username == "goncalo"


def test_wrong_password_is_rejected(
    authentication_environment: Session,
) -> None:
    service = AuthenticationService(authentication_environment)

    with pytest.raises(InvalidCredentialsError):
        service.authenticate(
            login="goncalo",
            password="wrong-password",
        )


def test_unknown_user_is_rejected(
    authentication_environment: Session,
) -> None:
    service = AuthenticationService(authentication_environment)

    with pytest.raises(InvalidCredentialsError):
        service.authenticate(
            login="unknown",
            password="correct-password-123",
        )


def test_inactive_user_is_rejected(
    authentication_environment: Session,
) -> None:
    session = authentication_environment

    user = session.query(User).filter_by(username="goncalo").one()
    user.is_active = False
    session.commit()

    service = AuthenticationService(session)

    with pytest.raises(InvalidCredentialsError):
        service.authenticate(
            login="goncalo",
            password="correct-password-123",
        )


def test_invalid_credentials_have_generic_error(
    authentication_environment: Session,
) -> None:
    service = AuthenticationService(authentication_environment)

    with pytest.raises(InvalidCredentialsError) as error:
        service.authenticate(
            login="unknown",
            password="wrong-password",
        )

    assert str(error.value) == "Invalid credentials."
