from fastapi import APIRouter, HTTPException

from app.schemas.ansoegning import Ansoegning
from app.services.mock_data import MOCK_ANSOEGNINGER

router = APIRouter()


@router.get("", response_model=list[Ansoegning])
def list_ansoegninger():
    """Return all mock modtagelsesklasse-ansøgninger."""

    return MOCK_ANSOEGNINGER


@router.get("/{ansoegning_id}", response_model=Ansoegning)
def get_ansoegning(ansoegning_id: int):
    """Return a single ansøgning by id (used by the elevmappe view)."""

    for ansoegning in MOCK_ANSOEGNINGER:
        if ansoegning.id == ansoegning_id:
            return ansoegning

    raise HTTPException(status_code=404, detail="Ansøgning ikke fundet")
