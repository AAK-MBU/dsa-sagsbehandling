import { error } from "@sveltejs/kit";

import { backendUserFetcher } from "$lib/server/backendApi";
import {
  TOMME_LOOKUPS,
  type AendringRow,
  type Lookups,
  type SkolebegynderDetail
} from "$lib/skolebegynder";

import type { PageServerLoad } from "./$types";


/**
 * One skolebegynder case, with what the page around it needs: the lookups
 * for the case-work form, the case's own log entries and its open changes.
 */
export const load: PageServerLoad = async (event) => {
  const id = Number(event.params.id);

  if (!Number.isInteger(id) || id <= 0) {
    throw error(404, "Sagen findes ikke");
  }

  const api = backendUserFetcher(event);

  const sagRes = await api(`/skolebegynder/${id}`);

  if (sagRes.status === 404) {
    throw error(404, "Sagen findes ikke");
  }
  if (!sagRes.ok) {
    throw error(502, "Kunne ikke hente sagen");
  }

  const sag: SkolebegynderDetail = await sagRes.json();

  const [lookupsRes, aktivitetRes, aendringerRes] = await Promise.all([
    api("/lookup/all"),
    api(`/aktivitet/${sag.cpr}`),
    api(`/skolebegynder/aendringer?skoleaar=${sag.skoleaar}`)
  ]);

  const lookups: Lookups = lookupsRes.ok ? { ...TOMME_LOOKUPS, ...(await lookupsRes.json()) } : TOMME_LOOKUPS;

  // The child's log holds every area and year; this page shows this case's.
  const aktivitet: any[] = aktivitetRes.ok ? await aktivitetRes.json() : [];
  const fagomraadeId = lookups.fagomraader.find((f) => f.label === "Skolebegynderscreeninger")?.id ?? null;
  const sagsforloeb = aktivitet.filter(
    (a) => a.relateret_sag_id === id && (fagomraadeId === null || a.fagomraade_id === fagomraadeId)
  );

  const aendringer: AendringRow[] = aendringerRes.ok
    ? (await aendringerRes.json()).filter((a: AendringRow) => a.skolebegynder_id === id)
    : [];

  return { sag, lookups, sagsforloeb, aendringer, fagomraadeId };
};
