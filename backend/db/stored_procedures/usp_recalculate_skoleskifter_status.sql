USE [DSA]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
    Recalculate the status of skoleskifter cases (Skoleskiftere og
    tilflyttere) from their data.

    Same contract as usp_recalculate_skolebegynder_status: one case
    (@skoleskifter_id) or all of them, @today overridable for testing,
    @dry_run to preview. The result set lists every case considered.

    Two flows (migration 007), told apart by variant: Intern for
    "Skoleskift internt", Ekstern for "Skoleskift eksternt" and "Tilflytter".
    Checked in this order — the first that holds wins, so a later step always
    beats an earlier one:

        Afsluttet               never moved by this procedure once set — by
                                hand, or by the rule below. Reopening is a
                                caseworker's act.

        Both flows
          Afsluttet (automatic) offer, skoletilbudstype and dato_skoletilbud
                                are filled and the date has passed (the
                                field list closes the case "dagen efter").
          Skoletilbud afsendt   the same, the date not yet passed.
          Sendt til PPR         manual, and kept until an offer is given.

        Intern — the school assesses the Danish
          Klar til afgørelse    the school's sprogvurdering is in
                                (skolens_sprogvurdering).
          Afventer sprogvurdering
                                the school has been asked
                                (dato_forespoergsel_skole).

        Ekstern — PUF screens the child
          Partshøring           the partshøringsbrev is sent.
          Afventer skolens svar an alternative school is contacted
                                (kontaktet_skole_matrikel_id).
          Afventer skoletilbud  the screening result is in (samlet_resultat).
          Indkaldt til sprogscreening
                                an invitation or a screening date.

        Ny                      none of the above.

    A case without a sprogstøttebehov (intern), or with "Alderssvarende dansk"
    once the admission letter is out (ekstern), is closed by hand —
    SkoleskifterService.afslut.

    The automatic close depends on time passing, so the procedure should also
    run once a night (without @skoleskifter_id) — not only after a save.

    Inactive cases (aktiv = 0) are left alone.
*/

