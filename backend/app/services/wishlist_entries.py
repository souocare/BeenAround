"""Application services for global wishlist entries."""

from dataclasses import dataclass, field
from uuid import UUID

from sqlalchemy import Engine

from app.db.write_transactions import sqlite_write_session
from app.models.wishlist_entry import WishlistEntry
from app.repositories.wishlist_entries import WishlistEntryRepository
from app.schemas.wishlist_entries import WishlistEntryCreate
from app.schemas.wishlist_entries import WishlistEntryCreate, WishlistEntryUpdate


class WishlistDestinationNotFound(Exception):
    """The requested country or city does not exist."""


class WishlistEntryNotFound(Exception):
    """The requested wishlist entry does not exist or is not owned by the user."""


@dataclass
class WishlistCreationResult:
    """Separate newly created entries from entries already on the wishlist."""

    created: list[WishlistEntry] = field(default_factory=list)
    existing: list[WishlistEntry] = field(default_factory=list)


def _get_or_create_country_entry(
    *,
    repository: WishlistEntryRepository,
    user_id: UUID,
    country_code: str,
    result: WishlistCreationResult,
    note: str | None = None,
) -> None:
    """Add an existing or newly created country entry to the result."""

    existing = repository.get_country_entry(
        user_id=user_id,
        country_code=country_code,
    )

    if existing is not None:
        result.existing.append(existing)
        return

    entry = repository.create(
        user_id=user_id,
        country_code=country_code,
        note=note,
        commit=False,
    )

    result.created.append(entry)


def _get_or_create_city_entry(
    *,
    repository: WishlistEntryRepository,
    user_id: UUID,
    city_id: int,
    result: WishlistCreationResult,
    note: str | None = None,
) -> None:
    """Add an existing or newly created city entry to the result."""

    existing = repository.get_city_entry(
        user_id=user_id,
        city_id=city_id,
    )

    if existing is not None:
        result.existing.append(existing)
        return

    entry = repository.create(
        user_id=user_id,
        city_id=city_id,
        note=note,
        commit=False,
    )

    result.created.append(entry)


def add_wishlist_entries(
    *,
    engine: Engine,
    user_id: UUID,
    payload: WishlistEntryCreate,
) -> WishlistCreationResult:
    """Atomically add requested destinations to the global wishlist.

    The operation is idempotent for the same user and destinations.

    A country entry is added alongside a city only when the user
    explicitly requests include_country=True.
    """

    with sqlite_write_session(engine) as session:
        repository = WishlistEntryRepository(session)

        result = WishlistCreationResult()

        # Option 1: Add an explicitly selected country.
        if payload.country_code is not None:
            country = repository.get_country(payload.country_code)

            if country is None:
                raise WishlistDestinationNotFound("Country not found.")

            _get_or_create_country_entry(
                repository=repository,
                user_id=user_id,
                country_code=country.code,
                result=result,
                note=payload.note,
            )

        # Option 2: Add a city and optionally its country.
        else:
            assert payload.city_id is not None

            city = repository.get_city(payload.city_id)

            if city is None:
                raise WishlistDestinationNotFound("City not found.")

            _get_or_create_city_entry(
                repository=repository,
                user_id=user_id,
                city_id=city.id,
                result=result,
                note=payload.note,
            )

            if payload.include_country:
                country = repository.get_country(city.country_code)

                if country is None:
                    raise WishlistDestinationNotFound("Country not found.")

                _get_or_create_country_entry(
                    repository=repository,
                    user_id=user_id,
                    country_code=country.code,
                    result=result,
                    note=None,
                )

        # Load timestamps before the dedicated session is closed.
        # Newly inserted entries have already been flushed by the repository.
        for entry in result.created:
            session.refresh(entry)

        return result


def delete_wishlist_entry(
    *,
    engine: Engine,
    user_id: UUID,
    entry_id: UUID,
) -> None:
    """Delete an owned wishlist entry within a SQLite write transaction."""

    with sqlite_write_session(engine) as session:
        repository = WishlistEntryRepository(session)

        deleted = repository.delete_for_user(
            entry_id=entry_id,
            user_id=user_id,
            commit=False,
        )

        if not deleted:
            raise WishlistEntryNotFound("Wishlist entry not found.")


def update_wishlist_entry(
    *,
    engine: Engine,
    user_id: UUID,
    entry_id: UUID,
    payload: WishlistEntryUpdate,
) -> WishlistEntry:
    """Update the note of an owned wishlist entry."""

    with sqlite_write_session(engine) as session:
        repository = WishlistEntryRepository(session)

        entry = repository.get_for_user(
            entry_id=entry_id,
            user_id=user_id,
        )

        if entry is None:
            raise WishlistEntryNotFound("Wishlist entry not found.")

        updated = repository.update_note(
            entry=entry,
            note=payload.note,
            commit=False,
        )

        # Ensure timestamps are loaded before the session closes.
        session.refresh(updated)

        return updated
