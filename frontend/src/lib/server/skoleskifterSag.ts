import { error, type RequestEvent } from "@sveltejs/kit";

import { backendUserFetcher } from "$lib/server/backendApi";
import { TOMME_LOOKUPS, type Lookups } from "$lib/skolebegynder";
import type { SkoleskifterDetail } from "$lib/skoleskifter";


/**
 * Everything SkoleskifterSag needs for one case: the case, the lookups for
 * the decision form and the case's own log entries. Shared by the student
 * page's "Aktiv sag" tab and its afgørelse page. (The siblings used to come
 * with it; they are the student page's own Søskende tab now.)
 */
export async function hentSkoleskifterSag(event: RequestEvent, id: number) {
  const api = backendUserFetcher(event);

  const [sagRes, lookupsRes] = await Promise.all([api(`/skoleskifter/${id}`), api("/lookup/all")]);

  if (sagRes.status === 404) {
    throw error(404, "Sagen findes ikke");
  }
  if (!sagRes.ok) {
    throw error(502, "Kunne ikke hente sagen");
  }

  const sag: SkoleskifterDetail = await sagRes.json();
  const lookups: Lookups = lookupsRes.ok ? { ...TOMME_LOOKUPS, ...(await lookupsRes.json()) } : TOMME_LOOKUPS;
  const fagomraadeId = lookups.fagomraader.find((f) => f.label === "Skoleskiftere og tilflyttere")?.id ?? null;

  const aktivitetRes = await api(`/aktivitet/${sag.cpr}`);
  // The child's log holds every area and case; this page shows this case's.
  const aktivitet: any[] = aktivitetRes.ok ? await aktivitetRes.json() : [];
  const sagsforloeb = aktivitet.filter(
    (a) => a.relateret_sag_id === id && (fagomraadeId === null || a.fagomraade_id === fagomraadeId)
  );

  return { sag, lookups, sagsforloeb, fagomraadeId };
}
