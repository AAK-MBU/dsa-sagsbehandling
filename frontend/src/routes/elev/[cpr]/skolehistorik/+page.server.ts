import { backendUserFetcher } from "$lib/server/backendApi";

import type { PageServerLoad } from "./$types";


/** The Skolehistorik tab: the child's rows in Elev_Skolehistorik, newest first. */
export const load: PageServerLoad = async (event) => {
  const res = await backendUserFetcher(event)(`/citizen/stamdata/${event.params.cpr}/historik`);
  const historik = res.ok ? await res.json() : null;

  return { skolehistorik: (historik?.skolehistorik ?? []) as any[], hentet: res.ok };
};
