"""Lookup / reference tables.

Shaped like befordringssystemet's app/models/lookup.py: <x>_id, <x>_tekst,
beskrivelse, aktiv. DSA adds fagomraade_id where a value only applies to
some areas (NULL = every area) and sortering for display order. The rows are
defined by backend/db/seed/seed_lookup_data.sql.
"""

from sqlalchemy import Boolean, Float, ForeignKey, Integer, String, Unicode, text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


DB_SCHEMA = "dsa"


class Fagomraade(Base):
    """An area of case work — the cards on the front page."""

    __tablename__ = "Fagomraade"
    __table_args__ = {"schema": DB_SCHEMA}

    fagomraade_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    fagomraade_tekst: Mapped[str] = mapped_column(Unicode(255), nullable=False)
    beskrivelse: Mapped[str | None] = mapped_column(Unicode(1000), nullable=True)
    aktiv: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("1"))
    sortering: Mapped[int | None] = mapped_column(Integer, nullable=True)


class Status(Base):
    """Case status. fagomraade_id NULL means the status is shared by all areas.

    For skolebegyndere the status is derived by
    usp_recalculate_skolebegynder_status — only "Afsluttet" is set by a person.
    """

    __tablename__ = "Status"
    __table_args__ = {"schema": DB_SCHEMA}

    status_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    status_tekst: Mapped[str] = mapped_column(Unicode(255), nullable=False)
    beskrivelse: Mapped[str | None] = mapped_column(Unicode(1000), nullable=True)
    aktiv: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("1"))
    fagomraade_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Fagomraade.fagomraade_id"),
        nullable=True,
    )
    sortering: Mapped[int | None] = mapped_column(Integer, nullable=True)


class Skoletilbudstype(Base):
    """The kind of school decision ("Optaget på distriktsskolen", ...)."""

    __tablename__ = "Skoletilbudstype"
    __table_args__ = {"schema": DB_SCHEMA}

    skoletilbudstype_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    skoletilbudstype_tekst: Mapped[str] = mapped_column(Unicode(255), nullable=False)
    beskrivelse: Mapped[str | None] = mapped_column(Unicode(1000), nullable=True)
    aktiv: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("1"))
    fagomraade_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Fagomraade.fagomraade_id"),
        nullable=True,
    )
    sortering: Mapped[int | None] = mapped_column(Integer, nullable=True)


class Skoleplaceringsaarsag(Base):
    """Why a child was placed where it was. Values not defined yet."""

    __tablename__ = "Skoleplaceringsaarsag"
    __table_args__ = {"schema": DB_SCHEMA}

    skoleplaceringsaarsag_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    skoleplaceringsaarsag_tekst: Mapped[str] = mapped_column(Unicode(255), nullable=False)
    beskrivelse: Mapped[str | None] = mapped_column(Unicode(1000), nullable=True)
    aktiv: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("1"))
    sortering: Mapped[int | None] = mapped_column(Integer, nullable=True)


class Brevskabelon(Base):
    """Letter template a case is sent with. Values not defined yet."""

    __tablename__ = "Brevskabelon"
    __table_args__ = {"schema": DB_SCHEMA}

    brevskabelon_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    brevskabelon_tekst: Mapped[str] = mapped_column(Unicode(255), nullable=False)
    beskrivelse: Mapped[str | None] = mapped_column(Unicode(1000), nullable=True)
    aktiv: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("1"))
    fagomraade_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Fagomraade.fagomraade_id"),
        nullable=True,
    )
    sortering: Mapped[int | None] = mapped_column(Integer, nullable=True)


class Aendringsaarsag(Base):
    """What changed about a child after its case opened (the Ændringer tab)."""

    __tablename__ = "Aendringsaarsag"
    __table_args__ = {"schema": DB_SCHEMA}

    aendringsaarsag_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    aendringsaarsag_tekst: Mapped[str] = mapped_column(Unicode(255), nullable=False)
    beskrivelse: Mapped[str | None] = mapped_column(Unicode(1000), nullable=True)
    aktiv: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("1"))
    sortering: Mapped[int | None] = mapped_column(Integer, nullable=True)


class Skolematrikel(Base):
    """A school campus — verbatim from befordringssystemet.

    skolekode is shared by the campuses of one school; exactly one of them has
    er_matrikel_hovedadresse set. Most of DSA refers to schools by skolekode;
    only the school offer points at a campus.
    """

    __tablename__ = "Skolematrikel"
    __table_args__ = {"schema": DB_SCHEMA}

    matrikel_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    matrikel_navn: Mapped[str] = mapped_column(String, nullable=False)
    matrikel_adresse: Mapped[str] = mapped_column(String, nullable=False)
    skolekode: Mapped[int] = mapped_column(Integer, nullable=False)
    er_matrikel_hovedadresse: Mapped[bool] = mapped_column(Boolean, nullable=False)
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
