import { error, type RequestEvent } from "@sveltejs/kit";

import { backendUserFetcher } from "$lib/server/backendApi";
import { iDagISO } from "$lib/dates";
import { daekkerIDag } from "$lib/elevsag";
import { TOMME_LOOKUPS, percentil, skoleaarTekst, type Lookups, type SkolebegynderRow } from "$lib/skolebegynder";
import type { SkoleskifterDetail, SkoleskifterRow, TidligereScreening } from "$lib/skoleskifter";


/**
 * Everything SkoleskifterSag needs for one case: the case, the lookups for
 * the decision form, the case's own log entries — and, for the assessment,
 * the child's earlier screenings (the skolebegynder screening at school
 * start, other skoleskifter cases) and language-support periods. Shared by
 * the student page's "Aktiv sag" tab and its afgørelse page. (The siblings
 * used to come with it; they are the student page's own Søskende tab now.)
 */
export async function hentSkoleskifterSag(event: RequestEvent, id: number) {
  const api = backendUserFetcher(event);

  const [sagRes, lookupsRes] = await Promise.all([api(`/skoleskifter/${id}`), api("/lookup/all")]);

  if (sagRes.status === 404) {
    throw error(404, "Sagen findes ikke");
  }
  if (!sagRes.ok) {
    throw error(502, "Kunne ikke hente sagen");
  }

  const sag: SkoleskifterDetail = await sagRes.json();
  const lookups: Lookups = lookupsRes.ok ? { ...TOMME_LOOKUPS, ...(await lookupsRes.json()) } : TOMME_LOOKUPS;
  const fagomraadeId = lookups.fagomraader.find((f) => f.label === "Skoleskiftere og tilflyttere")?.id ?? null;

  const [aktivitetRes, skolebegynderRes, skoleskifterRes, historikRes] = await Promise.all([
    api(`/aktivitet/${sag.cpr}`),
    api(`/skolebegynder/elev/${sag.cpr}`),
    api(`/skoleskifter/elev/${sag.cpr}`),
    api(`/citizen/stamdata/${sag.cpr}/historik`)
  ]);
  // The child's log holds every area and case; this page shows this case's.
  const aktivitet: any[] = aktivitetRes.ok ? await aktivitetRes.json() : [];
  const sagsforloeb = aktivitet.filter(
    (a) => a.relateret_sag_id === id && (fagomraadeId === null || a.fagomraade_id === fagomraadeId)
  );

  // Earlier screenings, newest first: "Historik fra tidligere sprogscreeninger
  // (f.eks. ved skolestart) skal kunne vises" (PUF, 2026-11).
  const skolebegynder: SkolebegynderRow[] = skolebegynderRes.ok ? await skolebegynderRes.json() : [];
  const andreSager: SkoleskifterRow[] = skoleskifterRes.ok ? await skoleskifterRes.json() : [];
  const screeninger: TidligereScreening[] = [
    ...skolebegynder
      .filter((b) => b.screeningsdato || b.samlet_resultat)
      .map((b) => ({
        kilde: `Skolebegynder ${skoleaarTekst(b.skoleaar)}`,
        dato: b.screeningsdato,
        resultat: b.puf_screeningsresultat ?? b.samlet_resultat,
        detalje:
          b.of_percentil !== null || b.sf_percentil !== null
            ? `Ordforråd ${percentil(b.of_percentil)} · Sprogforståelse ${percentil(b.sf_percentil)}`
            : null
      })),
    ...andreSager
      .filter((x) => x.skoleskifter_id !== id && (x.screeningsdato || x.samlet_resultat || x.skolens_sprogvurdering))
      .map((x) => ({
        kilde: `${x.variant}, modtaget ${x.modtaget_tidspunkt.slice(0, 4)}`,
        dato: x.screeningsdato ?? x.dato_svar_skole,
        resultat: x.samlet_resultat ?? x.skolens_sprogvurdering,
        detalje: null
      }))
  ].sort((a, b) => (b.dato ?? "").localeCompare(a.dato ?? ""));

  const historik = historikRes.ok ? await historikRes.json() : null;
  const sprogstoette: { startdato: string; slutdato: string | null }[] = historik?.sprogstoettebehov ?? [];
  // As the student card has it: a period covering today.
  const sprogstoettebehovNu = sprogstoette.some((p) => daekkerIDag(p.startdato, p.slutdato, iDagISO()));

  return { sag, lookups, sagsforloeb, fagomraadeId, screeninger, sprogstoette, sprogstoettebehovNu };
}
