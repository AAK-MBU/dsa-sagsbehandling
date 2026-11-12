import { backendUserFetcher } from "$lib/server/backendApi";

import type { PageServerLoad } from "./$types";


/**
 * The Sprog og støtte tab: the child's other Elev_* history — mother tongue,
 * language-support periods, PPR periods and arrival in Denmark.
 */
export const load: PageServerLoad = async (event) => {
  const res = await backendUserFetcher(event)(`/citizen/stamdata/${event.params.cpr}/historik`);
  const historik = res.ok ? await res.json() : null;

  return {
    modersmaal: (historik?.modersmaal ?? []) as { modersmaal: string; gyldig_fra: string; gyldig_til: string | null }[],
    sprogstoettebehov: (historik?.sprogstoettebehov ?? []) as { startdato: string; slutdato: string | null }[],
    ppr: (historik?.ppr ?? []) as { startdato: string; slutdato: string | null }[],
    indrejse: (historik?.indrejse ?? null) as { foerste_indrejse: string | null; seneste_indrejse: string | null } | null,
    hentet: res.ok
  };
};
