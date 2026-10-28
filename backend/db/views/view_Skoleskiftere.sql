USE [DSA]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
    One row per active skoleskifter case (Skoleskiftere og tilflyttere) —
    the area's overview grid, and the student page's tab.

    Every case has a CPR (migration 005); navn and stamdata are the child's
    from Elev.

    nuvaerende_skole is the Aarhus school's name for skoleskift internt, or
    the school given as text for one outside Aarhus. indgang says how the
    case came: straight from the parents (the child is in modtagelsesklasse)
    or through the receiving school's form.

    ventetid_dage — the mock-up's "Ventetid": days since the application was
    received, to the close date for a closed case. dage_hos_ppr — "hvor lang
    tid sagen har ligget hos PPR" — while the case is with PPR.

    ansoegningsdata (the raw form) is left out; the case detail reads it from
    the table.

    Depends on view_Skoler: create that first.
*/

CREATE OR ALTER VIEW [dsa].[view_Skoleskiftere]
AS
SELECT
    ss.skoleskifter_id,
    ss.cpr,
    e.adresseringsnavn                                      AS navn,
    e.navne_adresse_beskyttelse,
    a.adresse_tekst,
    e.modersmaal,
    e.elevklassetrin,
    e.distriktsskolekode,
    ds.skolenavn                                            AS distriktsskole,
    ss.variant,

    -- Status
    ss.status_id,
    st.status_tekst,
    st.sortering                                            AS status_sortering,
    ss.status_dato,
    ss.modtaget_tidspunkt,

    -- Application
    ss.esdh_noegle,
    ss.esdh_url,
    ss.skoleaar,
    CASE WHEN ss.nuvaerende_skoletilbud = N'Modtagelsesklasse'
         THEN N'Modtagelsesklasse' ELSE N'Via skolen' END   AS indgang,
    ss.nuvaerende_skoletilbud,
    ss.udslusningsdato,
    ss.nuvaerende_kommune,
    ss.oensket_skolekode,
    os.skolenavn                                            AS oensket_skole,
    ss.nuvaerende_skolekode,
    COALESCE(ns.skolenavn, ss.nuvaerende_skole_tekst)       AS nuvaerende_skole,
    ss.klassetrin_ansoegning,
    ss.flytning,
    ss.flyttedato,
    ss.kommende_adresse,
    ss.modersmaal_foraelder,
    ss.modersmaal_skole,
    ss.soeskende_paa_skolen,
    ss.soeskende_klasse,
    ss.skolens_afgoerelse,

    -- Language assessment
    ss.screeningsdato,
    ss.samlet_resultat,

    -- Decision
    ss.skoletilbud_matrikel_id,
    tm.matrikel_navn                                        AS skoletilbud_matrikel,
    ss.skoletilbudstype_id,
    stt.skoletilbudstype_tekst,
    ss.dato_skoletilbud,
    ss.klassetrin,
    ss.bemaerkning,
    ss.ppr_sendt_dato,
    ss.afsluttet_dato,

    -- Derived
    DATEDIFF(DAY, CAST(ss.modtaget_tidspunkt AS DATE),
             COALESCE(ss.afsluttet_dato, CAST(GETDATE() AS DATE)))       AS ventetid_dage,
    CASE WHEN st.status_tekst = N'Sendt til PPR' AND ss.ppr_sendt_dato IS NOT NULL
         THEN DATEDIFF(DAY, ss.ppr_sendt_dato, CAST(GETDATE() AS DATE)) END AS dage_hos_ppr,

    ss.updated_at,
    ss.updated_by
FROM
    [dsa].[Skoleskifter] ss
INNER JOIN
    [dsa].[Elev] e
    ON e.cpr = ss.cpr
LEFT JOIN
    [dsa].[Adresse] a
    ON a.adresse_id = e.adresse_id
INNER JOIN
    [dsa].[Status] st
    ON st.status_id = ss.status_id
LEFT JOIN
    [dsa].[view_Skoler] ds
    ON ds.skolekode = e.distriktsskolekode
LEFT JOIN
    [dsa].[view_Skoler] os
    ON os.skolekode = ss.oensket_skolekode
LEFT JOIN
    [dsa].[view_Skoler] ns
    ON ns.skolekode = ss.nuvaerende_skolekode
LEFT JOIN
    [dsa].[Skolematrikel] tm
    ON tm.matrikel_id = ss.skoletilbud_matrikel_id
LEFT JOIN
    [dsa].[Skoletilbudstype] stt
    ON stt.skoletilbudstype_id = ss.skoletilbudstype_id
WHERE
    ss.aktiv = 1;
GO
