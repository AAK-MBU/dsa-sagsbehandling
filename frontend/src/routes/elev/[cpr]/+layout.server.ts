import { error } from "@sveltejs/kit";

import { afgoerelser, alleSager, erAktiv } from "$lib/elevsag";
import { backendUserFetcher } from "$lib/server/backendApi";
import type { SkolebegynderRow } from "$lib/skolebegynder";
import type { SkoleskifterRow, Soeskende } from "$lib/skoleskifter";

import type { LayoutServerLoad } from "./$types";


/**
 * The student page: what every tab of it shows — the child's stamdata, the
 * custody holders, the siblings, and every case the child has in every built
 * area. From the cases it works out the one ACTIVE case (the "Aktiv sag" tab)
 * and the closed ones (Tidligere afgørelser), so the tab bar can label and
 * count them on every tab.
 *
 * Loaded as befordringssystemet's /sag/[cpr] loads its sag: stamdata and
 * parents from /citizen, the cases from the area's own route, side by side
 * in one Promise.all. Keyed by CPR in the URL — the backend calls carry it in
 * their path, which is what puts "who looked up whom" in PortalAuditLog.
 *
 * A new area adds its case list here and to alleSager in $lib/elevsag.
 */
export const load: LayoutServerLoad = async (event) => {
  const cpr = event.params.cpr;

  if (!/^\d{10}$/.test(cpr)) {
    throw error(404, "Eleven findes ikke");
  }

  const api = backendUserFetcher(event);

  const [stamdataRes, parentsRes, skolebegynderRes, skoleskifterRes, soeskendeRes] = await Promise.all([
    api(`/citizen/stamdata/${cpr}`),
    api(`/citizen/stamdata/${cpr}/parents`),
    api(`/skolebegynder/elev/${cpr}`),
    api(`/skoleskifter/elev/${cpr}`),
    api(`/citizen/stamdata/${cpr}/soeskende`)
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
  const skoleskifterSager: SkoleskifterRow[] = skoleskifterRes.ok ? await skoleskifterRes.json() : [];

  const sager = alleSager(skolebegynderSager, skoleskifterSager);

  return {
    stamdata,
    parents: (parentsRes.ok ? await parentsRes.json() : []) as any[],
    soeskende: (soeskendeRes.ok ? await soeskendeRes.json() : []) as Soeskende[],
    skolebegynderSager,
    skoleskifterSager,
    // Newest first. PUF's rule is one open case per child; should the data
    // ever hold two, the first tab shows the newest and says so.
    aktiveSager: sager.filter(erAktiv),
    afgoerelser: afgoerelser(sager)
  };
};
