"""Main API router for version 1 endpoints.

This module collects all endpoint routers for API v1 and registers them under
one shared APIRouter.

It also applies shared dependencies, such as API key validation, to protected
routers. Every router must be registered with one of the two dependency lists
below — a router included without either is open to anyone who can reach the
API.

By centralizing router registration here, main.py only needs to include this
single api_router instead of importing every endpoint router individually.
"""

from fastapi import APIRouter, Depends

from app.api.dependencies import require_auth
from app.api.v1.endpoints import ansoegninger
from app.core.security import verify_api_key


api_router = APIRouter()


# Human-facing routes accept either a valid API key (X-API-Key header) or an
# active OIDC browser session. RPA bots and integration partners use API keys;
# human users logging in via the browser use OIDC. While OIDC_ENABLED is off,
# browser calls resolve to a placeholder developer — see require_auth.
human_dependencies = [Depends(require_auth)]

# Automated / webhook routes require an API key and nothing else, e.g. an
# OS2Forms submission, which comes from an external system with no browser
# session. Unused until the first such route exists.
rpa_dependencies = [Depends(verify_api_key)]


# Register ansøgning routes. Mock data — see app/services/mock_data.py.
api_router.include_router(
    ansoegninger.router,
    prefix="/ansoegninger",
    tags=["ansoegninger"],
    dependencies=human_dependencies,
)
