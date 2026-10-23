-- Migration 003: SX screening column types, from a real SX export
-- Run once against the target database (test / prod).
-- Safe to re-run — each change checks the current type first.
--
-- Context:
--   A real SX report (2026-10-23, with headers) showed two columns typed
--   wrongly in migration 001, which was written from the field list alone:
--
--     of_percentil / sf_percentil   decimals with one place ("1,2", "25,0"),
--                                   not whole numbers: INT -> DECIMAL(4,1)
--     of_score_alt / sf_score_alt   text ("uden bonus", or empty), not a
--                                   number: INT -> NVARCHAR(50)
--
--   Existing values convert as they are (an INT percentile becomes n.0; an
--   INT score_alt becomes its digits as text). The views select these
--   columns, so they are refreshed at the end.

USE [DSA];
GO

IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID(N'dsa.Skolebegynder') AND name = N'of_percentil'
             AND TYPE_NAME(user_type_id) = N'int')
    ALTER TABLE [dsa].[Skolebegynder] ALTER COLUMN of_percentil DECIMAL(4,1) NULL;
GO

IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID(N'dsa.Skolebegynder') AND name = N'sf_percentil'
             AND TYPE_NAME(user_type_id) = N'int')
    ALTER TABLE [dsa].[Skolebegynder] ALTER COLUMN sf_percentil DECIMAL(4,1) NULL;
GO

IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID(N'dsa.Skolebegynder') AND name = N'of_score_alt'
             AND TYPE_NAME(user_type_id) = N'int')
    ALTER TABLE [dsa].[Skolebegynder] ALTER COLUMN of_score_alt NVARCHAR(50) NULL;
GO

IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID(N'dsa.Skolebegynder') AND name = N'sf_score_alt'
             AND TYPE_NAME(user_type_id) = N'int')
    ALTER TABLE [dsa].[Skolebegynder] ALTER COLUMN sf_score_alt NVARCHAR(50) NULL;
GO


-- The views were compiled against the old types.
IF OBJECT_ID(N'dsa.view_Skolebegyndere', N'V') IS NOT NULL
    EXEC sp_refreshview N'dsa.view_Skolebegyndere';
GO


-- Verify
SELECT name, TYPE_NAME(user_type_id) AS type_name, precision, scale, max_length
FROM   sys.columns
WHERE  object_id = OBJECT_ID(N'dsa.Skolebegynder')
  AND  name IN (N'of_percentil', N'sf_percentil', N'of_score_alt', N'sf_score_alt');


-- Next: redeploy stored_procedures/usp_recalculate_skolebegynder_status.sql
-- ("Ej sprogscreenet" is not a screening), then rerun seed/seed_test_data.sql
-- on a test database.
