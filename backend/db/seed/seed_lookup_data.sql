/* ============================================================
   Lookup / reference data for the dsa schema.

   Everything the application needs in order to run, and nothing about any
   individual child: areas, statuses, skoletilbudstyper, ændringsårsager,
   sagsaktivitet codes and school campuses (Skolematrikel). No Elev,
   Foraelder, Skolebegynder or Sagsaktivitet rows are created here — for
   those, see seed_test_data.sql, which is test data and is NOT for a real
   environment.

   Modelled on befordringssystemet's seed_lookup_data.sql, and like it the
   file is the DEFINITION of what the lookups contain, not a list of
   additions: it CLEARS every lookup table, reseeds the identities and
   inserts the whole set. A row deleted from this file disappears from the
   database on the next run.

   WHAT THIS COSTS: identity values change. Every lookup id is reassigned
   from 1 in the order the rows appear below, so anything holding a foreign
   key into these tables must be gone first. The guard below refuses to run
   while such rows exist rather than letting the deletes fail half way.

   NOT SEEDED YET, deliberately: Skoleplaceringsaarsag and Brevskabelon. The
   tables exist, but PUF has not defined their values. Both show 0 rows in
   the verification at the bottom until they are added here.

   Runs inside a transaction that ROLLBACKs by default — change the final
   ROLLBACK to COMMIT once the previewed counts look correct. The
   verification selects run BEFORE that decision, so they show what the
   commit would leave behind.

   Requires migration 001.
   ============================================================ */

USE [DSA];

SET NOCOUNT ON;

-- Any error aborts the batch and rolls the transaction back, so a failure
-- part-way cannot leave some lookup tables populated and others empty.
SET XACT_ABORT ON;

BEGIN TRANSACTION;


/* ------------------------------------------------------------
   0. Refuse to run while cases reference the lookups

   Reassigning every lookup id under a live Skolebegynder would silently
   repoint it at a different status or skoletilbudstype.
------------------------------------------------------------ */

DECLARE @blokerende NVARCHAR(MAX) = N'';

SELECT @blokerende = STRING_AGG(x.tabel + N' (' + CAST(x.antal AS NVARCHAR(20)) + N')', N', ')
FROM (
    SELECT N'Skolebegynder' AS tabel, COUNT(*) AS antal FROM [dsa].[Skolebegynder]
    UNION ALL SELECT N'Skolebegynder_Aendring', COUNT(*) FROM [dsa].[Skolebegynder_Aendring]
    UNION ALL SELECT N'Skoleskifter', COUNT(*) FROM [dsa].[Skoleskifter]   -- migration 004
) x
WHERE x.antal > 0;

IF @blokerende <> N''
BEGIN
    ROLLBACK TRANSACTION;

    RAISERROR(
        N'Cannot reseed the lookup tables: %s still reference them. This script reassigns every lookup id from 1, which would repoint those rows at different statuses and skoletilbudstyper. Clear the case data first (seed_test_data.sql does, on a dev database).',
        16, 1, @blokerende
    );

    RETURN;
END;


/* ------------------------------------------------------------
   1. Release references into the lookups about to be cleared

   Same reasoning as befordringssystemet: Sagsaktivitet.aktivitetstype still
   carries the display text, so clearing the type id loses nothing a reader
   needs, and the ids are not stable across a reseed anyway.
------------------------------------------------------------ */

UPDATE [dsa].[Sagsaktivitet]
SET    aktivitetstype_id = NULL
WHERE  aktivitetstype_id IS NOT NULL;

PRINT CONCAT('Released activity types on ', @@ROWCOUNT, ' sagsaktivitet(er).');

UPDATE [dsa].[Sagsaktivitet]
SET    fagomraade_id = NULL
WHERE  fagomraade_id IS NOT NULL;

PRINT CONCAT('Released fagomraader on ', @@ROWCOUNT, ' sagsaktivitet(er).');


/* ------------------------------------------------------------
   2. Clear the identity lookups, then restart their identities

   Children before parents: Status, Skoletilbudstype and Brevskabelon point
   at Fagomraade, so Fagomraade goes last.
------------------------------------------------------------ */

