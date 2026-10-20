"""Service layer for skolebegynder cases.

Reads go through the views (view_Skolebegyndere, view_Skolebegynder_
Aendringer), writes through the ORM, and status through the stored procedure
usp_recalculate_skolebegynder_status — the same split as
befordringssystemet's BevillingService.

The status rule (agreed 2026-10-20): every status except "Afsluttet" is
derived from the case's data by the procedure. So a write sets the data and
then recalculates; it never sets a status directly. "Afsluttet" is the one
status a person sets, through afslut / genaabn.
"""

from datetime import date

from fastapi import HTTPException
from sqlalchemy import Date, cast, func, select, text
from sqlalchemy.orm import Session

from app.models.citizen import Sagsaktivitet, SagsaktivitetType
from app.models.lookup import (
    Brevskabelon,
    Fagomraade,
    Skolematrikel,
    Skoleplaceringsaarsag,
    Skoletilbudstype,
    Status,
)
from app.models.skolebegynder import Skolebegynder, SkolebegynderAendring


FAGOMRAADE_TEKST = "Skolebegynderscreeninger"

STATUS_AFSLUTTET = "Afsluttet"
STATUS_SKOLETILBUD = "Skoletilbud"
# Placeholder written when a case is reopened, immediately replaced by the
# procedure's derived status in the same transaction.
STATUS_IKKE_SCREENET = "Ikke screenet"

# Fields on SkolebegynderUpdateRequest that reference a lookup table, with the
# model, its id column and whether it has an aktiv flag to honour.
_REFERENCER = {
    "skoletilbud_matrikel_id": (Skolematrikel, Skolematrikel.matrikel_id, "skoletilbud"),
    "skoletilbudstype_id": (Skoletilbudstype, Skoletilbudstype.skoletilbudstype_id, "skoletilbudstype"),
    "skoleplaceringsaarsag_id": (Skoleplaceringsaarsag, Skoleplaceringsaarsag.skoleplaceringsaarsag_id, "skoleplaceringsårsag"),
    "brevskabelon_id": (Brevskabelon, Brevskabelon.brevskabelon_id, "brevskabelon"),
}

# The fields that together make up "the school offer" — a change to any of
# them is logged as one skoletilbud_opdateret event.
_SKOLETILBUD_FELTER = ("skoletilbud_matrikel_id", "skoletilbudstype_id")


