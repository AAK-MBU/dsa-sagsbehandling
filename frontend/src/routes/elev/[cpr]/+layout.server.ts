import { error } from "@sveltejs/kit";

import { backendUserFetcher } from "$lib/server/backendApi";
import type { SkolebegynderRow } from "$lib/skolebegynder";

import type { LayoutServerLoad } from "./$types";


/**
 * The student page: what every tab of it shows — the child's stamdata, the
 * custody holders, and each built area's cases (for the counts on the area
 * tabs, and for the area's own page, which reads them through parent()).
 *
 * Loaded as befordringssystemet's /sag/[cpr] loads its sag: stamdata and
 * parents from /citizen, the cases from the area's own route, side by side
 * in one Promise.all. Keyed by CPR in the URL — the backend calls carry it in
 * their path, which is what puts "who looked up whom" in PortalAuditLog.
 *
 * A new area adds its case list here, and its count to `sagsantal`.
 */
export const load: LayoutServerLoad = async (event) => {
  const cpr = event.params.cpr;

  if (!/^\d{10}$/.test(cpr)) {
    throw error(404, "Eleven findes ikke");
  }

  const api = backendUserFetcher(event);

  const [stamdataRes, parentsRes, skolebegynderRes] = await Promise.all([
    api(`/citizen/stamdata/${cpr}`),
    api(`/citizen/stamdata/${cpr}/parents`),
    api(`/skolebegynder/elev/${cpr}`)
  ]);

  if (!stamdataRes.ok) {
    throw error(502, "Kunne ikke hente eleven");
  }

  // As in befordringssystemet, an unknown CPR is a 200 with null.
  const stamdata = await stamdataRes.json();

  if (stamdata === null) {
    throw error(404, "Eleven findes ikke i DSA");
  }

  const skolebegynderSager: SkolebegynderRow[] = skolebegynderRes.ok ? await skolebegynderRes.json() : [];

  return {
    stamdata,
    parents: (parentsRes.ok ? await parentsRes.json() : []) as any[],
    skolebegynderSager,
    // Per area tab (keyed by Area.elevside): all cases, and the open ones.
    sagsantal: {
      skolebegynder: {
        alle: skolebegynderSager.length,
        aabne: skolebegynderSager.filter((s) => s.status_tekst !== "Afsluttet").length
      }
    } as Record<string, { alle: number; aabne: number }>
  };
};
