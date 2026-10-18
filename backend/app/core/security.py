from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError

_password_hasher = PasswordHasher()

# Used to perform an Argon2 verification when a login does not exist.
# The random password is never exposed or used for authentication.
_DUMMY_PASSWORD_HASH = _password_hasher.hash("beenaround-dummy-password-not-for-authentication")


def hash_password(password: str) -> str:
    """Hash a password using Argon2id."""
    return _password_hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    """Verify a password without exposing invalid-hash errors."""
    try:
        return _password_hasher.verify(password_hash, password)
    except (VerificationError, InvalidHashError):
        return False


def verify_dummy_password(password: str) -> None:
    """Perform a dummy Argon2 verification to reduce timing differences."""
    verify_password(password, _DUMMY_PASSWORD_HASH)
