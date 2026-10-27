import { error, redirect } from "@sveltejs/kit";

import { backendUserFetcher } from "$lib/server/backendApi";

import type { RequestHandler } from "./$types";


/**
 * The old case page. A skolebegynder case now lives on the student page, in
 * its area tab: /elev/{cpr}/skolebegynder?sag={id}. Kept as a redirect so
 * links and bookmarks to /skolebegynder/{id} still land on the case.
 */
export const GET: RequestHandler = async (event) => {
  const id = Number(event.params.id);

  if (!Number.isInteger(id) || id <= 0) {
    throw error(404, "Sagen findes ikke");
  }

  const res = await backendUserFetcher(event)(`/skolebegynder/${id}`);

  if (res.status === 404) {
    throw error(404, "Sagen findes ikke");
  }
  if (!res.ok) {
    throw error(502, "Kunne ikke hente sagen");
  }

  const sag = await res.json();

  throw redirect(308, `/elev/${sag.cpr}/skolebegynder?sag=${id}`);
};
