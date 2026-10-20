/* ============================================================
   Test-data reset + seed for a DSA dev database.

   DESTRUCTIVE: clears every case table (Skolebegynder, its changes,
   Sagsaktivitet, SkoleHistorik, Foraelder, Elev, Adresse, PortalAuditLog)
   and inserts a small, fictional cohort of skolebegyndere. Lookups are NOT
   touched — run seed_lookup_data.sql first.

   All names, CPR numbers and address ids are made up. The addresses are
   real Aarhus streets with invented numbers and GUIDs; nothing here links a
   person to a place.

   What the cohort covers (skoleaar 2026, plus one child in 2025):
     - every status: Ikke screenet, Nærmere afklaring, Under behandling,
       Skoletilbud, Afsluttet
     - a child whose school start was postponed ("Skolegangsudsat") in 2025
       and who is a skolebegynder again in 2026 — the reason Skolebegynder
       has its own id rather than CPR as key
     - unhandled rows on the Ændringer tab, and one handled
     - cases where district school, wanted school and offer differ
       (skoler_afviger in view_Skolebegyndere)

   The SX result values (samlet_resultat, puf_screeningsresultat) are
   ILLUSTRATIVE — the real categories have to be confirmed against SX.

   Statuses are not hand-set except Afsluttet: the cases are inserted as
   "Ikke screenet" and usp_recalculate_skolebegynder_status derives the rest,
   so this file also exercises the status rule.

   Requires migration 001, seed_lookup_data.sql (including Skolematrikel),
   the views and the stored procedure usp_recalculate_skolebegynder_status.

   Runs inside a transaction that ROLLBACKs by default — change the final
   ROLLBACK to COMMIT once the previewed data looks correct.
   ============================================================ */

USE [DSA];

SET NOCOUNT ON;
SET XACT_ABORT ON;


/* ------------------------------------------------------------
   SERVERSPÆRRE — udfyld @tilladte_servere før scriptet bruges

   Som i befordringssystemet: USE [DSA] siger intet om hvilken server man
   står på, og det eneste andet værn er ROLLBACK'et nederst — som pointen er,
   at man laver om til COMMIT.

   Fejler LUKKET: kun servere på listen nedenfor er tilladt. Servernavnet
   skrives som en VÆRDI i INSERT'et — kolonnen hedder servernavn og skal
   blive ved med det. Find navnet med:   SELECT @@SERVERNAME;
------------------------------------------------------------ */

DECLARE @tilladte_servere TABLE (servernavn SYSNAME);

INSERT INTO @tilladte_servere (servernavn) VALUES
    -- (N'MIN-DEV-SERVER'),
    (N'SRVSQL58');

IF NOT EXISTS (SELECT 1 FROM @tilladte_servere WHERE servernavn = @@SERVERNAME)
BEGIN
    RAISERROR(
        'STOPPET: seed_test_data sletter ALLE sagsdata og maa ikke koere paa %s. Tilfoej servernavnet til @tilladte_servere, hvis det er en testserver.',
        16, 1, @@SERVERNAME
    );
    RETURN;
END;

PRINT CONCAT('Serverspaerre OK: ', @@SERVERNAME);


IF OBJECT_ID(N'[dsa].[usp_recalculate_skolebegynder_status]', N'P') IS NULL
BEGIN
    RAISERROR('STOPPET: dsa.usp_recalculate_skolebegynder_status findes ikke. Koer stored_procedures foerst.', 16, 1);
    RETURN;
END;


BEGIN TRANSACTION;


/* ------------------------------------------------------------
   1. Clear case data — children before parents
------------------------------------------------------------ */

DELETE FROM [dsa].[Skolebegynder_Aendring];
DELETE FROM [dsa].[Sagsaktivitet];
DELETE FROM [dsa].[Skolebegynder];
DELETE FROM [dsa].[SkoleHistorik];
DELETE FROM [dsa].[Foraelder];
DELETE FROM [dsa].[Elev];
DELETE FROM [dsa].[Adresse];
DELETE FROM [dsa].[PortalAuditLog];

