import { error } from "@sveltejs/kit";

import { hentSkoleskifterSag } from "$lib/server/skoleskifterSag";
import { TOMME_LOOKUPS } from "$lib/skolebegynder";

import type { PageServerLoad } from "./$types";


/**
 * The Skoleskiftere tab of the student page (draft): one of the child's
 * skoleskifter cases. ?sag={id} when given (the overview names it), otherwise
 * the newest open case, else the newest. A child can have several — a
 * tilflytter who later changes school, say.
 */
export const load: PageServerLoad = async (event) => {
  const { skoleskifterSager } = await event.parent();

  if (skoleskifterSager.length === 0) {
    return { sag: null, lookups: TOMME_LOOKUPS, sagsforloeb: [], soeskende: [], fagomraadeId: null };
  }

  let valgt;

  if (event.url.searchParams.has("sag")) {
    const oensket = Number(event.url.searchParams.get("sag"));
    valgt = skoleskifterSager.find((s) => s.skoleskifter_id === oensket);
    if (!valgt) {
      throw error(404, "Sagen findes ikke for denne elev");
    }
  } else {
    // The cases come newest first.
    valgt = skoleskifterSager.find((s) => s.status_tekst !== "Afsluttet") ?? skoleskifterSager[0];
  }

  return hentSkoleskifterSag(event, valgt.skoleskifter_id);
};
