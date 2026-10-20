-- Migration 001: Create the dsa schema — phase 1 (skolebegyndere)
-- Run once against the target database (test / prod).
-- Safe to re-run — every object is guarded, so an existing one is left alone.
--
-- Context:
--   DSA replaces PUF's spreadsheets ("Fra excel til database +
--   brugergrænseflade" in the process diagrams). Phase 1 is
--   Skolebegynderscreeninger: children with DSA who start in 0. klasse are
--   language-screened, a caseworker decides their school offer, a letter goes
--   to the parents, and the case is closed.
--
--   Structure and conventions follow befordringssystemet, which DSA is
--   modelled on: PascalCase tables, snake_case columns, lookup tables shaped
--   <x>_id / <x>_tekst / beskrivelse / aktiv, soft deletes through aktiv,
--   Sagsaktivitet as the case log, PortalAuditLog as the technical trail.
--
-- Decisions this schema encodes (agreed 2026-10-20):
--
--   Elev keyed on CPR. Every skolebegynder has one (from SX / LIS). Areas
--   where a child may lack a CPR (modtagelsesklasse) come later and will have
--   to revisit this.
--
--   One Skolebegynder row per child PER SCHOOL YEAR, under its own id —
--   NOT keyed on CPR. A child whose school start is postponed
--   ("Skolegangsudsat") is expected to return as a skolebegynder the next
--   year, and last year's decision and letter must survive that.
--   UQ_Skolebegynder_cpr_skoleaar keeps the one-row-per-child guarantee
--   within a year. If PUF confirms postponed children never come back, the
--   id can be dropped in favour of CPR.
--
--   One screening per skolebegynder, so the SX result columns live on the
--   case itself. A separate screenings table may come later.
--
--   No history on Elev. Elev is the current snapshot; a child's school and
--   sprogstøttebehov over time go in SkoleHistorik.
--
--   Status is a lookup with fagomraade_id, because statuses differ per area.
--   NULL there means "applies to every area".
--
-- Types: text that holds names, addresses or free text is NVARCHAR.
--   befordringssystemet mostly uses VARCHAR, which holds æ/ø/å but not every
--   letter in the names of children with Danish as a second language. Lookup
--   text is bounded (NVARCHAR(255) / NVARCHAR(1000)) like befordring's
--   Rutetype, so it can carry a unique constraint.
--
-- Not here yet, deliberately:
--   staging tables for SX / LIS / Lone's extract, and anything read live
--   from the befordring database. Each waits on a decision that has not been
--   made yet; they arrive as later migrations.
--
-- Run order on a fresh database:
--   1. this migration
--   2. stored_procedures/*.sql, then views/view_Skoler.sql before the other
--      views (they read from it, and a view cannot reference one that does
--      not exist yet)
--   3. seed/seed_lookup_data.sql            (change ROLLBACK to COMMIT)
--   4. seed/seed_test_data.sql — dev only   (needs the procedure from step 2)

USE [DSA];   -- adjust database name if different in your environment
GO

-- -----------------------------------------------------------------------
-- 0. Schema
-- -----------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dsa')
BEGIN
    EXEC (N'CREATE SCHEMA [dsa]');
    PRINT 'Created schema dsa.';
END
GO


-- =======================================================================
-- 1. Lookup tables
-- =======================================================================

-- Fagomraade: the areas of work ("områder") on the front page.
IF OBJECT_ID(N'[dsa].[Fagomraade]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Fagomraade] (
        fagomraade_id     INT            IDENTITY(1,1) NOT NULL,
        fagomraade_tekst  NVARCHAR(255)  NOT NULL,
        beskrivelse       NVARCHAR(1000) NULL,
        aktiv             BIT            NOT NULL CONSTRAINT DF_Fagomraade_aktiv DEFAULT (1),
        sortering         INT            NULL,

        CONSTRAINT PK_Fagomraade PRIMARY KEY (fagomraade_id),
        CONSTRAINT UQ_Fagomraade_tekst UNIQUE (fagomraade_tekst)
    );
    PRINT 'Created dsa.Fagomraade.';
END
GO

-- Status: case statuses. fagomraade_id NULL = shared by every area.
IF OBJECT_ID(N'[dsa].[Status]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Status] (
        status_id      INT            IDENTITY(1,1) NOT NULL,
        status_tekst   NVARCHAR(255)  NOT NULL,
        beskrivelse    NVARCHAR(1000) NULL,
        aktiv          BIT            NOT NULL CONSTRAINT DF_Status_aktiv DEFAULT (1),
        fagomraade_id  INT            NULL,
        sortering      INT            NULL,

        CONSTRAINT PK_Status PRIMARY KEY (status_id),
        CONSTRAINT FK_Status_Fagomraade FOREIGN KEY (fagomraade_id)
            REFERENCES [dsa].[Fagomraade] (fagomraade_id),
        -- The same label may exist in two areas, but only once per area.
        CONSTRAINT UQ_Status_tekst_fagomraade UNIQUE (status_tekst, fagomraade_id)
    );
    PRINT 'Created dsa.Status.';
END
GO

-- Skoletilbudstype: the kind of decision ("Optaget på distriktsskolen", ...).
-- Same fagomraade_id convention as Status: the eleven values from the field
-- inventory are shared by skolebegyndere and skoleskiftere, while nyankomne
-- and udslusning have lists of their own.
IF OBJECT_ID(N'[dsa].[Skoletilbudstype]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Skoletilbudstype] (
        skoletilbudstype_id     INT            IDENTITY(1,1) NOT NULL,
        skoletilbudstype_tekst  NVARCHAR(255)  NOT NULL,
        beskrivelse             NVARCHAR(1000) NULL,
        aktiv                   BIT            NOT NULL CONSTRAINT DF_Skoletilbudstype_aktiv DEFAULT (1),
        fagomraade_id           INT            NULL,
        sortering               INT            NULL,

        CONSTRAINT PK_Skoletilbudstype PRIMARY KEY (skoletilbudstype_id),
        CONSTRAINT FK_Skoletilbudstype_Fagomraade FOREIGN KEY (fagomraade_id)
            REFERENCES [dsa].[Fagomraade] (fagomraade_id),
        CONSTRAINT UQ_Skoletilbudstype_tekst_fagomraade UNIQUE (skoletilbudstype_tekst, fagomraade_id)
    );
    PRINT 'Created dsa.Skoletilbudstype.';
END
GO

-- Skoleplaceringsaarsag: why the child was placed where it was. The values
-- are not decided yet — the table exists so the column has somewhere to
-- point, and is seeded once PUF has defined the list.
IF OBJECT_ID(N'[dsa].[Skoleplaceringsaarsag]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Skoleplaceringsaarsag] (
        skoleplaceringsaarsag_id     INT            IDENTITY(1,1) NOT NULL,
        skoleplaceringsaarsag_tekst  NVARCHAR(255)  NOT NULL,
        beskrivelse                  NVARCHAR(1000) NULL,
        aktiv                        BIT            NOT NULL CONSTRAINT DF_Skoleplaceringsaarsag_aktiv DEFAULT (1),
        sortering                    INT            NULL,

        CONSTRAINT PK_Skoleplaceringsaarsag PRIMARY KEY (skoleplaceringsaarsag_id),
        CONSTRAINT UQ_Skoleplaceringsaarsag_tekst UNIQUE (skoleplaceringsaarsag_tekst)
    );
    PRINT 'Created dsa.Skoleplaceringsaarsag.';
END
GO

-- Brevskabelon: which letter template the case is sent with ("Skabelon (til
-- brev)" in the UI sketch). Values not decided yet, like the table above.
IF OBJECT_ID(N'[dsa].[Brevskabelon]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Brevskabelon] (
        brevskabelon_id     INT            IDENTITY(1,1) NOT NULL,
        brevskabelon_tekst  NVARCHAR(255)  NOT NULL,
        beskrivelse         NVARCHAR(1000) NULL,
        aktiv               BIT            NOT NULL CONSTRAINT DF_Brevskabelon_aktiv DEFAULT (1),
        fagomraade_id       INT            NULL,
        sortering           INT            NULL,

        CONSTRAINT PK_Brevskabelon PRIMARY KEY (brevskabelon_id),
        CONSTRAINT FK_Brevskabelon_Fagomraade FOREIGN KEY (fagomraade_id)
            REFERENCES [dsa].[Fagomraade] (fagomraade_id),
        CONSTRAINT UQ_Brevskabelon_tekst_fagomraade UNIQUE (brevskabelon_tekst, fagomraade_id)
    );
    PRINT 'Created dsa.Brevskabelon.';
END
GO

-- Aendringsaarsag: what changed about a child after the case was opened —
-- the rows behind the "Ændringer" tab.
IF OBJECT_ID(N'[dsa].[Aendringsaarsag]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Aendringsaarsag] (
        aendringsaarsag_id     INT            IDENTITY(1,1) NOT NULL,
        aendringsaarsag_tekst  NVARCHAR(255)  NOT NULL,
        beskrivelse            NVARCHAR(1000) NULL,
        aktiv                  BIT            NOT NULL CONSTRAINT DF_Aendringsaarsag_aktiv DEFAULT (1),
        sortering              INT            NULL,

        CONSTRAINT PK_Aendringsaarsag PRIMARY KEY (aendringsaarsag_id),
        CONSTRAINT UQ_Aendringsaarsag_tekst UNIQUE (aendringsaarsag_tekst)
    );
    PRINT 'Created dsa.Aendringsaarsag.';
END
GO

-- SagsaktivitetType: canonical codes for Sagsaktivitet, as in
-- befordringssystemet (its migration 023).
IF OBJECT_ID(N'[dsa].[SagsaktivitetType]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[SagsaktivitetType] (
        type_id    INT           IDENTITY(1,1) NOT NULL,
        type_kode  NVARCHAR(100) NOT NULL,

        CONSTRAINT PK_SagsaktivitetType PRIMARY KEY (type_id),
        CONSTRAINT UQ_SagsaktivitetType_kode UNIQUE (type_kode)
    );
    PRINT 'Created dsa.SagsaktivitetType.';
END
GO

-- Skolematrikel: school campuses — verbatim from befordringssystemet, table
-- and data (seed_lookup_data.sql), so both systems mean the same thing by a
-- matrikel_id. A school with several campuses has one row per campus, all
-- sharing its skolekode, exactly one of them er_matrikel_hovedadresse = 1.
--
-- skolekode is the institution code LIS / TEA use, which is how most of DSA
-- refers to a school (district school, wanted school, a sibling's school):
-- those columns hold a skolekode and, as in befordringssystemet, carry no FK
-- — skolekode is not unique here. Only the school OFFER points at a campus
-- (Skolebegynder.skoletilbud_matrikel_id), because that is a decision about
-- where the child will actually go.
IF OBJECT_ID(N'[dsa].[Skolematrikel]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Skolematrikel] (
        [matrikel_id] [int] IDENTITY(1,1) NOT NULL,
        [matrikel_navn] [varchar](max) NOT NULL,
        [matrikel_adresse] [varchar](max) NOT NULL,
        [skolekode] [int] NOT NULL,
        [er_matrikel_hovedadresse] [bit] NOT NULL,
        [latitude] [float] NULL,
        [longitude] [float] NULL,

        CONSTRAINT [PK_skolematrikel] PRIMARY KEY CLUSTERED ([matrikel_id] ASC)
    );
    PRINT 'Created dsa.Skolematrikel.';
END
GO

-- DSA: at most one main campus per school. view_Skoler resolves a skolekode
-- to a name and coordinates through that row, and a second one would
-- duplicate every row joined through it. Not in befordringssystemet, whose
-- data already satisfies it.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'UX_Skolematrikel_hovedadresse'
      AND object_id = OBJECT_ID(N'[dsa].[Skolematrikel]')
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_Skolematrikel_hovedadresse
        ON [dsa].[Skolematrikel] (skolekode)
        WHERE er_matrikel_hovedadresse = 1;
    PRINT 'Created UX_Skolematrikel_hovedadresse.';
END
GO


-- =======================================================================
-- 2. Citizens — mirrors befordringssystemet's Adresse / Elev / Foraelder
-- =======================================================================

-- Adresse: keyed on the DAR address GUID from LOIS, not a generated id.
IF OBJECT_ID(N'[dsa].[Adresse]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Adresse] (
        adresse_id     NVARCHAR(36)  NOT NULL,
        adresse_tekst  NVARCHAR(500) NULL,
        latitude       FLOAT         NULL,
        longitude      FLOAT         NULL,

        CONSTRAINT PK_Adresse PRIMARY KEY (adresse_id)
    );
    PRINT 'Created dsa.Adresse.';
END
GO

-- Elev: the child as it is NOW. Refreshed from LIS / TEA; history of school
-- and sprogstøttebehov goes in SkoleHistorik, not here.
IF OBJECT_ID(N'[dsa].[Elev]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Elev] (
        cpr                        VARCHAR(10)   NOT NULL,
        adresseringsnavn           NVARCHAR(200) NULL,
        navne_adresse_beskyttelse  BIT           NULL,
        adresse_id                 NVARCHAR(36)  NULL,
        koen                       NVARCHAR(20)  NULL,
        modersmaal                 NVARCHAR(100) NULL,
        -- The district school the address belongs to (bopælsskoledistrikt),
        -- as a skolekode rather than a district name, so it can be compared
        -- with the wanted school and the school offer. No FK — see
        -- Skolematrikel.
        distriktsskolekode         INT           NULL,
        -- Current school (skolekode); NULL for a skolebegynder, who has none
        -- yet.
        skolekode                  INT           NULL,
        elevklassetrin             NVARCHAR(20)  NULL,
        klassebetegnelse           NVARCHAR(50)  NULL,
        sprogstoettebehov          BIT           NULL,
        ppr_status                 BIT           NULL,
        tilflyttet_dk_dato         DATE          NULL,
        opdateret_tidspunkt        DATETIME2(7)  NOT NULL CONSTRAINT DF_Elev_opdateret DEFAULT (SYSDATETIME()),

        CONSTRAINT PK_Elev PRIMARY KEY (cpr),
        CONSTRAINT CK_Elev_cpr CHECK (LEN(cpr) = 10 AND cpr NOT LIKE '%[^0-9]%'),
        CONSTRAINT FK_Elev_Adresse FOREIGN KEY (adresse_id)
            REFERENCES [dsa].[Adresse] (adresse_id)
    );
    PRINT 'Created dsa.Elev.';
END
GO

-- Foraelder: custody holders (R1 / R2 in LIS), one row per adult per child.
-- Same shape and defaults as befordringssystemet.
IF OBJECT_ID(N'[dsa].[Foraelder]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Foraelder] (
        cpr_foraelder              VARCHAR(10)   NOT NULL,
        cpr_elev                   VARCHAR(10)   NOT NULL,
        adresseringsnavn           NVARCHAR(200) NULL,
        navne_adresse_beskyttelse  BIT           NULL,
        maa_vide_barns_adresse     BIT           NULL CONSTRAINT DF_Foraelder_maa_vide_barns_adresse DEFAULT (1),
        adresse_id                 NVARCHAR(36)  NULL,
        relation                   NVARCHAR(50)  NULL CONSTRAINT DF_Foraelder_relation DEFAULT (N'Ukendt'),

        CONSTRAINT PK_Foraelder PRIMARY KEY (cpr_foraelder, cpr_elev),
        CONSTRAINT CK_Foraelder_cpr CHECK (LEN(cpr_foraelder) = 10 AND cpr_foraelder NOT LIKE '%[^0-9]%'),
        CONSTRAINT FK_Foraelder_Elev FOREIGN KEY (cpr_elev)
            REFERENCES [dsa].[Elev] (cpr),
        CONSTRAINT FK_Foraelder_Adresse FOREIGN KEY (adresse_id)
            REFERENCES [dsa].[Adresse] (adresse_id)
    );
    PRINT 'Created dsa.Foraelder.';
END
GO

-- SkoleHistorik: a child's school and sprogstøttebehov over time. One row
-- per period; gyldig_til NULL marks the current one, and at most one may be
-- open per child (UX_SkoleHistorik_aaben below).
IF OBJECT_ID(N'[dsa].[SkoleHistorik]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[SkoleHistorik] (
        skolehistorik_id    INT           IDENTITY(1,1) NOT NULL,
        cpr                 VARCHAR(10)   NOT NULL,
        skolekode           INT           NULL,   -- no FK, see Skolematrikel
        elevklassetrin      NVARCHAR(20)  NULL,
        klassebetegnelse    NVARCHAR(50)  NULL,
        sprogstoettebehov   BIT           NULL,
        gyldig_fra          DATE          NOT NULL,
        gyldig_til          DATE          NULL,
        -- Where the row came from: 'LIS', 'TEA', 'Manuel', ...
        kilde               NVARCHAR(50)  NULL,
        oprettet_tidspunkt  DATETIME2(7)  NOT NULL CONSTRAINT DF_SkoleHistorik_oprettet DEFAULT (SYSDATETIME()),

        CONSTRAINT PK_SkoleHistorik PRIMARY KEY (skolehistorik_id),
        CONSTRAINT FK_SkoleHistorik_Elev FOREIGN KEY (cpr)
            REFERENCES [dsa].[Elev] (cpr),
        CONSTRAINT CK_SkoleHistorik_periode CHECK (gyldig_til IS NULL OR gyldig_til >= gyldig_fra)
    );
    PRINT 'Created dsa.SkoleHistorik.';
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'UX_SkoleHistorik_aaben'
      AND object_id = OBJECT_ID(N'[dsa].[SkoleHistorik]')
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_SkoleHistorik_aaben
        ON [dsa].[SkoleHistorik] (cpr)
        WHERE gyldig_til IS NULL;
    PRINT 'Created UX_SkoleHistorik_aaben.';
END
GO


-- =======================================================================
-- 3. Skolebegynder — one case per child per school year
-- =======================================================================
IF OBJECT_ID(N'[dsa].[Skolebegynder]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Skolebegynder] (
        skolebegynder_id   INT          IDENTITY(1,1) NOT NULL,
        cpr                VARCHAR(10)  NOT NULL,
        -- The calendar year school starts (1 August). A child screened in
        -- January 2027 has skoleaar 2027.
        skoleaar           INT          NOT NULL,
        status_id          INT          NOT NULL,
        status_dato        DATE         NULL,
        -- When the child entered DSA ("Modtagelsesdato fra system").
        modtaget_tidspunkt DATETIME2(7) NOT NULL CONSTRAINT DF_Skolebegynder_modtaget DEFAULT (SYSDATETIME()),

        -- --- Screening, from SX ---
        screeningsdato          DATE           NULL,
        testtype                NVARCHAR(100)  NULL,
        navn_konsulent          NVARCHAR(200)  NULL,
        alder_mdr               INT            NULL,  -- age in months at screening
        gennemfoert             BIT            NULL,
        afbrudt                 BIT            NULL,
        screening_noter         NVARCHAR(MAX)  NULL,
        -- of_ = ordforråd (vocabulary)
        of_percentil            INT            NULL,
        of_besvaret             INT            NULL,
        of_ubesvaret            INT            NULL,
        of_korrekt              INT            NULL,
        of_forkert              INT            NULL,
        of_korrekt_ratio        FLOAT          NULL,
        of_score                INT            NULL,
        of_score_alt            INT            NULL,
        -- sf_ = sprogforståelse (language comprehension)
        sf_percentil            INT            NULL,
        sf_besvaret             INT            NULL,
        sf_ubesvaret            INT            NULL,
        sf_korrekt              INT            NULL,
        sf_forkert              INT            NULL,
        sf_korrekt_ratio        FLOAT          NULL,
        sf_korrekt_ratio_ori    FLOAT          NULL,
        sf_score                INT            NULL,
        sf_score_alt            INT            NULL,
        samlet_resultat         NVARCHAR(100)  NULL,
        puf_screeningsresultat  NVARCHAR(100)  NULL,
        sprogstoettebehov       BIT            NULL,

        -- --- Context from enrolment / LIS / Lone's extract ---
        dagtilbud                   NVARCHAR(200)  NULL,
        dagtilbud_afdeling          NVARCHAR(200)  NULL,
        dagtilbud_afdeling_adresse  NVARCHAR(500)  NULL,
        email_pl                    NVARCHAR(255)  NULL,
        email_distriktsskole        NVARCHAR(255)  NULL,
        -- Wanted school and a sibling's school ("skoleonske_soskende") are
        -- schools, not campuses: skolekode, no FK (see Skolematrikel).
        oensket_skolekode           INT            NULL,
        soeskende_skolekode         INT            NULL,
        ansoeger_anden_skole        BIT            NULL,

        -- --- Case work (the "blue" fields in the UI sketch) ---
        -- The school offer is a campus: "Det skal være muligt at vælge skole
        -- ud fra matrikel" (field inventory).
        skoletilbud_matrikel_id       INT            NULL,
        skoletilbudstype_id           INT            NULL,
        skoleplaceringsaarsag_id      INT            NULL,
        brevskabelon_id               INT            NULL,
        krav_paa_befordring           BIT            NULL,
        gaaafstand_distriktsskole_km  FLOAT          NULL,
        gaaafstand_oensket_skole_km   FLOAT          NULL,
        gaaafstand_skoletilbud_km     FLOAT          NULL,
        bemaerkning                   NVARCHAR(MAX)  NULL,
        sagsbehandlingsdato           DATE           NULL,
        journalfil_dannet             DATE           NULL,
        graffil_dannet                DATE           NULL,
        afsluttet_dato                DATE           NULL,

        -- --- Bookkeeping, as on befordringssystemet's Bevilling ---
        created_at  DATETIME2(7)   NOT NULL CONSTRAINT DF_Skolebegynder_created_at DEFAULT (SYSDATETIME()),
        created_by  NVARCHAR(100)  NOT NULL,
        updated_at  DATETIME2(7)   NOT NULL CONSTRAINT DF_Skolebegynder_updated_at DEFAULT (SYSDATETIME()),
        updated_by  NVARCHAR(100)  NOT NULL,
        aktiv       BIT            NOT NULL CONSTRAINT DF_Skolebegynder_aktiv DEFAULT (1),

        CONSTRAINT PK_Skolebegynder PRIMARY KEY (skolebegynder_id),
        CONSTRAINT UQ_Skolebegynder_cpr_skoleaar UNIQUE (cpr, skoleaar),
        CONSTRAINT CK_Skolebegynder_skoleaar CHECK (skoleaar BETWEEN 2000 AND 2100),
        CONSTRAINT FK_Skolebegynder_Elev FOREIGN KEY (cpr)
            REFERENCES [dsa].[Elev] (cpr),
        CONSTRAINT FK_Skolebegynder_Status FOREIGN KEY (status_id)
            REFERENCES [dsa].[Status] (status_id),
        CONSTRAINT FK_Skolebegynder_Skoletilbud FOREIGN KEY (skoletilbud_matrikel_id)
            REFERENCES [dsa].[Skolematrikel] (matrikel_id),
        CONSTRAINT FK_Skolebegynder_Skoletilbudstype FOREIGN KEY (skoletilbudstype_id)
            REFERENCES [dsa].[Skoletilbudstype] (skoletilbudstype_id),
        CONSTRAINT FK_Skolebegynder_Skoleplaceringsaarsag FOREIGN KEY (skoleplaceringsaarsag_id)
            REFERENCES [dsa].[Skoleplaceringsaarsag] (skoleplaceringsaarsag_id),
        CONSTRAINT FK_Skolebegynder_Brevskabelon FOREIGN KEY (brevskabelon_id)
            REFERENCES [dsa].[Brevskabelon] (brevskabelon_id)
    );
    PRINT 'Created dsa.Skolebegynder.';
END
GO

-- The overview filters on status within a school year, newest screening first.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_Skolebegynder_skoleaar_status'
      AND object_id = OBJECT_ID(N'[dsa].[Skolebegynder]')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Skolebegynder_skoleaar_status
        ON [dsa].[Skolebegynder] (skoleaar, status_id)
        INCLUDE (cpr, screeningsdato, aktiv);
    PRINT 'Created IX_Skolebegynder_skoleaar_status.';
END
GO

-- updated_at follows every UPDATE, as on befordringssystemet's Bevilling
-- (its migration 002). updated_by is still the writer's job.
CREATE OR ALTER TRIGGER [dsa].[trg_Skolebegynder_UpdatedAt]
ON [dsa].[Skolebegynder]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE s
    SET s.updated_at = SYSDATETIME()
    FROM [dsa].[Skolebegynder] s
    INNER JOIN inserted i ON i.skolebegynder_id = s.skolebegynder_id;
END;
GO


-- Skolebegynder_Aendring: one row per change detected on a child after its
-- case was opened — the "Ændringer" tab. Stays until a caseworker marks it
-- handled, so a change is not lost because the next nightly load agrees with
-- it.
IF OBJECT_ID(N'[dsa].[Skolebegynder_Aendring]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Skolebegynder_Aendring] (
        aendring_id            INT            IDENTITY(1,1) NOT NULL,
        skolebegynder_id       INT            NOT NULL,
        aendringsaarsag_id     INT            NOT NULL,
        -- Human-readable before/after, e.g. "Adresse: X -> Y".
        beskrivelse            NVARCHAR(1000) NULL,
        registreret_tidspunkt  DATETIME2(7)   NOT NULL CONSTRAINT DF_Skolebegynder_Aendring_registreret DEFAULT (SYSDATETIME()),
        haandteret             BIT            NOT NULL CONSTRAINT DF_Skolebegynder_Aendring_haandteret DEFAULT (0),
        haandteret_af          NVARCHAR(100)  NULL,
        haandteret_tidspunkt   DATETIME2(7)   NULL,

        CONSTRAINT PK_Skolebegynder_Aendring PRIMARY KEY (aendring_id),
        CONSTRAINT FK_Skolebegynder_Aendring_Skolebegynder FOREIGN KEY (skolebegynder_id)
            REFERENCES [dsa].[Skolebegynder] (skolebegynder_id),
        CONSTRAINT FK_Skolebegynder_Aendring_Aarsag FOREIGN KEY (aendringsaarsag_id)
            REFERENCES [dsa].[Aendringsaarsag] (aendringsaarsag_id)
    );
    PRINT 'Created dsa.Skolebegynder_Aendring.';
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_Skolebegynder_Aendring_aabne'
      AND object_id = OBJECT_ID(N'[dsa].[Skolebegynder_Aendring]')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Skolebegynder_Aendring_aabne
        ON [dsa].[Skolebegynder_Aendring] (skolebegynder_id)
        WHERE haandteret = 0;
    PRINT 'Created IX_Skolebegynder_Aendring_aabne.';
END
GO


-- =======================================================================
-- 4. Sagsaktivitet — the case log, as in befordringssystemet
-- =======================================================================
-- Deliberately no FK to Elev or to any case table: rows must survive case
-- deletes and may reference a CPR not yet in Elev. A case is identified by
-- (fagomraade_id, relateret_sag_id) — befordringssystemet's
-- relateret_bevilling_id, generalised across areas.
IF OBJECT_ID(N'[dsa].[Sagsaktivitet]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Sagsaktivitet] (
        aktivitet_id        INT            IDENTITY(1,1) NOT NULL,
        cpr                 VARCHAR(10)    NOT NULL,
        aktivitetstype      NVARCHAR(50)   NOT NULL,
        kommentar           NVARCHAR(MAX)  NULL,
        udfoert_af          NVARCHAR(100)  NULL,
        oprettet_tidspunkt  DATETIME2(7)   NOT NULL CONSTRAINT DF_Sagsaktivitet_oprettet DEFAULT (SYSDATETIME()),
        fagomraade_id       INT            NULL,
        relateret_sag_id    INT            NULL,
        aktivitetstype_id   INT            NULL,

        CONSTRAINT PK_Sagsaktivitet PRIMARY KEY (aktivitet_id),
        CONSTRAINT FK_Sagsaktivitet_Fagomraade FOREIGN KEY (fagomraade_id)
            REFERENCES [dsa].[Fagomraade] (fagomraade_id),
        CONSTRAINT FK_Sagsaktivitet_Type FOREIGN KEY (aktivitetstype_id)
            REFERENCES [dsa].[SagsaktivitetType] (type_id)
    );
    PRINT 'Created dsa.Sagsaktivitet.';
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_Sagsaktivitet_cpr'
      AND object_id = OBJECT_ID(N'[dsa].[Sagsaktivitet]')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Sagsaktivitet_cpr
        ON [dsa].[Sagsaktivitet] (cpr, oprettet_tidspunkt DESC);
    PRINT 'Created IX_Sagsaktivitet_cpr.';
END
GO


-- =======================================================================
-- 5. PortalAuditLog — verbatim from befordringssystemet's migration 004
-- =======================================================================
-- Written by backend/app/middleware/audit_middleware.py; the model is
-- app/models/audit.py. PascalCase columns on purpose, matching the
-- PortalAuditLog in befordringssystemet and aktindsigt. Path holds personal
-- data by association, so retention and access need governing.
IF OBJECT_ID(N'[dsa].[PortalAuditLog]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[PortalAuditLog] (
        AuditLogId     INT IDENTITY(1,1) NOT NULL,
        BrugerIdent    NVARCHAR(200) NULL,
        IpAdresse      NVARCHAR(50) NULL,
        UserAgent      NVARCHAR(500) NULL,
        OprettetDato   DATETIME2(7) NOT NULL,
        Method         NVARCHAR(10) NULL,
        Path           NVARCHAR(500) NULL,
        QueryParams    NVARCHAR(MAX) NULL,
        StatusCode     INT NULL,
        DurationMs     DECIMAL(10,2) NULL,
        ErrorMessage   NVARCHAR(MAX) NULL,
        ApiKeyId       INT NULL,
        ApiKeyName     NVARCHAR(200) NULL,
        Action         NVARCHAR(200) NULL,

        CONSTRAINT PK_PortalAuditLog
            PRIMARY KEY (AuditLogId)
    );
    PRINT 'Created dsa.PortalAuditLog.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_PortalAuditLog_OprettetDato'
      AND object_id = OBJECT_ID('dsa.PortalAuditLog')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_PortalAuditLog_OprettetDato
        ON dsa.PortalAuditLog (OprettetDato DESC)
        INCLUDE (BrugerIdent, Method, Path, StatusCode);
    PRINT 'Created IX_PortalAuditLog_OprettetDato.';
END
GO


-- -----------------------------------------------------------------------
-- 6. Verify
-- -----------------------------------------------------------------------
SELECT t.name AS tabel,
       (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) AS kolonner
FROM   sys.tables  t
JOIN   sys.schemas s ON s.schema_id = t.schema_id
WHERE  s.name = N'dsa'
ORDER BY t.name;
