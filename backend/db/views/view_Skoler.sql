USE [DSA]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
    One row per school (skolekode), resolved through its main campus.

    Most of DSA refers to a school by skolekode — district school, wanted
    school, a sibling's school — while Skolematrikel has one row per campus.
    This is where a skolekode becomes a name, an address and coordinates: the
    campus marked er_matrikel_hovedadresse, which UX_Skolematrikel_hovedadresse
    guarantees is unique per school.

    skolenavn drops the campus suffix that Skolematrikel carries for schools
    with several campuses ("Kaløvigskolen (Bredevej)" -> "Kaløvigskolen"):
    a child's district school is the school, not one of its buildings.

    Also the source for school dropdowns that pick a school rather than a
    campus (wanted school, for instance).
*/

CREATE OR ALTER VIEW [dsa].[view_Skoler]
AS
SELECT
    sm.skolekode,
    CASE
        WHEN CHARINDEX(' (', sm.matrikel_navn) > 0
        THEN LEFT(sm.matrikel_navn, CHARINDEX(' (', sm.matrikel_navn) - 1)
        ELSE sm.matrikel_navn
    END                                AS skolenavn,
    sm.matrikel_id                     AS hovedmatrikel_id,
    sm.matrikel_adresse                AS hovedmatrikel_adresse,
    sm.latitude,
    sm.longitude,
    (SELECT COUNT(*)
     FROM   [dsa].[Skolematrikel] m
     WHERE  m.skolekode = sm.skolekode) AS antal_matrikler
FROM
    [dsa].[Skolematrikel] sm
WHERE
    sm.er_matrikel_hovedadresse = 1;
GO
