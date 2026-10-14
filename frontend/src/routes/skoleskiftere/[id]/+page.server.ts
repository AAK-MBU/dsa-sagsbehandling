import { error } from "@sveltejs/kit";
import { backendApiFetch } from "$lib/server/backendApi";
import type { PageServerLoad } from "./$types";
import type { Ansoegning } from "$lib/types";

export const load: PageServerLoad = async ({ fetch, params }) => {
  const res = await backendApiFetch(fetch, `/ansoegninger/${params.id}`);

  if (res.status === 404) {
    throw error(404, "Elevmappe ikke fundet");
  }
  if (!res.ok) {
    throw error(500, "Kunne ikke hente elevmappe");
  }

  const ansoegning: Ansoegning = await res.json();

  return { ansoegning };
};