PRINT 'Cleared case data.';


/* ------------------------------------------------------------
   2. Lookup ids, by name
------------------------------------------------------------ */

DECLARE @fagomraade_sb INT = (
    SELECT fagomraade_id FROM [dsa].[Fagomraade] WHERE fagomraade_tekst = N'Skolebegynderscreeninger');

DECLARE @status_ikke_screenet INT = (
    SELECT status_id FROM [dsa].[Status]
    WHERE status_tekst = N'Ikke screenet' AND fagomraade_id = @fagomraade_sb);
DECLARE @status_afsluttet INT = (
    SELECT status_id FROM [dsa].[Status]
    WHERE status_tekst = N'Afsluttet' AND fagomraade_id = @fagomraade_sb);

DECLARE @stt_distrikt   INT = (SELECT skoletilbudstype_id FROM [dsa].[Skoletilbudstype] WHERE skoletilbudstype_tekst = N'Optaget på distriktsskolen');
DECLARE @stt_oensket    INT = (SELECT skoletilbudstype_id FROM [dsa].[Skoletilbudstype] WHERE skoletilbudstype_tekst = N'Optaget på ønsket skole');
DECLARE @stt_soeskende  INT = (SELECT skoletilbudstype_id FROM [dsa].[Skoletilbudstype] WHERE skoletilbudstype_tekst = N'Optaget ønsket skole pba. søskendegaranti');
DECLARE @stt_henvist    INT = (SELECT skoletilbudstype_id FROM [dsa].[Skoletilbudstype] WHERE skoletilbudstype_tekst = N'Henvist til anden skole end distriktsskolen');
DECLARE @stt_udsat      INT = (SELECT skoletilbudstype_id FROM [dsa].[Skoletilbudstype] WHERE skoletilbudstype_tekst = N'Skolegangsudsat');

DECLARE @aa_ny_screening INT = (SELECT aendringsaarsag_id FROM [dsa].[Aendringsaarsag] WHERE aendringsaarsag_tekst = N'Ny screening uge 2-6');
DECLARE @aa_adresse      INT = (SELECT aendringsaarsag_id FROM [dsa].[Aendringsaarsag] WHERE aendringsaarsag_tekst = N'Adresseflyt / skoledistrikt ændret');
DECLARE @aa_modersmaal   INT = (SELECT aendringsaarsag_id FROM [dsa].[Aendringsaarsag] WHERE aendringsaarsag_tekst = N'Ændring i modersmål');
DECLARE @aa_skoleoenske  INT = (SELECT aendringsaarsag_id FROM [dsa].[Aendringsaarsag] WHERE aendringsaarsag_tekst = N'Skoleønske ændret eller slettet');

-- Main campus per school code, for the school offers below.
DECLARE @mat_soendervang INT = (SELECT matrikel_id FROM [dsa].[Skolematrikel] WHERE skolekode = 751044 AND er_matrikel_hovedadresse = 1);
DECLARE @mat_engdal      INT = (SELECT matrikel_id FROM [dsa].[Skolematrikel] WHERE skolekode = 751008 AND er_matrikel_hovedadresse = 1);
DECLARE @mat_samsoe      INT = (SELECT matrikel_id FROM [dsa].[Skolematrikel] WHERE skolekode = 751036 AND er_matrikel_hovedadresse = 1);
DECLARE @mat_hasle       INT = (SELECT matrikel_id FROM [dsa].[Skolematrikel] WHERE skolekode = 751015 AND er_matrikel_hovedadresse = 1);
DECLARE @mat_moellevang  INT = (SELECT matrikel_id FROM [dsa].[Skolematrikel] WHERE skolekode = 751025 AND er_matrikel_hovedadresse = 1);

