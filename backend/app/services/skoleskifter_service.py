"""Service layer for skoleskifter cases (Skoleskiftere og tilflyttere, draft).

The same split as SkolebegynderService: reads through view_Skoleskiftere,
writes through the ORM, status through usp_recalculate_skoleskifter_status.

Unlike skolebegyndere, part of the status is a caseworker's choice: Ny,
Afventer sprogvurdering and Sendt til PPR are set by hand (manuel_status on
an update), and Afsluttet can also be set by hand (afslut). The procedure
derives the rest and closes a case the day after its offer date.

A screening result of "Alderssvarende dansk" closes the case here, on the
save: the child has age-appropriate Danish and is not DSA's (PUF,
2026-10-28). Not in the procedure, so a caseworker can reopen such a case
without the next run closing it again.
"""

from datetime import date

from fastapi import HTTPException
from sqlalchemy import Date, cast, func, select, text
from sqlalchemy.orm import Session

from app.models.citizen import Sagsaktivitet, SagsaktivitetType
from app.models.lookup import Fagomraade, Skolematrikel, Skoletilbudstype, Status
from app.models.skoleskifter import Skoleskifter


FAGOMRAADE_TEKST = "Skoleskiftere og tilflyttere"

STATUS_AFSLUTTET = "Afsluttet"
STATUS_PPR = "Sendt til PPR"
# The screening result that closes a case on save.
ALDERSSVARENDE = "Alderssvarende dansk"
# Placeholder when a case is reopened; the procedure replaces it at once.
STATUS_NY = "Ny"

_REFERENCER = {
    "skoletilbud_matrikel_id": (Skolematrikel, Skolematrikel.matrikel_id, "skoletilbud"),
    "skoletilbudstype_id": (Skoletilbudstype, Skoletilbudstype.skoletilbudstype_id, "skoletilbudstype"),
}

_SKOLETILBUD_FELTER = ("skoletilbud_matrikel_id", "skoletilbudstype_id", "dato_skoletilbud")


