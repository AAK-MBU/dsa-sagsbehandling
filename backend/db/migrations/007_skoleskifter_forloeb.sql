-- Migration 007: Skoleskiftere og tilflyttere — the two case flows, and
-- caseworkers
-- Run once against the target database (test / prod), after 006.
-- Safe to re-run — every step checks before it changes anything.
--
-- Context (PUF meeting, 2026-11):
--   A skoleskifter case follows one of two flows:
--
--     Intern   Skoleskift internt — between two Aarhus folkeskoler. If the
--              child has a sprogstøttebehov, the caseworker asks the school
--              for a sprogvurdering (date of the request). The school replies
--              "Afventer optagelse i Sprog+" or "Fortsat behov for sprogstøtte";
--              with continued support a letter goes to the parents, and the
--              case is closed. No sprogstøttebehov: the case is closed — the
--              child is not DSA's.
--
--     Ekstern  Skoleskift eksternt (e.g. from a private school) and Tilflytter.
--              PUF screens the child (invitation date, screening date, result).
--              Then a school offer: the wished school when there is a free
--              place; otherwise an alternative school is contacted (it has two
--              days to answer) and a partshøringsbrev goes to the parents.
--              "Alderssvarende dansk" no longer closes the case by itself: an
--              admission letter is sent first, then the case is closed.
--
--   Both flows show befordring, entered by hand, and record when each letter
--   was sent (letter generation comes later). Cases can be assigned to a
--   caseworker.
--
--   So, here:
--     1. dsa.Sagsbehandler — befordringssystemet's table, as it is there.
--     2. The new columns on dsa.Skoleskifter.
--     3. "Skoleskift udefra" becomes "Skoleskift eksternt".
--     4. The statuses follow the flows:
--          Intern   Ny -> Afventer sprogvurdering -> Klar til afgørelse -> Afsluttet
--          Ekstern  Ny -> Indkaldt til sprogscreening -> Afventer skoletilbud
--                   -> Afventer skolens svar -> Partshøring -> Skoletilbud afsendt
--                   -> Afsluttet
--        plus Sendt til PPR (manual) in both. "Aftalt sprogscreening" is
--        renamed "Indkaldt til sprogscreening" (same status_id, so existing
--        cases keep it); three statuses are added.
--
--   Run afterwards: views/view_Skoleskiftere.sql and
--   stored_procedures/usp_recalculate_skoleskifter_status.sql, then
--   EXEC dsa.usp_recalculate_skoleskifter_status to re-derive every case.

USE [DSA];
GO

IF OBJECT_ID(N'[dsa].[Skoleskifter]', N'U') IS NULL
   OR OBJECT_ID(N'[dsa].[Elev_Skolehistorik]', N'U') IS NULL
BEGIN
    RAISERROR('STOPPET: dsa.Skoleskifter eller dsa.Elev_Skolehistorik findes ikke. Koer migration 004-006 foerst.', 16, 1);
    SET NOEXEC ON;
END
GO


