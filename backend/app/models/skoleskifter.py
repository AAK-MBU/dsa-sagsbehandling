"""Skoleskifter cases — Skoleskiftere og tilflyttere (draft).

One row per application (migrations 004 and 005). Every case has a CPR:
the forms send a child without one elsewhere (see migration 005).
"""

from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import Boolean, Date, ForeignKey, Integer, Numeric, String, Unicode, text
from sqlalchemy.dialects.mssql import DATETIME2
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


DB_SCHEMA = "dsa"

# The three kinds of case (CK_Skoleskifter_variant).
VARIANTER = ("Tilflytter", "Skoleskift internt", "Skoleskift udefra")

# How the case came (CK_Skoleskifter_skoletilbud): Modtagelsesklasse straight
# from the parents, Almen klasse through the receiving school's form.
NUVAERENDE_SKOLETILBUD = ("Almen klasse", "Modtagelsesklasse")

# The receiving school's ground for admission (CK_Skoleskifter_afgoerelse).
SKOLENS_AFGOERELSER = ("Tilflytter til distriktet", "Ledig plads")


class Skoleskifter(Base):
    """A skoleskifter / tilflytter case.

    status_id is derived by usp_recalculate_skoleskifter_status, except the
    manual statuses (Ny, Afventer sprogvurdering, Sendt til PPR, Afsluttet by
    hand) — write the data or the manual status, then recalculate.
    """

    __tablename__ = "Skoleskifter"
    __table_args__ = {"schema": DB_SCHEMA}

    skoleskifter_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    cpr: Mapped[str] = mapped_column(
        String(10),
        ForeignKey(f"{DB_SCHEMA}.Elev.cpr"),
        nullable=False,
    )
    variant: Mapped[str] = mapped_column(Unicode(30), nullable=False)
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

    # --- From the application (OS2Forms) ---
    os2forms_id: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    ansoegningsdata: Mapped[str | None] = mapped_column(Unicode, nullable=True)
    esdh_noegle: Mapped[str | None] = mapped_column(Unicode(50), nullable=True)
    esdh_url: Mapped[str | None] = mapped_column(Unicode(500), nullable=True)
    skoleaar: Mapped[int | None] = mapped_column(Integer, nullable=True)
    nuvaerende_skoletilbud: Mapped[str | None] = mapped_column(Unicode(30), nullable=True)
    udslusningsdato: Mapped[date | None] = mapped_column(Date, nullable=True)
    nuvaerende_kommune: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    oensket_skolekode: Mapped[int | None] = mapped_column(Integer, nullable=True)
    nuvaerende_skolekode: Mapped[int | None] = mapped_column(Integer, nullable=True)
    nuvaerende_skole_tekst: Mapped[str | None] = mapped_column(Unicode(200), nullable=True)
    klassetrin_ansoegning: Mapped[str | None] = mapped_column(Unicode(20), nullable=True)  # "Nuværende klasse", e.g. 3.B
    flytning: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    flyttedato: Mapped[date | None] = mapped_column(Date, nullable=True)
    kommende_adresse: Mapped[str | None] = mapped_column(Unicode(300), nullable=True)
    modersmaal_foraelder: Mapped[str | None] = mapped_column(Unicode(50), nullable=True)
    modersmaal_skole: Mapped[str | None] = mapped_column(Unicode(50), nullable=True)
    soeskende_paa_skolen: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    soeskende_klasse: Mapped[str | None] = mapped_column(Unicode(20), nullable=True)
    begrundelse: Mapped[str | None] = mapped_column(Unicode, nullable=True)
    skolens_afgoerelse: Mapped[str | None] = mapped_column(Unicode(50), nullable=True)

    # --- Language assessment (PUF) ---
    screeningsdato: Mapped[date | None] = mapped_column(Date, nullable=True)
    point_1: Mapped[float | None] = mapped_column(Numeric(6, 1, asdecimal=False), nullable=True)
    resultat_1: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    point_2: Mapped[float | None] = mapped_column(Numeric(6, 1, asdecimal=False), nullable=True)
    resultat_2: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    point_3: Mapped[float | None] = mapped_column(Numeric(6, 1, asdecimal=False), nullable=True)
    resultat_3: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)
    samlet_resultat: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)

    # --- Decision ---
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
    dato_skoletilbud: Mapped[date | None] = mapped_column(Date, nullable=True)
    start_visitationsklasse: Mapped[date | None] = mapped_column(Date, nullable=True)
    klassetrin: Mapped[str | None] = mapped_column(Unicode(20), nullable=True)
    spor: Mapped[str | None] = mapped_column(Unicode(50), nullable=True)
    bemaerkning: Mapped[str | None] = mapped_column(Unicode, nullable=True)
    ppr_sendt_dato: Mapped[date | None] = mapped_column(Date, nullable=True)
    afsluttet_dato: Mapped[date | None] = mapped_column(Date, nullable=True)

    # --- Bookkeeping, as on Skolebegynder ---
    # updated_at is maintained by trg_Skoleskifter_UpdatedAt.
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
