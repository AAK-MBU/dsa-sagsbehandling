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
 * The Skolebegynder tab of the student page: one of the child's skolebegynder
 * cases, with what the page around it needs — the lookups for the case-work
 * form, the case's own log entries and its open changes.
 *
 * Which case: ?sag={id} when given (a link from the overview names it),
 * otherwise the newest. A child whose school start was postponed has one
 * case per school year; the page lets the caseworker switch between them.
 */
export const load: PageServerLoad = async (event) => {
  const { skolebegynderSager } = await event.parent();

  if (skolebegynderSager.length === 0) {
    return { sag: null, lookups: TOMME_LOOKUPS, sagsforloeb: [], aendringer: [], fagomraadeId: null };
  }

  const oensket = Number(event.url.searchParams.get("sag"));
  // The cases come newest school year first.
  const valgt = skolebegynderSager.find((s) => s.skolebegynder_id === oensket) ?? skolebegynderSager[0];

  if (event.url.searchParams.has("sag") && valgt.skolebegynder_id !== oensket) {
    throw error(404, "Sagen findes ikke for denne elev");
  }

  const id = valgt.skolebegynder_id;
  const api = backendUserFetcher(event);

  const [sagRes, lookupsRes, aktivitetRes, aendringerRes] = await Promise.all([
    api(`/skolebegynder/${id}`),
    api("/lookup/all"),
    api(`/aktivitet/${event.params.cpr}`),
    api(`/skolebegynder/aendringer?skoleaar=${valgt.skoleaar}`)
  ]);

  if (!sagRes.ok) {
    throw error(502, "Kunne ikke hente sagen");
  }

  const sag: SkolebegynderDetail = await sagRes.json();

  const lookups: Lookups = lookupsRes.ok ? { ...TOMME_LOOKUPS, ...(await lookupsRes.json()) } : TOMME_LOOKUPS;

  // The child's log holds every area and year; this tab shows this case's.
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