-- --- 1. dsa.Sagsbehandler ------------------------------------------------------
-- As befordringssystemet's [befordring].[Sagsbehandler]: the caseworkers a
-- case can be assigned to. email is matched against the signed-in user's
-- OIDC email claim (befordringssystemet's Min side does that).

IF OBJECT_ID(N'[dsa].[Sagsbehandler]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Sagsbehandler](
        [sagsbehandler_id] [int] IDENTITY(1,1) NOT NULL,
        [sagsbehandler_tekst] [varchar](max) NOT NULL,
        [beskrivelse] [varchar](max) NULL,
        [aktiv] [bit] NOT NULL,
        [email] [nvarchar](255) NULL,
     CONSTRAINT [PK_sagsbehandler] PRIMARY KEY CLUSTERED
    (
        [sagsbehandler_id] ASC
    )
    );
    PRINT 'Created dsa.Sagsbehandler.';
END
GO


-- --- 2. New columns on dsa.Skoleskifter ----------------------------------------

IF COL_LENGTH(N'dsa.Skoleskifter', N'sagsbehandler_id') IS NULL
BEGIN
    ALTER TABLE [dsa].[Skoleskifter] ADD
        sagsbehandler_id                      INT            NULL,

        -- Ekstern: "andet modersmål end dansk", as the caseworker records it.
        andet_modersmaal                      BIT            NULL,

        -- Intern: the sprogvurdering the school carries out.
        dato_forespoergsel_skole              DATE           NULL,   -- request sent to the school
        dato_svar_skole                       DATE           NULL,   -- the school replied
        skolens_sprogvurdering                NVARCHAR(50)   NULL,

        -- Ekstern: PUF's sprogscreening (screeningsdato, 004, is the day it
        -- was carried out).
        dato_indkaldelse_screening            DATE           NULL,

        -- Ekstern: the school offer.
        ledig_plads                           BIT            NULL,   -- on the wished school
        kontaktet_skole_matrikel_id           INT            NULL,   -- no free place: the alternative
        dato_kontakt_skole                    DATE           NULL,   -- it has two days to answer
        midlertidigt_skoletilbud_matrikel_id  INT            NULL,   -- with start_visitationsklasse (004)

        -- Letters: the day each was sent. Generating them comes later.
        optagelsesbrev_sendt                  DATE           NULL,
        sprogstoettebrev_sendt                DATE           NULL,
        partshoeringsbrev_sendt               DATE           NULL,

        -- Befordring, entered by hand.
        krav_paa_befordring                   BIT            NULL,
        befordring_bemaerkning                NVARCHAR(MAX)  NULL;
    PRINT 'Added the flow columns.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Skoleskifter_Sagsbehandler')
BEGIN
    ALTER TABLE [dsa].[Skoleskifter] ADD CONSTRAINT FK_Skoleskifter_Sagsbehandler
        FOREIGN KEY (sagsbehandler_id) REFERENCES [dsa].[Sagsbehandler] (sagsbehandler_id);
    PRINT 'Created FK_Skoleskifter_Sagsbehandler.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Skoleskifter_KontaktetSkole')
BEGIN
    ALTER TABLE [dsa].[Skoleskifter] ADD CONSTRAINT FK_Skoleskifter_KontaktetSkole
        FOREIGN KEY (kontaktet_skole_matrikel_id) REFERENCES [dsa].[Skolematrikel] (matrikel_id);
    PRINT 'Created FK_Skoleskifter_KontaktetSkole.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Skoleskifter_MidlertidigtSkoletilbud')
BEGIN
    ALTER TABLE [dsa].[Skoleskifter] ADD CONSTRAINT FK_Skoleskifter_MidlertidigtSkoletilbud
        FOREIGN KEY (midlertidigt_skoletilbud_matrikel_id) REFERENCES [dsa].[Skolematrikel] (matrikel_id);
    PRINT 'Created FK_Skoleskifter_MidlertidigtSkoletilbud.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Skoleskifter_skolens_sprogvurdering')
BEGIN
    ALTER TABLE [dsa].[Skoleskifter] ADD CONSTRAINT CK_Skoleskifter_skolens_sprogvurdering
        CHECK (skolens_sprogvurdering IN (N'Afventer optagelse i Sprog+', N'Fortsat behov for sprogstøtte'));
    PRINT 'Created CK_Skoleskifter_skolens_sprogvurdering.';
END
GO


-- --- 3. "Skoleskift udefra" -> "Skoleskift eksternt" ---------------------------

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = N'CK_Skoleskifter_variant'
             AND definition LIKE N'%udefra%')
BEGIN
    ALTER TABLE [dsa].[Skoleskifter] DROP CONSTRAINT CK_Skoleskifter_variant;
    PRINT 'Dropped the old CK_Skoleskifter_variant.';
END
GO

