from pathlib import Path

import pytest
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.base import Base
from app.db.session import create_database_engine
from app.models.city import City
from app.models.country import Country


@pytest.fixture
def database_engine(tmp_path: Path):
    engine = create_database_engine(f"sqlite:///{tmp_path / 'cities.db'}")

    Base.metadata.create_all(engine)

    yield engine

    engine.dispose()


def seed_country(session: Session) -> None:
    session.add(
        Country(
            code="PT",
            name="Portugal",
            alpha3_code="PRT",
            continent="Europe",
        )
    )
    session.commit()


def make_city(
    *,
    city_id: int = 2267057,
    country_code: str = "PT",
    name: str = "Lisbon",
    ascii_name: str | None = "Lisbon",
    latitude: float = 38.7167,
    longitude: float = -9.1333,
    population: int | None = 500000,
    feature_code: str = "PPL",
) -> City:
    return City(
        id=city_id,
        country_code=country_code,
        name=name,
        ascii_name=ascii_name,
        latitude=latitude,
        longitude=longitude,
        population=population,
        feature_code=feature_code,
    )


def test_city_can_be_persisted(database_engine) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        session.add(make_city())
        session.commit()

    with Session(database_engine) as session:
        city = session.get(City, 2267057)

        assert city is not None
        assert city.id == 2267057
        assert city.country_code == "PT"
        assert city.name == "Lisbon"
        assert city.ascii_name == "Lisbon"
        assert city.latitude == pytest.approx(38.7167)
        assert city.longitude == pytest.approx(-9.1333)
        assert city.population == 500000


def test_city_requires_existing_country(database_engine) -> None:
    with Session(database_engine) as session:
        session.add(make_city(country_code="XX"))

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()


@pytest.mark.parametrize(
    "latitude",
    [-90.1, 90.1],
)
def test_invalid_latitude_is_rejected(database_engine, latitude) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        session.add(make_city(latitude=latitude))

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()


@pytest.mark.parametrize(
    "longitude",
    [-180.1, 180.1],
)
def test_invalid_longitude_is_rejected(database_engine, longitude) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        session.add(make_city(longitude=longitude))

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()


def test_negative_population_is_rejected(database_engine) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        session.add(make_city(population=-1))

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()


def test_unknown_population_is_allowed(database_engine) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        session.add(make_city(population=None))
        session.commit()

        city = session.get(City, 2267057)

        assert city is not None
        assert city.population is None


def test_unknown_ascii_name_is_allowed(database_engine) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        session.add(make_city(ascii_name=None))
        session.commit()

        city = session.get(City, 2267057)

        assert city is not None
        assert city.ascii_name is None


def test_duplicate_geonames_id_is_rejected(database_engine) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        session.add(make_city())
        session.commit()

    with Session(database_engine) as session:
        session.add(make_city(name="Different city"))

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()


def test_cities_with_same_name_are_allowed(database_engine) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        session.add_all(
            [
                make_city(city_id=1001, name="Springfield"),
                make_city(city_id=1002, name="Springfield"),
            ]
        )

        session.commit()

        assert session.get(City, 1001) is not None
        assert session.get(City, 1002) is not None


def test_country_with_cities_cannot_be_deleted(database_engine) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        session.add(make_city())
        session.commit()

    with Session(database_engine) as session:
        country = session.get(Country, "PT")

        assert country is not None

        session.delete(country)

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()


@pytest.mark.parametrize(
    ("latitude", "longitude"),
    [
        (-90.0, -180.0),
        (90.0, 180.0),
        (0.0, 0.0),
    ],
)
def test_coordinate_boundaries_are_allowed(
    database_engine,
    latitude,
    longitude,
) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        session.add(make_city(latitude=latitude, longitude=longitude))
        session.commit()


def test_city_requires_feature_code(database_engine) -> None:
    with Session(database_engine) as session:
        seed_country(session)

        city = make_city()
        city.feature_code = None

        session.add(city)

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()
