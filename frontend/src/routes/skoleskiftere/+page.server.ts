import { backendUserFetcher } from "$lib/server/backendApi";
import type { PageServerLoad } from "./$types";
import type { Ansoegning } from "$lib/types";


export const load: PageServerLoad = async (event) => {
  const api = backendUserFetcher(event);
  const res = await api("/ansoegninger");

  if (!res.ok) {
    console.error("Failed to fetch ansøgninger:", res.status);
    return { ansoegninger: [] as Ansoegning[] };
  }

  const ansoegninger: Ansoegning[] = await res.json();

  return { ansoegninger };
};
