-- Migration 004: Skoleskiftere og tilflyttere — the case table and its statuses
-- Run once against the target database (test / prod).
-- Safe to re-run — every step checks before it creates anything.
--
-- Context (draft, 2026-10-27):
--   The second area. One row per application, which is a case. Three kinds
--   (variant), from PUF's own description:
--
--     Tilflytter           new to Aarhus Kommune, from another kommune or
--                          from abroad. Always language-screened before the
--                          school offer.
--     Skoleskift internt   (A) between two of Aarhus' own schools. The child
--                          was screened at school start, so the CURRENT
--                          school assesses the Danish skills (skolens_vurdering).
--     Skoleskift udefra    (B) from another kommune's folkeskole or a
--                          privatskole. Nothing is known, so the child is
--                          screened.
--
--   Applications come from OS2Forms. A robot (like befordringssystemet's
--   rpa-befordring-kontrol) is to create the cases and attach the ESDH link:
--   os2forms_id makes that idempotent, ansoegningsdata keeps the form as
--   submitted, esdh_noegle / esdh_url are the GO case.
--
--   An application can arrive without a CPR. The case is created anyway
--   (cpr NULL, ansoeger_navn from the form) and is linked to the child once
--   a CPR is entered — so cpr is nullable here, unlike Skolebegynder.
--
--   Status is partly manual, partly derived — see
--   usp_recalculate_skoleskifter_status.
--
--   Not in the draft: befordring, letters (agterskrivelse / afgørelse),
--   the bemærkning statuses from the partshøring.

USE [DSA];
GO

IF OBJECT_ID(N'[dsa].[Skoleskifter]', N'U') IS NULL
BEGIN
    CREATE TABLE [dsa].[Skoleskifter] (
        skoleskifter_id     INT            IDENTITY(1,1) NOT NULL,
        -- NULL until a CPR is linked (application without CPR).
        cpr                 VARCHAR(10)    NULL,
        ansoeger_navn       NVARCHAR(200)  NULL,   -- the child's name as given in the form
        variant             NVARCHAR(30)   NOT NULL,
        status_id           INT            NOT NULL,
        status_dato         DATE           NULL,
        modtaget_tidspunkt  DATETIME2(7)   NOT NULL CONSTRAINT DF_Skoleskifter_modtaget DEFAULT (SYSDATETIME()),

        -- --- From the application (OS2Forms) ---
        os2forms_id              NVARCHAR(100)  NULL,
        ansoegningsdata          NVARCHAR(MAX)  NULL,   -- the submission as JSON
        esdh_noegle              NVARCHAR(50)   NULL,   -- GO case number ("SagsID")
        esdh_url                 NVARCHAR(500)  NULL,
        dato_oensket_skolestart  DATE           NULL,
        oensket_skolekode        INT            NULL,   -- skolekode, no FK (see Skolematrikel)
        -- Current school: an Aarhus school (A) by code, or one outside (B,
        -- tilflytter) by name.
        nuvaerende_skolekode     INT            NULL,
        nuvaerende_skole_tekst   NVARCHAR(200)  NULL,
        klassetrin_ansoegning    NVARCHAR(20)   NULL,
        kommende_adresse         NVARCHAR(300)  NULL,   -- tilflyttere: the address they move to
        saerlige_behov           BIT            NULL,   -- ticked in the form -> PPR

        -- --- Language assessment ---
        skolens_vurdering        NVARCHAR(500)  NULL,   -- A: the current school's assessment
        screeningsdato           DATE           NULL,   -- B / tilflytter
        point_1                  DECIMAL(6,1)   NULL,
        resultat_1               NVARCHAR(100)  NULL,
        point_2                  DECIMAL(6,1)   NULL,
        resultat_2               NVARCHAR(100)  NULL,
        point_3                  DECIMAL(6,1)   NULL,
        resultat_3               NVARCHAR(100)  NULL,
        samlet_resultat          NVARCHAR(100)  NULL,

        -- --- Decision ---
        skoletilbud_matrikel_id  INT            NULL,
        skoletilbudstype_id      INT            NULL,
        dato_skoletilbud         DATE           NULL,   -- the case closes after this date
        start_visitationsklasse  DATE           NULL,   -- only with a temporary offer
        klassetrin               NVARCHAR(20)   NULL,
        spor                     NVARCHAR(50)   NULL,   -- klassebetegnelse
        bemaerkning              NVARCHAR(MAX)  NULL,
        ppr_sendt_dato           DATE           NULL,   -- for "time at PPR"
        afsluttet_dato           DATE           NULL,

        created_at  DATETIME2(7)   NOT NULL CONSTRAINT DF_Skoleskifter_created_at DEFAULT (SYSDATETIME()),
        created_by  NVARCHAR(100)  NOT NULL,
        updated_at  DATETIME2(7)   NOT NULL CONSTRAINT DF_Skoleskifter_updated_at DEFAULT (SYSDATETIME()),
        updated_by  NVARCHAR(100)  NOT NULL,
        aktiv       BIT            NOT NULL CONSTRAINT DF_Skoleskifter_aktiv DEFAULT (1),

        CONSTRAINT PK_Skoleskifter PRIMARY KEY (skoleskifter_id),
        CONSTRAINT CK_Skoleskifter_variant CHECK (variant IN (N'Tilflytter', N'Skoleskift internt', N'Skoleskift udefra')),
        -- Without a CPR the form's name is all there is to go by.
        CONSTRAINT CK_Skoleskifter_hvem CHECK (cpr IS NOT NULL OR ansoeger_navn IS NOT NULL),
        CONSTRAINT FK_Skoleskifter_Elev FOREIGN KEY (cpr)
            REFERENCES [dsa].[Elev] (cpr),
        CONSTRAINT FK_Skoleskifter_Status FOREIGN KEY (status_id)
            REFERENCES [dsa].[Status] (status_id),
        CONSTRAINT FK_Skoleskifter_Skoletilbud FOREIGN KEY (skoletilbud_matrikel_id)
            REFERENCES [dsa].[Skolematrikel] (matrikel_id),
        CONSTRAINT FK_Skoleskifter_Skoletilbudstype FOREIGN KEY (skoletilbudstype_id)
            REFERENCES [dsa].[Skoletilbudstype] (skoletilbudstype_id)
    );
    PRINT 'Created dsa.Skoleskifter.';