DELETE FROM [dsa].[Aendringsaarsag];
DELETE FROM [dsa].[Brevskabelon];
DELETE FROM [dsa].[SagsaktivitetType];
DELETE FROM [dsa].[Skolematrikel];
DELETE FROM [dsa].[Skoleplaceringsaarsag];
DELETE FROM [dsa].[Skoletilbudstype];
DELETE FROM [dsa].[Status];
DELETE FROM [dsa].[Fagomraade];

PRINT 'Cleared lookup data.';

/* RESEED, 0 rather than a bare RESEED: on an emptied table a bare RESEED
   leaves the current identity where it was. DBCC CHECKIDENT is NOT
   transactional — the repair block after the transaction puts every counter
   back in step whichever way the transaction ends.

   DSA: only tables that have used their identity are reseeded. On a table
   that has NEVER held a row, RESEED 0 makes the first insert get id 0, not 1
   — invisible in befordringssystemet, whose tables are always populated, but
   exactly the state of a freshly created DSA database. A never-used table
   needs no reseed: its first insert gets 1 anyway. */
IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'[dsa].[Aendringsaarsag]')) IS NOT NULL
    DBCC CHECKIDENT ('[dsa].[Aendringsaarsag]', RESEED, 0);
IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'[dsa].[Brevskabelon]')) IS NOT NULL
    DBCC CHECKIDENT ('[dsa].[Brevskabelon]', RESEED, 0);
IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'[dsa].[Fagomraade]')) IS NOT NULL
    DBCC CHECKIDENT ('[dsa].[Fagomraade]', RESEED, 0);
IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'[dsa].[SagsaktivitetType]')) IS NOT NULL
    DBCC CHECKIDENT ('[dsa].[SagsaktivitetType]', RESEED, 0);
IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'[dsa].[Skolematrikel]')) IS NOT NULL
    DBCC CHECKIDENT ('[dsa].[Skolematrikel]', RESEED, 0);
IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'[dsa].[Skoleplaceringsaarsag]')) IS NOT NULL
    DBCC CHECKIDENT ('[dsa].[Skoleplaceringsaarsag]', RESEED, 0);
IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'[dsa].[Skoletilbudstype]')) IS NOT NULL
    DBCC CHECKIDENT ('[dsa].[Skoletilbudstype]', RESEED, 0);
IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'[dsa].[Status]')) IS NOT NULL
    DBCC CHECKIDENT ('[dsa].[Status]', RESEED, 0);


PRINT 'Seeding lookup data...';
PRINT '';


-- Fagomraade  (5 rows)
--
-- The areas on the front page, in the same order (sortering). "Dataudtræk"
-- is a page, not an area of case work, so it is not here.
INSERT INTO [dsa].[Fagomraade] (fagomraade_tekst, beskrivelse, aktiv, sortering)
SELECT v.fagomraade_tekst, v.beskrivelse, v.aktiv, v.sortering
FROM (VALUES
    (N'Nyankomne i modtagelsesklasse', N'Ansøgninger om modtagelsesklasse',                      1, 10),
    (N'Skoleskiftere og tilflyttere',  N'Skoleskift og tilflytning med dansk som andetsprog',    1, 20),
    (N'Skolebegynderscreeninger',      N'Sprogscreening og skoleplacering af skolebegyndere',    1, 30),
    (N'Udslusning basisundervisning',  N'Udslusning fra modtagelsesklasse til almindelig klasse', 1, 40),
    (N'Sproglig udvikling',            N'Sprog+ vurderinger',                                     1, 50)
) AS v (fagomraade_tekst, beskrivelse, aktiv, sortering);
PRINT CONCAT('Fagomraade: ', @@ROWCOUNT, ' row(s) inserted.');


-- Looked up by name rather than by id, so the rows below do not depend on
-- the order of the inserts above.
DECLARE @skolebegyndere INT = (
    SELECT fagomraade_id FROM [dsa].[Fagomraade]
    WHERE  fagomraade_tekst = N'Skolebegynderscreeninger'
);