DECLARE @at_oprettet  INT = (SELECT type_id FROM [dsa].[SagsaktivitetType] WHERE type_kode = N'sag_oprettet');
DECLARE @at_kommentar INT = (SELECT type_id FROM [dsa].[SagsaktivitetType] WHERE type_kode = N'kommentar');
DECLARE @at_brev      INT = (SELECT type_id FROM [dsa].[SagsaktivitetType] WHERE type_kode = N'brev_afsendt');
DECLARE @at_afsluttet INT = (SELECT type_id FROM [dsa].[SagsaktivitetType] WHERE type_kode = N'sag_afsluttet');

IF @fagomraade_sb IS NULL OR @status_ikke_screenet IS NULL OR @status_afsluttet IS NULL
   OR @stt_udsat IS NULL OR @aa_adresse IS NULL OR @at_oprettet IS NULL
   OR @mat_soendervang IS NULL OR @mat_moellevang IS NULL
BEGIN
    ROLLBACK TRANSACTION;
    RAISERROR('STOPPET: opslagsdata mangler. Koer seed_lookup_data.sql foerst.', 16, 1);
    RETURN;
END;


/* ------------------------------------------------------------
   3. Addresses (fictional numbers and ids)
------------------------------------------------------------ */

INSERT INTO [dsa].[Adresse] (adresse_id, adresse_tekst, latitude, longitude) VALUES
    (N'0d5b7a1e-1111-4a6e-9c01-000000000001', N'Hovedgaden 112, 8220 Brabrand',       56.1531, 10.1080),
    (N'0d5b7a1e-1111-4a6e-9c01-000000000002', N'Søndervangs Allé 7, 8260 Viby J',      56.1222, 10.1520),
    (N'0d5b7a1e-1111-4a6e-9c01-000000000003', N'Gudrunsvej 61, 8220 Brabrand',         56.1560, 10.1290),
    (N'0d5b7a1e-1111-4a6e-9c01-000000000004', N'Bispehavevej 33, 8210 Aarhus V',       56.1700, 10.1700),
    (N'0d5b7a1e-1111-4a6e-9c01-000000000005', N'Jettesvej 19, 8220 Brabrand',          56.1505, 10.1205),
    (N'0d5b7a1e-1111-4a6e-9c01-000000000006', N'Tranekærvej 4, 8240 Risskov',          56.1990, 10.2260),
    (N'0d5b7a1e-1111-4a6e-9c01-000000000007', N'Rymarksvej 50, 8260 Viby J',           56.1230, 10.1610),
    (N'0d5b7a1e-1111-4a6e-9c01-000000000008', N'Vestergade 70, 8000 Aarhus C',         56.1572, 10.2040),
    (N'0d5b7a1e-1111-4a6e-9c01-000000000009', N'Edwin Rahrs Vej 90, 8220 Brabrand',    56.1480, 10.1150);

PRINT CONCAT('Adresse: ', @@ROWCOUNT, ' row(s).');


/* ------------------------------------------------------------
   4. Children (fictional CPR; born 2020 for skoleaar 2026, 2019 for the
      postponed child) and their custody holders
------------------------------------------------------------ */

INSERT INTO [dsa].[Elev]
    (cpr, adresseringsnavn, navne_adresse_beskyttelse, adresse_id, koen, modersmaal,
     distriktsskolekode, skolekode, sprogstoettebehov, ppr_status, tilflyttet_dk_dato)