class SkolebegynderService:
    """Service class for skolebegynder cases.

    Args:
        db:
            SQLAlchemy database session.

    Notes:
        Write methods own their transaction and commit. Sagsaktivitet events
        are written after the commit and are best-effort, as in
        befordringssystemet: a failed log write never undoes the change it
        describes.
    """

    def __init__(self, db: Session):
        """Initialize the service with a database session."""

        self.db = db
        self._cache: dict[tuple[str, str], int | None] = {}


    # -------------------------
    # Small lookups
    # -------------------------

    def _fagomraade_id(self) -> int:
        """The id of the Skolebegynderscreeninger area."""

        key = ("fagomraade", FAGOMRAADE_TEKST)

        if key not in self._cache:
            self._cache[key] = self.db.execute(
                select(Fagomraade.fagomraade_id).where(
                    Fagomraade.fagomraade_tekst == FAGOMRAADE_TEKST
                )
            ).scalar_one_or_none()

        fagomraade_id = self._cache[key]

        if fagomraade_id is None:
            raise HTTPException(
                status_code=500,
                detail=f"Fagområdet '{FAGOMRAADE_TEKST}' findes ikke. Kør seed_lookup_data.sql.",
            )

        return fagomraade_id


    def _status_id(self, status_tekst: str) -> int:
        """A skolebegynder status id by its label."""

        key = ("status", status_tekst)

        if key not in self._cache:
            self._cache[key] = self.db.execute(
                select(Status.status_id).where(
                    Status.status_tekst == status_tekst,
                    Status.fagomraade_id == self._fagomraade_id(),
                )
            ).scalar_one_or_none()

        status_id = self._cache[key]

        if status_id is None:
            raise HTTPException(
                status_code=500,
                detail=f"Status '{status_tekst}' findes ikke for skolebegyndere. Kør seed_lookup_data.sql.",
            )

        return status_id


    def _aktivitetstype_id(self, type_kode: str) -> int | None:
        """Look up the SagsaktivitetType.type_id for a given type_kode."""

        key = ("aktivitetstype", type_kode)

        if key not in self._cache:
            self._cache[key] = self.db.execute(
                select(SagsaktivitetType.type_id).where(
                    SagsaktivitetType.type_kode == type_kode
                )
            ).scalar_one_or_none()

        return self._cache[key]


    def _log_event(
        self,
        cpr: str,
        skolebegynder_id: int,
        type_kode: str,
        aktivitetstype: str,
        kommentar: str | None = None,
        udfoert_af: str = "System",
    ) -> None:
        """Log a case event to Sagsaktivitet.

        Audit logging is best-effort: failures are swallowed so they never
        break the primary write operation.
        """

        try:
            self.db.add(Sagsaktivitet(
                cpr=cpr,
                aktivitetstype=aktivitetstype[:50],
                aktivitetstype_id=self._aktivitetstype_id(type_kode),
                kommentar=kommentar,
                udfoert_af=udfoert_af[:100] if udfoert_af else udfoert_af,
                fagomraade_id=self._fagomraade_id(),
                relateret_sag_id=skolebegynder_id,
            ))
            self.db.commit()
        except Exception:
            self.db.rollback()


    def _rows_to_dicts(self, result):
        """Convert SQLAlchemy result rows into normal dictionaries."""

        return [dict(row) for row in result.mappings().all()]


    # -------------------------
    # Status procedure
    # -------------------------

    def _execute_recalculate_status_procedure(
        self,
        skolebegynder_id: int | None = None,
        today: date | None = None,
        dry_run: bool = False,
    ) -> list[dict]:
        """Run usp_recalculate_skolebegynder_status.

        Args:
            skolebegynder_id:
                One case, or None for every active case.

            today:
                Optional test date; None lets SQL Server use today.

            dry_run:
                If True, only report what would change.

        Returns:
            The procedure's result set: one row per case considered, with
            current/calculated status and status_will_change. Closed
            (Afsluttet) and inactive cases are not considered.
        """

        result = self.db.execute(
            text("""
                EXEC [dsa].[usp_recalculate_skolebegynder_status]
                    @skolebegynder_id = :skolebegynder_id,
                    @today = :today,
                    @dry_run = :dry_run
            """),
            {
                "skolebegynder_id": skolebegynder_id,
                "today": today,
                "dry_run": int(dry_run),
            },
        )

        return self._rows_to_dicts(result)


    def recalculate_status(self) -> list[dict]:
        """Recalculate every active case's status and commit.

        For use after a data load. Returns the procedure's result set.
        """

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

    def get_overview(self, skoleaar: int | None = None) -> list[dict]:
        """All active cases, as the overview grid shows them.

        Args:
            skoleaar:
                Only this school year; None for every year.

        Returns:
            view_Skolebegyndere rows, newest screening first and unscreened
            children last — the sketch asks for "nyeste screeningsresultater
            øverst".
        """

        result = self.db.execute(
            text("""
                SELECT
                    *
                FROM
                    [dsa].[view_Skolebegyndere]
                WHERE
                    (:skoleaar IS NULL OR skoleaar = :skoleaar)
                ORDER BY
                    skoleaar DESC,
                    screeningsdato DESC,
                    navn
            """),
            {"skoleaar": skoleaar},
        )

        return self._rows_to_dicts(result)


    def get_aendringer(self, skoleaar: int | None = None) -> list[dict]:
        """Unhandled changes on active cases — the Ændringer tab, newest first."""

        result = self.db.execute(
            text("""
                SELECT
                    *
                FROM
                    [dsa].[view_Skolebegynder_Aendringer]
                WHERE
                    (:skoleaar IS NULL OR skoleaar = :skoleaar)
                ORDER BY
                    registreret_tidspunkt DESC
            """),
            {"skoleaar": skoleaar},
        )

        return self._rows_to_dicts(result)


    def get_skolebegynder(self, skolebegynder_id: int) -> dict:
        """One case: its overview row plus the fields the grid leaves out.

        Raises:
            HTTPException: 404 if no active case has this id.
        """

        rows = self._rows_to_dicts(self.db.execute(
            text("""
                SELECT
                    *
                FROM
                    [dsa].[view_Skolebegyndere]
                WHERE
                    skolebegynder_id = :skolebegynder_id
            """),
            {"skolebegynder_id": skolebegynder_id},
        ))

        if not rows:
            raise HTTPException(
                status_code=404,
                detail=f"Skolebegynder ikke fundet: {skolebegynder_id}",
            )

        case = self.db.get(Skolebegynder, skolebegynder_id)

        # The view supplies display text; the table supplies the screening
        # detail and bookkeeping the view leaves out. Overlapping keys agree,
        # so the order of the merge does not matter.
        detail = {
            column.key: getattr(case, column.key)
            for column in Skolebegynder.__table__.columns
        }
        detail.update(rows[0])

        return detail


    def get_for_cpr(self, cpr: str) -> list[dict]:
        """A child's skolebegynder cases, newest school year first."""

        result = self.db.execute(
            text("""
                SELECT
                    *
                FROM
                    [dsa].[view_Skolebegyndere]
                WHERE
                    cpr = :cpr
                ORDER BY
                    skoleaar DESC
            """),
            {"cpr": cpr},
        )

        return self._rows_to_dicts(result)


    # -------------------------
    # Writes
    # -------------------------

    def _get_open_case(self, skolebegynder_id: int) -> Skolebegynder:
        """An active case that is not closed, or an HTTPException."""

        case = self.db.get(Skolebegynder, skolebegynder_id)

        if case is None or not case.aktiv:
            raise HTTPException(
                status_code=404,
                detail=f"Skolebegynder ikke fundet: {skolebegynder_id}",
            )

        if case.status_id == self._status_id(STATUS_AFSLUTTET):
            raise HTTPException(
                status_code=409,
                detail="Sagen er afsluttet. Genåbn den, før den kan ændres.",
            )

        return case


    def _validate_references(self, data: dict) -> None:
        """Check that every lookup id in an update exists and is active.

        A bad id would otherwise reach the database as a foreign-key error and
        come back as a 500 that names a constraint, not the problem.
        """

        for field, (model, id_column, label) in _REFERENCER.items():
            value = data.get(field)

            if value is None:
                continue

            statement = select(id_column).where(id_column == value)

            if hasattr(model, "aktiv"):
                statement = statement.where(model.aktiv == True)  # noqa: E712

            if self.db.execute(statement).scalar_one_or_none() is None:
                raise HTTPException(
                    status_code=400,
                    detail=f"Ugyldig {label}: {value}",
                )


    def _describe_skoletilbud(self, case: Skolebegynder) -> str | None:
        """'Skoletilbud: <campus> (<type>)' for the case log, or None if unset."""

        if case.skoletilbud_matrikel_id is None and case.skoletilbudstype_id is None:
            return None

        matrikel = self.db.get(Skolematrikel, case.skoletilbud_matrikel_id) if case.skoletilbud_matrikel_id else None
        tilbudstype = self.db.get(Skoletilbudstype, case.skoletilbudstype_id) if case.skoletilbudstype_id else None

        navn = matrikel.matrikel_navn if matrikel else "—"
        type_tekst = tilbudstype.skoletilbudstype_tekst if tilbudstype else "—"

        return f"Skoletilbud: {navn} ({type_tekst})"


    def _status_events(
        self,
        cases: dict[int, Skolebegynder],
        old_status: dict[int, int],
        status_rows: list[dict],
        udfoert_af: str,
    ) -> int:
        """Log a status_opdateret event per case whose status changed.

        Returns the number of cases whose status changed.
        """

        changed = 0

        for row in status_rows:
            skolebegynder_id = int(row["skolebegynder_id"])

            if skolebegynder_id not in cases:
                continue

            if int(row["calculated_status_id"]) == old_status[skolebegynder_id]:
                continue

            changed += 1

            self._log_event(
                cases[skolebegynder_id].cpr,
                skolebegynder_id,
                type_kode="status_opdateret",
                aktivitetstype=f"Status sat til {row['calculated_status_text']}",
                udfoert_af=udfoert_af,
            )

        return changed


    def update_skolebegynder(
        self,
        skolebegynder_id: int,
        data: dict,
        udfoert_af: str = "System",
    ) -> dict:
        """Change the editable fields of one case, then recalculate its status.

        Args:
            skolebegynder_id:
                The case to change.

            data:
                Only the fields to change (exclude_unset on the request).

            udfoert_af:
                Who made the change, for updated_by and the case log.

        Returns:
            The case as get_skolebegynder returns it.

        Raises:
            HTTPException:
                400 if no fields were sent or a lookup id is invalid.
                404 if the case does not exist.
                409 if the case is closed.
        """

        if not data:
            raise HTTPException(status_code=400, detail="Ingen felter at opdatere")

        case = self._get_open_case(skolebegynder_id)
        self._validate_references(data)

        old_status = {skolebegynder_id: case.status_id}
        old_skoletilbud = tuple(getattr(case, f) for f in _SKOLETILBUD_FELTER)

        try:
            for key, value in data.items():
                setattr(case, key, value)

            case.updated_by = udfoert_af[:100]
            self.db.flush()

            status_rows = self._execute_recalculate_status_procedure(
                skolebegynder_id=skolebegynder_id,
            )

            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

        self.db.refresh(case)

        if tuple(getattr(case, f) for f in _SKOLETILBUD_FELTER) != old_skoletilbud:
            self._log_event(
                case.cpr,
                skolebegynder_id,
                type_kode="skoletilbud_opdateret",
                aktivitetstype="Skoletilbud opdateret",
                kommentar=self._describe_skoletilbud(case),
                udfoert_af=udfoert_af,
            )

        self._status_events({skolebegynder_id: case}, old_status, status_rows, udfoert_af)

        return self.get_skolebegynder(skolebegynder_id)


    def masseopdater(
        self,
        skolebegynder_ids: list[int],
        data: dict,
        udfoert_af: str = "System",
    ) -> dict:
        """Apply the same change to many cases in one transaction.

        All or nothing: if any case is missing, inactive or closed, nothing is
        changed and the error says how many — a mass update that silently
        skipped some rows would leave the caseworker believing the filtered
        list was done.

        Returns:
            {"opdaterede": n, "statusaendringer": m}
        """

        if not data:
            raise HTTPException(status_code=400, detail="Ingen felter at opdatere")

        self._validate_references(data)

        cases = {
            case.skolebegynder_id: case
            for case in self.db.execute(
                select(Skolebegynder).where(
                    Skolebegynder.skolebegynder_id.in_(skolebegynder_ids)
                )
            ).scalars()
        }

        missing = [i for i in skolebegynder_ids if i not in cases or not cases[i].aktiv]
        if missing:
            raise HTTPException(
                status_code=404,
                detail=f"{len(missing)} sag(er) findes ikke: {missing[:10]}",
            )

        afsluttet_id = self._status_id(STATUS_AFSLUTTET)
        closed = [i for i, c in cases.items() if c.status_id == afsluttet_id]
        if closed:
            raise HTTPException(
                status_code=409,
                detail=f"{len(closed)} af de valgte sager er afsluttet og kan ikke ændres. Fravælg dem eller genåbn dem først.",
            )

        old_status = {i: c.status_id for i, c in cases.items()}
        old_skoletilbud = {
            i: tuple(getattr(c, f) for f in _SKOLETILBUD_FELTER) for i, c in cases.items()
        }

        try:
            for case in cases.values():
                for key, value in data.items():
                    setattr(case, key, value)
                case.updated_by = udfoert_af[:100]

            self.db.flush()

            # One call for every case rather than one per id: the procedure
            # is idempotent, so cases outside the selection come out as they
            # went in, and only the selected ones are logged below.
            status_rows = self._execute_recalculate_status_procedure()

            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

        for i, case in cases.items():
            self.db.refresh(case)

            if tuple(getattr(case, f) for f in _SKOLETILBUD_FELTER) != old_skoletilbud[i]:
                self._log_event(
                    case.cpr,
                    i,
                    type_kode="skoletilbud_opdateret",
                    aktivitetstype="Skoletilbud opdateret",
                    kommentar=(self._describe_skoletilbud(case) or "") + " (masseopdatering)",
                    udfoert_af=udfoert_af,
                )

        statusaendringer = self._status_events(cases, old_status, status_rows, udfoert_af)

        return {"opdaterede": len(cases), "statusaendringer": statusaendringer}


    def afslut(self, skolebegynder_id: int, udfoert_af: str = "System") -> dict:
        """Close a case — the letter has gone out.

        Only a case with a school offer can be closed: "Afsluttet" means the
        decision has been sent, and there is no decision without an offer.

        Raises:
            HTTPException:
                404 if the case does not exist; 409 if it is already closed or
                has no school offer yet.
        """

        case = self._get_open_case(skolebegynder_id)

        if case.status_id != self._status_id(STATUS_SKOLETILBUD):
            raise HTTPException(
                status_code=409,
                detail="Kun sager med et skoletilbud kan afsluttes.",
            )

        # SQL Server's date, not Python's: the container clock is UTC, so
        # date.today() would stamp yesterday on a case closed just after
        # midnight Danish time.
        today = cast(func.sysdatetime(), Date)

        try:
            case.status_id = self._status_id(STATUS_AFSLUTTET)
            case.status_dato = today
            case.afsluttet_dato = today
            case.updated_by = udfoert_af[:100]
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

        self._log_event(
            case.cpr,
            skolebegynder_id,
            type_kode="sag_afsluttet",
            aktivitetstype="Sag afsluttet",
            udfoert_af=udfoert_af,
        )

        return self.get_skolebegynder(skolebegynder_id)


    def genaabn(self, skolebegynder_id: int, udfoert_af: str = "System") -> dict:
        """Reopen a closed case so it can be changed.

        The status is not chosen here: the case is moved out of "Afsluttet"
        and the procedure derives where it belongs from its data — normally
        back to "Skoletilbud".

        Raises:
            HTTPException:
                404 if the case does not exist; 409 if it is not closed.
        """

        case = self.db.get(Skolebegynder, skolebegynder_id)

        if case is None or not case.aktiv:
            raise HTTPException(
                status_code=404,
                detail=f"Skolebegynder ikke fundet: {skolebegynder_id}",
            )

        if case.status_id != self._status_id(STATUS_AFSLUTTET):
            raise HTTPException(status_code=409, detail="Sagen er ikke afsluttet.")

        try:
            # Placeholder only — the procedure overwrites it before commit.
            case.status_id = self._status_id(STATUS_IKKE_SCREENET)
            case.afsluttet_dato = None
            case.updated_by = udfoert_af[:100]
            self.db.flush()

            status_rows = self._execute_recalculate_status_procedure(
                skolebegynder_id=skolebegynder_id,
            )

            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

        ny_status = next(
            (r["calculated_status_text"] for r in status_rows
             if int(r["skolebegynder_id"]) == skolebegynder_id),
            None,
        )

        self._log_event(
            case.cpr,
            skolebegynder_id,
            type_kode="sag_genaabnet",
            aktivitetstype="Sag genåbnet",
            kommentar=f"Status sat til {ny_status}" if ny_status else None,
            udfoert_af=udfoert_af,
        )

        return self.get_skolebegynder(skolebegynder_id)


    def haandter_aendring(self, aendring_id: int, udfoert_af: str = "System") -> dict:
        """Mark a change on the Ændringer tab as handled.

        Raises:
            HTTPException:
                404 if the change does not exist; 409 if already handled.
        """

        aendring = self.db.get(SkolebegynderAendring, aendring_id)

        if aendring is None:
            raise HTTPException(status_code=404, detail=f"Ændring ikke fundet: {aendring_id}")

        if aendring.haandteret:
            raise HTTPException(status_code=409, detail="Ændringen er allerede håndteret.")

        case = self.db.get(Skolebegynder, aendring.skolebegynder_id)

        try:
            aendring.haandteret = True
            aendring.haandteret_af = udfoert_af[:100]
            # The database's clock, like every other timestamp in DSA — see
            # befordringssystemet's migration 002 for what mixing Python's
            # time with SQL Server's cost there.
            aendring.haandteret_tidspunkt = func.sysdatetime()
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

        self._log_event(
            case.cpr,
            aendring.skolebegynder_id,
            type_kode="aendring_haandteret",
            aktivitetstype="Ændring håndteret",
            kommentar=aendring.beskrivelse,
            udfoert_af=udfoert_af,
        )

        return {"aendring_id": aendring_id, "haandteret": True}
