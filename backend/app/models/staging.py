"""Staging tables for the nightly imports.

These are landing zones, not application tables. Nothing in the backend reads
or writes them — they are filled by external jobs and drained by a stored
procedure:

    Elev_STG       <- the nightly student import (LIS)
    Foraelder_STG  <- the nightly guardian import

DSA: befordringssystemet's Adresse_STG and Elev_Adresse_STG have no DSA
counterpart yet. The merge procedures do not exist yet either; when they do,
Elev_STG feeds Elev and the current period of the Elev_* history tables
(models/elev_historik.py), not Elev alone.

They are declared here so the schema is visible in the codebase, and so the
column names those external jobs depend on cannot be changed without this file
turning up in the diff. See backend/db/migrations/006_elev_historik.sql
for the DDL these mirror.

Core Table objects rather than ORM classes, deliberately: neither has a
primary key at all, and the ORM cannot map a keyless table without
inventing one. A fake key would be worse than no mapping — it would read as a
real constraint. Core Tables describe them honestly and are still usable via
select()/insert() should a future job need them.

Staging columns are almost all nullable because they hold whatever the source
produced; validation happens during the merge, not on the way in.
"""

from sqlalchemy import (
    Boolean,
    Column,
    Integer,
    String,
    Table,
    Unicode,
)
from sqlalchemy.dialects.mssql import DATETIME2

from app.core.database import Base


DB_SCHEMA = "dsa"


# Nightly student import. Mirrors Elev, plus what the merge spreads into
# Elev_Skolehistorik: the district, as distriktsskolekode and as the
# district's name (skoledistrikt).
elev_stg = Table(
    "Elev_STG",
    Base.metadata,
    Column("cpr", String(10), nullable=True),
    Column("adresseringsnavn", Unicode(200), nullable=True),
    Column("navne_adresse_beskyttelse", Boolean, nullable=True),
    Column("adresse_id", Unicode(36), nullable=True),
    Column("koen", Unicode(20), nullable=True),
    Column("distriktsskolekode", Integer, nullable=True),
    Column("opdateret_tidspunkt", DATETIME2, nullable=True),
    Column("skoledistrikt", Unicode(100), nullable=True),
    schema=DB_SCHEMA,
)


# Nightly guardian import. Mirrors Foraelder.
foraelder_stg = Table(
    "Foraelder_STG",
    Base.metadata,
    Column("cpr_foraelder", String(10), nullable=True),
    Column("cpr_elev", String(10), nullable=True),
    Column("adresseringsnavn", Unicode(200), nullable=True),
    Column("navne_adresse_beskyttelse", Boolean, nullable=True),
    Column("maa_vide_barns_adresse", Boolean, nullable=True),
    Column("adresse_id", Unicode(36), nullable=True),
    Column("relation", Unicode(50), nullable=True),
    schema=DB_SCHEMA,
)
