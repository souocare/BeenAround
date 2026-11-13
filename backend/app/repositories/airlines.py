"""Read-only access to the shared airline catalog."""

from sqlalchemy import case, func, or_, select
from sqlalchemy.orm import Session

from app.models.airline import Airline


class AirlineRepository:
    """Search and retrieve catalog airlines."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def search(
        self,
        *,
        query: str | None,
        limit: int,
        offset: int,
    ) -> tuple[list[Airline], int]:
        normalized_query = query.strip() if query else None

        statement = select(Airline)
        count_statement = select(func.count()).select_from(Airline)

        if normalized_query:
            escaped = (
                normalized_query
                .replace("\\", "\\\\")
                .replace("%", "\\%")
                .replace("_", "\\_")
            )

            pattern = f"%{escaped}%"
            prefix_pattern = f"{escaped}%"

            conditions = or_(
                Airline.name.ilike(pattern, escape="\\"),
                Airline.iata_code.ilike(pattern, escape="\\"),
                Airline.icao_code.ilike(pattern, escape="\\"),
                Airline.callsign.ilike(pattern, escape="\\"),
            )

            statement = statement.where(conditions)
            count_statement = count_statement.where(conditions)

            exact = normalized_query.lower()

            rank = case(
                (func.lower(Airline.iata_code) == exact, 0),
                (func.lower(Airline.icao_code) == exact, 1),
                (func.lower(Airline.name) == exact, 2),
                (
                    Airline.name.ilike(
                        prefix_pattern,
                        escape="\\",
                    ),
                    3,
                ),
                (
                    or_(
                        func.lower(Airline.callsign) == exact,
                        Airline.callsign.ilike(
                            prefix_pattern,
                            escape="\\",
                        ),
                    ),
                    4,
                ),
                else_=5,
            )

            statement = statement.order_by(
                rank,
                func.lower(Airline.name),
                Airline.id,
            )

        else:
            # Deterministic ordering for catalog browsing.
            statement = statement.order_by(
                func.lower(Airline.name),
                Airline.id,
            )

        total = self._session.scalar(count_statement) or 0

        statement = statement.limit(limit).offset(offset)

        airlines = list(self._session.scalars(statement).all())

        return airlines, total

    def get_by_id(self, airline_id: int) -> Airline | None:
        """Retrieve one airline by its BeenAround catalog ID."""

        return self._session.get(Airline, airline_id)
