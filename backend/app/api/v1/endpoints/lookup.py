"""API router for lookup-related endpoints.

This module contains simple read-only endpoints for lookup/reference data.

Lookup data is typically used by the frontend to populate dropdowns, select
fields, filters, and other UI options.

The router should stay very thin. The actual database queries should live in
LookupService.
"""

from fastapi import APIRouter

from app.api.dependencies import DbSession
from app.services.lookup_service import LookupService


# All routes in this file are grouped under /lookup.
# The tag is used by Swagger/OpenAPI to group these endpoints visually.
# WARNING: successful calls to routes on this router are NOT audit-logged.
# They are dropped as noise because everything here is reference data — the
# contents of dropdowns. Only their failures reach PortalAuditLog.
#
# So do not add an endpoint here that takes a CPR or returns citizen data: it
# would silently fall outside the audit trail. Such endpoints belong on the
# citizen, skolebegynder or aktivitet routers. See _REFERENCE_PATH_PREFIXES
# in app/middleware/audit_middleware.py.
router = APIRouter(prefix="/lookup", tags=["Lookup"])


@router.get("/all")
def get_all(db: DbSession):
    """Get every lookup list in a single request.

    Returns:
        An object keyed by lookup name, each value the list that the
        corresponding single-lookup route returns.
    """

    return LookupService(db=db).get_all()


@router.get("/fagomraader")
def get_fagomraader(db: DbSession):
    """Get the areas of case work."""

    return LookupService(db=db).get_fagomraader()


@router.get("/status")
def get_status(db: DbSession):
    """Get statuses, each with its fagomraade_id (NULL = every area)."""

    return LookupService(db=db).get_status()


@router.get("/skoletilbudstyper")
def get_skoletilbudstyper(db: DbSession):
    """Get skoletilbudstyper."""

    return LookupService(db=db).get_skoletilbudstyper()


@router.get("/skoleplaceringsaarsager")
def get_skoleplaceringsaarsager(db: DbSession):
    """Get skoleplaceringsårsager."""

    return LookupService(db=db).get_skoleplaceringsaarsager()


@router.get("/brevskabeloner")
def get_brevskabeloner(db: DbSession):
    """Get letter templates."""

    return LookupService(db=db).get_brevskabeloner()


@router.get("/aendringsaarsager")
def get_aendringsaarsager(db: DbSession):
    """Get ændringsårsager."""

    return LookupService(db=db).get_aendringsaarsager()


@router.get("/skolematrikel")
def get_skolematrikel(db: DbSession):
    """Get school campuses, each with its skolekode."""

    return LookupService(db=db).get_skolematrikel()


@router.get("/skoler")
def get_skoler(db: DbSession):
    """Get schools, one per skolekode."""

    return LookupService(db=db).get_skoler()
