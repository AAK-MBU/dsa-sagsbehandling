import { backendApiFetch } from "$lib/server/backendApi";
import type { PageServerLoad } from "./$types";
import type { Ansoegning } from "$lib/types";


export const load: PageServerLoad = async ({ fetch }) => {
  const res = await backendApiFetch(fetch, "/ansoegninger");

  if (!res.ok) {
    console.error("Failed to fetch ansøgninger:", res.status);
    return { ansoegninger: [] as Ansoegning[] };
  }

  const ansoegninger: Ansoegning[] = await res.json();

  return { ansoegninger };
};
