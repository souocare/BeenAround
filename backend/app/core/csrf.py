from urllib.parse import urlsplit

SAFE_METHODS = frozenset({"GET", "HEAD", "OPTIONS"})


def normalize_origin(value: str) -> str | None:
    """Normalize an HTTP(S) origin without accepting ambiguous URLs."""
    try:
        parsed = urlsplit(value)
        scheme = parsed.scheme.lower()
        hostname = parsed.hostname

        if scheme not in {"http", "https"} or not hostname:
            return None

        if parsed.username is not None or parsed.password is not None:
            return None

        if parsed.path not in {"", "/"}:
            return None

        if parsed.query or parsed.fragment:
            return None

        port = parsed.port

        host = f"[{hostname.lower()}]" if ":" in hostname else hostname.lower()

        if port is None:
            return f"{scheme}://{host}"

        if scheme == "https" and port == 443:
            return f"{scheme}://{host}"

        if scheme == "http" and port == 80:
            return f"{scheme}://{host}"

        return f"{scheme}://{host}:{port}"

    except ValueError:
        return None


def origin_from_referer(referer: str) -> str | None:
    """Extract the origin from an absolute HTTP(S) Referer URL."""
    try:
        parsed = urlsplit(referer)

        if parsed.scheme.lower() not in {"http", "https"}:
            return None

        if not parsed.netloc:
            return None

        return normalize_origin(f"{parsed.scheme}://{parsed.netloc}")

    except ValueError:
        return None


def is_allowed_request_origin(
    *,
    origin: str | None,
    referer: str | None,
    allowed_origins: list[str],
) -> bool:
    """Validate the request origin against explicitly trusted origins."""
    normalized_allowed = {
        normalized
        for value in allowed_origins
        if (normalized := normalize_origin(value)) is not None
    }

    if not normalized_allowed:
        return False

    if origin is not None:
        normalized_origin = normalize_origin(origin)
        return normalized_origin in normalized_allowed

    if referer is not None:
        normalized_referer = origin_from_referer(referer)
        return normalized_referer in normalized_allowed

    return False
