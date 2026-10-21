import { csvCpr, csvResponse, type CsvColumn } from "$lib/server/csv";
import { backendUserFetcher } from "$lib/server/backendApi";
import {
  aarFraQuery,
  faneFraQuery,
  iFane,
  jaNej,
  kommendeSkoleaar,
  skoleaarTekst,
  type SkolebegynderRow
} from "$lib/skolebegynder";

import type { RequestHandler } from "./$types";


/**
 * The skolebegynder cases of one school year and tab, as an Excel-ready file.
 *
 * The tab rule is NOT reimplemented here — $lib/skolebegynder.iFane is the
 * same function the page filters with, so the file holds exactly the cases
 * the tab showed. (The grid's own column filters are not applied: they live
 * in the browser. Narrow the result in Excel, which is what the export is
 * for.)
 *
 * Every column is exported, not only the visible ones — "Alt skal kunne
 * udtrækkes til Excel", as the sketch puts it.
 */

const jaNejCsv = (value: unknown) =>
  value === null || value === undefined ? "" : jaNej(Boolean(value));

const COLUMNS: CsvColumn[] = [
  { key: "navn", header: "Navn" },
  { key: "cpr", header: "CPR", format: csvCpr },
  { key: "skoleaar", header: "Skoleår", format: (value) => skoleaarTekst(Number(value)) },
  { key: "status_tekst", header: "Status" },
  { key: "screeningsdato", header: "Screeningsdato" },
  { key: "samlet_resultat", header: "Samlet resultat" },
  { key: "puf_screeningsresultat", header: "PUF-screeningsresultat" },
  { key: "of_percentil", header: "Ordforråd (percentil)" },
  { key: "sf_percentil", header: "Sprogforståelse (percentil)" },
  { key: "navn_konsulent", header: "Konsulent" },
  { key: "modersmaal", header: "Modersmål" },
  { key: "tilflyttet_dk_dato", header: "Tilflyttet DK" },
  { key: "ppr_status", header: "PPR", format: jaNejCsv },
  { key: "dagtilbud", header: "Indmeldt dagtilbud" },
  { key: "dagtilbud_afdeling", header: "Afdeling" },
  { key: "distriktsskole", header: "Distriktsskole" },
  { key: "oensket_skole", header: "Ønsket skole" },
  { key: "soeskende_skole", header: "Skoleønske søskende" },
  { key: "skoletilbud_matrikel", header: "Skoletilbud" },
  { key: "skoletilbudstype_tekst", header: "Skoletilbudstype" },
  { key: "skoleplaceringsaarsag_tekst", header: "Skoleplaceringsårsag" },
  { key: "krav_paa_befordring", header: "Krav på befordring", format: jaNejCsv },
  { key: "gaaafstand_distriktsskole_km", header: "Gåafstand distriktsskole (km)" },
  { key: "gaaafstand_oensket_skole_km", header: "Gåafstand ønsket skole (km)" },
  { key: "gaaafstand_skoletilbud_km", header: "Gåafstand skoletilbud (km)" },
  { key: "brevskabelon_tekst", header: "Skabelon" },
  { key: "bemaerkning", header: "Bemærkning" },
  { key: "skoler_afviger", header: "Skoler afviger", format: jaNejCsv },
  { key: "sagsbehandlingsdato", header: "Sagsbehandlingsdato" },
  { key: "afsluttet_dato", header: "Afsluttet" },
];


export const GET: RequestHandler = async (event) => {
  const api = backendUserFetcher(event);

  const res = await api("/skolebegynder");

  if (!res.ok) {
    console.error("Failed to fetch skolebegyndere:", res.status);

    return new Response("Kunne ikke hente skolebegyndere", { status: 502 });
  }

  const rows: SkolebegynderRow[] = await res.json();

  const fane = faneFraQuery(event.url.searchParams.get("fane"));
  const aar = aarFraQuery(event.url.searchParams.get("aar")) ?? kommendeSkoleaar();

  const udvalgte = rows.filter((row) => row.skoleaar === aar && iFane(row, fane));

  return csvResponse(
    udvalgte as unknown as Record<string, unknown>[],
    COLUMNS,
    `skolebegyndere-${aar}-${aar + 1}-${fane}`
  );
};
