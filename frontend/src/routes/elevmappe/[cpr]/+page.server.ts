import { error } from "@sveltejs/kit";

import { backendUserFetcher } from "$lib/server/backendApi";

import type { PageServerLoad } from "./$types";


/**
 * The Elevmappe: a child's master data and every case DSA holds on them.
 *
 * Keyed by CPR in the URL, as befordringssystemet's /sag/[cpr]: the backend
 * call carries the CPR in its path, which is what puts "who looked up whom"
 * in PortalAuditLog.
 */
export const load: PageServerLoad = async (event) => {
  const cpr = event.params.cpr;

  if (!/^\d{10}$/.test(cpr)) {
    throw error(404, "Eleven findes ikke");
  }

  const res = await backendUserFetcher(event)(`/citizen/stamdata/${cpr}`);

  if (res.status === 404) {
    throw error(404, "Eleven findes ikke i DSA");
  }
  if (!res.ok) {
    throw error(502, "Kunne ikke hente elevmappen");
  }

  return { stamdata: await res.json() };
};
