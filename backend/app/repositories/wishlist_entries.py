"""Database queries for global wishlist entries."""

from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models.city import City
from app.models.country import Country
from app.models.wishlist_entry import WishlistEntry


class WishlistEntryRepository:
    """Persistence operations for user-owned wishlist entries."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def list_for_user(self, user_id: UUID) -> list[WishlistEntry]:
        """Return only wishlist entries belonging to a user."""

        statement = (
            select(WishlistEntry)
            .where(WishlistEntry.user_id == user_id)
            .order_by(
                WishlistEntry.created_at.desc(),
                WishlistEntry.id.desc(),
            )
        )

        return list(self._session.scalars(statement).all())

    def get_for_user(
        self,
        *,
        entry_id: UUID,
        user_id: UUID,
    ) -> WishlistEntry | None:
        """Find an entry only when owned by the given user."""

        statement = select(WishlistEntry).where(
            WishlistEntry.id == entry_id,
            WishlistEntry.user_id == user_id,
        )

        return self._session.scalar(statement)

    def get_country_entry(
        self,
        *,
        user_id: UUID,
        country_code: str,
    ) -> WishlistEntry | None:
        """Find an existing country wishlist entry for a user."""

        statement = select(WishlistEntry).where(
            WishlistEntry.user_id == user_id,
            WishlistEntry.country_code == country_code,
        )

        return self._session.scalar(statement)

    def get_city_entry(
        self,
        *,
        user_id: UUID,
        city_id: int,
    ) -> WishlistEntry | None:
        """Find an existing city wishlist entry for a user."""

        statement = select(WishlistEntry).where(
            WishlistEntry.user_id == user_id,
            WishlistEntry.city_id == city_id,
        )

        return self._session.scalar(statement)

    def get_country(self, country_code: str) -> Country | None:
        """Retrieve a country from the shared geographical catalog."""

        return self._session.get(Country, country_code)

    def get_city(self, city_id: int) -> City | None:
        """Retrieve a city from the shared geographical catalog."""

        return self._session.get(City, city_id)

    def create(
        self,
        *,
        user_id: UUID,
        country_code: str | None = None,
        city_id: int | None = None,
        commit: bool = True,
    ) -> WishlistEntry:
        """Persist a wishlist entry.

        Exactly one destination must be provided.

        Domain validation belongs to the application service.
        Database constraints provide the final integrity guarantee.

        When commit=False, the caller owns the transaction.
        """

        entry = WishlistEntry(
            user_id=user_id,
            country_code=country_code,
            city_id=city_id,
        )

        self._session.add(entry)

        if commit:
            self._session.commit()
            self._session.refresh(entry)
        else:
            self._session.flush()

        return entry

    def delete_for_user(
        self,
        *,
        entry_id: UUID,
        user_id: UUID,
        commit: bool = True,
    ) -> bool:
        """Delete an entry only when owned by the given user."""

        statement = delete(WishlistEntry).where(
            WishlistEntry.id == entry_id,
            WishlistEntry.user_id == user_id,
        )

        result = self._session.execute(statement)
        deleted = result.rowcount == 1

        if commit:
            self._session.commit()

        return deleted
