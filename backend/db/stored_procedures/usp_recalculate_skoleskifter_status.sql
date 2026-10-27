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

    Unlike skolebegyndere, part of this area's status is a caseworker's
    choice — whether the language assessment has been ordered, whether the
    case has gone to PPR — so the rule keeps those and derives the rest
    (draft, 2026-10-27):

        Afsluttet               never moved by this procedure once set — by
                                hand, or by the rule below. Reopening is a
                                caseworker's act.

        Afsluttet (automatic)   offer, skoletilbudstype and dato_skoletilbud
                                are filled and the date has passed: the field
                                list closes the case "dagen efter" the offer
                                date (after the partshøring deadline).

        Skoletilbud afsendt     offer, skoletilbudstype and dato_skoletilbud
                                are filled, the date not yet passed.

        Sendt til PPR           manual, and kept until an offer is given.

        Afventer skoletilbud    a samlet_resultat (screening) or the current
                                school's assessment (skoleskift internt) is
                                there.

        Aftalt sprogscreening   a screening date, no result yet.

        Ny / Afventer           manual; kept as the caseworker set them. A
        sprogvurdering          case whose derived step is undone (a result
                                cleared) falls back to Ny.

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
        WHERE status_tekst IN (N'Ny', N'Afventer sprogvurdering', N'Aftalt sprogscreening', N'Sendt til PPR',
                               N'Afventer skoletilbud', N'Skoletilbud afsendt', N'Afsluttet'));

    IF @antal_statusser <> 7
    BEGIN
        THROW 50003, 'One or more skoleskifter statuses are missing from dsa.Status. Run migration 004.', 1;
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
            WHEN ss.samlet_resultat IS NOT NULL
                 OR ss.skolens_vurdering IS NOT NULL          THEN N'Afventer skoletilbud'
            WHEN ss.screeningsdato IS NOT NULL                THEN N'Aftalt sprogscreening'
            WHEN cur.status_tekst IN (N'Ny', N'Afventer sprogvurdering')
                                                              THEN cur.status_tekst
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
