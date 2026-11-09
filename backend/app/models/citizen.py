from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, ForeignKey, Integer, String, Unicode, text
from sqlalchemy.dialects.mssql import DATETIME2
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.adresse import Adresse  # noqa: F401 — re-exported; also ensures Adresse is
                                         # registered with Base.metadata before FK resolution.


DB_SCHEMA = "dsa"


class Elev(Base):
    """The child as a person — CPR, name, protection, address, koen.

    Same role as befordringssystemet's Elev, keyed on CPR. DSA (migration
    006): everything that changes over time lives in the Elev_* tables
    (models/elev_historik.py), one row per period. view_Elev_Aktuel puts each table's current
    period back beside the person under Elev's old column names; read the
    child through that (or view_Stamdata), not through this model.
    """

    __tablename__ = "Elev"
    __table_args__ = {"schema": DB_SCHEMA}

    cpr: Mapped[str] = mapped_column(String(10), primary_key=True)

    adresseringsnavn: Mapped[str | None] = mapped_column(Unicode(200), nullable=True)
    navne_adresse_beskyttelse: Mapped[bool | None] = mapped_column(Boolean, nullable=True)

    adresse_id: Mapped[str | None] = mapped_column(
        Unicode(36),
        ForeignKey(f"{DB_SCHEMA}.Adresse.adresse_id"),
        nullable=True,
    )

    koen: Mapped[str | None] = mapped_column(Unicode(20), nullable=True)

    adresse = relationship("Adresse")


class Foraelder(Base):
    """A custody holder (R1 / R2). Same shape as befordringssystemet's."""

    __tablename__ = "Foraelder"
    __table_args__ = {"schema": DB_SCHEMA}

    # Composite primary key (cpr_foraelder, cpr_elev) — a guardian can appear
    # once per child.
    cpr_foraelder: Mapped[str] = mapped_column(String(10), primary_key=True)

    cpr_elev: Mapped[str] = mapped_column(
        String(10),
        ForeignKey(f"{DB_SCHEMA}.Elev.cpr"),
        primary_key=True,
    )

    adresseringsnavn: Mapped[str | None] = mapped_column(Unicode(200), nullable=True)
    navne_adresse_beskyttelse: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    maa_vide_barns_adresse: Mapped[bool | None] = mapped_column(
        Boolean,
        nullable=True,
        server_default=text("1"),
    )

    adresse_id: Mapped[str | None] = mapped_column(
        Unicode(36),
        ForeignKey(f"{DB_SCHEMA}.Adresse.adresse_id"),
        nullable=True,
    )

    relation: Mapped[str | None] = mapped_column(
        Unicode(50),
        nullable=True,
        server_default=text("'Ukendt'"),
    )

    elev = relationship("Elev")
    adresse = relationship("Adresse")


class SagsaktivitetType(Base):
    """Lookup table for canonical Sagsaktivitet type codes.

    type_kode is the machine-readable key used for styling and logic;
    aktivitetstype on Sagsaktivitet is the human-readable display string.
    """

    __tablename__ = "SagsaktivitetType"
    __table_args__ = {"schema": DB_SCHEMA}

    type_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    type_kode: Mapped[str] = mapped_column(Unicode(100), nullable=False, unique=True)

    aktiviteter: Mapped[list["Sagsaktivitet"]] = relationship(back_populates="type")


class Sagsaktivitet(Base):
    """Log of case-level events for a citizen.

    Intentionally has no FK constraints to Elev or to any case table, so rows
    survive case deletes and can reference CPRs not yet in Elev.

    DSA: a case is identified by (fagomraade_id, relateret_sag_id) — the
    generalisation of befordringssystemet's relateret_bevilling_id, since DSA
    has a case table per area.
    """

    __tablename__ = "Sagsaktivitet"
    __table_args__ = {"schema": DB_SCHEMA}

    aktivitet_id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
    )

    cpr: Mapped[str] = mapped_column(String(10), nullable=False)
    aktivitetstype: Mapped[str] = mapped_column(Unicode(50), nullable=False)
    kommentar: Mapped[str | None] = mapped_column(Unicode, nullable=True)
    udfoert_af: Mapped[str | None] = mapped_column(Unicode(100), nullable=True)

    oprettet_tidspunkt: Mapped[datetime] = mapped_column(
        DATETIME2,
        nullable=False,
        server_default=text("sysdatetime()"),
    )

    fagomraade_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.Fagomraade.fagomraade_id"),
        nullable=True,
    )

    # Soft reference — no FK constraint in the DB.
    relateret_sag_id: Mapped[int | None] = mapped_column(Integer, nullable=True)

    aktivitetstype_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(f"{DB_SCHEMA}.SagsaktivitetType.type_id"),
        nullable=True,
    )
    type: Mapped["SagsaktivitetType | None"] = relationship(back_populates="aktiviteter")

    @property
    def type_kode(self) -> str | None:
        return self.type.type_kode if self.type else None
