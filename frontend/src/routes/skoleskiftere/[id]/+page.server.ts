import { error } from "@sveltejs/kit";
import { backendUserFetcher } from "$lib/server/backendApi";
import type { PageServerLoad } from "./$types";
import type { Ansoegning } from "$lib/types";

export const load: PageServerLoad = async (event) => {
  const api = backendUserFetcher(event);
  const res = await api(`/ansoegninger/${event.params.id}`);

  if (res.status === 404) {
    throw error(404, "Elevmappe ikke fundet");
  }
  if (!res.ok) {
    throw error(500, "Kunne ikke hente elevmappe");
  }

  const ansoegning: Ansoegning = await res.json();

  return { ansoegning };
};