-- Status  (5 rows, skolebegyndere)
--
-- The caseworkers' own statuses (pre-meeting 2026-10-21, migration 002),
-- which replaced the status legend in the skolebegynder UI sketch. The first four are
-- AUTOMATIC: usp_recalculate_skolebegynder_status sets them from the case's
-- data. Only Afsluttet is set by a person, and the procedure never moves a
-- case out of it — reopening is a deliberate act by a caseworker.
INSERT INTO [dsa].[Status] (status_tekst, beskrivelse, aktiv, fagomraade_id, sortering)
SELECT v.status_tekst, v.beskrivelse, v.aktiv, @skolebegyndere, v.sortering
FROM (VALUES
    (N'Potentiel skolestarter', N'Automatisk: på etableringslisten; ingen booket screening og intet resultat', 1, 10),
    (N'Tid booket',             N'Automatisk: forældrene har booket en tid til sprogscreening',               1, 20),
    (N'Screening afviklet',     N'Automatisk: der er et resultat af sprogscreeningen',                         1, 30),
    (N'Skoleplaceret',          N'Automatisk: skoletilbud og skoletilbudstype er udfyldt',                     1, 40),
    (N'Afsluttet',          N'Manuelt: sagen er afsluttet og brevet er sendt',                     1, 50)
) AS v (status_tekst, beskrivelse, aktiv, sortering);
PRINT CONCAT('Status: ', @@ROWCOUNT, ' row(s) inserted.');


-- Status  (7 rows, skoleskiftere og tilflyttere — migration 004)
--
-- From the field list. Ny, Afventer sprogvurdering and Sendt til PPR are set
-- by a caseworker; usp_recalculate_skoleskifter_status derives the rest, and
-- closes a case the day after its offer date.
DECLARE @skoleskiftere INT = (
    SELECT fagomraade_id FROM [dsa].[Fagomraade]
    WHERE  fagomraade_tekst = N'Skoleskiftere og tilflyttere'
);

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
) AS v (status_tekst, beskrivelse, sortering);
PRINT CONCAT('Status (skoleskiftere): ', @@ROWCOUNT, ' row(s) inserted.');


-- Skoletilbudstype  (11 rows, shared: fagomraade_id NULL)
--
-- The list from the field inventory ("Data til DSA-databaser"), identical
-- for skolebegyndere and skoleskiftere. Nyankomne and udslusning get lists
-- of their own, scoped to their area, when those areas are built.
INSERT INTO [dsa].[Skoletilbudstype] (skoletilbudstype_tekst, beskrivelse, aktiv, fagomraade_id, sortering)
SELECT v.skoletilbudstype_tekst, NULL, 1, NULL, v.sortering
FROM (VALUES
    (N'Optaget på distriktsskolen',                   10),
    (N'Optaget på ønsket skole',                      20),
    (N'Optaget ønsket skole pba. søskendegaranti',    30),
    (N'Henvist til anden skole end distriktsskolen',  40),
    (N'Afslag ønsket skole',                          50),
    (N'Fortsætter nuværende skole',                   60),
    (N'Specialklasse',                                70),
    (N'Privatskole',                                  80),
    (N'Skolegangsudsat',                              90),
    (N'Flyttet ud af kommunen',                      100),
    (N'Ansøgning annulleret',                        110)
) AS v (skoletilbudstype_tekst, sortering);
PRINT CONCAT('Skoletilbudstype: ', @@ROWCOUNT, ' row(s) inserted.');


