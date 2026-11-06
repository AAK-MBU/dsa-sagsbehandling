-- Migration 006: Split dsa.Elev into Elev + Elev_* history tables
-- Run once against the target database (test / prod), after 005.
-- Safe to re-run — every step checks before it changes anything.
--
-- Context (2026-11-06):
--   Migration 001 kept Elev as "the child as it is NOW", with school,
--   sprogstøttebehov, PPR, mother tongue and arrival date as plain columns.
--   Case work needs these over time — what was true when a decision was
--   made — so each moves to its own table keyed on cpr plus a period:
--
--     Elev                    cpr, adresseringsnavn, navne_adresse_beskyttelse,
--                             adresse_id, koen — nothing else
--     Elev_Skolehistorik      was SkoleHistorik: school, klassetrin, klasse
--                             and now distriktsskolekode (from Elev). Its
--                             sprogstoettebehov goes — Elev_Sprogstoettebehov
--                             is the one place for that.
--     Elev_Sprogstoettebehov  new; startdato/slutdato, shaped like Elev_PPR
--     Elev_PPR                was Elev.ppr_status
--     Elev_Modersmaal         was Elev.modersmaal
--     Elev_Indrejse           was Elev.tilflyttet_dk_dato
--
--   Elev_PPR, Elev_Modersmaal, Elev_Indrejse and the staging tables Elev_STG
--   and Foraelder_STG were created by hand on the dev database. They are
--   created here as they stand there (if missing), so every database ends
--   up the same.
--
--   Before Elev loses its columns, it is copied whole to dsa.ElevOld
--   (section 0): every column, with its type and any rows, so nothing about
--   how Elev looked is lost if something was missed. ElevOld is a plain
--   copy — no keys, constraints or defaults, and nothing points at it. Drop
--   it when the new tables have proven themselves.
--
--   Why a copy and not a rename of Elev to ElevOld plus a new Elev:
--   Foraelder, Skolebegynder, Skoleskifter and the Elev_* tables have
--   foreign keys to Elev, and a rename takes them along to ElevOld. Every one
--   would have to be dropped and recreated, and the constraint names
--   (PK_Elev, CK_Elev_cpr, FK_Elev_Adresse) moved out of the way first. The
--   copy leaves all of that untouched.
--
--   The dropped columns' values are NOT moved into the new tables: only test
--   data exists, and the bit columns (sprogstoettebehov, ppr_status) have no
--   date to start a period from. They survive in ElevOld.
--
-- AFTER THIS MIGRATION the views that read the dropped columns fail until
-- the new versions are run (see "Next" at the bottom): view_Stamdata,
-- view_Skolebegyndere, view_Skoleskiftere, view_Skolebegynder_Aendringer now
-- read the child through views/view_Elev_Aktuel.sql.

USE [DSA];
GO


-- --- 0. Keep the old Elev as dsa.ElevOld -------------------------------------

-- Only while Elev still has its old columns: on a re-run after section 4,
-- the copy would be of the new, slimmed Elev.
IF OBJECT_ID(N'[dsa].[ElevOld]', N'U') IS NULL
   AND COL_LENGTH(N'dsa.Elev', N'modersmaal') IS NOT NULL
BEGIN
    SELECT * INTO [dsa].[ElevOld] FROM [dsa].[Elev];
    PRINT CONCAT('Copied dsa.Elev to dsa.ElevOld (', @@ROWCOUNT, ' rows).');
END
GO

-- Stop rather than drop columns that were never copied.
IF COL_LENGTH(N'dsa.Elev', N'modersmaal') IS NOT NULL
   AND OBJECT_ID(N'[dsa].[ElevOld]', N'U') IS NULL
BEGIN
    RAISERROR('STOPPET: dsa.ElevOld blev ikke oprettet, saa Elev''s kolonner droppes ikke.', 16, 1);
    SET NOEXEC ON;
END
GO


-- --- 1. Tables created by hand on dev -----------------------------------------

-- Elev_Indrejse: when the child first and last entered Denmark. One row per
-- child.
IF OBJECT_ID(N'[dsa].[Elev_Indrejse]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Elev_Indrejse] (
        cpr               VARCHAR(10)  NOT NULL,
        foerste_indrejse  DATE         NOT NULL,
        seneste_indrejse  DATE         NOT NULL,

        CONSTRAINT PK_Elev_Indrejse PRIMARY KEY (cpr),
        CONSTRAINT FK_Elev_Indrejse_Elev FOREIGN KEY (cpr)
            REFERENCES [dsa].[Elev] (cpr),
        CONSTRAINT CK_Elev_Indrejse_cpr CHECK (LEN(cpr) = 10 AND cpr NOT LIKE '%[^0-9]%'),
        CONSTRAINT CK_Elev_Indrejse_datoer CHECK (seneste_indrejse >= foerste_indrejse)
    );
    PRINT 'Created dsa.Elev_Indrejse.';
END
GO