UPDATE [dsa].[Skoleskifter]
SET    variant = N'Skoleskift eksternt'
WHERE  variant = N'Skoleskift udefra';
PRINT CONCAT('Renamed Skoleskift udefra on ', @@ROWCOUNT, ' case(s).');
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Skoleskifter_variant')
BEGIN
    ALTER TABLE [dsa].[Skoleskifter] ADD CONSTRAINT CK_Skoleskifter_variant
        CHECK (variant IN (N'Tilflytter', N'Skoleskift internt', N'Skoleskift eksternt'));
    PRINT 'Created CK_Skoleskifter_variant (eksternt).';
END
GO


-- --- 4. Statuses -----------------------------------------------------------------

DECLARE @skoleskiftere INT = (
    SELECT fagomraade_id FROM [dsa].[Fagomraade] WHERE fagomraade_tekst = N'Skoleskiftere og tilflyttere');

IF @skoleskiftere IS NULL
BEGIN
    RAISERROR('STOPPET: fagområdet "Skoleskiftere og tilflyttere" findes ikke.', 16, 1);
    RETURN;
END;

-- Renamed in place, so the cases that have it keep their status_id.
UPDATE [dsa].[Status]
SET    status_tekst = N'Indkaldt til sprogscreening'
WHERE  fagomraade_id = @skoleskiftere
  AND  status_tekst = N'Aftalt sprogscreening'
  AND  NOT EXISTS (SELECT 1 FROM [dsa].[Status] s
                   WHERE s.fagomraade_id = @skoleskiftere AND s.status_tekst = N'Indkaldt til sprogscreening');
PRINT CONCAT('Renamed Aftalt sprogscreening: ', @@ROWCOUNT, ' row(s).');

INSERT INTO [dsa].[Status] (status_tekst, beskrivelse, aktiv, fagomraade_id, sortering)
SELECT v.status_tekst, v.beskrivelse, 1, @skoleskiftere, v.sortering
FROM (VALUES
    (N'Klar til afgørelse',    N'Automatisk (intern): skolens sprogvurdering foreligger',                 35),
    (N'Afventer skolens svar', N'Automatisk (ekstern): en alternativ skole er kontaktet (to dages frist)', 52),
    (N'Partshøring',           N'Automatisk (ekstern): partshøringsbrevet er sendt',                       55)
) AS v (status_tekst, beskrivelse, sortering)
WHERE NOT EXISTS (
    SELECT 1 FROM [dsa].[Status] s
    WHERE s.fagomraade_id = @skoleskiftere AND s.status_tekst = v.status_tekst
);
PRINT CONCAT('Status (skoleskiftere): ', @@ROWCOUNT, ' row(s) inserted.');

-- The descriptions, so the lookup says how each status now arises.
UPDATE s
SET    s.beskrivelse = v.beskrivelse,
       s.sortering   = v.sortering
FROM   [dsa].[Status] s
JOIN (VALUES
    (N'Ny',                          N'Ansøgningen er modtaget og ikke behandlet endnu',                     10),
    (N'Afventer sprogvurdering',     N'Automatisk (intern): skolen er bedt om en sprogvurdering',            20),
    (N'Indkaldt til sprogscreening', N'Automatisk (ekstern): barnet er indkaldt til sprogscreening',         30),
    (N'Sendt til PPR',               N'Manuelt: sagen er overdraget til PPR (særlige behov)',                40),
    (N'Afventer skoletilbud',        N'Automatisk (ekstern): sprogscreeningens resultat foreligger',         50),
    (N'Skoletilbud afsendt',         N'Automatisk: skoletilbud, skoletilbudstype og dato er udfyldt',        60),
    (N'Afsluttet',                   N'Manuelt, eller automatisk dagen efter dato for skoletilbud',          70)
) AS v (status_tekst, beskrivelse, sortering)
    ON v.status_tekst = s.status_tekst
WHERE  s.fagomraade_id = @skoleskiftere;
GO


SET NOEXEC OFF;
GO


-- Next, in this order:
--   1. views/view_Skoleskiftere.sql
--   2. stored_procedures/usp_recalculate_skoleskifter_status.sql
--   3. EXEC [dsa].[usp_recalculate_skoleskifter_status];   -- re-derive every case
--   4. (test) seed/seed_test_data.sql