-- Aendringsaarsag  (7 rows)
--
-- From the "Ændringer" tab in the skolebegynder sketch, plus forældremyndighed
-- from the field inventory's ændringsårsag list.
INSERT INTO [dsa].[Aendringsaarsag] (aendringsaarsag_tekst, beskrivelse, aktiv, sortering)
SELECT v.aendringsaarsag_tekst, v.beskrivelse, 1, v.sortering
FROM (VALUES
    (N'Ny screening uge 2-6',                N'Barnet er screenet efter at listen over skolebegyndere blev trukket', 10),
    (N'Sprogscreenet uden skoleplacering',   N'Der foreligger et screeningsresultat, men intet skoletilbud',          20),
    (N'Adresseflyt / skoledistrikt ændret',  N'Barnets adresse eller distriktsskole er ændret',                      30),
    (N'Skoleønske ændret eller slettet',     N'Det ønskede skolevalg er ændret eller fjernet',                       40),
    (N'Aktuel skole for søskende ændret',    N'En søskendes skole er ændret',                                        50),
    (N'Ændring i modersmål',                 N'Barnets registrerede modersmål er ændret',                            60),
    (N'Ændring i forældremyndighed',         N'Forældremyndighedsindehaverne er ændret',                             70)
) AS v (aendringsaarsag_tekst, beskrivelse, sortering);
PRINT CONCAT('Aendringsaarsag: ', @@ROWCOUNT, ' row(s) inserted.');


-- SagsaktivitetType  (9 rows)
--
-- The event kinds in a case's sagsforløb. The application writes type_kode;
-- the frontend styles and groups on the code rather than the Danish text, as
-- in befordringssystemet. "kommentar" is the only user-created kind.
INSERT INTO [dsa].[SagsaktivitetType] (type_kode)
SELECT v.type_kode
FROM (VALUES
    (N'aendring_haandteret'),
    (N'aendring_registreret'),
    (N'brev_afsendt'),
    (N'kommentar'),
    (N'sag_afsluttet'),
    (N'sag_genaabnet'),
    (N'sag_oprettet'),
    (N'skoletilbud_opdateret'),
    (N'status_opdateret')
) AS v (type_kode);
PRINT CONCAT('SagsaktivitetType: ', @@ROWCOUNT, ' row(s) inserted.');


