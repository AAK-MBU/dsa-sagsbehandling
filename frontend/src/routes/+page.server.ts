import { backendUserFetcher } from "$lib/server/backendApi";
import {
  iFane as iSkolebegynderFane,
  kommendeSkoleaar,
  type AendringRow,
  type SkolebegynderRow
} from "$lib/skolebegynder";
import {
  iFane as iSkoleskifterFane,
  VENTETID_GRAENSE,
  type SkoleskifterRow
} from "$lib/skoleskifter";

import type { PageServerLoad } from "./$types";


export type SkolebegynderTal = {
  skoleaar: number;
  mangler_skoleplacering: number;
  naermere_afklaring: number;
  aendringer: number;
  ikke_screenet: number;
  screenet: number;
  skoleplaceret: number;
  afsluttet: number;
};

export type SkoleskifterTal = {
  nye: number;
  skoleskiftere: number;
  tilflyttere: number;
  hos_ppr: number;
  ventet_laenge: number;
  afsluttet: number;
};


/**
 * The front page's numbers: what is waiting in each working area.
 *
 * Counted from the same lists the area pages load, with the tab rules from
 * $lib (iFane), so a number here always matches the tab it links to. Only
 * the counts go to the browser, not the cases.
 *
 * An area whose list fails shows "could not fetch" on its own card (null)
 * rather than failing the whole front page, which is also the way into the
 * areas that still work.
 */
export const load: PageServerLoad = async (event) => {
  const api = backendUserFetcher(event);

  const [sagerRes, aendringerRes, skoleskifterRes] = await Promise.all([
    api("/skolebegynder").catch(() => null),
    api("/skolebegynder/aendringer").catch(() => null),
    api("/skoleskifter").catch(() => null)
  ]);

  let skolebegynder: SkolebegynderTal | null = null;

  if (sagerRes?.ok && aendringerRes?.ok) {
    // The coming school start, as the skolebegynder page opens on.
    const aar = kommendeSkoleaar();
    const sager = ((await sagerRes.json()) as SkolebegynderRow[]).filter((s) => s.skoleaar === aar);
    const aendringer = ((await aendringerRes.json()) as AendringRow[]).filter((a) => a.skoleaar === aar);
    const status = (tekst: string) => sager.filter((s) => s.status_tekst === tekst).length;

    skolebegynder = {
      skoleaar: aar,
      mangler_skoleplacering: status("Screening afviklet"),
      naermere_afklaring: sager.filter((s) => iSkolebegynderFane(s, "naermere-afklaring")).length,
      aendringer: aendringer.length,
      ikke_screenet: sager.filter((s) => iSkolebegynderFane(s, "ikke-screenet")).length,
      screenet: sager.filter((s) => iSkolebegynderFane(s, "overblik")).length,
      skoleplaceret: status("Skoleplaceret"),
      afsluttet: status("Afsluttet")
    };
  } else {
    console.error("Forside: could not fetch skolebegyndere", sagerRes?.status, aendringerRes?.status);
  }

  let skoleskiftere: SkoleskifterTal | null = null;

  if (skoleskifterRes?.ok) {
    const sager = (await skoleskifterRes.json()) as SkoleskifterRow[];
    const aabne = sager.filter((s) => !iSkoleskifterFane(s, "afsluttede"));

    skoleskiftere = {
      nye: aabne.filter((s) => s.status_tekst === "Ny").length,
      skoleskiftere: sager.filter((s) => iSkoleskifterFane(s, "skoleskiftere")).length,
      tilflyttere: sager.filter((s) => iSkoleskifterFane(s, "tilflyttere")).length,
      hos_ppr: sager.filter((s) => iSkoleskifterFane(s, "hos-ppr")).length,
      // Marked in amber on the overview past the sketch's 14 days.
      ventet_laenge: aabne.filter((s) => (s.ventetid_dage ?? 0) > VENTETID_GRAENSE).length,
      afsluttet: sager.length - aabne.length
    };
  } else {
    console.error("Forside: could not fetch skoleskiftere", skoleskifterRes?.status);
  }

  return { skolebegynder, skoleskiftere };
};
