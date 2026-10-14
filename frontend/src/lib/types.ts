// Mirrors backend/app/schemas/ansoegning.py — field names follow the
// OS2Forms formular ("Ansøgning om indmeldelse i modtagelsesklasse").

export type AnsoegningStatus =
  | "Ny"
  | "Under behandling"
  | "Afventer PPR"
  | "Afventer konsulent"
  | "Sendt skrivelse"
  | "Færdigbehandlet";

export type AnsoegerRelation = "Forælder" | "Pårørende/kontaktperson" | "Fagprofessionel";

export interface Ansoeger {
  relation_til_barnet: AnsoegerRelation;
  navn: string | null;
  cpr: string | null;
  har_mitid: boolean;
}

export interface Barn {
  fulde_navn: string;
  har_cpr: boolean;
  cpr: string | null;
  foedselsdato: string;
  koen: "Pige" | "Dreng" | null;
  adresse: string | null;
  postnummer: string | null;
  by: string | null;
  nationalitet: string;
  tidligere_dansk_skole: boolean | null;
  modersmaal: string | null;
  ankomstdato_danmark: string;
  skoleaar_foer_ankomst: number;
  afsluttet_afgangseksamen: boolean;
  antal_dokumentation_bilag: number;
  antal_skolepapir_bilag: number;
}

export interface SaerligeBehov {
  har_saerlige_behov: boolean;
  beskrivelse: string | null;
  antal_bilag: number;
}

export interface Foraeldre {
  foraelder_1_navn: string | null;
  foraelder_1_cpr: string | null;
  foraelder_2_navn: string | null;
  foraelder_2_cpr: string | null;
  telefon: string | null;
  email: string;
  kontaktperson_navn: string | null;
  kontaktperson_telefon: string | null;
  kontaktperson_sprog: string | null;
}

export interface Ansoegning {
  id: number;
  modtagelsesdato: string;
  status: AnsoegningStatus;

  ansoeger: Ansoeger;
  barn: Barn;
  saerlige_behov: SaerligeBehov;
  foraeldre: Foraeldre;

  anden_information: string | null;

  // Assigned during sagsbehandling
  sagsbehandler: string | null;
  klassetrin: string | null;
  modtagelsesskole: string | null;
  soeskende_paa_sag: boolean;
}
