import { error, type RequestEvent } from "@sveltejs/kit";

import { backendUserFetcher } from "$lib/server/backendApi";
import { TOMME_LOOKUPS, type AendringRow, type Lookups, type SkolebegynderDetail } from "$lib/skolebegynder";


/**
 * Everything SkolebegynderSag needs for one case: the case, the lookups for
 * the case-work form, the case's own log entries and its open changes.
 *
 * Shared by the student page's "Aktiv sag" tab and its afgørelse page — the
 * counterpart of hentSkoleskifterSag. Was the load of the old Skolebegynder
 * tab route (/elev/[cpr]/skolebegynder).
 */
export async function hentSkolebegynderSag(event: RequestEvent, id: number) {
  const api = backendUserFetcher(event);

  const [sagRes, lookupsRes] = await Promise.all([api(`/skolebegynder/${id}`), api("/lookup/all")]);

  if (sagRes.status === 404) {
    throw error(404, "Sagen findes ikke");
  }
  if (!sagRes.ok) {
    throw error(502, "Kunne ikke hente sagen");
  }

  const sag: SkolebegynderDetail = await sagRes.json();
  const lookups: Lookups = lookupsRes.ok ? { ...TOMME_LOOKUPS, ...(await lookupsRes.json()) } : TOMME_LOOKUPS;
  const fagomraadeId = lookups.fagomraader.find((f) => f.label === "Skolebegynderscreeninger")?.id ?? null;

  const [aktivitetRes, aendringerRes] = await Promise.all([
    api(`/aktivitet/${sag.cpr}`),
    api(`/skolebegynder/aendringer?skoleaar=${sag.skoleaar}`)
  ]);

  // The child's log holds every area and year; this page shows this case's.
  const aktivitet: any[] = aktivitetRes.ok ? await aktivitetRes.json() : [];
  const sagsforloeb = aktivitet.filter(
    (a) => a.relateret_sag_id === id && (fagomraadeId === null || a.fagomraade_id === fagomraadeId)
  );

  const aendringer: AendringRow[] = aendringerRes.ok
    ? (await aendringerRes.json()).filter((a: AendringRow) => a.skolebegynder_id === id)
    : [];

  return { sag, lookups, sagsforloeb, aendringer, fagomraadeId };
}
