"""Service layer for citizen-related business logic.

This module contains database operations related to citizens/students.

The service is responsible for:

- Fetching citizen stamdata
- Fetching parent/guardian data

Ported from befordringssystemet's CitizenService: the same methods, reading
the same-named views (view_Stamdata, view_ParentData). DSA: create_elev and
genberegn_skole are omitted — they belong to befordring's conversion bot and
its walking-distance calculation.

Stamdata itself is maintained by external systems and is read-only here.
"""

from sqlalchemy import text
from sqlalchemy.orm import Session


class CitizenService:
    """Service class for citizen-related operations.

    Args:
        db:
            SQLAlchemy database session.
    """

    def __init__(self, db: Session):
        """Initialize the service with a database session."""

        self.db = db


    def _rows_to_dicts(self, result):
        """Convert SQLAlchemy result rows into normal dictionaries.

        Args:
            result:
                SQLAlchemy result object.

        Returns:
            A list of dictionaries.

        Notes:
            This is useful when reading from SQL views using raw SQL.
        """

        return [dict(row) for row in result.mappings().all()]


    @staticmethod
    def _escape_like(value: str) -> str:
        """Neutralise LIKE wildcards in user input.

        Without this a caseworker typing "%" matches every student in the
        municipality. Bracket-escaping avoids needing an ESCAPE clause; "["
        must be handled first or it would re-escape the brackets added after.
        """

        return (
            value.replace("[", "[[]")
            .replace("%", "[%]")
            .replace("_", "[_]")
        )


    # DSA: befordringssystemet's OverviewService.search_elever, moved here with
    # the endpoint (see endpoints/citizen.py). Otherwise verbatim but for the
    # schema.
    def search_elever(self, q: str):
        """Search students by CPR or name, for the global search box.

        Args:
            q:
                Search string. Must be at least 2 characters.

        Returns:
            Up to 20 students, each with ``cpr_elev`` and ``adresseringsnavn``.

        Notes:
            Reads [Elev] directly rather than view_Stamdata, which joins in
            what the search does not need.

            Digits and text are handled as separate statements so each can use an
            index:

            * CPR is matched as a prefix, which seeks the primary key. Nobody
              searches a CPR by its middle digits.
            * Names are matched as a WORD prefix — "starts with" OR "contains a
              word starting with" — because adresseringsnavn is stored as
              "Fornavn Efternavn" and searching by surname has to work. The
              second pattern keeps a leading wildcard, so it scans; an index on
              adresseringsnavn keeps that scan narrow. If it ever gets too slow,
              a full-text index with CONTAINS(..., '"q*"') is the proper fix.
        """

        query = (q or "").strip()

        if len(query) < 2:
            return []

        digits = "".join(ch for ch in query if ch.isdigit())

        # A CPR may be typed with or without its hyphen.
        if digits and not any(ch.isalpha() for ch in query):
            sql = text("""
                SELECT TOP 20
                    e.cpr AS cpr_elev,
                    e.adresseringsnavn
                FROM
                    [dsa].[Elev] e
                WHERE
                    e.cpr LIKE :prefix
                ORDER BY
                    e.cpr
            """)

            params = {"prefix": f"{self._escape_like(digits)}%"}

        else:
            escaped = self._escape_like(query)

            sql = text("""
                SELECT TOP 20
                    e.cpr AS cpr_elev,
                    e.adresseringsnavn
                FROM
                    [dsa].[Elev] e
                WHERE
                    e.adresseringsnavn LIKE :prefix
                    OR e.adresseringsnavn LIKE :word_prefix
                ORDER BY
                    e.adresseringsnavn
            """)

            params = {"prefix": f"{escaped}%", "word_prefix": f"% {escaped}%"}

        result = self.db.execute(sql, params)

        return self._rows_to_dicts(result)


    def get_stamdata(self, cpr: str):
        """Get stamdata for a citizen/student.

        Args:
            cpr:
                CPR number of the citizen/student.

        Returns:
            A dictionary containing stamdata if found.
            Otherwise None.

        Notes:
            Data is read from view_Stamdata, not directly from the Elev table.
            This means the returned object may contain joined/calculated fields
            that are not present directly on the Elev model.
        """

        sql = text("""
            SELECT
                *
            FROM
                [dsa].[view_Stamdata]
            WHERE
                cpr = :cpr
        """)

        result = self.db.execute(sql, {"cpr": cpr})
        records = self._rows_to_dicts(result)

        # No stamdata was found for this CPR.
        if not records:
            return None

        # CPR should identify one citizen/student, so return the first row.
        return records[0]


    def get_parent_data(self, cpr: str):
        """Get parent/guardian data for a citizen/student.

        Args:
            cpr:
                CPR number of the citizen/student.

        Returns:
            A list of parent/guardian records.

        Notes:
            Data is read from view_ParentData.

            The result is ordered by:
            1. foraelderrolle_sortering
            2. adresseringsnavn

            This gives the frontend a stable and predictable display order.
        """

        sql = text("""
            SELECT
                adresseringsnavn,
                cpr_foraelder,
                adresse_tekst,
                relation,
                navne_adresse_beskyttelse,
                maa_vide_barns_adresse
            FROM
                [dsa].[view_ParentData]
            WHERE
                cpr_elev = :cpr
            ORDER BY
                foraelderrolle_sortering,
                adresseringsnavn
        """)

        result = self.db.execute(sql, {"cpr": cpr})

        return self._rows_to_dicts(result)
