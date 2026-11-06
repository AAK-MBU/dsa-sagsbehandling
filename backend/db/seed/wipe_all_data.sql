/* ============================================================
   Wipe ALL data in the dsa schema — an empty database, as after the
   migrations.

   DESTRUCTIVE: deletes every row in every table in [dsa] — case data AND
   lookups (Status, Fagomraade, Skolematrikel, ...). The tables, views and
   stored procedures stay. The app cannot run on the result until the
   lookups are back:

       1. seed_lookup_data.sql   (what the app needs to run)
       2. seed_test_data.sql     (optional — the fictional cohort)

   The tables are found from the catalog, not listed by hand, so a table
   added by a later migration is wiped too without changing this file.
   Foreign keys are switched off for the deletes and back on afterwards
   (WITH CHECK, so they stay trusted), which makes the delete order
   irrelevant.

   Identity counters restart at 1: the block after the transaction sets
   each counter to the table's current MAX — 0 after a COMMIT, the old
   value after a ROLLBACK. DBCC CHECKIDENT is not transactional, which is
   why it runs there and not inside.

   Runs inside a transaction that ROLLBACKs by default — change the final
   ROLLBACK to COMMIT once the preview shows what you expect.
   ============================================================ */

USE [DSA];

SET NOCOUNT ON;
SET XACT_ABORT ON;


/* ------------------------------------------------------------
   SERVERSPÆRRE — som i seed_test_data.sql

   Fejler LUKKET: kun servere på listen nedenfor er tilladt. Find navnet
   med:   SELECT @@SERVERNAME;
------------------------------------------------------------ */

DECLARE @tilladte_servere TABLE (servernavn SYSNAME);

INSERT INTO @tilladte_servere (servernavn) VALUES
    -- (N'MIN-DEV-SERVER'),
    (N'SRVSQL58');

IF NOT EXISTS (SELECT 1 FROM @tilladte_servere WHERE servernavn = @@SERVERNAME)
BEGIN
    RAISERROR(
        'STOPPET: wipe_all_data sletter ALLE data i dsa-skemaet og maa ikke koere paa %s. Tilfoej servernavnet til @tilladte_servere, hvis det er en testserver.',
        16, 1, @@SERVERNAME
    );
    -- NOEXEC rather than RETURN: it also stops the batch after the GO
    -- (the identity reseed). Turned off again on the last line.
    SET NOEXEC ON;
END;

PRINT CONCAT('Serverspaerre OK: ', @@SERVERNAME);


/* ------------------------------------------------------------
   1. The tables, and their row counts before
------------------------------------------------------------ */

IF OBJECT_ID(N'tempdb..#tabeller') IS NOT NULL DROP TABLE #tabeller;

CREATE TABLE #tabeller (
    object_id  INT       NOT NULL PRIMARY KEY,
    navn       NVARCHAR(300) NOT NULL,   -- [dsa].[Tabel], ready for dynamic SQL
    foer       BIGINT    NULL,
    efter      BIGINT    NULL
);

INSERT INTO #tabeller (object_id, navn)
SELECT t.object_id, QUOTENAME(s.name) + N'.' + QUOTENAME(t.name)
FROM   sys.tables  t
JOIN   sys.schemas s ON s.schema_id = t.schema_id
WHERE  s.name = N'dsa'
  AND  t.is_ms_shipped = 0;

DECLARE @sql NVARCHAR(MAX);

SELECT @sql = STRING_AGG(CAST(
           N'UPDATE #tabeller SET foer = (SELECT COUNT_BIG(*) FROM ' + navn + N') WHERE object_id = '
           + CAST(object_id AS NVARCHAR(20)) + N';' AS NVARCHAR(MAX)), NCHAR(10))
FROM   #tabeller;

EXEC sys.sp_executesql @sql;


BEGIN TRANSACTION;


/* ------------------------------------------------------------
   2. Foreign keys off, delete everything, foreign keys back on
------------------------------------------------------------ */

SELECT @sql = STRING_AGG(CAST(N'ALTER TABLE ' + navn + N' NOCHECK CONSTRAINT ALL;' AS NVARCHAR(MAX)), NCHAR(10))
FROM   #tabeller;
EXEC sys.sp_executesql @sql;

SELECT @sql = STRING_AGG(CAST(N'DELETE FROM ' + navn + N';' AS NVARCHAR(MAX)), NCHAR(10))
FROM   #tabeller;
EXEC sys.sp_executesql @sql;

-- WITH CHECK: the constraints are re-validated (trivially, the tables are
-- empty) and stay trusted by the optimizer.
SELECT @sql = STRING_AGG(CAST(N'ALTER TABLE ' + navn + N' WITH CHECK CHECK CONSTRAINT ALL;' AS NVARCHAR(MAX)), NCHAR(10))
FROM   #tabeller;
EXEC sys.sp_executesql @sql;

PRINT 'Deleted all rows in the dsa schema.';


/* ------------------------------------------------------------
   3. Preview — runs before the COMMIT/ROLLBACK decision
------------------------------------------------------------ */

SELECT @sql = STRING_AGG(CAST(
           N'UPDATE #tabeller SET efter = (SELECT COUNT_BIG(*) FROM ' + navn + N') WHERE object_id = '
           + CAST(object_id AS NVARCHAR(20)) + N';' AS NVARCHAR(MAX)), NCHAR(10))
FROM   #tabeller;
EXEC sys.sp_executesql @sql;

SELECT navn AS tabel, foer AS rows_foer, efter AS rows_efter
FROM   #tabeller
ORDER BY navn;
-- Every rows_efter should be 0.


-- Change to COMMIT once the preview above looks right.
ROLLBACK TRANSACTION;
-- COMMIT TRANSACTION;
GO


/* ============================================================
   Put the identity counters back in step with the rows

   Runs OUTSIDE the transaction deliberately (DBCC CHECKIDENT is not
   transactional). After a COMMIT the tables are empty and each counter goes
   to 0, so the next insert gets 1; after a ROLLBACK it goes back to the
   table's MAX, i.e. nothing changes.

   Only identities that have been used (last_value not null) — on a table
   that never held a row, RESEED 0 would make the first insert get id 0
   (see seed_lookup_data.sql, section 2).
============================================================ */

USE [DSA];

SET NOCOUNT ON;

DECLARE @sql NVARCHAR(MAX);

SELECT @sql = STRING_AGG(CAST(
           N'DECLARE @m' + CAST(t.object_id AS NVARCHAR(20)) + N' BIGINT = (SELECT ISNULL(MAX('
           + QUOTENAME(ic.name) + N'), 0) FROM ' + QUOTENAME(s.name) + N'.' + QUOTENAME(t.name) + N'); '
           + N'DBCC CHECKIDENT (''' + REPLACE(QUOTENAME(s.name) + N'.' + QUOTENAME(t.name), N'''', N'''''')
           + N''', RESEED, @m' + CAST(t.object_id AS NVARCHAR(20)) + N') WITH NO_INFOMSGS;'
       AS NVARCHAR(MAX)), NCHAR(10))
FROM   sys.identity_columns ic
JOIN   sys.tables  t ON t.object_id = ic.object_id
JOIN   sys.schemas s ON s.schema_id = t.schema_id
WHERE  s.name = N'dsa'
  AND  ic.last_value IS NOT NULL;

IF @sql IS NOT NULL
    EXEC sys.sp_executesql @sql;

PRINT 'Identity counters aligned with the current rows.';
GO

-- Leaves the SSMS session usable whether or not the server lock stopped the run.
SET NOEXEC OFF;