class SkoleskifterService:
    """Service class for skoleskifter cases.

    Write methods own their transaction. Sagsaktivitet events are written
    after the commit and are best-effort, as in SkolebegynderService.
    """

    def __init__(self, db: Session):
        self.db = db
        self._cache: dict[tuple[str, str], int | None] = {}


    # -------------------------
    # Small lookups
    # -------------------------

    def _fagomraade_id(self) -> int:
        key = ("fagomraade", FAGOMRAADE_TEKST)

        if key not in self._cache:
            self._cache[key] = self.db.execute(
                select(Fagomraade.fagomraade_id).where(Fagomraade.fagomraade_tekst == FAGOMRAADE_TEKST)
            ).scalar_one_or_none()

        if self._cache[key] is None:
            raise HTTPException(
                status_code=500,
                detail=f"Fagområdet '{FAGOMRAADE_TEKST}' findes ikke. Kør seed_lookup_data.sql.",
            )

        return self._cache[key]


    def _status_id(self, status_tekst: str) -> int:
        key = ("status", status_tekst)

        if key not in self._cache:
            self._cache[key] = self.db.execute(
                select(Status.status_id).where(
                    Status.status_tekst == status_tekst,
                    Status.fagomraade_id == self._fagomraade_id(),
                )
            ).scalar_one_or_none()

        if self._cache[key] is None:
            raise HTTPException(
                status_code=500,
                detail=f"Status '{status_tekst}' findes ikke for skoleskiftere. Kør migration 004.",
            )

        return self._cache[key]


    def _aktivitetstype_id(self, type_kode: str) -> int | None:
        key = ("aktivitetstype", type_kode)

        if key not in self._cache:
            self._cache[key] = self.db.execute(
                select(SagsaktivitetType.type_id).where(SagsaktivitetType.type_kode == type_kode)
            ).scalar_one_or_none()

        return self._cache[key]


    def _log_event(
        self,
        case: Skoleskifter,
        type_kode: str,
        aktivitetstype: str,
        kommentar: str | None = None,
        udfoert_af: str = "System",
    ) -> None:
        """Log a case event — best-effort."""

        try:
            self.db.add(Sagsaktivitet(
                cpr=case.cpr,
                aktivitetstype=aktivitetstype[:50],
                aktivitetstype_id=self._aktivitetstype_id(type_kode),
                kommentar=kommentar,
                udfoert_af=udfoert_af[:100] if udfoert_af else udfoert_af,
                fagomraade_id=self._fagomraade_id(),
                relateret_sag_id=case.skoleskifter_id,
            ))
            self.db.commit()
        except Exception:
            self.db.rollback()


    def _rows_to_dicts(self, result):
        return [dict(row) for row in result.mappings().all()]


    # -------------------------
    # Status procedure
    # -------------------------

    def _execute_recalculate_status_procedure(
        self,
        skoleskifter_id: int | None = None,
        today: date | None = None,
        dry_run: bool = False,
    ) -> list[dict]:
        """Run usp_recalculate_skoleskifter_status; returns its result set."""

        result = self.db.execute(
            text("""
                EXEC [dsa].[usp_recalculate_skoleskifter_status]
                    @skoleskifter_id = :skoleskifter_id,
                    @today = :today,
                    @dry_run = :dry_run
            """),
            {"skoleskifter_id": skoleskifter_id, "today": today, "dry_run": int(dry_run)},
        )

        return self._rows_to_dicts(result)


    def recalculate_status(self) -> list[dict]:
        """Recalculate every active case — after a data load, and nightly
        (the automatic close depends on the date)."""

        try:
            rows = self._execute_recalculate_status_procedure()
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

        return rows


    # -------------------------
    # Reads
    # -------------------------

    def get_overview(self) -> list[dict]:
        """All active cases, oldest application first — the longest wait at
        the top. The tabs (Skoleskiftere / Tilflyttere / Hos PPR / Afsluttede) are filters on this one list in the frontend."""

        result = self.db.execute(text("""
            SELECT
                *
            FROM
                [dsa].[view_Skoleskiftere]
            ORDER BY
                modtaget_tidspunkt,
                navn
        """))

        return self._rows_to_dicts(result)


    def get_skoleskifter(self, skoleskifter_id: int) -> dict:
        """One case: the view's row plus the table's own columns."""

        case = self.db.get(Skoleskifter, skoleskifter_id)

        if case is None or not case.aktiv:
            raise HTTPException(status_code=404, detail=f"Skoleskiftersag ikke fundet: {skoleskifter_id}")

        rows = self._rows_to_dicts(self.db.execute(
            text("SELECT * FROM [dsa].[view_Skoleskiftere] WHERE skoleskifter_id = :id"),
            {"id": skoleskifter_id},
        ))

        detail = {column.key: getattr(case, column.key) for column in Skoleskifter.__table__.columns}
        if rows:
            detail.update(rows[0])

        return detail


    def get_for_cpr(self, cpr: str) -> list[dict]:
        """A child's skoleskifter cases, newest application first."""

        result = self.db.execute(
            text("""
                SELECT
                    *
                FROM
                    [dsa].[view_Skoleskiftere]
                WHERE
                    cpr = :cpr
                ORDER BY
                    modtaget_tidspunkt DESC
            """),
            {"cpr": cpr},
        )

        return self._rows_to_dicts(result)


    # -------------------------
    # Writes
    # -------------------------

    def _get_open_case(self, skoleskifter_id: int) -> Skoleskifter:
        case = self.db.get(Skoleskifter, skoleskifter_id)

        if case is None or not case.aktiv:
            raise HTTPException(status_code=404, detail=f"Skoleskiftersag ikke fundet: {skoleskifter_id}")

        if case.status_id == self._status_id(STATUS_AFSLUTTET):
            raise HTTPException(status_code=409, detail="Sagen er afsluttet. Genåbn den, før den kan ændres.")

        return case


    def _validate_references(self, data: dict) -> None:
        for field, (model, id_column, label) in _REFERENCER.items():
            value = data.get(field)

            if value is None:
                continue

            statement = select(id_column).where(id_column == value)

            if hasattr(model, "aktiv"):
                statement = statement.where(model.aktiv == True)  # noqa: E712

            if self.db.execute(statement).scalar_one_or_none() is None:
                raise HTTPException(status_code=400, detail=f"Ugyldig {label}: {value}")


    def _status_text(self, status_id: int) -> str | None:
        return self.db.execute(
            select(Status.status_tekst).where(Status.status_id == status_id)
        ).scalar_one_or_none()


    def update_skoleskifter(self, skoleskifter_id: int, data: dict, udfoert_af: str = "System") -> dict:
        """Change a case's editable fields and/or its manual status, then
        recalculate — or close the case, when the screening result is newly
        "Alderssvarende dansk".

        Raises:
            HTTPException: 400 nothing to change / bad lookup id; 404 no such
            case; 409 the case is closed.
        """

        if not data:
            raise HTTPException(status_code=400, detail="Ingen felter at opdatere")

        if "variant" in data and data["variant"] is None:
            raise HTTPException(status_code=400, detail="Sagen skal have en type")

        case = self._get_open_case(skoleskifter_id)
        self._validate_references(data)

        manuel_status = data.pop("manuel_status", None)
        old_status = case.status_id
        lukkes = data.get("samlet_resultat") == ALDERSSVARENDE and case.samlet_resultat != ALDERSSVARENDE
        old_skoletilbud = tuple(getattr(case, f) for f in _SKOLETILBUD_FELTER)

        try:
            for key, value in data.items():
                setattr(case, key, value)

            if manuel_status:
                case.status_id = self._status_id(manuel_status)
                # When the case went to PPR — for "tid hos PPR".
                if manuel_status == STATUS_PPR and case.ppr_sendt_dato is None:
                    case.ppr_sendt_dato = self.db.execute(select(cast(func.sysdatetime(), Date))).scalar_one()

            case.updated_by = udfoert_af[:100]
            self.db.flush()

            if lukkes:
                # SQL Server's date, not Python's: the container clock is UTC.
                today = self.db.execute(select(cast(func.sysdatetime(), Date))).scalar_one()
                case.status_id = self._status_id(STATUS_AFSLUTTET)
                case.status_dato = today
                case.afsluttet_dato = today
            else:
                self._execute_recalculate_status_procedure(skoleskifter_id=skoleskifter_id)

            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

        self.db.refresh(case)

        if tuple(getattr(case, f) for f in _SKOLETILBUD_FELTER) != old_skoletilbud:
            matrikel = self.db.get(Skolematrikel, case.skoletilbud_matrikel_id) if case.skoletilbud_matrikel_id else None
            tilbudstype = self.db.get(Skoletilbudstype, case.skoletilbudstype_id) if case.skoletilbudstype_id else None
            self._log_event(
                case,
                type_kode="skoletilbud_opdateret",
                aktivitetstype="Skoletilbud opdateret",
                kommentar=(
                    f"Skoletilbud: {matrikel.matrikel_navn if matrikel else '—'} "
                    f"({tilbudstype.skoletilbudstype_tekst if tilbudstype else '—'})"
                ),
                udfoert_af=udfoert_af,
            )

        if lukkes:
            self._log_event(
                case,
                type_kode="sag_afsluttet",
                aktivitetstype="Sag afsluttet",
                kommentar="Alderssvarende dansk — ikke relevant for DSA",
                udfoert_af=udfoert_af,
            )
        elif case.status_id != old_status:
            self._log_event(
                case,
                type_kode="status_opdateret",
                aktivitetstype=f"Status sat til {self._status_text(case.status_id)}",
                udfoert_af=udfoert_af,
            )

        return self.get_skoleskifter(skoleskifter_id)


    def afslut(self, skoleskifter_id: int, udfoert_af: str = "System") -> dict:
        """Close a case by hand — e.g. an application withdrawn. The normal
        close is automatic, the day after the offer date."""

        case = self._get_open_case(skoleskifter_id)

        try:
            # SQL Server's date, not Python's: the container clock is UTC.
            today = self.db.execute(select(cast(func.sysdatetime(), Date))).scalar_one()
            case.status_id = self._status_id(STATUS_AFSLUTTET)
            case.status_dato = today
            case.afsluttet_dato = today
            case.updated_by = udfoert_af[:100]
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

        self._log_event(case, type_kode="sag_afsluttet", aktivitetstype="Sag afsluttet", udfoert_af=udfoert_af)

        return self.get_skoleskifter(skoleskifter_id)


    def genaabn(self, skoleskifter_id: int, udfoert_af: str = "System") -> dict:
        """Reopen a closed case; its status is derived again from its data.

        Note: a case with a passed offer date closes again on the next run,
        unless the offer or its date is changed first.
        """

        case = self.db.get(Skoleskifter, skoleskifter_id)

        if case is None or not case.aktiv:
            raise HTTPException(status_code=404, detail=f"Skoleskiftersag ikke fundet: {skoleskifter_id}")

        if case.status_id != self._status_id(STATUS_AFSLUTTET):
            raise HTTPException(status_code=409, detail="Sagen er ikke afsluttet.")

        try:
            case.status_id = self._status_id(STATUS_NY)
            case.afsluttet_dato = None
            case.updated_by = udfoert_af[:100]
            self.db.flush()
            self._execute_recalculate_status_procedure(skoleskifter_id=skoleskifter_id)
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

        self.db.refresh(case)
        self._log_event(
            case,
            type_kode="sag_genaabnet",
            aktivitetstype="Sag genåbnet",
            kommentar=f"Status: {self._status_text(case.status_id)}",
            udfoert_af=udfoert_af,
        )

        return self.get_skoleskifter(skoleskifter_id)
