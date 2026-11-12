import { error, redirect } from "@sveltejs/kit";

import { sagHref } from "$lib/elevsag";

import type { PageServerLoad } from "./$types";


/**
 * The old Skolebegynder tab of the student page. The student page has no area
 * tabs any more: an open case is its "Aktiv sag" tab (/elev/{cpr}), a closed
 * one is under Tidligere afgørelser. Kept as a redirect so links and
 * bookmarks to /elev/{cpr}/skolebegynder[?sag={id}] still land on the case.
 */
export const load: PageServerLoad = async ({ params, url, parent }) => {
  const { skolebegynderSager } = await parent();

  if (!url.searchParams.has("sag")) {
    throw redirect(308, `/elev/${params.cpr}`);
  }

  const id = Number(url.searchParams.get("sag"));
  const sag = skolebegynderSager.find((s) => s.skolebegynder_id === id);

  if (!sag) {
    throw error(404, "Sagen findes ikke for denne elev");
  }

  throw redirect(307, sagHref(params.cpr, "skolebegynder", id, sag.status_tekst));
};
