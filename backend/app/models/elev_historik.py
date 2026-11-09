"""A child's history — one table per subject, one row per period.

DSA (migration 006): what changes about a child over time moved out of Elev
into these tables, keyed on cpr plus a period. Elev (models/citizen.py) keeps
only the person.

    Elev_Skolehistorik      school, klassetrin, klasse, district
    Elev_Modersmaal         mother tongue
    Elev_Sprogstoettebehov  periods with sprogstøttebehov
    Elev_PPR                periods known by PPR
    Elev_Indrejse           first and latest arrival in Denmark (some children)

Not lookup tables: each row is a fact about one child, not a shared value
that cases point at.

Filled from LIS only; the backend does not write them. The open-ended period
is the current one — gyldig_til NULL in Elev_Skolehistorik, 9999-12-31
(AABEN) in the others — and view_Elev_Aktuel puts those back beside the
person under Elev's old column names, which is how the services read them.
"""

from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import Date, ForeignKey, Integer, String, Unicode, text
from sqlalchemy.dialects.mssql import DATETIME2
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


DB_SCHEMA = "dsa"


AABEN = date(9999, 12, 31)


class ElevSkolehistorik(Base):
    """A child's school, klassetrin, klasse and district over time.

    Was SkoleHistorik; renamed in migration 006, which moved
    distriktsskolekode here from Elev and sprogstoettebehov out to
    Elev_Sprogstoettebehov. gyldig_til NULL marks the current period; the
    database allows one per child (UX_Elev_Skolehistorik_aaben). skolekode
    and distriktsskolekode are skolekoder without an FK — resolve them
    through view_Skoler.
    """

    __tablename__ = "Elev_Skolehistorik"
    __table_args__ = {"schema": DB_SCHEMA}

    skolehistorik_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    cpr: Mapped[str] = mapped_column(
        String(10),
        ForeignKey(f"{DB_SCHEMA}.Elev.cpr"),
        nullable=False,
    )

    skolekode: Mapped[int | None] = mapped_column(Integer, nullable=True)
    elevklassetrin: Mapped[str | None] = mapped_column(Unicode(20), nullable=True)
    klassebetegnelse: Mapped[str | None] = mapped_column(Unicode(50), nullable=True)
    gyldig_fra: Mapped[date] = mapped_column(Date, nullable=False)
    gyldig_til: Mapped[date | None] = mapped_column(Date, nullable=True)
    # Where the row came from: 'LIS', 'TEA', 'Manuel', ...
    kilde: Mapped[str | None] = mapped_column(Unicode(50), nullable=True)

    oprettet_tidspunkt: Mapped[datetime] = mapped_column(
        DATETIME2,
        nullable=False,
        server_default=text("sysdatetime()"),
    )

    distriktsskolekode: Mapped[int | None] = mapped_column(Integer, nullable=True)


class ElevModersmaal(Base):
    """A child's mother tongue over time; gyldig_til 9999-12-31 = current."""

    __tablename__ = "Elev_Modersmaal"
    __table_args__ = {"schema": DB_SCHEMA}

    cpr: Mapped[str] = mapped_column(
        String(10),
        ForeignKey(f"{DB_SCHEMA}.Elev.cpr"),
        primary_key=True,
    )
    gyldig_fra: Mapped[date] = mapped_column(Date, primary_key=True)

    modersmaal: Mapped[str | None] = mapped_column(Unicode(50), nullable=True)
    gyldig_til: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        server_default=text("'99991231'"),
    )


class ElevSprogstoettebehov(Base):
    """Periods with sprogstøttebehov; slutdato 9999-12-31 = current."""

    __tablename__ = "Elev_Sprogstoettebehov"
    __table_args__ = {"schema": DB_SCHEMA}

    cpr: Mapped[str] = mapped_column(
        String(10),
        ForeignKey(f"{DB_SCHEMA}.Elev.cpr"),
        primary_key=True,
    )
    startdato: Mapped[date] = mapped_column(Date, primary_key=True)
    slutdato: Mapped[date] = mapped_column(Date, nullable=False)


class ElevPPR(Base):
    """Periods the child is known by PPR; slutdato 9999-12-31 = current."""

    __tablename__ = "Elev_PPR"
    __table_args__ = {"schema": DB_SCHEMA}

    cpr: Mapped[str] = mapped_column(
        String(10),
        ForeignKey(f"{DB_SCHEMA}.Elev.cpr"),
        primary_key=True,
    )
    startdato: Mapped[date] = mapped_column(Date, primary_key=True)
    slutdato: Mapped[date] = mapped_column(Date, nullable=False)


class ElevIndrejse(Base):
    """When a child came to Denmark: first and latest entry. Only some
    children have a row."""

    __tablename__ = "Elev_Indrejse"
    __table_args__ = {"schema": DB_SCHEMA}

    cpr: Mapped[str] = mapped_column(
        String(10),
        ForeignKey(f"{DB_SCHEMA}.Elev.cpr"),
        primary_key=True,
    )
    foerste_indrejse: Mapped[date] = mapped_column(Date, nullable=False)
    seneste_indrejse: Mapped[date] = mapped_column(Date, nullable=False)
