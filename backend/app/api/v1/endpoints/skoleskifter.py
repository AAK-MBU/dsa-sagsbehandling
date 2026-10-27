"""API router for skoleskifter cases (Skoleskiftere og tilflyttere, draft).

Thin, as the skolebegynder router: the rules live in SkoleskifterService.
Fixed paths (/elev/{cpr}) come before /{skoleskifter_id}.
"""

from fastapi import APIRouter

from app.api.dependencies import CurrentUser, DbSession, RequireEdit
from app.schemas.skoleskifter import (
    SkoleskifterDetail,
    SkoleskifterOverviewRecord,
    SkoleskifterUpdateRequest,
    TilknytCprRequest,
)
from app.services.skoleskifter_service import SkoleskifterService


router = APIRouter(prefix="/skoleskifter", tags=["Skoleskifter"])


@router.get("", response_model=list[SkoleskifterOverviewRecord])
def get_overview(db: DbSession):
    """All active cases, oldest application first."""

    return SkoleskifterService(db=db).get_overview()


@router.get("/elev/{cpr}", response_model=list[SkoleskifterOverviewRecord])
def get_elev_skoleskiftere(cpr: str, db: DbSession):
    """A child's skoleskifter cases, newest first — for the student page.
    The CPR is in the path so PortalAuditLog records whose cases were read."""

    return SkoleskifterService(db=db).get_for_cpr(cpr=cpr)


@router.get("/{skoleskifter_id}", response_model=SkoleskifterDetail)
def get_skoleskifter(skoleskifter_id: int, db: DbSession):
    """One case, including the application data and the assessment points."""

    return SkoleskifterService(db=db).get_skoleskifter(skoleskifter_id=skoleskifter_id)


@router.put("/{skoleskifter_id}", response_model=SkoleskifterDetail, dependencies=[RequireEdit])
def update_skoleskifter(
    skoleskifter_id: int,
    request: SkoleskifterUpdateRequest,
    db: DbSession,
    udfoert_af: CurrentUser,
):
    """Change the editable fields and/or the manual status; status follows."""

    return SkoleskifterService(db=db).update_skoleskifter(
        skoleskifter_id=skoleskifter_id,
        data=request.model_dump(exclude_unset=True),
        udfoert_af=udfoert_af,
    )


@router.post("/{skoleskifter_id}/afslut", response_model=SkoleskifterDetail, dependencies=[RequireEdit])
def afslut(skoleskifter_id: int, db: DbSession, udfoert_af: CurrentUser):
    """Close a case by hand (the normal close is automatic)."""

    return SkoleskifterService(db=db).afslut(skoleskifter_id=skoleskifter_id, udfoert_af=udfoert_af)


@router.post("/{skoleskifter_id}/genaabn", response_model=SkoleskifterDetail, dependencies=[RequireEdit])
def genaabn(skoleskifter_id: int, db: DbSession, udfoert_af: CurrentUser):
    """Reopen a closed case."""

    return SkoleskifterService(db=db).genaabn(skoleskifter_id=skoleskifter_id, udfoert_af=udfoert_af)


@router.post("/{skoleskifter_id}/cpr", response_model=SkoleskifterDetail, dependencies=[RequireEdit])
def tilknyt_cpr(skoleskifter_id: int, request: TilknytCprRequest, db: DbSession, udfoert_af: CurrentUser):
    """Link a case that arrived without a CPR to the child."""

    return SkoleskifterService(db=db).tilknyt_cpr(
        skoleskifter_id=skoleskifter_id, cpr=request.cpr, udfoert_af=udfoert_af
    )
