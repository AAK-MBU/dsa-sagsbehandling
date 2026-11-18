import { error, redirect } from "@sveltejs/kit";

import { sagHref } from "$lib/elevsag";

import type { PageServerLoad } from "./$types";


/**
 * The old Skoleskiftere tab of the student page — see the Skolebegynder one
 * next door. Kept as a redirect so links and bookmarks to
 * /elev/{cpr}/skoleskiftere[?sag={id}] still land on the case.
 */
export const load: PageServerLoad = async ({ params, url, parent }) => {
  const { skoleskifterSager } = await parent();

  if (!url.searchParams.has("sag")) {
    throw redirect(308, `/elev/${params.cpr}`);
  }

  const id = Number(url.searchParams.get("sag"));
  const sag = skoleskifterSager.find((s) => s.skoleskifter_id === id);

  if (!sag) {
    throw error(404, "Sagen findes ikke for denne elev");
  }

  throw redirect(307, sagHref(params.cpr, "skoleskifter", id, sag.status_tekst));
};
