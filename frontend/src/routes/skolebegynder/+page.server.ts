import { error } from "@sveltejs/kit";

import { backendUserFetcher } from "$lib/server/backendApi";
import { TOMME_LOOKUPS, type AendringRow, type Lookups, type SkolebegynderRow } from "$lib/skolebegynder";

import type { PageServerLoad } from "./$types";


/**
 * The skolebegynder overview: every case, the open changes and the lookups
 * the grid's dropdowns need.
 *
 * All school years are fetched and the page narrows to one. A cohort is a few
 * hundred children, so this keeps year switching instant without a reload.
 *
 * A failed case list is an error page, not an empty grid: an empty overview
 * would read as "nothing to do". Lookups degrade to empty dropdowns instead,
 * which shows up as missing options rather than a misleading picture.
 */
export const load: PageServerLoad = async (event) => {
  const api = backendUserFetcher(event);

  const [sagerRes, aendringerRes, lookupsRes] = await Promise.all([
    api("/skolebegynder"),
    api("/skolebegynder/aendringer"),
    api("/lookup/all")
  ]);

  if (!sagerRes.ok) {
    console.error("Failed to fetch skolebegyndere:", sagerRes.status);
    throw error(502, "Kunne ikke hente skolebegyndere");
  }

  const sager: SkolebegynderRow[] = await sagerRes.json();
  const aendringer: AendringRow[] = aendringerRes.ok ? await aendringerRes.json() : [];
  const lookups: Lookups = lookupsRes.ok ? { ...TOMME_LOOKUPS, ...(await lookupsRes.json()) } : TOMME_LOOKUPS;

  return { sager, aendringer, lookups };
};
