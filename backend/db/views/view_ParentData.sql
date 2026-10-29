USE [DSA]
GO

/* Verbatim from befordringssystemet (schema names aside). */
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER VIEW [dsa].[view_ParentData]
AS
SELECT
    f.cpr_elev,
    f.adresseringsnavn,
    f.cpr_foraelder,
    ad.adresse_tekst,
    f.navne_adresse_beskyttelse,
    f.maa_vide_barns_adresse,
    f.relation,

    CASE
        WHEN f.relation = 'Mor' THEN 1
        WHEN f.relation = 'Far' THEN 2
        ELSE 99
    END AS foraelderrolle_sortering

FROM
    [dsa].[Foraelder] f

LEFT JOIN
    [dsa].[Adresse] ad
    ON ad.adresse_id = f.adresse_id;
GO


