import { error } from "@sveltejs/kit";

import { backendUserFetcher } from "$lib/server/backendApi";
import type { SkoleskifterRow } from "$lib/skoleskifter";

import type { PageServerLoad } from "./$types";


/**
 * The skoleskifter overview (draft): every active case, open and closed. The
 * tabs are filters on this one list, as on the skolebegynder overview.
 *
 * A failed list is an error page, not an empty grid — an empty overview
 * would read as "nothing to do".
 */
export const load: PageServerLoad = async (event) => {
  const res = await backendUserFetcher(event)("/skoleskifter");

  if (!res.ok) {
    console.error("Failed to fetch skoleskiftere:", res.status);
    throw error(502, "Kunne ikke hente skoleskiftere og tilflyttere");
  }

  return { sager: (await res.json()) as SkoleskifterRow[] };
};
