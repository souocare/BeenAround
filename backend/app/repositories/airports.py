"""Read-only queries for the shared airport catalog."""

from sqlalchemy import case, func, or_, select
from sqlalchemy.orm import Session

from app.models.airport import Airport
from app.models.country import Country


class AirportRepository:
    """Search and retrieve airports from the local catalog."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def search(
        self,
        *,
        query: str | None,
        country_code: str | None,
        scheduled_only: bool,
        limit: int,
        offset: int,
    ) -> tuple[list[tuple[Airport, str | None]], int]:
        conditions = []

        normalized_query = query.strip() if query else None

        if country_code:
            conditions.append(Airport.country_code == country_code)

        if scheduled_only:
            conditions.append(Airport.scheduled_service.is_(True))

        if normalized_query:
            escaped = normalized_query.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")

            pattern = f"%{escaped}%"

            conditions.append(
                or_(
                    Airport.iata_code.ilike(pattern, escape="\\"),
                    Airport.icao_code.ilike(pattern, escape="\\"),
                    Airport.ident.ilike(pattern, escape="\\"),
                    Airport.name.ilike(pattern, escape="\\"),
                    Airport.municipality.ilike(pattern, escape="\\"),
                )
            )

        total = (
            self._session.scalar(select(func.count()).select_from(Airport).where(*conditions)) or 0
        )

        statement = (
            select(Airport, Country.name)
            .outerjoin(
                Country,
                Country.code == Airport.country_code,
            )
            .where(*conditions)
        )

        if normalized_query:
            exact = normalized_query.lower()

            rank = case(
                (
                    func.lower(Airport.iata_code) == exact,
                    0,
                ),
                (
                    func.lower(Airport.icao_code) == exact,
                    1,
                ),
                (
                    func.lower(Airport.ident) == exact,
                    2,
                ),
                (
                    or_(
                        Airport.name.ilike(
                            f"{escaped}%",
                            escape="\\",
                        ),
                        Airport.municipality.ilike(
                            f"{escaped}%",
                            escape="\\",
                        ),
                    ),
                    3,
                ),
                else_=4,
            )

            statement = statement.order_by(
                rank,
                Airport.scheduled_service.desc(),
                func.lower(Airport.name),
                Airport.id,
            )
        else:
            statement = statement.order_by(
                Airport.scheduled_service.desc(),
                func.lower(Airport.name),
                Airport.id,
            )

        rows = self._session.execute(statement.limit(limit).offset(offset)).all()

        return [(airport, country_name) for airport, country_name in rows], total

    def get_by_id(self, airport_id: int) -> Airport | None:
        """Return an airport by its stable catalog ID."""

        return self._session.get(Airport, airport_id)


    def get_with_country(
        self,
        airport_id: int,
    ) -> tuple[Airport, str | None] | None:
        """Return an airport with its optional country name."""

        statement = (
            select(Airport, Country.name)
            .outerjoin(
                Country,
                Country.code == Airport.country_code,
            )
            .where(Airport.id == airport_id)
        )

        row = self._session.execute(statement).one_or_none()

        if row is None:
            return None

        return row[0], row[1]