VALUES
    ('1203204102', N'Amira Hassan',     0, N'0d5b7a1e-1111-4a6e-9c01-000000000001', N'Pige',   N'Arabisk',   751008, NULL, NULL, 0, NULL),
    ('0507204113', N'Yusuf Ali',        0, N'0d5b7a1e-1111-4a6e-9c01-000000000002', N'Dreng',  N'Somali',    751044, NULL, NULL, 0, NULL),
    ('2101204124', N'Leyla Mohammed',   0, N'0d5b7a1e-1111-4a6e-9c01-000000000003', N'Pige',   N'Kurdisk',   751014, NULL, NULL, 0, NULL),
    ('1409204135', N'Omar Abdi',        0, N'0d5b7a1e-1111-4a6e-9c01-000000000002', N'Dreng',  N'Somali',    751044, NULL, NULL, 0, NULL),
    ('3006204146', N'Sara Nguyen',      0, N'0d5b7a1e-1111-4a6e-9c01-000000000004', N'Pige',   N'Vietnamesisk', 751025, NULL, NULL, 0, NULL),
    ('0811204157', N'Ivan Petrenko',    0, N'0d5b7a1e-1111-4a6e-9c01-000000000006', N'Dreng',  N'Ukrainsk',  751042, NULL, NULL, 0, '2025-03-01'),
    ('1702204168', N'Hana Kovač',       0, N'0d5b7a1e-1111-4a6e-9c01-000000000005', N'Pige',   N'Bosnisk',   751008, NULL, NULL, 0, NULL),
    ('2512204179', N'Mustafa Yilmaz',   0, N'0d5b7a1e-1111-4a6e-9c01-000000000007', N'Dreng',  N'Tyrkisk',   751044, NULL, NULL, 0, NULL),
    ('0904204180', N'Zainab Ahmed',     0, N'0d5b7a1e-1111-4a6e-9c01-000000000009', N'Pige',   N'Urdu',      751014, NULL, NULL, 0, NULL),
    ('1910204191', N'Elias Haddad',     0, N'0d5b7a1e-1111-4a6e-9c01-000000000008', N'Dreng',  N'Arabisk',   751023, NULL, NULL, 0, NULL),
    ('0206204202', N'Maryam Rahimi',    0, N'0d5b7a1e-1111-4a6e-9c01-000000000003', N'Pige',   N'Dari',      751014, NULL, NULL, 0, NULL),
    ('2311194213', N'Tomas Novák',      0, N'0d5b7a1e-1111-4a6e-9c01-000000000004', N'Dreng',  N'Tjekkisk',  751025, NULL, NULL, 0, NULL),
    ('1108204224', N'Aya Saleh',        0, N'0d5b7a1e-1111-4a6e-9c01-000000000001', N'Pige',   N'Arabisk',   751008, NULL, NULL, 0, NULL),
    ('2804204235', N'Daniel Osei',      0, N'0d5b7a1e-1111-4a6e-9c01-000000000007', N'Dreng',  N'Twi',       751044, NULL, NULL, 1, NULL);

PRINT CONCAT('Elev: ', @@ROWCOUNT, ' row(s).');

-- Custody holders (R1 / R2). Omar and Yusuf share a mother: siblings.
INSERT INTO [dsa].[Foraelder]
    (cpr_foraelder, cpr_elev, adresseringsnavn, navne_adresse_beskyttelse, maa_vide_barns_adresse, adresse_id, relation)
