"""Read-only access to the shared city catalog."""

from sqlalchemy import case, func, or_, select
from sqlalchemy.orm import Session

from app.models.city import City
from app.models.country import Country


class CityRepository:
    """Search and retrieve catalog cities."""

    def __init__(self, session: Session) -> None:
        self.session = session

    def search(
        self,
        *,
        query: str | None,
        country_code: str | None,
        limit: int,
        offset: int,
    ) -> tuple[list[tuple[City, str]], int]:
        conditions = []

        normalized_query = query.strip() if query else None

        if country_code:
            conditions.append(City.country_code == country_code)

        if normalized_query:
            escaped = normalized_query.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")

            pattern = f"%{escaped}%"

            conditions.append(
                or_(
                    City.name.ilike(pattern, escape="\\"),
                    City.ascii_name.ilike(pattern, escape="\\"),
                )
            )

        total = self.session.scalar(select(func.count()).select_from(City).where(*conditions))

        statement = (
            select(City, Country.name)
            .join(Country, Country.code == City.country_code)
            .where(*conditions)
        )

        if normalized_query:
            exact = normalized_query.casefold()

            rank = case(
                (
                    or_(
                        func.lower(City.name) == exact,
                        func.lower(City.ascii_name) == exact,
                    ),
                    0,
                ),
                (
                    or_(
                        City.name.ilike(f"{escaped}%", escape="\\"),
                        City.ascii_name.ilike(f"{escaped}%", escape="\\"),
                    ),
                    1,
                ),
                else_=2,
            )

            statement = statement.order_by(
                rank,
                City.population.desc().nullslast(),
                City.name,
                City.id,
            )
        else:
            statement = statement.order_by(
                City.population.desc().nullslast(),
                City.name,
                City.id,
            )

        rows = self.session.execute(statement.limit(limit).offset(offset)).all()

        return [(city, country_name) for city, country_name in rows], total or 0
