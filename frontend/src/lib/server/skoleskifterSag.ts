import { error, type RequestEvent } from "@sveltejs/kit";

import { backendUserFetcher } from "$lib/server/backendApi";
import { TOMME_LOOKUPS, type Lookups } from "$lib/skolebegynder";
import type { SkoleskifterDetail, Soeskende } from "$lib/skoleskifter";


/**
 * Everything one skoleskifter case page needs — shared by the student page's
 * Skoleskiftere tab and the page of a case without CPR: the case, the
 * lookups for the decision form, the case's own log entries and the child's
 * siblings. Log and siblings need a CPR; without one they are empty.
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

  let sagsforloeb: any[] = [];
  let soeskende: Soeskende[] = [];

  if (sag.cpr) {
    const [aktivitetRes, soeskendeRes] = await Promise.all([
      api(`/aktivitet/${sag.cpr}`),
      api(`/citizen/stamdata/${sag.cpr}/soeskende`)
    ]);
    // The child's log holds every area and case; this page shows this case's.
    const aktivitet: any[] = aktivitetRes.ok ? await aktivitetRes.json() : [];
    sagsforloeb = aktivitet.filter(
      (a) => a.relateret_sag_id === id && (fagomraadeId === null || a.fagomraade_id === fagomraadeId)
    );
    soeskende = soeskendeRes.ok ? await soeskendeRes.json() : [];
  }

  return { sag, lookups, sagsforloeb, soeskende, fagomraadeId };
}
