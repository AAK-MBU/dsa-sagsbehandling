// Skolebegynderscreeninger — types and the rules the overview, the case page
// and the CSV export share.
//
// The types mirror backend/app/schemas/skolebegynder.py. The tab rule lives
// here once, so the page and the export cannot disagree about which cases a
// tab holds (the same lesson as befordringssystemet's revurderingFilter).

export type SkolebegynderRow = {
  skolebegynder_id: number;
  cpr: string;
  skoleaar: number;
  navn: string | null;
  navne_adresse_beskyttelse: boolean | null;
  adresse_tekst: string | null;
  koen: string | null;
  modersmaal: string | null;
  tilflyttet_dk_dato: string | null;
  ppr_status: boolean | null;
  status_id: number;
  status_tekst: string;
  status_sortering: number | null;
  status_dato: string | null;
  modtaget_tidspunkt: string;
  screeningsdato: string | null;
  samlet_resultat: string | null;
  puf_screeningsresultat: string | null;
  sprogstoettebehov: boolean | null;
  of_percentil: number | null;
  sf_percentil: number | null;
  navn_konsulent: string | null;
  dagtilbud: string | null;
  dagtilbud_afdeling: string | null;
  distriktsskolekode: number | null;
  distriktsskole: string | null;
  oensket_skolekode: number | null;
  oensket_skole: string | null;
  soeskende_skolekode: number | null;
  soeskende_skole: string | null;
  ansoeger_anden_skole: boolean | null;
  skoletilbud_matrikel_id: number | null;
  skoletilbud_matrikel: string | null;
  skoletilbud_skolekode: number | null;
  skoletilbudstype_id: number | null;
  skoletilbudstype_tekst: string | null;
  skoleplaceringsaarsag_id: number | null;
  skoleplaceringsaarsag_tekst: string | null;
  brevskabelon_id: number | null;
  brevskabelon_tekst: string | null;
  krav_paa_befordring: boolean | null;
  gaaafstand_distriktsskole_km: number | null;
  gaaafstand_oensket_skole_km: number | null;
  gaaafstand_skoletilbud_km: number | null;
  bemaerkning: string | null;
  sagsbehandlingsdato: string | null;
  afsluttet_dato: string | null;
  skoler_afviger: boolean;
  aabne_aendringer: number;
  updated_at: string;
  updated_by: string;
};

export type SkolebegynderDetail = SkolebegynderRow & {
  testtype: string | null;
  alder_mdr: number | null;
  gennemfoert: boolean | null;
  afbrudt: boolean | null;
  screening_noter: string | null;
  of_besvaret: number | null;
  of_ubesvaret: number | null;
  of_korrekt: number | null;
  of_forkert: number | null;
  of_korrekt_ratio: number | null;
  of_score: number | null;
  of_score_alt: number | null;
  sf_besvaret: number | null;
  sf_ubesvaret: number | null;
  sf_korrekt: number | null;
  sf_forkert: number | null;
  sf_korrekt_ratio: number | null;
  sf_korrekt_ratio_ori: number | null;
  sf_score: number | null;
  sf_score_alt: number | null;
  dagtilbud_afdeling_adresse: string | null;
  email_pl: string | null;
  email_distriktsskole: string | null;
  journalfil_dannet: string | null;
  graffil_dannet: string | null;
  created_at: string;
  created_by: string;
};

export type AendringRow = {
  aendring_id: number;
  skolebegynder_id: number;
  cpr: string;
  skoleaar: number;
  navn: string | null;
  navne_adresse_beskyttelse: boolean | null;
  adresse_tekst: string | null;
  distriktsskole: string | null;
  aendringsaarsag_id: number;
  aendringsaarsag_tekst: string;
  aendringsaarsag_sortering: number | null;
  beskrivelse: string | null;
  registreret_tidspunkt: string;
  status_tekst: string;
};

export type LookupOption = { id: number; label: string; fagomraade_id?: number | null; skolekode?: number };

