import pytest

from app.core.csrf import (
    is_allowed_request_origin,
    normalize_origin,
    origin_from_referer,
)


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("https://example.com", "https://example.com"),
        ("HTTPS://EXAMPLE.COM", "https://example.com"),
        ("https://example.com:443", "https://example.com"),
        ("http://localhost:3000", "http://localhost:3000"),
        ("https://example.com/path", None),
        ("https://example.com?query=1", None),
        ("https://user@example.com", None),
        ("null", None),
        ("", None),
    ],
)
def test_normalize_origin(value: str, expected: str | None) -> None:
    assert normalize_origin(value) == expected


def test_origin_from_referer() -> None:
    assert origin_from_referer("https://example.com/trips/123") == "https://example.com"


def test_allowed_origin_is_accepted() -> None:
    assert is_allowed_request_origin(
        origin="https://example.com",
        referer=None,
        allowed_origins=["https://example.com"],
    )


def test_external_origin_is_rejected() -> None:
    assert not is_allowed_request_origin(
        origin="https://evil.example",
        referer=None,
        allowed_origins=["https://example.com"],
    )


def test_missing_origin_and_referer_are_rejected() -> None:
    assert not is_allowed_request_origin(
        origin=None,
        referer=None,
        allowed_origins=["https://example.com"],
    )


def test_valid_referer_is_accepted() -> None:
    assert is_allowed_request_origin(
        origin=None,
        referer="https://example.com/trips",
        allowed_origins=["https://example.com"],
    )


def test_origin_takes_precedence_over_referer() -> None:
    assert not is_allowed_request_origin(
        origin="https://evil.example",
        referer="https://example.com/trips",
        allowed_origins=["https://example.com"],
    )


def test_no_allowed_origins_fails_closed() -> None:
    assert not is_allowed_request_origin(
        origin="https://example.com",
        referer=None,
        allowed_origins=[],
    )