-- DSA: copied verbatim from befordringssystemet's seed_lookup_data.sql, so a
-- matrikel_id means the same campus in both systems. Keep the two in step.
-- Skolematrikel  (56 rows)
INSERT INTO [dsa].[Skolematrikel] (matrikel_navn, matrikel_adresse, skolekode, er_matrikel_hovedadresse, latitude, longitude)
SELECT v.matrikel_navn, v.matrikel_adresse, v.skolekode, v.er_matrikel_hovedadresse, v.latitude, v.longitude
FROM (VALUES
    ('Bakkegårdsskolen',                    'Bjørnshøjvej 1, 8380 Trige',                      751002, 1, 56.253285, 10.149081),
    ('Bavnehøj Skole',                      'Koltvej 19, 21, 8361 Hasselager',                 751016, 1, 56.106589, 10.095978),
    ('Beder Skole',                         'Skoleparken 6, 8330 Beder',                       751004, 1, 56.061574, 10.211609),
    ('Elev Skole',                          'Høvej 10, 8520 Lystrup',                          751006, 1, 56.241190, 10.199622),
    ('Ellevangskolen',                      'Jellebakken 17, 8240 Risskov',                    751003, 1, 56.202644, 10.218707),
    ('Elsted Skole',                        'Elsted Skolevej 6, 8520 Lystrup',                 751007, 1, 56.241526, 10.228948),
    ('Engdalskolen',                        'Hovedgaden 5, 8220 Brabrand',                     751008, 1, 56.152602, 10.109452),
    ('Frederiksbjerg skole',                'Ingerslevs Boulevard 2, 8000 Aarhus C',           751027, 1, 56.145005, 10.197084),
    ('Gammelgaardsskolen',                  'Carit Etlars Vej 31, 8230 Åbyhøj',                751013, 1, 56.159329, 10.157079),
    ('Hasle Skole',                         'Herredsvej 15, 8210 Aarhus V',                    751015, 1, 56.169300, 10.163680),
    ('Holme Skole',                         'Mølleskovvej 11, 8270 Højbjerg',                  751017, 1, 56.116237, 10.178254),
    ('Højvangskolen',                       'Klokkeskovvej 1, 8260 Viby J',                    751018, 1, 56.129903, 10.115003),
    ('Hårup Skole',                         'Salonikivej 14, 8530 Hjortshøj',                  751046, 1, 56.288342, 10.216692),
    ('Kaløvigskolen (Bredevej)',            'Bredevej 2D, 8250 Egå',                           751020, 0, 56.229193, 10.295141),
    ('Kaløvigskolen (Sanatorievej)',        'Sanatorievej 38, 8541 Skødstrup',                 751020, 1, 56.260172, 10.342974),
    ('Kaløvigskolen (Skovager)',            'Skovager 4, 8530 Hjortshøj',                      751020, 0, 56.245661, 10.273222),
    ('Katrinebjergskolen',                  'Katrinebjergvej 60, 8200 Aarhus N',               751019, 1, 56.173827, 10.196322),
    ('Kløverskolen',                        'Karen Blixens Boulevard 59, 8220 Brabrand',       281401, 1, 56.153100, 10.105700),
    ('Kragelundskolen',                     'Aage Jedichs Vej 3, 8270 Højbjerg',               751021, 1, 56.114507, 10.200129),
    ('Langagerskolen (Bøgeskov Høvej)',     'Bøgeskov Høvej 10, 8260 Viby J',                  751090, 1, 56.118367, 10.133548),
    ('Langagerskolen (Kolt Østervej)',      'Kolt Østervej 45, 8361 Hasselager',               751090, 0, 56.109433, 10.075118),
    ('Lisbjergskolen',                      'Jørgen Clevins Gade 31, 8200 Aarhus N',           751022, 1, 56.218634, 10.157948),
    ('Lystrup Skole',                       'Lystrupvej 256, 8520 Lystrup',                    751066, 1, 56.237290, 10.229867),
    ('Læssøesgades Skole',                  'Læssøesgade 24, 8000 Aarhus C',                   751023, 1, 56.146377, 10.188354),
    ('Malling Skole',                       'Lundshøjgårdsvej 19, 8340 Malling',               751024, 1, 56.039315, 10.198617),
    ('Møllevangskolen',                     'Møllevangs Allé 20, 8210 Aarhus V',               751025, 1, 56.164825, 10.184485),
    ('Mårslet Skole',                       'Testrupvej 4, 8320 Mårslet',                      751026, 1, 56.068830, 10.155902),
    ('Netværksskolen',                      'Randersvej 302, 8200 Aarhus N',                   751221, 1, 56.213263, 10.171948),
    ('Næshøjskolen',                        'Gammel Stillingvej 424, 8462 Harlev J',           751055, 1, 56.145839,  9.999646),
    ('Risskov Skole',                       'Vestre Strandallé 97, 8240 Risskov',              751032, 1, 56.192986, 10.229468),
    ('Rosenvangskolen',                     'Rosenvangs Allé 49, 8260 Viby J',                 751033, 1, 56.131271, 10.183323),
    ('Rundhøjskolen',                       'Holmevej 200, 8270 Højbjerg',                     751034, 1, 56.118412, 10.178171),
    ('Sabro-Korsvejskolen',                 'Sabro Skolevej 4, 8471 Sabro',                    751035, 1, 56.211678, 10.025800),
    ('Samsøgades Skole',                    'Ny Munkegade 17, 8000 Aarhus C',                  751036, 1, 56.162449, 10.202540),
    ('Skjoldhøjskolen',                     'Skjoldhøjvej 11, 8381 Tilst',                     751065, 1, 56.174108, 10.113792),
    ('Skovvangskolen',                      'Skovvangsvej 150, 8200 Aarhus N',                 751038, 1, 56.175534, 10.208733),
    ('Skæring Skole',                       'Skæring Skolevej 200, 8250 Egå',                  751056, 1, 56.226157, 10.298083),
    ('Skødstrup Skole',                     'Rosenbakken 4, 8541 Skødstrup',                   751039, 1, 56.271534, 10.308426),
    ('Skåde Skole',                         'Mantziusvej 5, 8270 Højbjerg',                    751040, 1, 56.104037, 10.207346),
    ('Solbjergskolen',                      'Kærgårdsvej 4, 8355 Solbjerg',                    751041, 1, 56.042553, 10.084737),
    ('Stensagerskolen (Janesvej)',          'Janesvej 2, 8220 Brabrand',                       751903, 1, 56.166770, 10.137611),
    ('Stensagerskolen (Stensagervej)',      'Stensagervej 11, 8260 Viby J',                    751903, 0, 56.131239, 10.146707),
    ('Strandskolen',                        'Nellikevej 1, 8240 Risskov',                      751042, 1, 56.200330, 10.245746),
    ('Sygehusundervisning',                 'Palle Juul-Jensens Boulevard 175, 8200 Aarhus N', 751107, 1, 56.190967, 10.165825),
    ('Sødalskolen',                         'Louisevej 29, 8220 Brabrand',                     751014, 1, 56.150375, 10.136786),
    ('Sølystskolen',                        'Egå Havvej 5, 8250 Egå',                          751043, 1, 56.212247, 10.281777),
    ('Søndervangskolen',                    'Søndervangs Allé 40, 8260 Viby J',                751044, 1, 56.111261, 10.149489),
    ('Tilst Skole',                         'Tåstumvænget 8, 8381 Tilst',                      751045, 1, 56.189515, 10.113195),
    ('Tranbjergskolen (Grønløkke Allé)',    'Grønløkke Allé 9, 8310 Tranbjerg J',              280458, 1, 56.094176, 10.124531),
    ('Tranbjergskolen (Kirketorvet)',       'Kirketorvet 22, 8310 Tranbjerg J',                280458, 0, 56.090076, 10.140480),
    ('Vestergårdsskolen (Nordbyvej)',       'Nordbyvej 25, 8260 Viby J',                       751050, 1, 56.129377, 10.156499),
    ('Vestergårdsskolen (Stensagervej)',    'Stensagervej 10, 8260 Viby J',                    751050, 0, 56.130530, 10.148991),
    ('Viby Skole',                          'Kirkevej 2, 8260 Viby J',                         751051, 1, 56.127557, 10.164857),
    ('Virupskolen',                         'Virupvej 75, 8530 Hjortshøj',                     751052, 1, 56.243340, 10.271937),
    ('Vorrevangskolen',                     'Vorregårds Allé 109, 8200 Aarhus N',              751053, 1, 56.185948, 10.199095),
    ('Åby Skole',                           'Åbyvej 80, 8230 Åbyhøj',                          751054, 1, 56.150634, 10.164975)
) AS v (matrikel_navn, matrikel_adresse, skolekode, er_matrikel_hovedadresse, latitude, longitude);
PRINT CONCAT('Skolematrikel: ', @@ROWCOUNT, ' row(s) inserted.');


