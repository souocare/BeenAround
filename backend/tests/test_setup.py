from collections.abc import Generator
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import Engine, select
from sqlalchemy.orm import Session, sessionmaker

from app.core.security import verify_password
from app.db.base import Base
from app.db.session import create_database_engine, get_db
from app.main import create_app
from app.models.user import User


@pytest.fixture
def setup_environment(
    tmp_path: Path,
) -> Generator[tuple[TestClient, Engine], None, None]:
    engine = create_database_engine(f"sqlite:///{tmp_path / 'setup.db'}")

    Base.metadata.create_all(engine)

    test_session_factory = sessionmaker(
        bind=engine,
        autoflush=False,
        expire_on_commit=False,
    )

    app = create_app()

    def override_get_db() -> Generator[Session, None, None]:
        with test_session_factory() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as client:
        yield client, engine

    app.dependency_overrides.clear()
    engine.dispose()


def valid_payload() -> dict[str, str]:
    return {
        "username": "Goncalo",
        "email": "GONCALO@example.com",
        "display_name": "Gonçalo",
        "password": "a-strong-test-password-123",
    }


def test_setup_required_before_first_user(setup_environment) -> None:
    client, _ = setup_environment

    response = client.get("/api/v1/setup/status")

    assert response.status_code == 200
    assert response.json() == {"setup_required": True}


def test_first_user_becomes_admin(setup_environment) -> None:
    client, engine = setup_environment

    response = client.post("/api/v1/setup", json=valid_payload())

    assert response.status_code == 201

    body = response.json()

    assert body["username"] == "goncalo"
    assert body["display_name"] == "Gonçalo"
    assert body["is_admin"] is True
    assert "password_hash" not in body
    assert "password" not in body

    with Session(engine) as session:
        user = session.scalar(select(User))

        assert user is not None
        assert user.email == "goncalo@example.com"
        assert user.is_active is True
        assert user.is_admin is True
        assert user.password_hash != valid_payload()["password"]
        assert verify_password(valid_payload()["password"], user.password_hash)


def test_setup_not_required_after_first_user(setup_environment) -> None:
    client, _ = setup_environment

    assert client.post("/api/v1/setup", json=valid_payload()).status_code == 201

    response = client.get("/api/v1/setup/status")

    assert response.json() == {"setup_required": False}


def test_second_setup_is_rejected(setup_environment) -> None:
    client, engine = setup_environment

    assert client.post("/api/v1/setup", json=valid_payload()).status_code == 201

    second_payload = valid_payload()
    second_payload["username"] = "anotheruser"
    second_payload["email"] = "another@example.com"

    response = client.post("/api/v1/setup", json=second_payload)

    assert response.status_code == 409

    with Session(engine) as session:
        assert len(session.scalars(select(User)).all()) == 1


@pytest.mark.parametrize(
    "password",
    [
        "short",
        "",
        "12345678901",
    ],
)
def test_weak_password_is_rejected(setup_environment, password: str) -> None:
    client, _ = setup_environment

    payload = valid_payload()
    payload["password"] = password

    response = client.post("/api/v1/setup", json=payload)

    assert response.status_code == 422


@pytest.mark.parametrize(
    "username",
    [
        "ab",
        "invalid name",
        "user!",
        "",
    ],
)
def test_invalid_username_is_rejected(setup_environment, username: str) -> None:
    client, _ = setup_environment

    payload = valid_payload()
    payload["username"] = username

    response = client.post("/api/v1/setup", json=payload)

    assert response.status_code == 422


def test_concurrent_setup_creates_only_one_admin(setup_environment) -> None:
    client, engine = setup_environment

    def attempt_setup(index: int) -> int:
        payload = valid_payload()
        payload["username"] = f"admin{index}"
        payload["email"] = f"admin{index}@example.com"

        response = client.post("/api/v1/setup", json=payload)

        return response.status_code

    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(attempt_setup, [1, 2]))

    assert sorted(results) == [201, 409]

    with Session(engine) as session:
        users = session.scalars(select(User)).all()

        assert len(users) == 1
        assert users[0].is_admin is True
