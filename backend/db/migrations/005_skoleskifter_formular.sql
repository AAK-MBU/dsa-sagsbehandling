-- Migration 005: Skoleskiftere og tilflyttere — fit dsa.Skoleskifter to the
-- OS2Forms forms
-- Run once against the target database (test / prod), after 004.
-- Safe to re-run — every step checks before it changes anything.
--
-- Context (2026-10-28):
--   Migration 004 was drafted from PUF's description. The forms themselves
--   (backend/db/formulars/) show how a case actually reaches DSA:
--
--     ansoegning_om_skoleskifte        the parents' application. "Elevens
--                                      nuværende skoletilbud":
--         Modtagelsesklasse  -> straight to DSA.
--         Almen klasse       -> to the wished-for school (next form).
--         Specialklasse      -> to PPR; never DSA.
--     ansoegning_om_skoleskifte_skole  the school's decision:
--         tilflytter til distriktet / ledig plads, and a mother tongue other
--         than Danish -> to PUF, i.e. DSA ("dansk som andetsprog").
--         Danish mother tongue -> the school admits the child itself.
--         No room -> refusal and waiting list; never DSA.
--
--   So, here:
--     * cpr is required. A child without a CPR is sent to another form
--       ("Ansøgning om indmeldelse i modtagelsesklasse"), and "Mit barn kommer
--       ikke frem i listen" still asks for one. A CPR not yet in dsa.Elev is
--       the robot's to create, not a case without CPR. ansoeger_navn and
--       CK_Skoleskifter_hvem go.
--     * skolens_vurdering in 004 was the CURRENT school assessing the Danish
--       (skoleskift internt). The forms have no such step — every case is
--       PUF's to assess — so it goes. The form's "Skolens vurdering" is the
--       RECEIVING school's ground for admission: skolens_afgoerelse.
--     * saerlige_behov (special needs go to PPR before DSA) and
--       dato_oensket_skolestart (the form asks for none) go.
--     * The form's answers the case work needs become columns; the whole
--       submission stays in ansoegningsdata.
--
--   variant is kept, set by the robot from the form and correctable by the
--   caseworker: current kommune not Aarhus and moving -> Tilflytter; Aarhus
--   -> Skoleskift internt; not Aarhus, not moving -> Skoleskift udefra. (The
--   form's own "tilflytter" means new to the SCHOOL's district, which can be
--   a move inside Aarhus — not PUF's meaning.)
--
--   Only test data exists in dsa.Skoleskifter so far. Rows without a CPR
--   are deleted if they are all test data (created_by = 'Testdata');
--   otherwise the migration stops.

USE [DSA];
GO

IF OBJECT_ID(N'[dsa].[Skoleskifter]', N'U') IS NULL
BEGIN
    RAISERROR('STOPPET: dsa.Skoleskifter findes ikke. Koer migration 004 foerst.', 16, 1);
    SET NOEXEC ON;
END
GO


-- --- 1. cpr NOT NULL --------------------------------------------------------

IF COL_LENGTH(N'dsa.Skoleskifter', N'ansoeger_navn') IS NOT NULL
   AND EXISTS (SELECT 1 FROM [dsa].[Skoleskifter] WHERE cpr IS NULL AND created_by <> N'Testdata')
BEGIN
    RAISERROR('STOPPET: der er sager uden CPR, som ikke er testdata. Tilknyt CPR eller slet dem foerst.', 16, 1);
    SET NOEXEC ON;
END
GO

IF EXISTS (SELECT 1 FROM [dsa].[Skoleskifter] WHERE cpr IS NULL)
BEGIN
    DELETE FROM [dsa].[Skoleskifter] WHERE cpr IS NULL AND created_by = N'Testdata';
    PRINT CONCAT('Deleted ', @@ROWCOUNT, ' test case(s) without CPR.');
END
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Skoleskifter_hvem')
BEGIN
    ALTER TABLE [dsa].[Skoleskifter] DROP CONSTRAINT CK_Skoleskifter_hvem;
    PRINT 'Dropped CK_Skoleskifter_hvem.';
END
GO

-- The foreign key and the index use cpr, so they are dropped around the change.
IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID(N'[dsa].[Skoleskifter]') AND name = N'cpr' AND is_nullable = 1)
BEGIN
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Skoleskifter_Elev')
        ALTER TABLE [dsa].[Skoleskifter] DROP CONSTRAINT FK_Skoleskifter_Elev;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Skoleskifter_status' AND object_id = OBJECT_ID(N'[dsa].[Skoleskifter]'))
        DROP INDEX IX_Skoleskifter_status ON [dsa].[Skoleskifter];

    ALTER TABLE [dsa].[Skoleskifter] ALTER COLUMN cpr VARCHAR(10) NOT NULL;
    PRINT 'cpr is now NOT NULL.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Skoleskifter_Elev')
