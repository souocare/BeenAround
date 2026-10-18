from app.core.session_credentials import (
    generate_session_credential,
    hash_session_credential,
)


def test_generated_credentials_are_unique() -> None:
    first = generate_session_credential()
    second = generate_session_credential()

    assert first.value != second.value
    assert first.hash != second.hash


def test_credential_hash_matches_plaintext() -> None:
    credential = generate_session_credential()

    assert credential.hash == hash_session_credential(credential.value)


def test_plaintext_is_not_stored_as_hash() -> None:
    credential = generate_session_credential()

    assert credential.value != credential.hash
    assert len(credential.hash) == 64


def test_same_credential_produces_same_hash() -> None:
    credential = generate_session_credential()

    assert hash_session_credential(credential.value) == hash_session_credential(credential.value)
