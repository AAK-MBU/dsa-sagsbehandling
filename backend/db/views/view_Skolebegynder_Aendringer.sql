USE [DSA]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
    Unhandled changes on active skolebegynder cases — the "Ændringer" tab.

    One row per change, not per child: a child who both moved and changed
    mother tongue appears twice, once per ændringsårsag, so each can be
    handled on its own. Columns follow the sketch: Navn, CPR, Adresse,
    Distriktskole, Ændringsårsag.
*/

CREATE OR ALTER VIEW [dsa].[view_Skolebegynder_Aendringer]
AS
SELECT
    ae.aendring_id,
    ae.skolebegynder_id,
    sb.cpr,
    sb.skoleaar,
    e.adresseringsnavn          AS navn,
    e.navne_adresse_beskyttelse,
    a.adresse_tekst,
    ds.skolenavn                AS distriktsskole,
    ae.aendringsaarsag_id,
    aa.aendringsaarsag_tekst,
    aa.sortering                AS aendringsaarsag_sortering,
    ae.beskrivelse,
    ae.registreret_tidspunkt,
    st.status_tekst
FROM
    [dsa].[Skolebegynder_Aendring] ae
INNER JOIN
    [dsa].[Skolebegynder] sb
    ON sb.skolebegynder_id = ae.skolebegynder_id
INNER JOIN
    [dsa].[Elev] e
    ON e.cpr = sb.cpr
LEFT JOIN
    [dsa].[Adresse] a
    ON a.adresse_id = e.adresse_id
LEFT JOIN
    [dsa].[view_Skoler] ds
    ON ds.skolekode = e.distriktsskolekode
INNER JOIN
    [dsa].[Aendringsaarsag] aa
    ON aa.aendringsaarsag_id = ae.aendringsaarsag_id
INNER JOIN
    [dsa].[Status] st
    ON st.status_id = sb.status_id
WHERE
    ae.haandteret = 0
    AND sb.aktiv = 1;
GO
