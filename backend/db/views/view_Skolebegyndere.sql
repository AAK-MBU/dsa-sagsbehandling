USE [DSA]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
    One row per active skolebegynder case — the overview grid.

    Carries every column in the skolebegynder UI sketch, resolved to display
    text (school names, status, skoletilbudstype), alongside the ids the grid
    needs to edit them. Filtering, column choice and the Overblik / Screening
    afviklet / Ikke screenet tabs are all the frontend's, on top of this one
    set.

    School names come from view_Skoler (one row per skolekode). The school
    offer is a campus (Skolematrikel), shown with its campus name, and its
    skolekode is what the comparisons use.

    skoler_afviger flags the sketch's "Hvis skole er forskellig fra hinanden":
    1 when the district school, the wanted school and the school offer do not
    all name the same school (ignoring the ones not filled in yet). Compared
    on skolekode, so an offer at another campus of the wanted school still
    counts as the wanted school.

    aabne_aendringer counts unhandled rows in Skolebegynder_Aendring — the
    "!" on the Ændringer tab.

    navne_adresse_beskyttelse is passed through, not acted on. Deciding what a
    protected child's row may show is the application's job, and it must be
    done before this view reaches a screen.
*/

CREATE OR ALTER VIEW [dsa].[view_Skolebegyndere]
AS
SELECT
    sb.skolebegynder_id,
    sb.cpr,
    sb.skoleaar,

    -- Child
    e.adresseringsnavn                AS navn,
    e.navne_adresse_beskyttelse,
    a.adresse_tekst,
    e.koen,
    e.modersmaal,
    e.tilflyttet_dk_dato,
    e.ppr_status,

    -- Status
    sb.status_id,
    st.status_tekst,
    st.sortering                      AS status_sortering,
    sb.status_dato,
    sb.modtaget_tidspunkt,

    -- Screening
    sb.screening_booket_tidspunkt,
    sb.screeningsdato,
    sb.samlet_resultat,
    sb.puf_screeningsresultat,
    sb.sprogstoettebehov,
    sb.of_percentil,
    sb.sf_percentil,
    sb.navn_konsulent,

    -- Daycare and wishes
    sb.dagtilbud,
    sb.dagtilbud_afdeling,
    e.distriktsskolekode,
    ds.skolenavn                      AS distriktsskole,
    sb.oensket_skolekode,
    os.skolenavn                      AS oensket_skole,
    sb.oensket_skolekode_2,
    os2.skolenavn                     AS oensket_skole_2,
    sb.soeskende_skolekode,
    ss.skolenavn                      AS soeskende_skole,
    sb.ansoeger_anden_skole,

    -- Case work
    sb.skoletilbud_matrikel_id,
    tm.matrikel_navn                  AS skoletilbud_matrikel,
    tm.skolekode                      AS skoletilbud_skolekode,
    sb.skoletilbudstype_id,
    stt.skoletilbudstype_tekst,
    sb.skoleplaceringsaarsag_id,
    spa.skoleplaceringsaarsag_tekst,
    sb.brevskabelon_id,
    bs.brevskabelon_tekst,
    sb.krav_paa_befordring,
    sb.gaaafstand_distriktsskole_km,
    sb.gaaafstand_oensket_skole_km,
    sb.gaaafstand_skoletilbud_km,
    sb.afklaring,
    sb.bemaerkning,
    sb.sagsbehandlingsdato,
    sb.afsluttet_dato,

    -- Derived
    CAST(CASE
        WHEN (SELECT COUNT(DISTINCT k.skolekode)
              FROM (VALUES (e.distriktsskolekode),
                           (sb.oensket_skolekode),
                           (tm.skolekode)) AS k (skolekode)
              WHERE k.skolekode IS NOT NULL) > 1
        THEN 1 ELSE 0
    END AS BIT)                       AS skoler_afviger,

    (SELECT COUNT(*)
     FROM   [dsa].[Skolebegynder_Aendring] ae
     WHERE  ae.skolebegynder_id = sb.skolebegynder_id
       AND  ae.haandteret = 0)        AS aabne_aendringer,

    sb.updated_at,
    sb.updated_by
FROM
    [dsa].[Skolebegynder] sb
INNER JOIN
    [dsa].[Elev] e
    ON e.cpr = sb.cpr
LEFT JOIN
    [dsa].[Adresse] a
    ON a.adresse_id = e.adresse_id
INNER JOIN
    [dsa].[Status] st
    ON st.status_id = sb.status_id
LEFT JOIN
    [dsa].[view_Skoler] ds
    ON ds.skolekode = e.distriktsskolekode
LEFT JOIN
    [dsa].[view_Skoler] os
    ON os.skolekode = sb.oensket_skolekode
LEFT JOIN
    [dsa].[view_Skoler] os2
    ON os2.skolekode = sb.oensket_skolekode_2
LEFT JOIN
    [dsa].[view_Skoler] ss
    ON ss.skolekode = sb.soeskende_skolekode
LEFT JOIN
    [dsa].[Skolematrikel] tm
    ON tm.matrikel_id = sb.skoletilbud_matrikel_id
LEFT JOIN
    [dsa].[Skoletilbudstype] stt
    ON stt.skoletilbudstype_id = sb.skoletilbudstype_id
LEFT JOIN
    [dsa].[Skoleplaceringsaarsag] spa
    ON spa.skoleplaceringsaarsag_id = sb.skoleplaceringsaarsag_id
LEFT JOIN
    [dsa].[Brevskabelon] bs
    ON bs.brevskabelon_id = sb.brevskabelon_id
WHERE
    sb.aktiv = 1;
GO
