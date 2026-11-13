"""Offline IANA timezone identification for airport coordinates."""

from timezonefinder import TimezoneFinder


class AirportTimezoneResolver:
    """Resolve airport coordinates to IANA timezone identifiers.

    The geographic dataset is loaded once and reused for
    multiple airport lookups.

    No external requests are performed.
    """

    def __init__(self) -> None:
        self._finder = TimezoneFinder(in_memory=True)

    def resolve(
        self,
        *,
        latitude: float | None,
        longitude: float | None,
    ) -> str | None:
        """Return the IANA timezone covering the coordinates."""

        if latitude is None or longitude is None:
            return None

        return self._finder.timezone_at(
            lat=latitude,
            lng=longitude,
        )
