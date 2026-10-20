from sqlalchemy import Float, Unicode
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


DB_SCHEMA = "dsa"


class Adresse(Base):
    """Municipality address record.

    The primary key is the address GUID (AdresseId / DAR id) from LOIS — it
    is NOT a server-generated identity. FK references from Elev and
    Foraelder point here.

    DSA: ported verbatim from befordringssystemet. How rows arrive (a nightly
    load, as there) is not decided yet; for now they come from test data.
    """

    __tablename__ = "Adresse"
    __table_args__ = {"schema": DB_SCHEMA}

    adresse_id: Mapped[str] = mapped_column(
        Unicode(36),
        primary_key=True,
    )

    adresse_tekst: Mapped[str | None] = mapped_column(Unicode(500), nullable=True)
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
