import { hentSkolebegynderSag } from "$lib/server/skolebegynderSag";
import { hentSkoleskifterSag } from "$lib/server/skoleskifterSag";

import type { PageServerLoad } from "./$types";


/**
 * /elev/{cpr} — the student page's first tab, "Aktiv sag": the child's open
 * case, whichever area it is in. A child has at most one (PUF's rule); if the
 * data ever holds more, this shows the newest and the page lists the others,
 * each reachable as ?sag={omraade}-{id}.
 *
 * No active case: the page says so and points to Tidligere afgørelser. It used
 * to redirect to an area tab instead; there are no area tabs any more.
 */
export const load: PageServerLoad = async (event) => {
  const { aktiveSager } = await event.parent();
  const valgt = event.url.searchParams.get("sag");
  const aktiv = aktiveSager.find((s) => `${s.omraade}-${s.id}` === valgt) ?? aktiveSager[0];

  if (!aktiv) {
    return { skolebegynder: null, skoleskifter: null, vist: null };
  }

  const vist = `${aktiv.omraade}-${aktiv.id}`;

  if (aktiv.omraade === "skolebegynder") {
    return { skolebegynder: await hentSkolebegynderSag(event, aktiv.id), skoleskifter: null, vist };
  }

  return { skolebegynder: null, skoleskifter: await hentSkoleskifterSag(event, aktiv.id), vist };
};
