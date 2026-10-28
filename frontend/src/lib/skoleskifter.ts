// Skoleskiftere og tilflyttere (draft) — types and the rules the overview and
// the case share. The types mirror backend/app/schemas/skoleskifter.py.

export type SkoleskifterRow = {
  skoleskifter_id: number;
  cpr: string;
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
  skoleaar: number | null;
  indgang: Indgang;
  nuvaerende_skoletilbud: string | null;
  udslusningsdato: string | null;
  nuvaerende_kommune: string | null;
  oensket_skolekode: number | null;
  oensket_skole: string | null;
  nuvaerende_skolekode: number | null;
  nuvaerende_skole: string | null;
  klassetrin_ansoegning: string | null;
  flytning: boolean | null;
  flyttedato: string | null;
  kommende_adresse: string | null;
  modersmaal_foraelder: string | null;
  modersmaal_skole: string | null;
  soeskende_paa_skolen: boolean | null;
  soeskende_klasse: string | null;
  skolens_afgoerelse: string | null;
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
  nuvaerende_skole_tekst: string | null;
  ansoegningsdata: string | null;
  begrundelse: string | null;
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
 * The three kinds of case (PUF's own description). The robot sets it from
 * the form; the caseworker can correct it. All three are assessed by PUF.
 * - Tilflytter: new to Aarhus Kommune — current kommune not Aarhus, moving.
 * - Skoleskift internt (A): between two Aarhus schools.
 * - Skoleskift udefra (B): from another kommune's school, not moving.
 */
export type Variant = "Tilflytter" | "Skoleskift internt" | "Skoleskift udefra";

export const VARIANTER: Variant[] = ["Tilflytter", "Skoleskift internt", "Skoleskift udefra"];

/**
 * How the case came (migration 005): straight from the parents when the
 * child is in modtagelsesklasse, else through the receiving school's form
 * (tilflytter til distriktet / ledig plads, and not Danish mother tongue).
 */
export type Indgang = "Modtagelsesklasse" | "Via skolen";

/** The screening result that closes the case: the child is not DSA's. */
export const ALDERSSVARENDE = "Alderssvarende dansk";

/** The statuses a caseworker sets; usp_recalculate_skoleskifter_status derives the rest. */
export const MANUELLE_STATUSSER = ["Ny", "Afventer sprogvurdering", "Sendt til PPR"] as const;

export const AFSLUTTET = "Afsluttet";

/** Waiting longer than this is marked on the overview (the sketch's "14 dage"). */
export const VENTETID_GRAENSE = 14;


// -----------------------------
// Tabs
// -----------------------------

export type Fane = "skoleskiftere" | "tilflyttere" | "hos-ppr" | "afsluttede";

// The sketch's two columns — skoleskiftere and tilflyttere — first, then
// the cases with PPR ("hvor lang tid sagen har ligget hos PPR"). Closed
// cases last.
export const FANER: { id: Fane; label: string }[] = [
  { id: "skoleskiftere", label: "Skoleskiftere" },
  { id: "tilflyttere", label: "Tilflyttere" },
  { id: "hos-ppr", label: "Hos PPR" },
  { id: "afsluttede", label: "Afsluttede" }
];

/** Which cases a tab shows. */
export function iFane(row: SkoleskifterRow, fane: Fane): boolean {
  const aaben = row.status_tekst !== AFSLUTTET;
  switch (fane) {
    case "skoleskiftere":
      return aaben && row.variant !== "Tilflytter";
    case "tilflyttere":
      return aaben && row.variant === "Tilflytter";
    case "hos-ppr":
      return aaben && row.status_tekst === "Sendt til PPR";
    case "afsluttede":
      return !aaben;
  }
}

export function faneFraQuery(value: string | null): Fane {
  return FANER.some((f) => f.id === value) ? (value as Fane) : "skoleskiftere";
}

/** Where a case opens: on the child's page. */
export function sagHref(row: { skoleskifter_id: number; cpr: string }): string {
  return `/elev/${row.cpr}/skoleskiftere?sag=${row.skoleskifter_id}`;
}