export type Lookups = {
  fagomraader: LookupOption[];
  status: LookupOption[];
  skoletilbudstyper: LookupOption[];
  skoleplaceringsaarsager: LookupOption[];
  brevskabeloner: LookupOption[];
  aendringsaarsager: LookupOption[];
  skolematrikel: LookupOption[];
  skoler: LookupOption[];
};

export const TOMME_LOOKUPS: Lookups = {
  fagomraader: [],
  status: [],
  skoletilbudstyper: [],
  skoleplaceringsaarsager: [],
  brevskabeloner: [],
  aendringsaarsager: [],
  skolematrikel: [],
  skoler: []
};

/** The fields a caseworker may edit — SkolebegynderUpdateRequest. */
export type SkolebegynderFelter = {
  puf_screeningsresultat?: string | null;
  skoletilbud_matrikel_id?: number | null;
  skoletilbudstype_id?: number | null;
  skoleplaceringsaarsag_id?: number | null;
  brevskabelon_id?: number | null;
  krav_paa_befordring?: boolean | null;
  bemaerkning?: string | null;
  sagsbehandlingsdato?: string | null;
};


// -----------------------------
// Tabs
// -----------------------------

export type Fane = "overblik" | "naermere-afklaring" | "ikke-screenet" | "aendringer";

export const FANER: { id: Fane; label: string }[] = [
  { id: "overblik", label: "Overblik" },
  { id: "naermere-afklaring", label: "Nærmere afklaring" },
  { id: "ikke-screenet", label: "Ikke screenet" },
  { id: "aendringer", label: "Ændringer" }
];

/** Statuses on the Overblik tab: every screened child ("Alle screenet"). */
const OVERBLIK_STATUSSER = new Set(["Under behandling", "Skoletilbud", "Afsluttet"]);

/**
 * Which cases a tab shows. Ændringer is a different list (changes, not
 * cases) and is not filtered here.
 */
export function iFane(row: SkolebegynderRow, fane: Fane): boolean {
  switch (fane) {
    case "overblik":
      return OVERBLIK_STATUSSER.has(row.status_tekst);
    case "naermere-afklaring":
      return row.status_tekst === "Nærmere afklaring";
    case "ikke-screenet":
      return row.status_tekst === "Ikke screenet";
    default:
      return false;
  }
}

/** Parse ?fane=…, falling back to Overblik. */
export function faneFraQuery(value: string | null): Fane {
  return FANER.some((f) => f.id === value) ? (value as Fane) : "overblik";
}

/** Parse ?aar=…; null means "use the newest year in the data". */
export function aarFraQuery(value: string | null): number | null {
  const aar = Number(value);
  return Number.isInteger(aar) && aar >= 2000 && aar <= 2100 ? aar : null;
}


// -----------------------------
// Small display helpers
// -----------------------------

export function jaNej(value: boolean | null | undefined): string {
  if (value === null || value === undefined) return "—";
  return value ? "Ja" : "Nej";
}

/** A date or datetime from the API as DD-MM-YYYY. */
export function dato(value: string | null | undefined): string {
  if (!value) return "—";
  const [year, month, day] = value.slice(0, 10).split("-");
  return day && month && year ? `${day}-${month}-${year}` : value;
}

/** A datetime from the API as DD-MM-YYYY HH:MM. */
export function tidspunkt(value: string | null | undefined): string {
  if (!value) return "—";
  return `${dato(value)} ${value.slice(11, 16)}`.trim();
}

/** The API's error message from a failed response, for display. */
export async function fejltekst(res: Response): Promise<string> {
  try {
    const body = await res.json();
    if (typeof body?.detail === "string") return body.detail;
    if (Array.isArray(body?.detail) && body.detail[0]?.msg) return body.detail[0].msg;
  } catch {
    // Not JSON — fall through.
  }
  return `Fejl ${res.status}`;
}