CREATE OR ALTER PROCEDURE [dsa].[usp_recalculate_skoleskifter_status]
    @skoleskifter_id INT = NULL,
    @today DATE = NULL,
    @dry_run BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @today IS NULL
    BEGIN
        SET @today = CONVERT(DATE, GETDATE());
    END;

    IF @skoleskifter_id IS NOT NULL
        AND NOT EXISTS (
            SELECT 1
            FROM [dsa].[Skoleskifter]
            WHERE skoleskifter_id = @skoleskifter_id
        )
    BEGIN
        THROW 50001, 'Skoleskifter not found.', 1;
    END;

    DECLARE @statuses TABLE (status_tekst NVARCHAR(255) PRIMARY KEY, status_id INT NOT NULL);

    INSERT INTO @statuses (status_tekst, status_id)
    SELECT s.status_tekst, s.status_id
    FROM   [dsa].[Status] s
    JOIN   [dsa].[Fagomraade] f ON f.fagomraade_id = s.fagomraade_id
    WHERE  f.fagomraade_tekst = N'Skoleskiftere og tilflyttere'
      AND  s.aktiv = 1;

    DECLARE @antal_statusser INT = (
        SELECT COUNT(*) FROM @statuses
        WHERE status_tekst IN (N'Ny', N'Afventer sprogvurdering', N'Klar til afgørelse',
                               N'Indkaldt til sprogscreening', N'Sendt til PPR', N'Afventer skoletilbud',
                               N'Afventer skolens svar', N'Partshøring', N'Skoletilbud afsendt', N'Afsluttet'));

    IF @antal_statusser <> 10
    BEGIN
        THROW 50003, 'One or more skoleskifter statuses are missing from dsa.Status. Run migrations 004 and 007.', 1;
    END;

    DECLARE @afsluttet_status_id INT =
        (SELECT status_id FROM @statuses WHERE status_tekst = N'Afsluttet');

    IF OBJECT_ID('tempdb..#calculated_statuses') IS NOT NULL
        DROP TABLE #calculated_statuses;

    SELECT
        ss.skoleskifter_id,
        ss.status_id                                   AS current_status_id,
        cur.status_tekst                               AS current_status_text,
        calc.calculated_status_text,
        target.status_id                               AS calculated_status_id,
        CAST(CASE WHEN target.status_id <> ss.status_id THEN 1 ELSE 0 END AS BIT)
                                                       AS status_will_change
    INTO #calculated_statuses
    FROM [dsa].[Skoleskifter] ss
    LEFT JOIN [dsa].[Status] cur
        ON cur.status_id = ss.status_id
    CROSS APPLY (
        SELECT CASE
            WHEN ss.skoletilbud_matrikel_id IS NOT NULL
                 AND ss.skoletilbudstype_id IS NOT NULL
                 AND ss.dato_skoletilbud IS NOT NULL
                 AND ss.dato_skoletilbud < @today             THEN N'Afsluttet'
            WHEN ss.skoletilbud_matrikel_id IS NOT NULL
                 AND ss.skoletilbudstype_id IS NOT NULL
                 AND ss.dato_skoletilbud IS NOT NULL          THEN N'Skoletilbud afsendt'
            WHEN cur.status_tekst = N'Sendt til PPR'          THEN N'Sendt til PPR'

            -- Intern
            WHEN ss.variant = N'Skoleskift internt'
                 AND ss.skolens_sprogvurdering IS NOT NULL    THEN N'Klar til afgørelse'
            WHEN ss.variant = N'Skoleskift internt'
                 AND ss.dato_forespoergsel_skole IS NOT NULL  THEN N'Afventer sprogvurdering'

            -- Ekstern
            WHEN ss.variant <> N'Skoleskift internt'
                 AND ss.partshoeringsbrev_sendt IS NOT NULL   THEN N'Partshøring'
            WHEN ss.variant <> N'Skoleskift internt'
                 AND ss.kontaktet_skole_matrikel_id IS NOT NULL
                                                              THEN N'Afventer skolens svar'
            WHEN ss.variant <> N'Skoleskift internt'
                 AND ss.samlet_resultat IS NOT NULL           THEN N'Afventer skoletilbud'
            WHEN ss.variant <> N'Skoleskift internt'
                 AND (ss.dato_indkaldelse_screening IS NOT NULL OR ss.screeningsdato IS NOT NULL)
                                                              THEN N'Indkaldt til sprogscreening'

            ELSE                                                   N'Ny'
        END AS calculated_status_text
    ) calc
    LEFT JOIN @statuses target
        ON target.status_tekst = calc.calculated_status_text
    WHERE ss.aktiv = 1
      AND ss.status_id <> @afsluttet_status_id
      AND (@skoleskifter_id IS NULL OR ss.skoleskifter_id = @skoleskifter_id);

    IF EXISTS (SELECT 1 FROM #calculated_statuses WHERE calculated_status_id IS NULL)
    BEGIN
        THROW 50002, 'Calculated status does not exist in Status table.', 1;
    END;

    IF @dry_run = 0
    BEGIN
        UPDATE ss
        -- updated_by is left alone, as in the skolebegynder procedure.
        SET    ss.status_id      = cs.calculated_status_id,
               ss.status_dato    = @today,
               ss.afsluttet_dato = CASE WHEN cs.calculated_status_id = @afsluttet_status_id
                                        THEN COALESCE(ss.afsluttet_dato, @today)
                                        ELSE ss.afsluttet_dato END
        FROM   [dsa].[Skoleskifter] ss
        INNER JOIN #calculated_statuses cs
            ON cs.skoleskifter_id = ss.skoleskifter_id
        WHERE  cs.status_will_change = 1;
    END;

    SELECT
        skoleskifter_id,
        current_status_id,
        current_status_text,
        calculated_status_id,
        calculated_status_text,
        status_will_change,
        @dry_run AS dry_run
    FROM
        #calculated_statuses
    ORDER BY
        skoleskifter_id;
END;
GO
