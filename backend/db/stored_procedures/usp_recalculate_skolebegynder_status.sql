USE [DSA]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
    Recalculate the status of skolebegynder cases from their data.

    Same contract as befordringssystemet's usp_recalculate_bevilling_status:
    "status is calculated, not set". One case (@skolebegynder_id) or all of
    them, @today overridable for testing, @dry_run to preview without
    writing. The result set lists every case considered and whether its
    status would change.

    The rule, agreed 2026-10-20 — automatic transitions, but never overriding
    what a person has decided:

        Afsluttet           set by a caseworker; this procedure NEVER moves a
                            case into or out of it. Reopening is deliberate.

        Skoletilbud         skoletilbud_matrikel_id AND skoletilbudstype_id
                            are both filled. Wins over the screening rules below,
                            because a decision such as "Skolegangsudsat" or
                            "Flyttet ud af kommunen" can be made without a
                            screening.

        Ikke screenet       no samlet_resultat from SX yet.

        Nærmere afklaring   screened, but puf_screeningsresultat is empty.

        Under behandling    screened and PUF-assessed; ready for placement.

    Because Skoletilbud is derived, it "switches back" by itself: a caseworker
    who clears the school offer after a change sees the case return to Under
    behandling on the next run, as the UI sketch asks.

    Inactive cases (aktiv = 0) are left alone.

    Run by the API after it saves a case (with @skolebegynder_id), and after
    each data load (without).
*/

CREATE OR ALTER PROCEDURE [dsa].[usp_recalculate_skolebegynder_status]
    @skolebegynder_id INT = NULL,
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

    IF @skolebegynder_id IS NOT NULL
        AND NOT EXISTS (
            SELECT 1
            FROM [dsa].[Skolebegynder]
            WHERE skolebegynder_id = @skolebegynder_id
        )
    BEGIN
        THROW 50001, 'Skolebegynder not found.', 1;
    END;

    -- Status ids by name, scoped to the area: another area may one day have
    -- a status with the same label.
    DECLARE @statuses TABLE (status_tekst NVARCHAR(255) PRIMARY KEY, status_id INT NOT NULL);

    INSERT INTO @statuses (status_tekst, status_id)
    SELECT s.status_tekst, s.status_id
    FROM   [dsa].[Status] s
    JOIN   [dsa].[Fagomraade] f ON f.fagomraade_id = s.fagomraade_id
    WHERE  f.fagomraade_tekst = N'Skolebegynderscreeninger'
      AND  s.aktiv = 1;

    IF (SELECT COUNT(*) FROM @statuses
        WHERE status_tekst IN (N'Ikke screenet', N'Nærmere afklaring', N'Under behandling',
                               N'Skoletilbud', N'Afsluttet')) <> 5
    BEGIN
        THROW 50003, 'One or more skolebegynder statuses are missing from dsa.Status. Run seed_lookup_data.sql.', 1;
    END;

    DECLARE @afsluttet_status_id INT =
        (SELECT status_id FROM @statuses WHERE status_tekst = N'Afsluttet');

    IF OBJECT_ID('tempdb..#calculated_statuses') IS NOT NULL
        DROP TABLE #calculated_statuses;

    SELECT
        sb.skolebegynder_id,
        sb.status_id                                   AS current_status_id,
        cur.status_tekst                               AS current_status_text,
        calc.calculated_status_text,
        target.status_id                               AS calculated_status_id,
        CAST(CASE WHEN target.status_id <> sb.status_id THEN 1 ELSE 0 END AS BIT)
                                                       AS status_will_change
    INTO #calculated_statuses
    FROM [dsa].[Skolebegynder] sb
    LEFT JOIN [dsa].[Status] cur
        ON cur.status_id = sb.status_id
    CROSS APPLY (
        SELECT CASE
            WHEN sb.skoletilbud_matrikel_id IS NOT NULL
                 AND sb.skoletilbudstype_id IS NOT NULL      THEN N'Skoletilbud'
            WHEN sb.samlet_resultat IS NULL                  THEN N'Ikke screenet'
            WHEN sb.puf_screeningsresultat IS NULL           THEN N'Nærmere afklaring'
            ELSE                                                  N'Under behandling'
        END AS calculated_status_text
    ) calc
    LEFT JOIN @statuses target
        ON target.status_tekst = calc.calculated_status_text
    WHERE sb.aktiv = 1
      AND sb.status_id <> @afsluttet_status_id
      AND (@skolebegynder_id IS NULL OR sb.skolebegynder_id = @skolebegynder_id);

    IF EXISTS (SELECT 1 FROM #calculated_statuses WHERE calculated_status_id IS NULL)
    BEGIN
        THROW 50002, 'Calculated status does not exist in Status table.', 1;
    END;

    IF @dry_run = 0
    BEGIN
        UPDATE sb
        -- updated_by is left alone: run straight after a caseworker's save,
        -- writing "System" here would erase who actually changed the case.
        SET    sb.status_id   = cs.calculated_status_id,
               sb.status_dato = @today
        FROM   [dsa].[Skolebegynder] sb
        INNER JOIN #calculated_statuses cs
            ON cs.skolebegynder_id = sb.skolebegynder_id
        WHERE  cs.status_will_change = 1;
    END;

    SELECT
        skolebegynder_id,
        current_status_id,
        current_status_text,
        calculated_status_id,
        calculated_status_text,
        status_will_change,
        @dry_run AS dry_run
    FROM
        #calculated_statuses
    ORDER BY
        skolebegynder_id;
END;
GO
