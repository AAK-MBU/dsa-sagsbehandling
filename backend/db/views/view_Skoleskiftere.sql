USE [DSA]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
    One row per active skoleskifter case (Skoleskiftere og tilflyttere) —
    the area's overview grid, and the student page's tab.

    navn is the child's from Elev once a CPR is linked, else the name the
    application gave (ansoeger_navn): a case without CPR still needs a name
    on the list.

    nuvaerende_skole is the Aarhus school's name for skoleskift internt, or
    the school given as text for one outside Aarhus.

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
    CAST(CASE WHEN ss.cpr IS NULL THEN 0 ELSE 1 END AS BIT) AS har_cpr,
    COALESCE(e.adresseringsnavn, ss.ansoeger_navn)          AS navn,
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
    ss.dato_oensket_skolestart,
    ss.oensket_skolekode,
    os.skolenavn                                            AS oensket_skole,
    ss.nuvaerende_skolekode,
    COALESCE(ns.skolenavn, ss.nuvaerende_skole_tekst)       AS nuvaerende_skole,
    ss.klassetrin_ansoegning,
    ss.kommende_adresse,
    ss.saerlige_behov,

    -- Language assessment
    ss.skolens_vurdering,
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
LEFT JOIN
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
