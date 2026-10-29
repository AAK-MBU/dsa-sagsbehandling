"""Schemas for skoleskifter cases (Skoleskiftere og tilflyttere, draft).

The record schemas mirror view_Skoleskiftere. The update request lists what
a caseworker edits in the draft: the kind of case (set by the robot from the
form, correctable), the language assessment, the decision, the remark — and
the manual statuses, since part of this area's status is a
caseworker's choice (see usp_recalculate_skoleskifter_status).
"""

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class SkoleskifterOverviewRecord(BaseModel):
    """One row of the overview grid (view_Skoleskiftere)."""

    skoleskifter_id: int
    cpr: str
    navn: str | None = None
    navne_adresse_beskyttelse: bool | None = None
    adresse_tekst: str | None = None
    modersmaal: str | None = None
    elevklassetrin: str | None = None
    distriktsskolekode: int | None = None
    distriktsskole: str | None = None
    variant: str

    status_id: int
    status_tekst: str
    status_sortering: int | None = None
    status_dato: date | None = None
    modtaget_tidspunkt: datetime

    esdh_noegle: str | None = None
    esdh_url: str | None = None
    skoleaar: int | None = None
    indgang: str
    nuvaerende_skoletilbud: str | None = None
    udslusningsdato: date | None = None
    nuvaerende_kommune: str | None = None
    oensket_skolekode: int | None = None
    oensket_skole: str | None = None
    nuvaerende_skolekode: int | None = None
    nuvaerende_skole: str | None = None
    klassetrin_ansoegning: str | None = None
    flytning: bool | None = None
    flyttedato: date | None = None
    kommende_adresse: str | None = None
    modersmaal_foraelder: str | None = None
    modersmaal_skole: str | None = None
    soeskende_paa_skolen: bool | None = None
    soeskende_klasse: str | None = None
    skolens_afgoerelse: str | None = None

    screeningsdato: date | None = None
    samlet_resultat: str | None = None

    skoletilbud_matrikel_id: int | None = None
    skoletilbud_matrikel: str | None = None
    skoletilbudstype_id: int | None = None
    skoletilbudstype_tekst: str | None = None
    dato_skoletilbud: date | None = None
    klassetrin: str | None = None
    bemaerkning: str | None = None
    ppr_sendt_dato: date | None = None
    afsluttet_dato: date | None = None

    ventetid_dage: int | None = None
    dage_hos_ppr: int | None = None

    updated_at: datetime
    updated_by: str


class SkoleskifterDetail(SkoleskifterOverviewRecord):
    """A whole case: the overview row plus what the grid leaves out."""

    nuvaerende_skole_tekst: str | None = None
    ansoegningsdata: str | None = None
    begrundelse: str | None = None

    point_1: float | None = None
    resultat_1: str | None = None
    point_2: float | None = None
    resultat_2: str | None = None
    point_3: float | None = None
    resultat_3: str | None = None

    start_visitationsklasse: date | None = None
    spor: str | None = None

    created_at: datetime
    created_by: str


Variant = Literal["Tilflytter", "Skoleskift internt", "Skoleskift udefra"]

# The statuses a caseworker sets by hand; the rest are derived.
ManuelStatus = Literal["Ny", "Afventer sprogvurdering", "Sendt til PPR"]


class SkoleskifterUpdateRequest(BaseModel):
    """The fields a caseworker may change on a case (draft).

    Only the fields sent are changed (exclude_unset). `manuel_status` sets
    one of the manual statuses; the procedure then derives the rest, so an
    offer still wins over "Sendt til PPR".
    """

    model_config = ConfigDict(extra="forbid")

    manuel_status: ManuelStatus | None = None

    variant: Variant | None = None
    screeningsdato: date | None = None
    point_1: float | None = None
    resultat_1: str | None = Field(default=None, max_length=100)
    point_2: float | None = None
    resultat_2: str | None = Field(default=None, max_length=100)
    point_3: float | None = None
    resultat_3: str | None = Field(default=None, max_length=100)
    samlet_resultat: str | None = Field(default=None, max_length=100)

    skoletilbud_matrikel_id: int | None = None
    skoletilbudstype_id: int | None = None
    dato_skoletilbud: date | None = None
    start_visitationsklasse: date | None = None
    klassetrin: str | None = Field(default=None, max_length=20)
    spor: str | None = Field(default=None, max_length=50)
    bemaerkning: str | None = None