END
GO

-- One case per OS2Forms submission, so the robot can safely retry.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Skoleskifter_os2forms_id' AND object_id = OBJECT_ID(N'[dsa].[Skoleskifter]'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_Skoleskifter_os2forms_id
        ON [dsa].[Skoleskifter] (os2forms_id)
        WHERE os2forms_id IS NOT NULL;
    PRINT 'Created UX_Skoleskifter_os2forms_id.';
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

CREATE OR ALTER TRIGGER [dsa].[trg_Skoleskifter_UpdatedAt]
ON [dsa].[Skoleskifter]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE s
    SET s.updated_at = SYSDATETIME()
    FROM [dsa].[Skoleskifter] s
    INNER JOIN inserted i ON i.skoleskifter_id = s.skoleskifter_id;
END;
GO


-- The area's statuses (field list, skoleskiftereTiflyttereFane). Manual:
-- Ny, Afventer sprogvurdering, Sendt til PPR (and Afsluttet by hand).
-- Derived: Aftalt sprogscreening, Afventer skoletilbud, Skoletilbud afsendt,
-- Afsluttet once the offer date has passed.
DECLARE @skoleskiftere INT = (
    SELECT fagomraade_id FROM [dsa].[Fagomraade] WHERE fagomraade_tekst = N'Skoleskiftere og tilflyttere');

IF @skoleskiftere IS NULL
BEGIN
    RAISERROR('STOPPET: fagområdet "Skoleskiftere og tilflyttere" findes ikke. Koer seed_lookup_data.sql foerst.', 16, 1);
    RETURN;
END;

INSERT INTO [dsa].[Status] (status_tekst, beskrivelse, aktiv, fagomraade_id, sortering)
SELECT v.status_tekst, v.beskrivelse, 1, @skoleskiftere, v.sortering
FROM (VALUES
    (N'Ny',                      N'Manuelt: ansøgningen er modtaget og ikke behandlet endnu',          10),
    (N'Afventer sprogvurdering', N'Manuelt: sprogvurdering er bestilt (skolen eller screening)',       20),
    (N'Aftalt sprogscreening',   N'Automatisk: der er en screeningsdato, men intet resultat',          30),
    (N'Sendt til PPR',           N'Manuelt: sagen er overdraget til PPR (særlige behov)',              40),
    (N'Afventer skoletilbud',    N'Automatisk: sprogvurderingen foreligger',                           50),
    (N'Skoletilbud afsendt',     N'Automatisk: skoletilbud, skoletilbudstype og dato er udfyldt',      60),
    (N'Afsluttet',               N'Automatisk dagen efter dato for skoletilbud, eller manuelt',        70)
) AS v (status_tekst, beskrivelse, sortering)
WHERE NOT EXISTS (
    SELECT 1 FROM [dsa].[Status] s
    WHERE s.fagomraade_id = @skoleskiftere AND s.status_tekst = v.status_tekst
);

PRINT CONCAT('Status (skoleskiftere): ', @@ROWCOUNT, ' row(s) inserted.');
GO


-- Next, in this order:
--   1. stored_procedures/usp_recalculate_skoleskifter_status.sql
--   2. views/view_Skoleskiftere.sql (after view_Skoler)
--   3. seed/seed_test_data.sql on a test database
