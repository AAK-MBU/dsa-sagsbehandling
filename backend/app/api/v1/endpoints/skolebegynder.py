"""API router for skolebegynder cases (Skolebegynderscreeninger).

Thin by design: every rule — what may change, when status moves, what is
logged — lives in SkolebegynderService.

Route order matters below: the fixed paths (/aendringer, /masseopdatering)
are declared before /{skolebegynder_id}, so they are not read as an id.
"""

from fastapi import APIRouter, Query

from app.api.dependencies import CurrentUser, DbSession, RequireEdit
from app.schemas.skolebegynder import (
    MasseopdateringResult,
    SkolebegynderAendringRecord,
    SkolebegynderDetail,
    SkolebegynderMasseopdateringRequest,
    SkolebegynderOverviewRecord,
    SkolebegynderUpdateRequest,
)
from app.services.skolebegynder_service import SkolebegynderService


router = APIRouter(prefix="/skolebegynder", tags=["Skolebegynder"])


@router.get("", response_model=list[SkolebegynderOverviewRecord])
def get_overview(
    db: DbSession,
    skoleaar: int | None = Query(default=None, ge=2000, le=2100),
):
    """All active cases for the overview grid, newest screening first.

    The Overblik / Ikke screenet / Nærmere afklaring tabs are filters on this
    one list — by status_tekst — so the page fetches it once.
    """

    return SkolebegynderService(db=db).get_overview(skoleaar=skoleaar)


@router.get("/aendringer", response_model=list[SkolebegynderAendringRecord])
def get_aendringer(
    db: DbSession,
    skoleaar: int | None = Query(default=None, ge=2000, le=2100),
):
    """Unhandled changes on active cases — the Ændringer tab."""

    return SkolebegynderService(db=db).get_aendringer(skoleaar=skoleaar)


@router.post("/aendringer/{aendring_id}/haandter", dependencies=[RequireEdit])
def haandter_aendring(aendring_id: int, db: DbSession, udfoert_af: CurrentUser):
    """Mark a change as handled, so it leaves the Ændringer tab."""

    return SkolebegynderService(db=db).haandter_aendring(
        aendring_id=aendring_id,
        udfoert_af=udfoert_af,
    )


@router.put(
    "/masseopdatering",
    response_model=MasseopdateringResult,
    dependencies=[RequireEdit],
)
def masseopdater(
    request: SkolebegynderMasseopdateringRequest,
    db: DbSession,
    udfoert_af: CurrentUser,
):
    """Apply the same change to many cases at once.

    All or nothing: a closed or missing case in the selection rejects the
    whole request. exclude_unset, as on the single update, so only the fields
    actually sent are written.
    """

    return SkolebegynderService(db=db).masseopdater(
        skolebegynder_ids=request.skolebegynder_ids,
        data=request.felter.model_dump(exclude_unset=True),
        udfoert_af=udfoert_af,
    )


@router.get("/{skolebegynder_id}", response_model=SkolebegynderDetail)
def get_skolebegynder(skolebegynder_id: int, db: DbSession):
    """One case, including the screening detail the grid leaves out."""

    return SkolebegynderService(db=db).get_skolebegynder(skolebegynder_id=skolebegynder_id)


@router.put(
    "/{skolebegynder_id}",
    response_model=SkolebegynderDetail,
    dependencies=[RequireEdit],
)
def update_skolebegynder(
    skolebegynder_id: int,
    request: SkolebegynderUpdateRequest,
    db: DbSession,
    udfoert_af: CurrentUser,
):
    """Change the editable fields of a case; its status follows.

    Notes:
        exclude_unset=True means only fields actually provided by the caller
        are included. This prevents missing fields from being interpreted as
        values that should be changed to None.
    """

    return SkolebegynderService(db=db).update_skolebegynder(
        skolebegynder_id=skolebegynder_id,
        data=request.model_dump(exclude_unset=True),
        udfoert_af=udfoert_af,
    )


@router.post(
    "/{skolebegynder_id}/afslut",
    response_model=SkolebegynderDetail,
    dependencies=[RequireEdit],
)
def afslut(skolebegynder_id: int, db: DbSession, udfoert_af: CurrentUser):
    """Close a case once the letter has gone out. Needs a school offer."""

    return SkolebegynderService(db=db).afslut(
        skolebegynder_id=skolebegynder_id,
        udfoert_af=udfoert_af,
    )


@router.post(
    "/{skolebegynder_id}/genaabn",
    response_model=SkolebegynderDetail,
    dependencies=[RequireEdit],
)
def genaabn(skolebegynder_id: int, db: DbSession, udfoert_af: CurrentUser):
    """Reopen a closed case; its status is derived again from its data."""

    return SkolebegynderService(db=db).genaabn(
        skolebegynder_id=skolebegynder_id,
        udfoert_af=udfoert_af,
    )