VALUES
    ('0402881234', '1203204102', N'Nadia Hassan',     0, 1, N'0d5b7a1e-1111-4a6e-9c01-000000000001', N'Mor'),
    ('1709851235', '1203204102', N'Karim Hassan',     0, 1, N'0d5b7a1e-1111-4a6e-9c01-000000000001', N'Far'),
    ('2306901246', '0507204113', N'Fadumo Ali',       0, 1, N'0d5b7a1e-1111-4a6e-9c01-000000000002', N'Mor'),
    ('2306901246', '1409204135', N'Fadumo Ali',       0, 1, N'0d5b7a1e-1111-4a6e-9c01-000000000002', N'Mor'),
    ('1012871258', '2101204124', N'Rojda Mohammed',   0, 1, N'0d5b7a1e-1111-4a6e-9c01-000000000003', N'Mor'),
    ('0703891260', '3006204146', N'Linh Nguyen',      0, 1, N'0d5b7a1e-1111-4a6e-9c01-000000000004', N'Mor'),
    ('1505861271', '0811204157', N'Olena Petrenko',   0, 1, N'0d5b7a1e-1111-4a6e-9c01-000000000006', N'Mor'),
    ('2908841282', '1702204168', N'Amra Kovač',       0, 1, N'0d5b7a1e-1111-4a6e-9c01-000000000005', N'Mor'),
    ('0101831293', '2512204179', N'Emre Yilmaz',      0, 1, N'0d5b7a1e-1111-4a6e-9c01-000000000007', N'Far'),
    ('1811921304', '0904204180', N'Ayesha Ahmed',     0, 1, N'0d5b7a1e-1111-4a6e-9c01-000000000009', N'Mor'),
    ('0609871315', '1910204191', N'Rami Haddad',      0, 1, N'0d5b7a1e-1111-4a6e-9c01-000000000008', N'Far'),
    ('2002901326', '0206204202', N'Shirin Rahimi',    0, 1, N'0d5b7a1e-1111-4a6e-9c01-000000000003', N'Mor'),
    ('1306881337', '2311194213', N'Petra Nováková',   0, 1, N'0d5b7a1e-1111-4a6e-9c01-000000000004', N'Mor'),
    ('0410911348', '1108204224', N'Huda Saleh',       0, 1, N'0d5b7a1e-1111-4a6e-9c01-000000000001', N'Mor'),
    ('2707861359', '2804204235', N'Kwame Osei',       0, 1, N'0d5b7a1e-1111-4a6e-9c01-000000000007', N'Far');

PRINT CONCAT('Foraelder: ', @@ROWCOUNT, ' row(s).');


/* ------------------------------------------------------------
   5. Skolebegynder cases

   All inserted as "Ikke screenet"; the procedure in step 7 derives the
   real status from the data. Only the Afsluttet cases are set by hand,
   because that status is a caseworker's decision.
------------------------------------------------------------ */

INSERT INTO [dsa].[Skolebegynder]
    (cpr, skoleaar, status_id, modtaget_tidspunkt,
     screeningsdato, navn_konsulent, alder_mdr, gennemfoert, afbrudt,
     of_percentil, sf_percentil, samlet_resultat, puf_screeningsresultat, sprogstoettebehov,
     dagtilbud, dagtilbud_afdeling, oensket_skolekode, soeskende_skolekode, ansoeger_anden_skole,
     skoletilbud_matrikel_id, skoletilbudstype_id, krav_paa_befordring, bemaerkning, sagsbehandlingsdato,
     afsluttet_dato, created_by, updated_by)