/* ------------------------------------------------------------
   3. Verification — runs before the COMMIT/ROLLBACK decision
------------------------------------------------------------ */

SELECT 'Fagomraade'              AS lookup_table, COUNT(*) AS antal_rows FROM [dsa].[Fagomraade]
UNION ALL SELECT 'Status',                COUNT(*) FROM [dsa].[Status]
UNION ALL SELECT 'Skoletilbudstype',      COUNT(*) FROM [dsa].[Skoletilbudstype]
UNION ALL SELECT 'Aendringsaarsag',       COUNT(*) FROM [dsa].[Aendringsaarsag]
UNION ALL SELECT 'SagsaktivitetType',     COUNT(*) FROM [dsa].[SagsaktivitetType]
UNION ALL SELECT 'Skolematrikel',         COUNT(*) FROM [dsa].[Skolematrikel]
UNION ALL SELECT 'Skoler (hovedmatrikel)', COUNT(*) FROM [dsa].[Skolematrikel] WHERE er_matrikel_hovedadresse = 1
UNION ALL SELECT 'Skoleplaceringsaarsag *', COUNT(*) FROM [dsa].[Skoleplaceringsaarsag]
UNION ALL SELECT 'Brevskabelon *',        COUNT(*) FROM [dsa].[Brevskabelon];
-- * not seeded yet — values to be defined by PUF.