-- Elev_Modersmaal: mother tongue over time. gyldig_til 9999-12-31 = current.
IF OBJECT_ID(N'[dsa].[Elev_Modersmaal]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Elev_Modersmaal] (
        cpr         VARCHAR(10)   NOT NULL,
        modersmaal  NVARCHAR(50)  NULL,
        gyldig_fra  DATE          NOT NULL,
        gyldig_til  DATE          NOT NULL CONSTRAINT DF_Elev_Modersmaal_gyldig_til DEFAULT ('99991231'),

        CONSTRAINT PK_Elev_Modersmaal PRIMARY KEY (cpr, gyldig_fra),
        CONSTRAINT FK_Elev_Modersmaal_Elev FOREIGN KEY (cpr)
            REFERENCES [dsa].[Elev] (cpr),
        CONSTRAINT CK_Elev_Modersmaal_cpr CHECK (LEN(cpr) = 10 AND cpr NOT LIKE '%[^0-9]%'),
        CONSTRAINT CK_Elev_Modersmaal_periode CHECK (gyldig_til >= gyldig_fra)
    );
    PRINT 'Created dsa.Elev_Modersmaal.';
END
GO

-- Elev_PPR: periods the child is known by PPR.
IF OBJECT_ID(N'[dsa].[Elev_PPR]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Elev_PPR] (
        cpr        VARCHAR(10)  NOT NULL,
        startdato  DATE         NOT NULL,
        slutdato   DATE         NOT NULL,

        CONSTRAINT PK_Elev_PPR PRIMARY KEY (cpr, startdato),
        CONSTRAINT FK_Elev_PPR_Elev FOREIGN KEY (cpr)
            REFERENCES [dsa].[Elev] (cpr),
        CONSTRAINT CK_Elev_PPR_periode CHECK (slutdato >= startdato)
    );
    PRINT 'Created dsa.Elev_PPR.';
END
GO

-- Staging tables: loaded by the import, no keys or constraints.
IF OBJECT_ID(N'[dsa].[Elev_STG]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Elev_STG] (
        cpr                        VARCHAR(10)   NULL,
        adresseringsnavn           NVARCHAR(200) NULL,
        navne_adresse_beskyttelse  BIT           NULL,
        adresse_id                 NVARCHAR(36)  NULL,
        koen                       NVARCHAR(20)  NULL,
        distriktsskolekode         INT           NULL,
        opdateret_tidspunkt        DATETIME2(7)  NULL,
        skoledistrikt              NVARCHAR(100) NULL
    );
    PRINT 'Created dsa.Elev_STG.';
END
GO

IF OBJECT_ID(N'[dsa].[Foraelder_STG]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Foraelder_STG] (
        cpr_foraelder              VARCHAR(10)   NULL,
        cpr_elev                   VARCHAR(10)   NULL,
        adresseringsnavn           NVARCHAR(200) NULL,
        navne_adresse_beskyttelse  BIT           NULL,
        maa_vide_barns_adresse     BIT           NULL,
        adresse_id                 NVARCHAR(36)  NULL,
        relation                   NVARCHAR(50)  NULL
    );
    PRINT 'Created dsa.Foraelder_STG.';
END
GO


-- --- 2. Elev_Sprogstoettebehov — new, shaped like Elev_PPR --------------------

IF OBJECT_ID(N'[dsa].[Elev_Sprogstoettebehov]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Elev_Sprogstoettebehov] (
        cpr        VARCHAR(10)  NOT NULL,
        startdato  DATE         NOT NULL,
        slutdato   DATE         NOT NULL,

        CONSTRAINT PK_Elev_Sprogstoettebehov PRIMARY KEY (cpr, startdato),
        CONSTRAINT FK_Elev_Sprogstoettebehov_Elev FOREIGN KEY (cpr)
            REFERENCES [dsa].[Elev] (cpr),
        CONSTRAINT CK_Elev_Sprogstoettebehov_periode CHECK (slutdato >= startdato)
    );
    PRINT 'Created dsa.Elev_Sprogstoettebehov.';
END
GO


-- --- 3. SkoleHistorik -> Elev_Skolehistorik -----------------------------------

IF OBJECT_ID(N'[dsa].[SkoleHistorik]', N'U') IS NOT NULL
   AND OBJECT_ID(N'[dsa].[Elev_Skolehistorik]', N'U') IS NULL
BEGIN
    EXEC sp_rename N'dsa.SkoleHistorik', N'Elev_Skolehistorik';
    PRINT 'Renamed dsa.SkoleHistorik to dsa.Elev_Skolehistorik.';
END
GO

-- The constraint and index names follow the table, so a later script that
-- looks them up by name finds them.
IF OBJECT_ID(N'[dsa].[PK_SkoleHistorik]') IS NOT NULL
    EXEC sp_rename N'dsa.PK_SkoleHistorik', N'PK_Elev_Skolehistorik', N'OBJECT';
IF OBJECT_ID(N'[dsa].[FK_SkoleHistorik_Elev]') IS NOT NULL
    EXEC sp_rename N'dsa.FK_SkoleHistorik_Elev', N'FK_Elev_Skolehistorik_Elev', N'OBJECT';
