from fastapi import APIRouter

from app.api.v1.endpoints import ansoegninger

api_router = APIRouter()

api_router.include_router(ansoegninger.router, prefix="/ansoegninger", tags=["ansoegninger"])
