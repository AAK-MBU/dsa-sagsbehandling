"""Service layer for lookup/reference data.

This module contains read-only lookup methods used by the frontend.

Lookup data is typically used for dropdowns, select fields, filters, and other
UI options.

The service returns lookup records in a shared format:

    {
        "id": ...,
        "label": ...
    }

This keeps the frontend simpler because most lookup endpoints return the same
basic structure.

Mirrors befordringssystemet's LookupService over DSA's own lookup tables.
"""

from sqlalchemy import select, text, true
from sqlalchemy.orm import Session

from app.models.lookup import (
    Aendringsaarsag,
    Brevskabelon,
    Fagomraade,
    Skolematrikel,
    Skoleplaceringsaarsag,
    Skoletilbudstype,
    Status,
)


class LookupService:
    """Service class for lookup-related database reads.

    Args:
        db:
            SQLAlchemy database session.
    """

    def __init__(self, db: Session):
        """Initialize the service with a database session."""

        self.db = db


    def _get_lookup_records(
        self,
        model,
        id_column,
        label_column,
        only_active: bool = True,
        order_column=None,
        extra_columns: tuple = (),
    ):
        """Get lookup records from a model in a shared id/label format.

        Args:
            model:
                SQLAlchemy model class to query.

            id_column:
                Column used as the returned "id" value.

            label_column:
                Column used as the returned "label" value.

            only_active:
                Whether to only return active records.

                If True and the model has an "aktiv" column, only rows where
                aktiv is True are returned.

            order_column:
                Optional column used for sorting.

                If not provided, the model's "sortering" column is used where
                it has one, then the label.

            extra_columns:
                DSA: further columns returned under their own names, e.g.
                fagomraade_id on statuses, so a page can narrow a shared list
                to its own area without a second request.

        Returns:
            A list of dictionaries in this format:

                [
                    {
                        "id": 1,
                        "label": "Some value",
                    }
                ]
        """

        statement = select(
            id_column.label("id"),
            label_column.label("label"),
            *extra_columns,
        )

        if only_active and hasattr(model, "aktiv"):
            statement = statement.where(model.aktiv == true())

        if order_column is not None:
            statement = statement.order_by(order_column)
        elif hasattr(model, "sortering"):
            statement = statement.order_by(model.sortering, label_column)
        else:
            statement = statement.order_by(label_column)

        rows = self.db.execute(statement).mappings().all()

        return [dict(row) for row in rows]


    def get_all(self):
        """Get every parameterless reference-data list in one call.

        Returns:
            A dictionary keyed by lookup name, where each value is exactly what
            the corresponding single-lookup method returns.

        Notes:
            The keys match the single-lookup route paths (/lookup/status ->
            "status") so the two stay visibly in step. Adding a key is
            backwards compatible for callers; renaming one is not.

            Composes the individual methods on one session — one HTTP request
            and one pooled connection instead of one per lookup, as in
            befordringssystemet.
        """

        return {
            "fagomraader": self.get_fagomraader(),
            "status": self.get_status(),
            "skoletilbudstyper": self.get_skoletilbudstyper(),
            "skoleplaceringsaarsager": self.get_skoleplaceringsaarsager(),
            "brevskabeloner": self.get_brevskabeloner(),
            "aendringsaarsager": self.get_aendringsaarsager(),
            "skolematrikel": self.get_skolematrikel(),
            "skoler": self.get_skoler(),
        }


    def get_fagomraader(self):
        """Get the areas of case work, in front-page order."""

        return self._get_lookup_records(
            model=Fagomraade,
            id_column=Fagomraade.fagomraade_id,
            label_column=Fagomraade.fagomraade_tekst,
        )


    def get_status(self):
        """Get statuses, each with the fagomraade_id it belongs to.

        fagomraade_id NULL means the status is shared by every area.
        """

        return self._get_lookup_records(
            model=Status,
            id_column=Status.status_id,
            label_column=Status.status_tekst,
            extra_columns=(Status.fagomraade_id,),
        )


    def get_skoletilbudstyper(self):
        """Get skoletilbudstyper, each with its fagomraade_id (NULL = shared)."""

        return self._get_lookup_records(
            model=Skoletilbudstype,
            id_column=Skoletilbudstype.skoletilbudstype_id,
            label_column=Skoletilbudstype.skoletilbudstype_tekst,
            extra_columns=(Skoletilbudstype.fagomraade_id,),
        )


    def get_skoleplaceringsaarsager(self):
        """Get skoleplaceringsårsager. Empty until PUF defines the values."""

        return self._get_lookup_records(
            model=Skoleplaceringsaarsag,
            id_column=Skoleplaceringsaarsag.skoleplaceringsaarsag_id,
            label_column=Skoleplaceringsaarsag.skoleplaceringsaarsag_tekst,
        )


    def get_brevskabeloner(self):
        """Get letter templates. Empty until PUF defines the values."""

        return self._get_lookup_records(
            model=Brevskabelon,
            id_column=Brevskabelon.brevskabelon_id,
            label_column=Brevskabelon.brevskabelon_tekst,
            extra_columns=(Brevskabelon.fagomraade_id,),
        )


    def get_aendringsaarsager(self):
        """Get ændringsårsager — the kinds of change on the Ændringer tab."""

        return self._get_lookup_records(
            model=Aendringsaarsag,
            id_column=Aendringsaarsag.aendringsaarsag_id,
            label_column=Aendringsaarsag.aendringsaarsag_tekst,
        )


    def get_skolematrikel(self):
        """Get school campuses — the options for a school offer.

        Each carries its skolekode, so a page can group campuses by school.
        """

        return self._get_lookup_records(
            model=Skolematrikel,
            id_column=Skolematrikel.matrikel_id,
            label_column=Skolematrikel.matrikel_navn,
            extra_columns=(Skolematrikel.skolekode,),
        )


    def get_skoler(self):
        """Get schools (one per skolekode) — for wanted school and the like.

        Read from view_Skoler, which names each school after its main campus
        without the campus suffix. id is the skolekode.
        """

        rows = self.db.execute(text("""
            SELECT
                skolekode AS id,
                skolenavn AS label
            FROM
                [dsa].[view_Skoler]
            ORDER BY
                skolenavn
        """)).mappings().all()

        return [dict(row) for row in rows]
