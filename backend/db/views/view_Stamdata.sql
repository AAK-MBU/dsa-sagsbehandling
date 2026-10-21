USE [DSA]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
    A child's master data, one row per Elev — what the Elevmappe shows.

    Modelled on befordringssystemet's view_Stamdata and named like it, so the
    two systems describe the same child with the same column names: the
    address is folkeregister_adresse, not adresse_tekst ("det ER
    folkeregisteradressen"), and the name is adresseringsnavn.

    What befordringssystemet joins in for its own domain (the prioritised
    bevilling, ungdomsuddannelse) is left out; DSA resolves its schools
    through view_Skoler instead. A child's cases are not here — each area has
    its own route for them (e.g. /skolebegynder/elev/{cpr}), as
    befordringssystemet has /bevilling/get_student_bevillinger/{cpr}.

    Depends on view_Skoler: create that first.
*/

CREATE OR ALTER VIEW [dsa].[view_Stamdata]
AS
SELECT
    e.navne_adresse_beskyttelse,
    e.adresseringsnavn,
    e.cpr,

    e.adresse_id,
    ad.adresse_tekst                 AS folkeregister_adresse,

    e.koen,
    e.modersmaal,
    e.tilflyttet_dk_dato,

    e.distriktsskolekode,
    ds.skolenavn                     AS distriktsskole,
    e.skolekode,
    sk.skolenavn                     AS skole_navn,
    e.elevklassetrin,
    e.klassebetegnelse,

    e.sprogstoettebehov,
    e.ppr_status

FROM [dsa].[Elev] e

LEFT JOIN [dsa].[Adresse] ad
    ON ad.adresse_id = e.adresse_id

LEFT JOIN [dsa].[view_Skoler] ds
    ON ds.skolekode = e.distriktsskolekode

LEFT JOIN [dsa].[view_Skoler] sk
    ON sk.skolekode = e.skolekode;
GO
