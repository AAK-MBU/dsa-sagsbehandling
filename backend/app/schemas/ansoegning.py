"""Schemas for modtagelsesklasse-ansøgninger.

Field names follow the OS2Forms formular ("Ansøgning om indmeldelse i
modtagelsesklasse") where the data originates. Fields that are assigned
during sagsbehandling (status, sagsbehandler, klassetrin, skole) are
nullable and live at the top level of the case.
"""

from typing import Literal, Optional

from pydantic import BaseModel

AnsoegningStatus = Literal[
    "Ny",
    "Under behandling",
    "Afventer PPR",
    "Afventer konsulent",
    "Sendt skrivelse",
    "Færdigbehandlet",
]

# Relation options from the formular (relation_til_barnet)
AnsoegerRelation = Literal["Forælder", "Pårørende/kontaktperson", "Fagprofessionel"]


class Ansoeger(BaseModel):
    """The person who submitted the formular."""

    relation_til_barnet: AnsoegerRelation
    # Filled via MitID login; null when ansøger has no MitID
    navn: Optional[str] = None
    cpr: Optional[str] = None
    har_mitid: bool


class Barn(BaseModel):
    """Oplysninger om barnet from the formular."""

    fulde_navn: str
    har_cpr: bool
    cpr: Optional[str] = None
    foedselsdato: str
    # Only asked when barnet has no CPR
    koen: Optional[Literal["Pige", "Dreng"]] = None
    adresse: Optional[str] = None
    postnummer: Optional[str] = None
    by: Optional[str] = None
    nationalitet: str
    tidligere_dansk_skole: Optional[bool] = None
    modersmaal: Optional[str] = None
    ankomstdato_danmark: str
    skoleaar_foer_ankomst: int
    afsluttet_afgangseksamen: bool
    # Attachment counts — stand-ins until real file handling exists
    antal_dokumentation_bilag: int = 0
    antal_skolepapir_bilag: int = 0


class SaerligeBehov(BaseModel):
    """Særlige behov section — drives the PPR track."""

    har_saerlige_behov: bool
    beskrivelse: Optional[str] = None
    antal_bilag: int = 0


class Foraeldre(BaseModel):
    """Forældremyndighedsindehaver(e) + evt. kontaktperson.

    Each forælder has a CPR — this is what actually ties siblings together:
    two children with a shared forælder-CPR are søskende.
    """

    foraelder_1_navn: Optional[str] = None
    foraelder_1_cpr: Optional[str] = None
    foraelder_2_navn: Optional[str] = None
    foraelder_2_cpr: Optional[str] = None
    telefon: Optional[str] = None
    email: str
    kontaktperson_navn: Optional[str] = None
    kontaktperson_telefon: Optional[str] = None
    kontaktperson_sprog: Optional[str] = None


class Ansoegning(BaseModel):
    """A modtagelsesklasse case as shown in the fagsystem."""

    id: int
    modtagelsesdato: str
    status: AnsoegningStatus

    ansoeger: Ansoeger
    barn: Barn
    saerlige_behov: SaerligeBehov
    foraeldre: Foraeldre

    anden_information: Optional[str] = None

    # Assigned during sagsbehandling — null until a sagsbehandler sets them
    sagsbehandler: Optional[str] = None
    klassetrin: Optional[str] = None
    modtagelsesskole: Optional[str] = None
    # Siblings are derived from shared forælder-CPR (see Foraeldre), not stored.
    soeskende_paa_sag: bool = False
