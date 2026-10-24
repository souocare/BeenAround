"""Shared date validation rules for travel visits."""

from datetime import date


def validate_visit_dates(
    started_on: date | None,
    ended_on: date | None,
) -> None:
    """Validate the date range of a travel visit."""

    if ended_on is None:
        return

    if started_on is None:
        raise ValueError("End date requires a start date.")

    if ended_on < started_on:
        raise ValueError("End date cannot be earlier than start date.")
