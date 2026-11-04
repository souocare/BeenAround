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
        sort: str = "population",
    ) -> tuple[list[tuple[City, str]], int]:
        if sort not in {"population", "name"}:
            raise ValueError(f"Unsupported city sort: {sort}")
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

        if sort == "name":
            sort_columns = (
                func.lower(City.name),
                City.name,
                City.id,
            )
        else:
            sort_columns = (
                City.population.desc().nullslast(),
                func.lower(City.name),
                City.name,
                City.id,
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

            statement = statement.order_by(rank, *sort_columns)
        else:
            statement = statement.order_by(*sort_columns)

        rows = self.session.execute(statement.limit(limit).offset(offset)).all()

        return [(city, country_name) for city, country_name in rows], total or 0

    def list_country_city_counts(self) -> list[tuple[str, str, int]]:
        """Return all catalog countries with their city counts."""

        statement = (
            select(
                Country.code,
                Country.name,
                func.count(City.id).label("city_count"),
            )
            .outerjoin(City, City.country_code == Country.code)
            .group_by(Country.code, Country.name)
            .order_by(Country.name, Country.code)
        )

        return [
            (country_code, country_name, city_count)
            for country_code, country_name, city_count in self.session.execute(statement).all()
        ]

    def resolve_by_ids(
        self,
        *,
        city_ids: list[int],
    ) -> list[tuple[City, str]]:
        """Return catalog cities by ID, preserving the requested order.

        Unknown IDs are omitted. Duplicate IDs are resolved once.
        """
        unique_ids = list(dict.fromkeys(city_ids))

        if not unique_ids:
            return []

        statement = (
            select(City, Country.name)
            .join(Country, Country.code == City.country_code)
            .where(City.id.in_(unique_ids))
        )

        rows = self.session.execute(statement).all()

        cities_by_id = {city.id: (city, country_name) for city, country_name in rows}

        return [cities_by_id[city_id] for city_id in unique_ids if city_id in cities_by_id]
