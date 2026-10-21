"""Schemas for skolebegynder cases.

The record schemas mirror the columns of view_Skolebegyndere and
view_Skolebegynder_Aendringer, so the API documents exactly what the views
return. The request schemas list the fields a caseworker may edit — the
"blue" fields in the UI sketch — and nothing else.
"""

from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class SkolebegynderOverviewRecord(BaseModel):
    """One row of the overview grid (view_Skolebegyndere)."""

    skolebegynder_id: int
    cpr: str
    skoleaar: int

    navn: str | None = None
    navne_adresse_beskyttelse: bool | None = None
    adresse_tekst: str | None = None
    koen: str | None = None
    modersmaal: str | None = None
    tilflyttet_dk_dato: date | None = None
    ppr_status: bool | None = None

    status_id: int
    status_tekst: str
    status_sortering: int | None = None
    status_dato: date | None = None
    modtaget_tidspunkt: datetime

    screening_booket_tidspunkt: datetime | None = None
    screeningsdato: date | None = None
    samlet_resultat: str | None = None
    puf_screeningsresultat: str | None = None
    sprogstoettebehov: bool | None = None
    of_percentil: int | None = None
    sf_percentil: int | None = None
    navn_konsulent: str | None = None

    dagtilbud: str | None = None
    dagtilbud_afdeling: str | None = None
    distriktsskolekode: int | None = None
    distriktsskole: str | None = None
    oensket_skolekode: int | None = None
    oensket_skole: str | None = None
    oensket_skolekode_2: int | None = None
    oensket_skole_2: str | None = None
    soeskende_skolekode: int | None = None
    soeskende_skole: str | None = None
    ansoeger_anden_skole: bool | None = None

    skoletilbud_matrikel_id: int | None = None
    skoletilbud_matrikel: str | None = None
    skoletilbud_skolekode: int | None = None
    skoletilbudstype_id: int | None = None
    skoletilbudstype_tekst: str | None = None
    skoleplaceringsaarsag_id: int | None = None
    skoleplaceringsaarsag_tekst: str | None = None
    brevskabelon_id: int | None = None
    brevskabelon_tekst: str | None = None
    krav_paa_befordring: bool | None = None
    gaaafstand_distriktsskole_km: float | None = None
    gaaafstand_oensket_skole_km: float | None = None
    gaaafstand_skoletilbud_km: float | None = None
    afklaring: str | None = None
    bemaerkning: str | None = None
    sagsbehandlingsdato: date | None = None
    afsluttet_dato: date | None = None

    skoler_afviger: bool
    aabne_aendringer: int

    updated_at: datetime
    updated_by: str


class SkolebegynderDetail(SkolebegynderOverviewRecord):
    """A whole case: the overview row plus the fields the grid leaves out."""

    testtype: str | None = None
    alder_mdr: int | None = None
    gennemfoert: bool | None = None
    afbrudt: bool | None = None
    screening_noter: str | None = None

    of_besvaret: int | None = None
    of_ubesvaret: int | None = None
    of_korrekt: int | None = None
    of_forkert: int | None = None
    of_korrekt_ratio: float | None = None
    of_score: int | None = None
    of_score_alt: int | None = None

    sf_besvaret: int | None = None
    sf_ubesvaret: int | None = None
    sf_korrekt: int | None = None
    sf_forkert: int | None = None
    sf_korrekt_ratio: float | None = None
    sf_korrekt_ratio_ori: float | None = None
    sf_score: int | None = None
    sf_score_alt: int | None = None

    dagtilbud_afdeling_adresse: str | None = None
    email_pl: str | None = None
    email_distriktsskole: str | None = None

    journalfil_dannet: date | None = None
    graffil_dannet: date | None = None

    created_at: datetime
    created_by: str


class SkolebegynderUpdateRequest(BaseModel):
    """The fields a caseworker may change on a case.

    Only the fields actually sent are changed (exclude_unset), so sending
    {"bemaerkning": null} clears the remark while leaving everything else as
    it is. Status is not here: it is derived from these fields, and closing or
    reopening a case has its own endpoints.
    """

    model_config = ConfigDict(extra="forbid")

    puf_screeningsresultat: str | None = Field(default=None, max_length=100)
    skoletilbud_matrikel_id: int | None = None
    skoletilbudstype_id: int | None = None
    skoleplaceringsaarsag_id: int | None = None
    brevskabelon_id: int | None = None
    krav_paa_befordring: bool | None = None
    afklaring: str | None = None
    bemaerkning: str | None = None
    sagsbehandlingsdato: date | None = None


# A filtered overview is a few hundred children at most. The cap keeps one
# request from holding a transaction across the whole cohort.
MAX_MASSEOPDATERING = 500


class SkolebegynderMasseopdateringRequest(BaseModel):
    """The same change applied to many cases at once ("masseopdatering")."""

    model_config = ConfigDict(extra="forbid")

    skolebegynder_ids: list[int] = Field(min_length=1, max_length=MAX_MASSEOPDATERING)
    felter: SkolebegynderUpdateRequest

    @field_validator("skolebegynder_ids")
    @classmethod
    def _unikke(cls, ids: list[int]) -> list[int]:
        if len(set(ids)) != len(ids):
            raise ValueError("skolebegynder_ids indeholder dubletter")
        return ids


class SkolebegynderAendringRecord(BaseModel):
    """One unhandled change (view_Skolebegynder_Aendringer)."""

    aendring_id: int
    skolebegynder_id: int
    cpr: str
    skoleaar: int
    navn: str | None = None
    navne_adresse_beskyttelse: bool | None = None
    adresse_tekst: str | None = None
    distriktsskole: str | None = None
    aendringsaarsag_id: int
    aendringsaarsag_tekst: str
    aendringsaarsag_sortering: int | None = None
    beskrivelse: str | None = None
    registreret_tidspunkt: datetime
    status_tekst: str


class MasseopdateringResult(BaseModel):
    """What a mass update did."""

    opdaterede: int
    statusaendringer: int
