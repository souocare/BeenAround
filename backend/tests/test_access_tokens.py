from datetime import UTC, datetime, timedelta
from uuid import uuid4

import jwt
import pytest

from app.core.access_tokens import (
    AccessTokenService,
    InvalidAccessTokenError,
)

TEST_SECRET = "beenaround-test-secret-key-32-bytes-minimum"


@pytest.fixture
def token_service() -> AccessTokenService:
    return AccessTokenService(
        secret_key=TEST_SECRET,
        expire_minutes=15,
    )


def test_create_access_token(token_service: AccessTokenService) -> None:
    user_id = uuid4()
    session_id = uuid4()

    token = token_service.create(
        user_id=user_id,
        session_id=session_id,
    )

    claims = token_service.validate(token)

    assert claims.user_id == user_id
    assert claims.session_id == session_id
    assert claims.expires_at - claims.issued_at == timedelta(minutes=15)


def test_access_token_contains_expected_claims(
    token_service: AccessTokenService,
) -> None:
    user_id = uuid4()
    session_id = uuid4()

    token = token_service.create(
        user_id=user_id,
        session_id=session_id,
    )

    payload = jwt.decode(
        token,
        TEST_SECRET,
        algorithms=["HS256"],
    )

    assert payload["sub"] == str(user_id)
    assert payload["sid"] == str(session_id)
    assert payload["type"] == "access"
    assert set(payload) == {"sub", "sid", "type", "iat", "exp"}


def test_expired_access_token_is_rejected(
    token_service: AccessTokenService,
) -> None:
    token = token_service.create(
        user_id=uuid4(),
        session_id=uuid4(),
        now=datetime.now(UTC) - timedelta(hours=1),
    )

    with pytest.raises(InvalidAccessTokenError):
        token_service.validate(token)


def test_invalid_access_token_is_rejected(
    token_service: AccessTokenService,
) -> None:
    with pytest.raises(InvalidAccessTokenError):
        token_service.validate("invalid-token")


def test_empty_access_token_is_rejected(
    token_service: AccessTokenService,
) -> None:
    with pytest.raises(InvalidAccessTokenError):
        token_service.validate("")


def test_wrong_token_type_is_rejected(
    token_service: AccessTokenService,
) -> None:
    now = datetime.now(UTC)

    token = jwt.encode(
        {
            "sub": str(uuid4()),
            "sid": str(uuid4()),
            "type": "refresh",
            "iat": now,
            "exp": now + timedelta(minutes=15),
        },
        TEST_SECRET,
        algorithm="HS256",
    )

    with pytest.raises(InvalidAccessTokenError):
        token_service.validate(token)


def test_missing_required_claim_is_rejected(
    token_service: AccessTokenService,
) -> None:
    now = datetime.now(UTC)

    token = jwt.encode(
        {
            "sub": str(uuid4()),
            "type": "access",
            "iat": now,
            "exp": now + timedelta(minutes=15),
        },
        TEST_SECRET,
        algorithm="HS256",
    )

    with pytest.raises(InvalidAccessTokenError):
        token_service.validate(token)


def test_invalid_session_id_is_rejected(
    token_service: AccessTokenService,
) -> None:
    now = datetime.now(UTC)

    token = jwt.encode(
        {
            "sub": str(uuid4()),
            "sid": "not-a-uuid",
            "type": "access",
            "iat": now,
            "exp": now + timedelta(minutes=15),
        },
        TEST_SECRET,
        algorithm="HS256",
    )

    with pytest.raises(InvalidAccessTokenError):
        token_service.validate(token)


def test_invalid_token_lifetime_is_rejected(
    token_service: AccessTokenService,
) -> None:
    now = datetime.now(UTC)

    token = jwt.encode(
        {
            "sub": str(uuid4()),
            "sid": str(uuid4()),
            "type": "access",
            "iat": now,
            "exp": now,
        },
        TEST_SECRET,
        algorithm="HS256",
    )

    with pytest.raises(InvalidAccessTokenError):
        token_service.validate(token)


def test_short_secret_is_rejected() -> None:
    with pytest.raises(ValueError):
        AccessTokenService(
            secret_key="short",
            expire_minutes=15,
        )


def test_invalid_expiration_is_rejected() -> None:
    with pytest.raises(ValueError):
        AccessTokenService(
            secret_key=TEST_SECRET,
            expire_minutes=0,
        )


def test_naive_datetime_is_normalized(
    token_service: AccessTokenService,
) -> None:
    now = datetime.now(UTC).replace(tzinfo=None)

    token = token_service.create(
        user_id=uuid4(),
        session_id=uuid4(),
        now=now,
    )

    claims = token_service.validate(token)

    assert claims.issued_at.tzinfo == UTC


def test_access_token_rejects_wrong_signature(
    token_service: AccessTokenService,
) -> None:
    other_service = AccessTokenService(
        secret_key="another-valid-secret-key-with-enough-bytes",
        expire_minutes=15,
    )

    token = other_service.create(
        user_id=uuid4(),
        session_id=uuid4(),
    )

    with pytest.raises(InvalidAccessTokenError):
        token_service.validate(token)