BEGIN
    ALTER TABLE [dsa].[Skoleskifter] ADD CONSTRAINT FK_Skoleskifter_Elev
        FOREIGN KEY (cpr) REFERENCES [dsa].[Elev] (cpr);
    PRINT 'Created FK_Skoleskifter_Elev.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Skoleskifter_status' AND object_id = OBJECT_ID(N'[dsa].[Skoleskifter]'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Skoleskifter_status
        ON [dsa].[Skoleskifter] (status_id)
        INCLUDE (cpr, variant, modtaget_tidspunkt, aktiv);
    PRINT 'Created IX_Skoleskifter_status.';
END
GO


-- --- 2. Columns that go ------------------------------------------------------

IF COL_LENGTH(N'dsa.Skoleskifter', N'ansoeger_navn') IS NOT NULL
BEGIN
    ALTER TABLE [dsa].[Skoleskifter] DROP COLUMN ansoeger_navn;
    PRINT 'Dropped ansoeger_navn.';
END
GO

IF COL_LENGTH(N'dsa.Skoleskifter', N'saerlige_behov') IS NOT NULL
BEGIN
    ALTER TABLE [dsa].[Skoleskifter] DROP COLUMN saerlige_behov;
    PRINT 'Dropped saerlige_behov.';
END
GO

IF COL_LENGTH(N'dsa.Skoleskifter', N'dato_oensket_skolestart') IS NOT NULL
BEGIN
    ALTER TABLE [dsa].[Skoleskifter] DROP COLUMN dato_oensket_skolestart;
    PRINT 'Dropped dato_oensket_skolestart.';
END
GO

IF COL_LENGTH(N'dsa.Skoleskifter', N'skolens_vurdering') IS NOT NULL
BEGIN
    ALTER TABLE [dsa].[Skoleskifter] DROP COLUMN skolens_vurdering;
    PRINT 'Dropped skolens_vurdering.';
END
GO


-- --- 3. The form's answers -----------------------------------------------------
-- Element keys from the forms in brackets.

IF COL_LENGTH(N'dsa.Skoleskifter', N'skoleaar') IS NULL
BEGIN
    ALTER TABLE [dsa].[Skoleskifter] ADD
        -- The school year applied for, by its first year, as Skolebegynder:
        -- 2026 = 2026/2027 (du_soeger_skoleskift_for_skoleaaret).
        skoleaar                 INT            NULL,
        -- (gaar_barnet_i_en_normal_klasse) Modtagelsesklasse: came straight
        -- from the parents; Almen klasse: came through the school's form.
        nuvaerende_skoletilbud   NVARCHAR(30)   NULL,
        -- (skolen_har_vurderet_at_mit_barn_kan_udsluses_fra_modtagelsesklas)
        udslusningsdato          DATE           NULL,
        nuvaerende_kommune       NVARCHAR(100)  NULL,   -- (nuvaerende_kommune)
        -- (soeger_i_skole_inden_for_eller_uden_for_skoledistriktet) — the
        -- address (kommende_adresse, 004) may still be unknown.
        flytning                 BIT            NULL,
        flyttedato               DATE           NULL,   -- (gaeldende_fra_dato)
        -- The mother tongue as the parents and the school gave it, when
        -- Børn og Unge had none registered (Elev.modersmaal is that one).
        modersmaal_foraelder     NVARCHAR(50)   NULL,   -- (hvilket_sprog_er_barnets_modersmaal_01)
        modersmaal_skole         NVARCHAR(50)   NULL,   -- (elevens_modersmaal)
        soeskende_paa_skolen     BIT            NULL,   -- (er_der_soeskende_paa_denne_skole)
        soeskende_klasse         NVARCHAR(20)   NULL,   -- (hvilket_klassetrin_soeskende)
        begrundelse              NVARCHAR(MAX)  NULL,   -- (begrund_oenske_om_skoleskift)
        -- (skolens_vurdering, school form) the receiving school's ground for
        -- admission, shortened. NULL for a child from modtagelsesklasse.
        skolens_afgoerelse       NVARCHAR(50)   NULL;
    PRINT 'Added the form columns.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Skoleskifter_skoletilbud')
BEGIN
    ALTER TABLE [dsa].[Skoleskifter] ADD CONSTRAINT CK_Skoleskifter_skoletilbud
        CHECK (nuvaerende_skoletilbud IN (N'Almen klasse', N'Modtagelsesklasse'));
    PRINT 'Created CK_Skoleskifter_skoletilbud.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Skoleskifter_afgoerelse')
BEGIN
    ALTER TABLE [dsa].[Skoleskifter] ADD CONSTRAINT CK_Skoleskifter_afgoerelse
        CHECK (skolens_afgoerelse IN (N'Tilflytter til distriktet', N'Ledig plads'));
    PRINT 'Created CK_Skoleskifter_afgoerelse.';
END
GO

-- klassetrin_ansoegning (004) now holds the form's "Nuværende klasse", e.g. 3.B.

SET NOEXEC OFF;
GO


-- Next, in this order:
--   1. stored_procedures/usp_recalculate_skoleskifter_status.sql
--   2. views/view_Skoleskiftere.sql
--   3. seed/seed_test_data.sql on a test database
