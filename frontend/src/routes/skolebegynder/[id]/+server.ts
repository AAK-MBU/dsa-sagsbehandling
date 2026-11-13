import { error, redirect } from "@sveltejs/kit";

import { sagHref } from "$lib/elevsag";
import { backendUserFetcher } from "$lib/server/backendApi";

import type { RequestHandler } from "./$types";


/**
 * The old case page. A skolebegynder case now lives on the student page: its
 * "Aktiv sag" tab while open, Tidligere afgørelser once closed. Kept as a
 * redirect so links and bookmarks to /skolebegynder/{id} still land on it.
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

  // 307, not 308: where the case lives changes when it is closed or reopened.
  throw redirect(307, sagHref(sag.cpr, "skolebegynder", id, sag.status_tekst));
};
