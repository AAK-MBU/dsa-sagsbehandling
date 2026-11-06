USE [DSA]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
    One row per Elev: the child as it is TODAY, with the columns Elev had
    before migration 006.

    Migration 006 left Elev with the person only (cpr, name, protection,
    address, koen) and moved everything that changes over time to the Elev_*
    tables. This view puts the current period of each back beside the person,
    under the old column names, so the views and services that read "the
    child" keep their shape:

      modersmaal          Elev_Modersmaal, the period covering today
      tilflyttet_dk_dato  Elev_Indrejse.seneste_indrejse (foerste_indrejse too)
      distriktsskolekode,
      skolekode,
      elevklassetrin,
      klassebetegnelse    Elev_Skolehistorik, the open period (gyldig_til NULL
                          — at most one per child, UX_Elev_Skolehistorik_aaben)
      sprogstoettebehov,
      ppr_status          1 when a period in Elev_Sprogstoettebehov / Elev_PPR
                          covers today, else 0

    A child with no row in a table gets NULL there (0 for the two flags).
    The history itself is read from the tables, not from here.

    Create before view_Stamdata, view_Skolebegyndere, view_Skoleskiftere and
    view_Skolebegynder_Aendringer, which read it.
*/

CREATE OR ALTER VIEW [dsa].[view_Elev_Aktuel]
AS
SELECT
    e.cpr,
    e.adresseringsnavn,
    e.navne_adresse_beskyttelse,
    e.adresse_id,
    e.koen,

    m.modersmaal,
    i.seneste_indrejse                 AS tilflyttet_dk_dato,
    i.foerste_indrejse,

    h.distriktsskolekode,
    h.skolekode,
    h.elevklassetrin,
    h.klassebetegnelse,

    CAST(CASE WHEN EXISTS (
            SELECT 1 FROM [dsa].[Elev_Sprogstoettebehov] s
            WHERE  s.cpr = e.cpr AND s.startdato <= d.i_dag AND s.slutdato >= d.i_dag)
         THEN 1 ELSE 0 END AS BIT)     AS sprogstoettebehov,

    CAST(CASE WHEN EXISTS (
            SELECT 1 FROM [dsa].[Elev_PPR] p
            WHERE  p.cpr = e.cpr AND p.startdato <= d.i_dag AND p.slutdato >= d.i_dag)
         THEN 1 ELSE 0 END AS BIT)     AS ppr_status

FROM [dsa].[Elev] e

CROSS APPLY (SELECT CAST(GETDATE() AS DATE) AS i_dag) d

LEFT JOIN [dsa].[Elev_Skolehistorik] h
    ON  h.cpr = e.cpr
    AND h.gyldig_til IS NULL

OUTER APPLY (
    SELECT TOP (1) mm.modersmaal
    FROM   [dsa].[Elev_Modersmaal] mm
    WHERE  mm.cpr = e.cpr
      AND  mm.gyldig_fra <= d.i_dag
      AND  mm.gyldig_til >= d.i_dag
    ORDER BY mm.gyldig_fra DESC
) m

LEFT JOIN [dsa].[Elev_Indrejse] i
    ON i.cpr = e.cpr;
GO
