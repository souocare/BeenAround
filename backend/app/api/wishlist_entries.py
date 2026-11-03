"""Global wishlist REST endpoints."""

from uuid import UUID

from fastapi import APIRouter, HTTPException, Response, status
from sqlalchemy.engine import Engine

from app.api.dependencies import CurrentApiUser, DatabaseSession
from app.repositories.wishlist_entries import WishlistEntryRepository
from app.schemas.wishlist_entries import (
    WishlistEntryCreate,
    WishlistEntryCreateResponse,
    WishlistEntryListResponse,
    WishlistEntryResponse,
    WishlistEntryUpdate,
)
from app.services.wishlist_entries import (
    WishlistDestinationNotFound,
    WishlistEntryNotFound,
    add_wishlist_entries,
    delete_wishlist_entry,
    update_wishlist_entry,
)


router = APIRouter(
    prefix="/wishlist",
    tags=["Wishlist"],
)


def get_write_engine(session: DatabaseSession) -> Engine:
    """Resolve the configured engine for dedicated wishlist writes."""

    bind = session.get_bind()

    if not isinstance(bind, Engine):
        raise RuntimeError("Wishlist write operations require an engine-bound session.")

    return bind


@router.get(
    "",
    response_model=WishlistEntryListResponse,
)
def list_wishlist_entries(
    user: CurrentApiUser,
    session: DatabaseSession,
) -> WishlistEntryListResponse:
    """List the authenticated user's global wishlist."""

    repository = WishlistEntryRepository(session)

    entries = repository.list_for_user(user.id)

    return WishlistEntryListResponse(
        items=[WishlistEntryResponse.model_validate(entry) for entry in entries],
        total=len(entries),
    )


@router.get(
    "/{entry_id}",
    response_model=WishlistEntryResponse,
)
def get_wishlist_entry(
    entry_id: UUID,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> WishlistEntryResponse:
    """Retrieve a wishlist entry owned by the authenticated user."""

    repository = WishlistEntryRepository(session)

    entry = repository.get_for_user(
        entry_id=entry_id,
        user_id=user.id,
    )

    if entry is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Wishlist entry not found.",
        )

    return WishlistEntryResponse.model_validate(entry)


@router.post(
    "",
    response_model=WishlistEntryCreateResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        200: {
            "model": WishlistEntryCreateResponse,
            "description": "All requested destinations already exist.",
        },
        404: {
            "description": "Country or city not found.",
        },
    },
)
def create_wishlist_entries(
    payload: WishlistEntryCreate,
    response: Response,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> WishlistEntryCreateResponse:
    """Atomically add one or two destinations to the user's wishlist.

    Returns 201 when at least one entry was created.
    Returns 200 when all requested entries already existed.
    """

    try:
        result = add_wishlist_entries(
            engine=get_write_engine(session),
            user_id=user.id,
            payload=payload,
        )

    except WishlistDestinationNotFound as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error

    if not result.created:
        response.status_code = status.HTTP_200_OK

    return WishlistEntryCreateResponse(
        created=[WishlistEntryResponse.model_validate(entry) for entry in result.created],
        existing=[WishlistEntryResponse.model_validate(entry) for entry in result.existing],
    )


@router.patch(
    "/{entry_id}",
    response_model=WishlistEntryResponse,
)
def update_wishlist_entry_endpoint(
    entry_id: UUID,
    payload: WishlistEntryUpdate,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> WishlistEntryResponse:
    """Update the optional note of an owned wishlist entry."""

    try:
        entry = update_wishlist_entry(
            engine=get_write_engine(session),
            user_id=user.id,
            entry_id=entry_id,
            payload=payload,
        )

    except WishlistEntryNotFound as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error

    return WishlistEntryResponse.model_validate(entry)


@router.delete(
    "/{entry_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_wishlist_entry_endpoint(
    entry_id: UUID,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> None:
    """Delete an owned wishlist entry."""

    try:
        delete_wishlist_entry(
            engine=get_write_engine(session),
            user_id=user.id,
            entry_id=entry_id,
        )

    except WishlistEntryNotFound as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error