IF OBJECT_ID(N'[dsa].[CK_SkoleHistorik_periode]') IS NOT NULL
    EXEC sp_rename N'dsa.CK_SkoleHistorik_periode', N'CK_Elev_Skolehistorik_periode', N'OBJECT';
IF OBJECT_ID(N'[dsa].[DF_SkoleHistorik_oprettet]') IS NOT NULL
    EXEC sp_rename N'dsa.DF_SkoleHistorik_oprettet', N'DF_Elev_Skolehistorik_oprettet', N'OBJECT';
IF EXISTS (SELECT 1 FROM sys.indexes
           WHERE name = N'UX_SkoleHistorik_aaben' AND object_id = OBJECT_ID(N'[dsa].[Elev_Skolehistorik]'))
    EXEC sp_rename N'dsa.Elev_Skolehistorik.UX_SkoleHistorik_aaben', N'UX_Elev_Skolehistorik_aaben', N'INDEX';
GO

-- At most one open period (gyldig_til NULL) per child — as in 001, in case
-- the dev database never got the index.
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = N'UX_Elev_Skolehistorik_aaben' AND object_id = OBJECT_ID(N'[dsa].[Elev_Skolehistorik]'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_Elev_Skolehistorik_aaben
        ON [dsa].[Elev_Skolehistorik] (cpr)
        WHERE gyldig_til IS NULL;
    PRINT 'Created UX_Elev_Skolehistorik_aaben.';
END
GO

-- The district school for the child's address in that period, as a skolekode
-- (no FK — see Skolematrikel). Moved from Elev.
IF COL_LENGTH(N'dsa.Elev_Skolehistorik', N'distriktsskolekode') IS NULL
BEGIN
    ALTER TABLE [dsa].[Elev_Skolehistorik] ADD distriktsskolekode INT NULL;
    PRINT 'Added Elev_Skolehistorik.distriktsskolekode.';
END
GO

-- Elev_Sprogstoettebehov holds this now.
IF COL_LENGTH(N'dsa.Elev_Skolehistorik', N'sprogstoettebehov') IS NOT NULL
BEGIN
    ALTER TABLE [dsa].[Elev_Skolehistorik] DROP COLUMN sprogstoettebehov;
    PRINT 'Dropped Elev_Skolehistorik.sprogstoettebehov.';
END
GO


-- --- 4. Elev keeps only the person --------------------------------------------

IF OBJECT_ID(N'[dsa].[DF_Elev_opdateret]', N'D') IS NOT NULL
BEGIN
    ALTER TABLE [dsa].[Elev] DROP CONSTRAINT DF_Elev_opdateret;
    PRINT 'Dropped DF_Elev_opdateret.';
END
GO

DECLARE @kolonner TABLE (navn SYSNAME);
INSERT INTO @kolonner (navn) VALUES
    (N'modersmaal'),            -- Elev_Modersmaal
    (N'distriktsskolekode'),    -- Elev_Skolehistorik
    (N'skolekode'),             -- Elev_Skolehistorik
    (N'elevklassetrin'),        -- Elev_Skolehistorik
    (N'klassebetegnelse'),      -- Elev_Skolehistorik
    (N'sprogstoettebehov'),     -- Elev_Sprogstoettebehov
    (N'ppr_status'),            -- Elev_PPR
    (N'tilflyttet_dk_dato'),    -- Elev_Indrejse
    (N'opdateret_tidspunkt');   -- dropped

DECLARE @navn SYSNAME, @sql NVARCHAR(400);

DECLARE kolonne CURSOR LOCAL FAST_FORWARD FOR
    SELECT navn FROM @kolonner WHERE COL_LENGTH(N'dsa.Elev', navn) IS NOT NULL;
OPEN kolonne;
FETCH NEXT FROM kolonne INTO @navn;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'ALTER TABLE [dsa].[Elev] DROP COLUMN ' + QUOTENAME(@navn) + N';';
    EXEC sys.sp_executesql @sql;
    PRINT CONCAT('Dropped Elev.', @navn, '.');
    FETCH NEXT FROM kolonne INTO @navn;
END;
CLOSE kolonne;
DEALLOCATE kolonne;
GO


-- --- 5. Result ---------------------------------------------------------------

SELECT t.name AS tabel, c.column_id, c.name AS kolonne, ty.name AS type, c.max_length, c.is_nullable
FROM   sys.tables  t
JOIN   sys.columns c  ON c.object_id = t.object_id
JOIN   sys.types   ty ON ty.user_type_id = c.user_type_id
WHERE  t.schema_id = SCHEMA_ID(N'dsa')
  AND  (t.name IN (N'Elev', N'ElevOld') OR t.name LIKE N'Elev[_]%')
ORDER BY t.name, c.column_id;
GO

SET NOEXEC OFF;
GO


-- Next, in this order:
--   1. views/view_Elev_Aktuel.sql — new: Elev plus the current period of each
--      Elev_* table, under Elev's old column names
--   2. views/view_Stamdata.sql, view_Skolebegyndere.sql, view_Skoleskiftere.sql,
--      view_Skolebegynder_Aendringer.sql — now read view_Elev_Aktuel
--   3. seed/seed_test_data.sql on a test database
