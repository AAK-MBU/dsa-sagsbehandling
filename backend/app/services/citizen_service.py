"""Service layer for citizen (Elev) data — the "Elevmappe".

The citizen's master data and every case DSA holds on them, across areas.
Only skolebegynder cases exist so far; each new area adds its own list here.

Citizen data is maintained by external systems (LIS / TEA) and is read-only
in this application, as in befordringssystemet.
"""

from sqlalchemy import select, text
from sqlalchemy.orm import Session, joinedload

from app.models.citizen import Elev, Foraelder
from app.services.skolebegynder_service import SkolebegynderService


class CitizenService:
    """Service class for citizen-related database reads.

    Args:
        db:
            SQLAlchemy database session.
    """

    def __init__(self, db: Session):
        """Initialize the service with a database session."""

        self.db = db


    def _skolenavn(self, skolekode: int | None) -> str | None:
        """A school's name by skolekode, through view_Skoler."""

        if skolekode is None:
            return None

        return self.db.execute(
            text("SELECT skolenavn FROM [dsa].[view_Skoler] WHERE skolekode = :skolekode"),
            {"skolekode": skolekode},
        ).scalar_one_or_none()


    def get_stamdata(self, cpr: str) -> dict | None:
        """Master data for a child: themselves, custody holders and cases.

        Args:
            cpr:
                CPR number of the child.

        Returns:
            None if DSA holds no child with this CPR, otherwise:

                {
                    "elev": {...},
                    "foraeldre": [{...}, ...],
                    "skolebegynder_sager": [{...}, ...],
                }

        Notes:
            navne_adresse_beskyttelse and maa_vide_barns_adresse are returned
            as they are. What a protected child's or parent's data may show is
            for the screen to decide, and it must decide before it renders.
        """

        elev = self.db.execute(
            select(Elev).options(joinedload(Elev.adresse)).where(Elev.cpr == cpr)
        ).scalar_one_or_none()

        if elev is None:
            return None

        foraeldre = self.db.execute(
            select(Foraelder)
            .options(joinedload(Foraelder.adresse))
            .where(Foraelder.cpr_elev == cpr)
            .order_by(Foraelder.adresseringsnavn)
        ).scalars().all()

        return {
            "elev": {
                "cpr": elev.cpr,
                "navn": elev.adresseringsnavn,
                "navne_adresse_beskyttelse": elev.navne_adresse_beskyttelse,
                "adresse_tekst": elev.adresse.adresse_tekst if elev.adresse else None,
                "koen": elev.koen,
                "modersmaal": elev.modersmaal,
                "distriktsskolekode": elev.distriktsskolekode,
                "distriktsskole": self._skolenavn(elev.distriktsskolekode),
                "skolekode": elev.skolekode,
                "skole": self._skolenavn(elev.skolekode),
                "elevklassetrin": elev.elevklassetrin,
                "klassebetegnelse": elev.klassebetegnelse,
                "sprogstoettebehov": elev.sprogstoettebehov,
                "ppr_status": elev.ppr_status,
                "tilflyttet_dk_dato": elev.tilflyttet_dk_dato,
            },
            "foraeldre": [
                {
                    "cpr": f.cpr_foraelder,
                    "navn": f.adresseringsnavn,
                    "relation": f.relation,
                    "navne_adresse_beskyttelse": f.navne_adresse_beskyttelse,
                    "maa_vide_barns_adresse": f.maa_vide_barns_adresse,
                    "adresse_tekst": f.adresse.adresse_tekst if f.adresse else None,
                }
                for f in foraeldre
            ],
            "skolebegynder_sager": SkolebegynderService(db=self.db).get_for_cpr(cpr),
        }
