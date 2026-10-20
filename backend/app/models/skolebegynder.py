"""Skolebegynder cases — Skolebegynderscreeninger, phase 1.

One row per child per school year (UQ_Skolebegynder_cpr_skoleaar): a child
whose school start is postponed returns the next year as a new case, and the
old decision survives. See migration 001 for the reasoning.
"""

from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import Boolean, Date, Float, ForeignKey, Integer, String, Unicode, text
from sqlalchemy.dialects.mssql import DATETIME2
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


DB_SCHEMA = "dsa"


class Skolebegynder(Base):
    """A skolebegynder case.

    status_id is owned by usp_recalculate_skolebegynder_status for every
    status but "Afsluttet" — write the data, then recalculate, rather than
    setting the status directly.
    """

    __tablename__ = "Skolebegynder"
    __table_args__ = {"schema": DB_SCHEMA}

    skolebegynder_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    cpr: Mapped[str] = mapped_column(
        String(10),
        ForeignKey(f"{DB_SCHEMA}.Elev.cpr"),
        nullable=False,
    )
    skoleaar: Mapped[int] = mapped_column(Integer, nullable=False)

    status_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Status.status_id"),
        nullable=False,
    )
    status_dato: Mapped[date | None] = mapped_column(Date, nullable=True)
    modtaget_tidspunkt: Mapped[datetime] = mapped_column(
        DATETIME2,
        nullable=False,
        server_default=text("sysdatetime()"),
    )

    # --- Screening, from SX ---
    screeningsdato: Mapped[date | None] = mapped_column(Date, nullable=True)
    testtype: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    navn_konsulent: Mapped[str | None] = mapped_column(Unicode(200), nullable=True)
    alder_mdr: Mapped[int | None] = mapped_column(Integer, nullable=True)
    gennemfoert: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    afbrudt: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    screening_noter: Mapped[str | None] = mapped_column(Unicode, nullable=True)

    # of_ = ordforråd (vocabulary)
    of_percentil: Mapped[int | None] = mapped_column(Integer, nullable=True)
    of_besvaret: Mapped[int | None] = mapped_column(Integer, nullable=True)
    of_ubesvaret: Mapped[int | None] = mapped_column(Integer, nullable=True)
    of_korrekt: Mapped[int | None] = mapped_column(Integer, nullable=True)
    of_forkert: Mapped[int | None] = mapped_column(Integer, nullable=True)
    of_korrekt_ratio: Mapped[float | None] = mapped_column(Float, nullable=True)
    of_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    of_score_alt: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # sf_ = sprogforståelse (language comprehension)
    sf_percentil: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sf_besvaret: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sf_ubesvaret: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sf_korrekt: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sf_forkert: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sf_korrekt_ratio: Mapped[float | None] = mapped_column(Float, nullable=True)
    sf_korrekt_ratio_ori: Mapped[float | None] = mapped_column(Float, nullable=True)
    sf_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sf_score_alt: Mapped[int | None] = mapped_column(Integer, nullable=True)

    samlet_resultat: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    puf_screeningsresultat: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    sprogstoettebehov: Mapped[bool | None] = mapped_column(Boolean, nullable=True)

    # --- Context from enrolment / LIS / Lone's extract ---
    dagtilbud: Mapped[str | None] = mapped_column(Unicode(200), nullable=True)
    dagtilbud_afdeling: Mapped[str | None] = mapped_column(Unicode(200), nullable=True)
    dagtilbud_afdeling_adresse: Mapped[str | None] = mapped_column(Unicode(500), nullable=True)
    email_pl: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    email_distriktsskole: Mapped[str | None] = mapped_column(Unicode(255), nullable=True)
    # Schools, not campuses: skolekode, no FK — see view_Skoler.
    oensket_skolekode: Mapped[int | None] = mapped_column(Integer, nullable=True)
    soeskende_skolekode: Mapped[int | None] = mapped_column(Integer, nullable=True)
    ansoeger_anden_skole: Mapped[bool | None] = mapped_column(Boolean, nullable=True)

    # --- Case work ---
    skoletilbud_matrikel_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Skolematrikel.matrikel_id"),
        nullable=True,
    )
    skoletilbudstype_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Skoletilbudstype.skoletilbudstype_id"),
        nullable=True,
    )
    skoleplaceringsaarsag_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Skoleplaceringsaarsag.skoleplaceringsaarsag_id"),
        nullable=True,
    )
    brevskabelon_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Brevskabelon.brevskabelon_id"),
        nullable=True,
    )
    krav_paa_befordring: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    gaaafstand_distriktsskole_km: Mapped[float | None] = mapped_column(Float, nullable=True)
    gaaafstand_oensket_skole_km: Mapped[float | None] = mapped_column(Float, nullable=True)
    gaaafstand_skoletilbud_km: Mapped[float | None] = mapped_column(Float, nullable=True)
    bemaerkning: Mapped[str | None] = mapped_column(Unicode, nullable=True)
    sagsbehandlingsdato: Mapped[date | None] = mapped_column(Date, nullable=True)
    journalfil_dannet: Mapped[date | None] = mapped_column(Date, nullable=True)
    graffil_dannet: Mapped[date | None] = mapped_column(Date, nullable=True)
    afsluttet_dato: Mapped[date | None] = mapped_column(Date, nullable=True)

    # --- Bookkeeping, as on befordringssystemet's Bevilling ---
    # updated_at is maintained by trg_Skolebegynder_UpdatedAt.
    created_at: Mapped[datetime] = mapped_column(
        DATETIME2,
        nullable=False,
        server_default=text("sysdatetime()"),
    )
    created_by: Mapped[str] = mapped_column(Unicode(100), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DATETIME2,
        nullable=False,
        server_default=text("sysdatetime()"),
    )
    updated_by: Mapped[str] = mapped_column(Unicode(100), nullable=False)
    aktiv: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("1"))


class SkolebegynderAendring(Base):
    """A change detected on a child after its case opened (Ændringer tab).

    Stays until a caseworker marks it handled.
    """

    __tablename__ = "Skolebegynder_Aendring"
    __table_args__ = {"schema": DB_SCHEMA}

    aendring_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    skolebegynder_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Skolebegynder.skolebegynder_id"),
        nullable=False,
    )
    aendringsaarsag_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Aendringsaarsag.aendringsaarsag_id"),
        nullable=False,
    )
    beskrivelse: Mapped[str | None] = mapped_column(Unicode(1000), nullable=True)
    registreret_tidspunkt: Mapped[datetime] = mapped_column(
        DATETIME2,
        nullable=False,
        server_default=text("sysdatetime()"),
    )
    haandteret: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("0"))
    haandteret_af: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    haandteret_tidspunkt: Mapped[datetime | None] = mapped_column(DATETIME2, nullable=True)
