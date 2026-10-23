"""Benchmark read-only city catalog searches.

Run from the backend directory:
    python -m scripts.geography.benchmark_city_search
"""

from __future__ import annotations

from statistics import median
from time import perf_counter

from sqlalchemy.orm import Session

from app.db.session import engine
from app.repositories.cities import CityRepository


SEARCHES = [
    ("Lisbon", None),
    ("Porto", "PT"),
    ("Paris", None),
    ("Sao", "BR"),
    ("a", None),
    (None, "PT"),
]

REPETITIONS = 10


def benchmark(
    session: Session,
    query: str | None,
    country_code: str | None,
) -> None:
    repository = CityRepository(session)

    durations: list[float] = []
    total = 0
    rows = []

    # Warm up SQLite and filesystem caches.
    repository.search(
        query=query,
        country_code=country_code,
        limit=20,
        offset=0,
    )

    for _ in range(REPETITIONS):
        start = perf_counter()

        rows, total = repository.search(
            query=query,
            country_code=country_code,
            limit=20,
            offset=0,
        )

        elapsed_ms = (perf_counter() - start) * 1000
        durations.append(elapsed_ms)

    label = f"q={query!r}, country={country_code!r}"

    print(f"\n{label}")
    print(f"  Matches: {total}")
    print(f"  Median:  {median(durations):.2f} ms")
    print(f"  Min:     {min(durations):.2f} ms")
    print(f"  Max:     {max(durations):.2f} ms")

    if rows:
        print(f"  First:   {rows[0][0].name}")


def main() -> None:
    with Session(engine) as session:
        for query, country_code in SEARCHES:
            benchmark(session, query, country_code)


if __name__ == "__main__":
    main()