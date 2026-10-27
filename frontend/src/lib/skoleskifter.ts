// Skoleskiftere og tilflyttere (draft) — types and the rules the overview and
// the case share. The types mirror backend/app/schemas/skoleskifter.py.

export type SkoleskifterRow = {
  skoleskifter_id: number;
  cpr: string | null;
  har_cpr: boolean;
  navn: string | null;
  navne_adresse_beskyttelse: boolean | null;
  adresse_tekst: string | null;
  modersmaal: string | null;
  elevklassetrin: string | null;
  distriktsskolekode: number | null;
  distriktsskole: string | null;
  variant: Variant;
  status_id: number;
  status_tekst: string;
  status_sortering: number | null;
  status_dato: string | null;
  modtaget_tidspunkt: string;
  esdh_noegle: string | null;
  esdh_url: string | null;
  dato_oensket_skolestart: string | null;
  oensket_skolekode: number | null;
  oensket_skole: string | null;
  nuvaerende_skolekode: number | null;
  nuvaerende_skole: string | null;
  klassetrin_ansoegning: string | null;
  kommende_adresse: string | null;
  saerlige_behov: boolean | null;
  skolens_vurdering: string | null;
  screeningsdato: string | null;
  samlet_resultat: string | null;
  skoletilbud_matrikel_id: number | null;
  skoletilbud_matrikel: string | null;
  skoletilbudstype_id: number | null;
  skoletilbudstype_tekst: string | null;
  dato_skoletilbud: string | null;
  klassetrin: string | null;
  bemaerkning: string | null;
  ppr_sendt_dato: string | null;
  afsluttet_dato: string | null;
  ventetid_dage: number | null;
  dage_hos_ppr: number | null;
  updated_at: string;
  updated_by: string;
};

export type SkoleskifterDetail = SkoleskifterRow & {
  ansoeger_navn: string | null;
  nuvaerende_skole_tekst: string | null;
  ansoegningsdata: string | null;
  point_1: number | null;
  resultat_1: string | null;
  point_2: number | null;
  resultat_2: string | null;
  point_3: number | null;
  resultat_3: string | null;
  start_visitationsklasse: string | null;
  spor: string | null;
  created_at: string;
  created_by: string;
};

export type Soeskende = {
  cpr: string;
  adresseringsnavn: string | null;
  navne_adresse_beskyttelse: boolean | null;
  skole_navn: string | null;
  elevklassetrin: string | null;
  sager: { omraade: string; beskrivelse: string; status_tekst: string; skoletilbud: string | null; dato: string }[];
};

/**
 * The three kinds of case (PUF's own description):
 * - Tilflytter: new to Aarhus Kommune, from another kommune or abroad — screened.
 * - Skoleskift internt (A): between two Aarhus schools — the current school assesses.
 * - Skoleskift udefra (B): from another kommune's folkeskole or a privatskole — screened.
 */
export type Variant = "Tilflytter" | "Skoleskift internt" | "Skoleskift udefra";

/** Only skoleskift internt is assessed by the school rather than screened. */
export const vurderesAfSkolen = (variant: Variant) => variant === "Skoleskift internt";

/** The statuses a caseworker sets; usp_recalculate_skoleskifter_status derives the rest. */
export const MANUELLE_STATUSSER = ["Ny", "Afventer sprogvurdering", "Sendt til PPR"] as const;

export const AFSLUTTET = "Afsluttet";

/** Waiting longer than this is marked on the overview (the sketch's "14 dage"). */
export const VENTETID_GRAENSE = 14;


// -----------------------------
// Tabs
// -----------------------------

export type Fane = "skoleskiftere" | "tilflyttere" | "uden-cpr" | "hos-ppr" | "afsluttede";

// The sketch's two columns — skoleskiftere and tilflyttere — first, then
// the special views it asks for: applications without CPR, and cases with
// PPR ("hvor lang tid sagen har ligget hos PPR"). Closed cases last.
export const FANER: { id: Fane; label: string }[] = [
  { id: "skoleskiftere", label: "Skoleskiftere" },
  { id: "tilflyttere", label: "Tilflyttere" },
  { id: "uden-cpr", label: "Uden CPR" },
  { id: "hos-ppr", label: "Hos PPR" },
  { id: "afsluttede", label: "Afsluttede" }
];

/** Which cases a tab shows. A case without CPR is on its own tab only. */
export function iFane(row: SkoleskifterRow, fane: Fane): boolean {
  const aaben = row.status_tekst !== AFSLUTTET;
  switch (fane) {
    case "skoleskiftere":
      return aaben && row.har_cpr && row.variant !== "Tilflytter";
    case "tilflyttere":
      return aaben && row.har_cpr && row.variant === "Tilflytter";
    case "uden-cpr":
      return aaben && !row.har_cpr;
    case "hos-ppr":
      return aaben && row.status_tekst === "Sendt til PPR";
    case "afsluttede":
      return !aaben;
  }
}

export function faneFraQuery(value: string | null): Fane {
  return FANER.some((f) => f.id === value) ? (value as Fane) : "skoleskiftere";
}

/** Where a case opens: on the child's page, or its own page while it has no CPR. */
export function sagHref(row: { skoleskifter_id: number; cpr: string | null }): string {
  return row.cpr
    ? `/elev/${row.cpr}/skoleskiftere?sag=${row.skoleskifter_id}`
    : `/skoleskiftere/sag/${row.skoleskifter_id}`;
}
