"""Shared SQLite write transaction utilities."""

from collections.abc import Iterator
from contextlib import contextmanager

from sqlalchemy import Engine
from sqlalchemy.orm import Session


@contextmanager
def sqlite_write_session(engine: Engine) -> Iterator[Session]:
    """Open a dedicated SQLite write transaction before reading data.

    BEGIN IMMEDIATE reserves the SQLite writer lock before application
    queries are executed.

    All cooperating writers must use this transaction strategy when
    their business rules depend on checking existing records first.
    """

    if engine.dialect.name != "sqlite":
        raise RuntimeError("This write transaction strategy requires SQLite.")

    with engine.connect() as connection:
        connection.exec_driver_sql("BEGIN IMMEDIATE")

        try:
            with Session(
                bind=connection,
                autoflush=False,
                expire_on_commit=False,
            ) as session:
                yield session

                session.flush()
                connection.commit()

        except Exception:
            connection.rollback()
            raise