VALUES
    -- Under behandling; wants another school than the district school -> skoler_afviger
    ('1203204102', 2026, @status_ikke_screenet, '2025-10-21T09:00:00',
     '2026-01-14', N'Testkonsulent A', 70, 1, 0,  22, 18, N'Fokuseret indsats', N'Sprogstøttebehov', 1,
     N'Børnehuset Hovedgaden', N'Afd. Solsikken', 751014, NULL, 1,
     NULL, NULL, NULL, NULL, NULL, NULL, N'Testdata', N'Testdata'),

    -- Under behandling
    ('0507204113', 2026, @status_ikke_screenet, '2025-10-21T09:00:00',
     '2026-01-15', N'Testkonsulent A', 67, 1, 0,  45, 51, N'Generel indsats', N'Intet sprogstøttebehov', 0,
     N'Vuggestuen Søndervang', NULL, 751044, NULL, 0,
     NULL, NULL, NULL, NULL, NULL, NULL, N'Testdata', N'Testdata'),

    -- Nærmere afklaring: screened, PUF result missing
    ('2101204124', 2026, @status_ikke_screenet, '2025-10-21T09:00:00',
     '2026-01-20', N'Testkonsulent B', 69, 1, 0,  8, 11, N'Særlig indsats', NULL, NULL,
     N'Børnehaven Gudrun', NULL, 751014, NULL, 0,
     NULL, NULL, NULL, NULL, NULL, NULL, N'Testdata', N'Testdata'),

    -- Ikke screenet: screening was interrupted, so there is no result yet.
    -- Sibling of Yusuf, who also wants Søndervangskolen.
    ('1409204135', 2026, @status_ikke_screenet, '2025-10-21T09:00:00',
     '2026-01-15', N'Testkonsulent A', 66, 0, 1,  NULL, NULL, NULL, NULL, NULL,
     N'Vuggestuen Søndervang', NULL, 751044, 751044, 0,
     NULL, NULL, NULL, N'Screening afbrudt – barnet var træt. Ny tid aftales.', NULL, NULL, N'Testdata', N'Testdata'),

    -- Ikke screenet
    ('3006204146', 2026, @status_ikke_screenet, '2025-10-21T09:00:00',
     NULL, NULL, NULL, NULL, NULL,  NULL, NULL, NULL, NULL, NULL,
     N'Dagplejen Aarhus V', NULL, 751025, NULL, 0,
     NULL, NULL, NULL, NULL, NULL, NULL, N'Testdata', N'Testdata'),

    -- Ikke screenet; moved to Denmark in 2025
    ('0811204157', 2026, @status_ikke_screenet, '2026-01-26T08:00:00',
     NULL, NULL, NULL, NULL, NULL,  NULL, NULL, NULL, NULL, NULL,
     N'Børnehuset Risskov', NULL, 751042, NULL, 0,
     NULL, NULL, NULL, NULL, NULL, NULL, N'Testdata', N'Testdata'),

    -- Under behandling; arrived on the list after it was drawn (Ændringer: ny screening)
    ('1702204168', 2026, @status_ikke_screenet, '2026-02-02T08:00:00',
     '2026-02-03', N'Testkonsulent B', 71, 1, 0,  35, 29, N'Fokuseret indsats', N'Sprogstøttebehov', 1,
     N'Børnehuset Jettesvej', NULL, 751008, NULL, 0,
     NULL, NULL, NULL, NULL, NULL, NULL, N'Testdata', N'Testdata'),

    -- Skoletilbud: district school
    ('2512204179', 2026, @status_ikke_screenet, '2025-10-21T09:00:00',
     '2026-01-16', N'Testkonsulent A', 68, 1, 0,  55, 60, N'Generel indsats', N'Intet sprogstøttebehov', 0,
     N'Børnehaven Rymarken', NULL, 751044, NULL, 0,
     @mat_soendervang, @stt_distrikt, 0, NULL, '2026-03-02', NULL, N'Testdata', N'Testdata'),

    -- Skoletilbud: referred to another school -> transport; address changed since (Ændringer)
    ('0904204180', 2026, @status_ikke_screenet, '2025-10-21T09:00:00',
     '2026-01-21', N'Testkonsulent B', 70, 1, 0,  12, 9, N'Særlig indsats', N'Sprogstøttebehov', 1,
     N'Børnehaven Edwin Rahr', NULL, 751014, NULL, 0,
     @mat_engdal, @stt_henvist, 1, N'Henvist pga. kapacitet i modtagelsesklasse.', '2026-03-04', NULL, N'Testdata', N'Testdata'),

    -- Afsluttet: wanted school granted, letter sent
    ('1910204191', 2026, @status_afsluttet, '2025-10-21T09:00:00',
     '2026-01-13', N'Testkonsulent A', 72, 1, 0,  60, 58, N'Generel indsats', N'Intet sprogstøttebehov', 0,
     N'Børnehuset Vestergade', NULL, 751036, NULL, 1,
     @mat_samsoe, @stt_oensket, 0, NULL, '2026-02-24', '2026-04-10', N'Testdata', N'Testdata'),

    -- Afsluttet: sibling guarantee
    ('0206204202', 2026, @status_afsluttet, '2025-10-21T09:00:00',
     '2026-01-20', N'Testkonsulent B', 69, 1, 0,  40, 37, N'Fokuseret indsats', N'Sprogstøttebehov', 1,
     N'Børnehaven Gudrun', NULL, 751015, 751015, 1,
     @mat_hasle, @stt_soeskende, 0, NULL, '2026-02-26', '2026-04-10', N'Testdata', N'Testdata'),

    -- Tomas, year 1 (2025): school start postponed, case closed
    ('2311194213', 2025, @status_afsluttet, '2024-10-22T09:00:00',
     '2025-01-22', N'Testkonsulent A', 62, 1, 0,  5, 7, N'Særlig indsats', N'Sprogstøttebehov', 1,
     N'Dagplejen Aarhus V', NULL, 751025, NULL, 0,
     @mat_moellevang, @stt_udsat, 0, N'Skolestart udsat et år efter aftale med forældre.', '2025-02-28', '2025-04-11', N'Testdata', N'Testdata'),

    -- Tomas, year 2 (2026): a skolebegynder again — same CPR, new case
    ('2311194213', 2026, @status_ikke_screenet, '2025-10-21T09:00:00',
     '2026-01-22', N'Testkonsulent A', 74, 1, 0,  31, 26, N'Fokuseret indsats', N'Sprogstøttebehov', 1,
     N'Dagplejen Aarhus V', NULL, 751025, NULL, 0,
     NULL, NULL, NULL, NULL, NULL, NULL, N'Testdata', N'Testdata'),

    -- Nærmere afklaring; mother tongue changed (Ændringer)
    ('1108204224', 2026, @status_ikke_screenet, '2025-10-21T09:00:00',
     '2026-01-27', N'Testkonsulent B', 65, 1, 0,  27, 33, N'Fokuseret indsats', NULL, NULL,
     N'Børnehuset Hovedgaden', N'Afd. Solsikken', 751008, NULL, 0,
     NULL, NULL, NULL, NULL, NULL, NULL, N'Testdata', N'Testdata'),

    -- Ikke screenet; PPR involved
    ('2804204235', 2026, @status_ikke_screenet, '2025-10-21T09:00:00',
     NULL, NULL, NULL, NULL, NULL,  NULL, NULL, NULL, NULL, NULL,
     N'Børnehaven Rymarken', NULL, 751044, NULL, 0,
     NULL, NULL, NULL, N'Sag hos PPR – afvent vurdering før screening.', NULL, NULL, N'Testdata', N'Testdata');