SELECT s.status_id, s.status_tekst, f.fagomraade_tekst, s.sortering
FROM   [dsa].[Status] s
LEFT JOIN [dsa].[Fagomraade] f ON f.fagomraade_id = s.fagomraade_id
ORDER BY f.sortering, s.sortering;


-- Change to COMMIT once the counts above look right.
ROLLBACK TRANSACTION;
-- COMMIT TRANSACTION;
GO


/* ============================================================
   Put the identity counters back in step with the rows

   DBCC CHECKIDENT is NOT transactional, so after a ROLLBACK the counters are
   at 0 while the old rows are back — the next insert would collide. Setting
   each counter to the table's current MAX is right after a COMMIT too.

   Runs OUTSIDE the transaction deliberately. Do not move it above the
   ROLLBACK/COMMIT.
============================================================ */

USE [DSA];

DECLARE @naeste BIGINT;

-- DSA: guarded on last_value for the reason given in section 2 — reseeding a
-- never-used table to MAX = 0 would make its first insert 0.

IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'[dsa].[Aendringsaarsag]')) IS NOT NULL
BEGIN
    SET @naeste = (SELECT ISNULL(MAX([aendringsaarsag_id]), 0) FROM [dsa].[Aendringsaarsag]);
    DBCC CHECKIDENT ('[dsa].[Aendringsaarsag]', RESEED, @naeste);
END;

IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'[dsa].[Brevskabelon]')) IS NOT NULL
BEGIN
    SET @naeste = (SELECT ISNULL(MAX([brevskabelon_id]), 0) FROM [dsa].[Brevskabelon]);
    DBCC CHECKIDENT ('[dsa].[Brevskabelon]', RESEED, @naeste);
END;

IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'[dsa].[Fagomraade]')) IS NOT NULL
BEGIN
    SET @naeste = (SELECT ISNULL(MAX([fagomraade_id]), 0) FROM [dsa].[Fagomraade]);
    DBCC CHECKIDENT ('[dsa].[Fagomraade]', RESEED, @naeste);
END;

IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'[dsa].[SagsaktivitetType]')) IS NOT NULL
BEGIN
    SET @naeste = (SELECT ISNULL(MAX([type_id]), 0) FROM [dsa].[SagsaktivitetType]);
    DBCC CHECKIDENT ('[dsa].[SagsaktivitetType]', RESEED, @naeste);
END;

IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'[dsa].[Skolematrikel]')) IS NOT NULL
BEGIN
    SET @naeste = (SELECT ISNULL(MAX([matrikel_id]), 0) FROM [dsa].[Skolematrikel]);
    DBCC CHECKIDENT ('[dsa].[Skolematrikel]', RESEED, @naeste);
END;

IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'[dsa].[Skoleplaceringsaarsag]')) IS NOT NULL
BEGIN
    SET @naeste = (SELECT ISNULL(MAX([skoleplaceringsaarsag_id]), 0) FROM [dsa].[Skoleplaceringsaarsag]);
    DBCC CHECKIDENT ('[dsa].[Skoleplaceringsaarsag]', RESEED, @naeste);
END;

IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'[dsa].[Skoletilbudstype]')) IS NOT NULL
BEGIN
    SET @naeste = (SELECT ISNULL(MAX([skoletilbudstype_id]), 0) FROM [dsa].[Skoletilbudstype]);
    DBCC CHECKIDENT ('[dsa].[Skoletilbudstype]', RESEED, @naeste);
END;

IF (SELECT last_value FROM sys.identity_columns WHERE object_id = OBJECT_ID(N'[dsa].[Status]')) IS NOT NULL
BEGIN
    SET @naeste = (SELECT ISNULL(MAX([status_id]), 0) FROM [dsa].[Status]);
    DBCC CHECKIDENT ('[dsa].[Status]', RESEED, @naeste);
END;

PRINT 'Identity counters aligned with the current rows.';
