"""Schemas for skoleskifter cases (Skoleskiftere og tilflyttere, draft).

The record schemas mirror view_Skoleskiftere. The update request lists what
a caseworker edits: the kind of case (set by the robot from the form,
correctable), the caseworker, each flow's assessment and decision, the
letters and befordring (migration 007) — and
the manual statuses, since part of this area's status is a
caseworker's choice (see usp_recalculate_skoleskifter_status).
"""

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.skolebegynder import PufResultat


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
    forloeb: str                      # "Intern" / "Ekstern" (migration 007)
    sagsbehandler_id: int | None = None
    sagsbehandler_tekst: str | None = None

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
    andet_modersmaal: bool | None = None

    # Intern: the school's sprogvurdering. Ekstern: PUF's screening.
    dato_forespoergsel_skole: date | None = None
    dato_svar_skole: date | None = None
    skolens_sprogvurdering: str | None = None
    dato_indkaldelse_screening: date | None = None
    screeningsdato: date | None = None
    samlet_resultat: str | None = None

    ledig_plads: bool | None = None
    kontaktet_skole_matrikel_id: int | None = None
    kontaktet_skole: str | None = None
    dato_kontakt_skole: date | None = None
    midlertidigt_skoletilbud_matrikel_id: int | None = None
    midlertidigt_skoletilbud: str | None = None
    start_visitationsklasse: date | None = None
    skoletilbud_matrikel_id: int | None = None
    skoletilbud_matrikel: str | None = None
    skoletilbudstype_id: int | None = None
    skoletilbudstype_tekst: str | None = None
    dato_skoletilbud: date | None = None
    klassetrin: str | None = None
    bemaerkning: str | None = None
    ppr_sendt_dato: date | None = None
    afsluttet_dato: date | None = None

    optagelsesbrev_sendt: date | None = None
    sprogstoettebrev_sendt: date | None = None
    partshoeringsbrev_sendt: date | None = None
    krav_paa_befordring: bool | None = None
    befordring_bemaerkning: str | None = None

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

    spor: str | None = None

    created_at: datetime
    created_by: str


Variant = Literal["Tilflytter", "Skoleskift internt", "Skoleskift eksternt"]

SkolensSprogvurdering = Literal["Afventer optagelse i Sprog+", "Fortsat behov for sprogstøtte"]

# The statuses a caseworker sets by hand; the rest are derived. (Migration
# 007: "Afventer sprogvurdering" is derived now, from the day the school was
# asked.)
ManuelStatus = Literal["Ny", "Sendt til PPR"]


class SkoleskifterUpdateRequest(BaseModel):
    """The fields a caseworker may change on a case (draft).

    Only the fields sent are changed (exclude_unset). `manuel_status` sets
    one of the manual statuses; the procedure then derives the rest, so an
    offer still wins over "Sendt til PPR".
    """

    model_config = ConfigDict(extra="forbid")

    manuel_status: ManuelStatus | None = None

    variant: Variant | None = None
    sagsbehandler_id: int | None = None
    andet_modersmaal: bool | None = None

    # Intern: the school's sprogvurdering
    dato_forespoergsel_skole: date | None = None
    dato_svar_skole: date | None = None
    skolens_sprogvurdering: SkolensSprogvurdering | None = None

    # Ekstern: PUF's screening
    dato_indkaldelse_screening: date | None = None
    screeningsdato: date | None = None
    point_1: float | None = None
    resultat_1: str | None = Field(default=None, max_length=100)
    point_2: float | None = None
    resultat_2: str | None = Field(default=None, max_length=100)
    point_3: float | None = None
    resultat_3: str | None = Field(default=None, max_length=100)
    samlet_resultat: PufResultat | None = None

    ledig_plads: bool | None = None
    kontaktet_skole_matrikel_id: int | None = None
    dato_kontakt_skole: date | None = None
    midlertidigt_skoletilbud_matrikel_id: int | None = None
    skoletilbud_matrikel_id: int | None = None
    skoletilbudstype_id: int | None = None
    dato_skoletilbud: date | None = None
    start_visitationsklasse: date | None = None
    klassetrin: str | None = Field(default=None, max_length=20)
    spor: str | None = Field(default=None, max_length=50)
    bemaerkning: str | None = None

    # Letters (the day each was sent) and befordring
    optagelsesbrev_sendt: date | None = None
    sprogstoettebrev_sendt: date | None = None
    partshoeringsbrev_sendt: date | None = None
    krav_paa_befordring: bool | None = None
    befordring_bemaerkning: str | None = None


class SkoleskifterAfslutRequest(BaseModel):
    """Closing a case by hand: why, for the case log. Optional."""

    model_config = ConfigDict(extra="forbid")

    begrundelse: str | None = Field(default=None, max_length=500)
