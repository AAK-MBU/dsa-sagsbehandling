"""API router for citizen (Elev) endpoints — the Elevmappe.

Citizen data is read-only here; it is maintained in LIS / TEA.

The CPR is in the path on purpose, as in befordringssystemet: PortalAuditLog
records the path, and who looked up which child is what the trail is for.
"""

from fastapi import APIRouter, HTTPException

from app.api.dependencies import DbSession
from app.services.citizen_service import CitizenService


router = APIRouter(prefix="/citizen", tags=["Citizen"])


@router.get("/stamdata/{cpr}")
def get_stamdata(cpr: str, db: DbSession):
    """Get master data for a child: the child, custody holders and cases.

    Args:
        cpr:
            CPR number of the child.

    Raises:
        HTTPException: 404 if DSA holds no child with this CPR.
    """

    stamdata = CitizenService(db=db).get_stamdata(cpr=cpr)

    if stamdata is None:
        raise HTTPException(status_code=404, detail="Elev ikke fundet")

    return stamdata
