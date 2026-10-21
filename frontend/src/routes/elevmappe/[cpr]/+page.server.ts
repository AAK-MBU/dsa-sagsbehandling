import { error } from "@sveltejs/kit";

import { backendUserFetcher } from "$lib/server/backendApi";
import type { SkolebegynderRow } from "$lib/skolebegynder";

import type { PageServerLoad } from "./$types";


/**
 * The Elevmappe: a child's master data, custody holders and cases.
 *
 * Loaded as befordringssystemet's /sag/[cpr] loads its sag: stamdata and
 * parents from /citizen, the cases from the area's own route, side by side
 * in one Promise.all. Keyed by CPR in the URL — the backend calls carry it in
 * their path, which is what puts "who looked up whom" in PortalAuditLog.
 */
export const load: PageServerLoad = async (event) => {
  const cpr = event.params.cpr;

  if (!/^\d{10}$/.test(cpr)) {
    throw error(404, "Eleven findes ikke");
  }

  const api = backendUserFetcher(event);

  const [stamdataRes, parentsRes, sagerRes] = await Promise.all([
    api(`/citizen/stamdata/${cpr}`),
    api(`/citizen/stamdata/${cpr}/parents`),
    api(`/skolebegynder/elev/${cpr}`)
  ]);

  if (!stamdataRes.ok) {
    throw error(502, "Kunne ikke hente elevmappen");
  }

  // As in befordringssystemet, an unknown CPR is a 200 with null.
  const stamdata = await stamdataRes.json();

  if (stamdata === null) {
    throw error(404, "Eleven findes ikke i DSA");
  }

  return {
    stamdata,
    parents: parentsRes.ok ? await parentsRes.json() : [],
    skolebegynderSager: (sagerRes.ok ? await sagerRes.json() : []) as SkolebegynderRow[]
  };
};
