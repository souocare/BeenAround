from pathlib import Path

import pytest
from sqlalchemy import Column, ForeignKey, Integer, MetaData, Table, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.session import create_database_engine


def test_sqlite_foreign_keys_are_enabled(tmp_path: Path) -> None:
    database_url = f"sqlite:///{tmp_path / 'test.db'}"
    engine = create_database_engine(database_url)

    try:
        with engine.connect() as connection:
            result = connection.execute(text("PRAGMA foreign_keys"))
            assert result.scalar_one() == 1
    finally:
        engine.dispose()


def test_database_directory_is_created(tmp_path: Path) -> None:
    database_path = tmp_path / "nested" / "test.db"
    engine = create_database_engine(f"sqlite:///{database_path}")

    try:
        with engine.connect():
            pass

        assert database_path.exists()
    finally:
        engine.dispose()


def test_session_can_commit_and_read_data(tmp_path: Path) -> None:
    engine = create_database_engine(f"sqlite:///{tmp_path / 'test.db'}")

    metadata = MetaData()

    sample = Table(
        "sample",
        metadata,
        Column("id", Integer, primary_key=True),
        Column("value", Integer, nullable=False),
    )

    try:
        metadata.create_all(engine)

        with Session(engine) as session:
            session.execute(sample.insert().values(value=42))
            session.commit()

        with Session(engine) as session:
            result = session.execute(sample.select())
            assert result.one().value == 42
    finally:
        engine.dispose()


def test_foreign_key_constraint_is_enforced(tmp_path: Path) -> None:
    engine = create_database_engine(f"sqlite:///{tmp_path / 'test.db'}")

    metadata = MetaData()

    Table(
        "parent",
        metadata,
        Column("id", Integer, primary_key=True),
    )

    child = Table(
        "child",
        metadata,
        Column("id", Integer, primary_key=True),
        Column("parent_id", Integer, ForeignKey("parent.id"), nullable=False),
    )

    try:
        metadata.create_all(engine)

        with Session(engine) as session:
            with pytest.raises(IntegrityError, match="FOREIGN KEY constraint failed"):
                session.execute(child.insert().values(parent_id=999))

            session.rollback()
    finally:
        engine.dispose()
