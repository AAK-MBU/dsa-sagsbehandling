"""API router for citizen-related endpoints.

This module contains endpoints for citizen stamdata and parent data.

Ported from befordringssystemet. DSA: create_elev and genberegn_skole are
omitted (befordring's conversion bot and walking-distance calculation).

Stamdata and parent data themselves are maintained by external systems and are
read-only here.

The CPR is in the path on purpose: PortalAuditLog records the path, and who
looked up which child is what the trail is for.
"""

from fastapi import APIRouter

from app.api.dependencies import DbSession
from app.services.citizen_service import CitizenService


# All routes in this file are grouped under /citizen.
# The tag is used by Swagger/OpenAPI to group the endpoints visually.
router = APIRouter(prefix="/citizen", tags=["Citizen"])


@router.get("/stamdata/{cpr}")
def get_stamdata(cpr: str, db: DbSession):
    """Get stamdata for a citizen/student.

    Args:
        cpr:
            The CPR number of the citizen/student.

        db:
            The database session injected by FastAPI.

    Returns:
        Stamdata for the provided CPR.
    """

    service = CitizenService(db=db)

    return service.get_stamdata(cpr=cpr)


@router.get("/stamdata/{cpr}/parents")
def get_parent_data(cpr: str, db: DbSession):
    """Get parent/guardian data for a citizen/student.

    Args:
        cpr:
            The CPR number of the citizen/student.

        db:
            The database session injected by FastAPI.

    Returns:
        Parent/guardian data connected to the provided CPR.
    """

    service = CitizenService(db=db)

    return service.get_parent_data(cpr=cpr)
