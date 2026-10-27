import { error, redirect } from "@sveltejs/kit";

import { hentSkoleskifterSag } from "$lib/server/skoleskifterSag";

import type { PageServerLoad } from "./$types";


/**
 * A skoleskifter case that arrived without a CPR (draft). It cannot live on
 * the student page, which is keyed by CPR, so it has this page until a CPR
 * is linked — then it moves, and this address redirects there.
 */
export const load: PageServerLoad = async (event) => {
  const id = Number(event.params.id);

  if (!Number.isInteger(id) || id <= 0) {
    throw error(404, "Sagen findes ikke");
  }

  const data = await hentSkoleskifterSag(event, id);

  if (data.sag.cpr) {
    throw redirect(307, `/elev/${data.sag.cpr}/skoleskiftere?sag=${id}`);
  }

  return data;
};
