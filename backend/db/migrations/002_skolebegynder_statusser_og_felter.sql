-- Migration 002: The caseworkers' statuses, booked screening time, second
-- skoleønske and an afklaring note on Skolebegynder
-- Run once against the target database (test / prod).
-- Safe to re-run — every step checks before it changes anything.
--
-- Context:
--   A pre-meeting with a skolebegynder caseworker (2026-10-21) gave the
--   statuses the caseworkers use, and three things a case must hold:
--
--     Potentiel skolestarter   on the etableringsliste; no booking, no result
--     Tid booket               parents booked a screening — show the time
--     Screening afviklet       there is a screening result
--     Skoleplaceret            a school offer and a skoletilbudstype
--     Afsluttet                closed by a caseworker (unchanged)
--
--   "Nærmere afklaring" and "Under behandling" both meant "screened, not
--   placed" and become "Screening afviklet"; the clarification itself moves
--   to the new afklaring column. The rows are renamed in place, so status ids
--   and every FK stay valid. The old Nærmere afklaring row becomes
--   "Tid booket"; cases are put right by the procedure, which must be
--   redeployed and run straight after this script (see the end).
--
--   New columns:
--     screening_booket_tidspunkt  the booked screening time, from the booking
--                                 data (source to be settled) — drives
--                                 "Tid booket".
--     oensket_skolekode_2         parents can give two schools at
--                                 skoleindskrivning; oensket_skolekode is the
--                                 first. A skolekode, no FK, like the first.
--     afklaring                   the caseworker's note on a screening result
--                                 that is not clear-cut.

USE [DSA];
GO

IF COL_LENGTH(N'dsa.Skolebegynder', N'screening_booket_tidspunkt') IS NULL
    ALTER TABLE [dsa].[Skolebegynder] ADD screening_booket_tidspunkt DATETIME2(0) NULL;
GO

IF COL_LENGTH(N'dsa.Skolebegynder', N'oensket_skolekode_2') IS NULL
    ALTER TABLE [dsa].[Skolebegynder] ADD oensket_skolekode_2 INT NULL;
GO

IF COL_LENGTH(N'dsa.Skolebegynder', N'afklaring') IS NULL
    ALTER TABLE [dsa].[Skolebegynder] ADD afklaring NVARCHAR(MAX) NULL;
GO


-- Rename the statuses in place. Keyed on the old name, so a second run
-- finds nothing to rename.
DECLARE @skolebegyndere INT = (
    SELECT fagomraade_id FROM [dsa].[Fagomraade] WHERE fagomraade_tekst = N'Skolebegynderscreeninger');

UPDATE s
SET    s.status_tekst = v.ny_tekst,
       s.beskrivelse  = v.beskrivelse,
       s.sortering    = v.sortering
FROM   [dsa].[Status] s
JOIN (VALUES
    (N'Ikke screenet',     N'Potentiel skolestarter', N'Automatisk: på etableringslisten; ingen booket screening og intet resultat', 10),
    (N'Nærmere afklaring', N'Tid booket',             N'Automatisk: forældrene har booket en tid til sprogscreening',               20),
    (N'Under behandling',  N'Screening afviklet',     N'Automatisk: der er et resultat af sprogscreeningen',                         30),
    (N'Skoletilbud',       N'Skoleplaceret',          N'Automatisk: skoletilbud og skoletilbudstype er udfyldt',                     40)
) AS v (gammel_tekst, ny_tekst, beskrivelse, sortering)
    ON v.gammel_tekst = s.status_tekst
WHERE  s.fagomraade_id = @skolebegyndere;

PRINT CONCAT('Status: ', @@ROWCOUNT, ' row(s) renamed.');
GO


-- Verify
SELECT s.status_id, s.status_tekst, s.beskrivelse, s.sortering
FROM   [dsa].[Status] s
JOIN   [dsa].[Fagomraade] f ON f.fagomraade_id = s.fagomraade_id
WHERE  f.fagomraade_tekst = N'Skolebegynderscreeninger'
ORDER BY s.sortering;

SELECT name, TYPE_NAME(user_type_id) AS type_name, is_nullable
FROM   sys.columns
WHERE  object_id = OBJECT_ID(N'dsa.Skolebegynder')
  AND  name IN (N'screening_booket_tidspunkt', N'oensket_skolekode_2', N'afklaring');


-- Next, in this order:
--   1. stored_procedures/usp_recalculate_skolebegynder_status.sql (new rule)
--   2. views/view_Skolebegyndere.sql (new columns)
--   3. EXEC [dsa].[usp_recalculate_skolebegynder_status];
--      — or rerun seed/seed_test_data.sql on a test database.