PRINT CONCAT('Skolebegynder: ', @@ROWCOUNT, ' row(s).');


/* ------------------------------------------------------------
   6. Changes (Ændringer tab) and case log
------------------------------------------------------------ */

INSERT INTO [dsa].[Skolebegynder_Aendring]
    (skolebegynder_id, aendringsaarsag_id, beskrivelse, registreret_tidspunkt, haandteret, haandteret_af, haandteret_tidspunkt)
SELECT sb.skolebegynder_id, v.aarsag, v.beskrivelse, v.registreret, v.haandteret, v.af, v.tidspunkt
FROM (VALUES
    ('1702204168', 2026, @aa_ny_screening, N'Screenet 03-02-2026, efter at listen blev trukket', CAST('2026-02-03T07:00:00' AS DATETIME2), 0, NULL,           CAST(NULL AS DATETIME2)),
    ('0904204180', 2026, @aa_adresse,      N'Adresse: Edwin Rahrs Vej 90 -> Tranekærvej 4',       CAST('2026-03-10T07:00:00' AS DATETIME2), 0, NULL,           CAST(NULL AS DATETIME2)),
    ('1108204224', 2026, @aa_modersmaal,   N'Modersmål: Dansk -> Arabisk',                         CAST('2026-02-05T07:00:00' AS DATETIME2), 0, NULL,           CAST(NULL AS DATETIME2)),
    ('1203204102', 2026, @aa_skoleoenske,  N'Ønsket skole: Engdalskolen -> Sødalskolen',           CAST('2026-01-30T07:00:00' AS DATETIME2), 1, N'Testdata',    CAST('2026-02-02T10:15:00' AS DATETIME2))
) AS v (cpr, skoleaar, aarsag, beskrivelse, registreret, haandteret, af, tidspunkt)
JOIN [dsa].[Skolebegynder] sb ON sb.cpr = v.cpr AND sb.skoleaar = v.skoleaar;

