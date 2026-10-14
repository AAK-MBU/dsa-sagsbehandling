"""Main FastAPI application entrypoint for the DSA (modtagelsesklasse) prototype.

This is a mock-data prototype: there is no database yet, all endpoints
return in-memory data from app/services/mock_data.py.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1.api import api_router


class UTF8JSONResponse(JSONResponse):
    """JSON response class with explicit UTF-8 charset (for æ, ø, å)."""

    media_type = "application/json; charset=utf-8"


app = FastAPI(
    title="DSA API",
    description="API for DSA (modtagelsesklasse) prototype",
    version="0.0.1",
    default_response_class=UTF8JSONResponse,
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(api_router)


@app.get("/")
def root():
    return {"message": "DSA API is running"}


@app.get("/health", tags=["health"])
async def health_check():
    return {"status": "ok"}
