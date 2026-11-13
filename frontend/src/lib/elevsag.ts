/**
 * A child's cases across areas, as the student page sees them.
 *
 * The student page opens on the child's ACTIVE case — the one not yet
 * "Afsluttet". A child has at most one at a time, whatever the area (PUF's
 * rule); the closed ones are the child's afgørelser, listed on their own tab.
 *
 * Kept here, not in a route, because the overviews link to a case too, and a
 * link must go where the case actually is: the active-case tab while it is
 * open, its afgørelse page once it is closed.
 */

import type { SkolebegynderRow } from "$lib/skolebegynder";
import type { SkoleskifterRow } from "$lib/skoleskifter";

export const AFSLUTTET = "Afsluttet";

/** The areas a case can belong to, as they appear in afgørelse URLs. */
export type Omraade = "skolebegynder" | "skoleskifter";

export const OMRAADER: readonly Omraade[] = ["skolebegynder", "skoleskifter"];

/** One case, whichever area it is from. */
export type ElevSag = {
  omraade: Omraade;
  id: number;
  /** "Skolebegynder" or the skoleskifter variant (Tilflytter, …). */
  type: string;
  skoleaar: number | null;
  status_tekst: string;
  modtaget_tidspunkt: string;
  afsluttet_dato: string | null;
  /** The decision in short: the screening result PUF settled on. */
  resultat: string | null;
  /** The school offer: campus and kind, when there is one. */
  skoletilbud: string | null;
};

export function fraSkolebegynder(s: SkolebegynderRow): ElevSag {
  return {
    omraade: "skolebegynder",
    id: s.skolebegynder_id,
    type: "Skolebegynder",
    skoleaar: s.skoleaar,
    status_tekst: s.status_tekst,
    modtaget_tidspunkt: s.modtaget_tidspunkt,
    afsluttet_dato: s.afsluttet_dato,
    resultat: s.puf_screeningsresultat ?? s.samlet_resultat,
    skoletilbud: [s.skoletilbud_matrikel, s.skoletilbudstype_tekst].filter(Boolean).join(" · ") || null
  };
}

export function fraSkoleskifter(s: SkoleskifterRow): ElevSag {
  return {
    omraade: "skoleskifter",
    id: s.skoleskifter_id,
    type: s.variant,
    skoleaar: s.skoleaar,
    status_tekst: s.status_tekst,
    modtaget_tidspunkt: s.modtaget_tidspunkt,
    afsluttet_dato: s.afsluttet_dato,
    resultat: s.samlet_resultat,
    skoletilbud: [s.skoletilbud_matrikel, s.skoletilbudstype_tekst].filter(Boolean).join(" · ") || null
  };
}

/** Every case the child has, newest received first. */
export function alleSager(skolebegynder: SkolebegynderRow[], skoleskifter: SkoleskifterRow[]): ElevSag[] {
  return [...skolebegynder.map(fraSkolebegynder), ...skoleskifter.map(fraSkoleskifter)].sort((a, b) =>
    b.modtaget_tidspunkt.localeCompare(a.modtaget_tidspunkt)
  );
}

export const erAktiv = (s: { status_tekst: string }) => s.status_tekst !== AFSLUTTET;

/**
 * Closed cases, most recently closed first. A case closed without a date
 * (none should be) sorts by when it was received.
 */
export function afgoerelser(sager: ElevSag[]): ElevSag[] {
  return sager
    .filter((s) => !erAktiv(s))
    .sort((a, b) => (b.afsluttet_dato ?? b.modtaget_tidspunkt).localeCompare(a.afsluttet_dato ?? a.modtaget_tidspunkt));
}

/** Where a case lives on the student page: the first tab while open, else its afgørelse. */
export function sagHref(cpr: string, omraade: Omraade, id: number, status_tekst: string): string {
  return status_tekst === AFSLUTTET ? `/elev/${cpr}/afgoerelser/${omraade}/${id}` : `/elev/${cpr}`;
}

/**
 * An open period ends on 9999-12-31 in Elev_Modersmaal, Elev_PPR and
 * Elev_Sprogstoettebehov, and on NULL in Elev_Skolehistorik (migration 006).
 * Both read as "still running".
 */
export const erAabenPeriode = (slut: string | null | undefined) => !slut || slut.startsWith("9999");

/**
 * Whether a period covers today — the rule view_Elev_Aktuel uses for the
 * student card's modersmål, sprogstøttebehov and PPR. Labelling the history
 * by the same rule keeps the tab and the card from disagreeing.
 */
export function daekkerIDag(fra: string, til: string | null | undefined, iDag: string): boolean {
  return fra.slice(0, 10) <= iDag && (erAabenPeriode(til) || til!.slice(0, 10) >= iDag);
}