PRINT CONCAT('Skolebegynder_Aendring: ', @@ROWCOUNT, ' row(s).');

-- One "sag_oprettet" per case, then a few events on the closed ones.
INSERT INTO [dsa].[Sagsaktivitet]
    (cpr, aktivitetstype, kommentar, udfoert_af, oprettet_tidspunkt, fagomraade_id, relateret_sag_id, aktivitetstype_id)
SELECT sb.cpr, N'Sag oprettet', NULL, N'System', sb.modtaget_tidspunkt, @fagomraade_sb, sb.skolebegynder_id, @at_oprettet
FROM   [dsa].[Skolebegynder] sb;

INSERT INTO [dsa].[Sagsaktivitet]
    (cpr, aktivitetstype, kommentar, udfoert_af, oprettet_tidspunkt, fagomraade_id, relateret_sag_id, aktivitetstype_id)
SELECT sb.cpr, v.aktivitetstype, v.kommentar, N'Testdata', v.tidspunkt, @fagomraade_sb, sb.skolebegynder_id, v.type_id
FROM (VALUES
    ('1910204191', 2026, N'Brev afsendt',  N'Afgørelsesbrev sendt via Digital Post', CAST('2026-04-10T09:30:00' AS DATETIME2), @at_brev),
    ('1910204191', 2026, N'Sag afsluttet', NULL,                                     CAST('2026-04-10T09:31:00' AS DATETIME2), @at_afsluttet),
    ('0206204202', 2026, N'Brev afsendt',  N'Afgørelsesbrev sendt via Digital Post', CAST('2026-04-10T09:40:00' AS DATETIME2), @at_brev),
    ('0206204202', 2026, N'Sag afsluttet', NULL,                                     CAST('2026-04-10T09:41:00' AS DATETIME2), @at_afsluttet),
    ('2311194213', 2025, N'Kommentar',     N'Forældre ønsker udsat skolestart; PPR enig.', CAST('2025-02-20T13:00:00' AS DATETIME2), @at_kommentar),
    ('2311194213', 2025, N'Brev afsendt',  N'Brev om udsat skolestart sendt',        CAST('2025-04-11T09:00:00' AS DATETIME2), @at_brev),
    ('2311194213', 2025, N'Sag afsluttet', NULL,                                     CAST('2025-04-11T09:01:00' AS DATETIME2), @at_afsluttet)
) AS v (cpr, skoleaar, aktivitetstype, kommentar, tidspunkt, type_id)
JOIN [dsa].[Skolebegynder] sb ON sb.cpr = v.cpr AND sb.skoleaar = v.skoleaar;

PRINT 'Sagsaktivitet seeded.';


/* ------------------------------------------------------------
   7. Derive statuses — exercises the status rule
------------------------------------------------------------ */

EXEC [dsa].[usp_recalculate_skolebegynder_status] @today = '2026-03-15';


/* ------------------------------------------------------------
   8. Preview — runs before the COMMIT/ROLLBACK decision
------------------------------------------------------------ */

SELECT status_tekst, COUNT(*) AS antal
FROM   [dsa].[view_Skolebegyndere]
GROUP BY status_tekst, status_sortering
ORDER BY status_sortering;

SELECT skolebegynder_id, skoleaar, navn, status_tekst, distriktsskole, oensket_skole,
       skoletilbud_matrikel, skoletilbudstype_tekst, skoler_afviger, aabne_aendringer
FROM   [dsa].[view_Skolebegyndere]
ORDER BY skoleaar, status_sortering, navn;

SELECT * FROM [dsa].[view_Skolebegynder_Aendringer] ORDER BY registreret_tidspunkt;


-- Change to COMMIT once the preview above looks right.
ROLLBACK TRANSACTION;
-- COMMIT TRANSACTION;
