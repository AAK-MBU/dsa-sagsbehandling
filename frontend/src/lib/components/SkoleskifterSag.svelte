<script lang="ts">
  import { invalidateAll } from "$app/navigation";

  import { backendFetch } from "$lib/client/backendFetch";
  import { MAX_DATE, MIN_DATE, firstInvalidDate, firstOutOfRangeDate, iDagISO } from "$lib/dates";
  import DateInput from "$lib/components/DateInput.svelte";
  import Felt from "$lib/components/Felt.svelte";
  import { erAabenPeriode } from "$lib/elevsag";
  import { dato, fejltekst, PUF_RESULTATER, skoleaarTekst, tidspunkt, type Lookups } from "$lib/skolebegynder";
  import {
    AFSLUTTET,
    ALDERSSVARENDE,
    SKOLENS_SPROGVURDERINGER,
    SVARFRIST_DAGE,
    VARIANTER,
    type SkoleskifterDetail,
    type TidligereScreening
  } from "$lib/skoleskifter";
  import { getStatusBadgeClass } from "$lib/tableColumnConfig";

  /**
   * One skoleskifter case, as ONE card — laid out like befordringssystemet's
   * bevilling card: a header row (type, status, Sags-ID, caseworker, actions),
   * then the case read top to bottom in the order it is worked, a section per
   * step. Values are read-only until "Redigér"; then the fields turn into
   * inputs and the header offers Gem / Annullér. The case log sits beside the
   * card.
   *
   * Two flows (PUF, 2026-11; migration 007), from the case's type:
   *
   *   Intern   Skoleskift internt. Ansøgning -> Sprogvurdering på skolen ->
   *            Breve -> Afgørelse. No sprogstøttebehov: the case is closed.
   *   Ekstern  Skoleskift eksternt / Tilflytter. Ansøgning -> Sprogscreening
   *            -> Skoletilbud -> Breve.
   *
   * Shown on the student page: the "Aktiv sag" tab while open, Tidligere
   * afgørelser once closed (read-only, with "Genåbn sag").
   */
  export let sag: SkoleskifterDetail;
  export let lookups: Lookups;
  export let sagsforloeb: any[] = [];
  export let kanRedigere = false;
  export let fagomraadeId: number | null = null;
  /** The child's earlier assessments (the skolebegynder screening, other cases). */
  export let screeninger: TidligereScreening[] = [];
  /** The child's language-support periods (Elev_Sprogstoettebehov). */
  export let sprogstoette: { startdato: string; slutdato: string | null }[] = [];
  /** A period covering today — the student card's "Sprogstøttebehov". */
  export let sprogstoettebehovNu = false;

  $: afsluttet = sag.status_tekst === AFSLUTTET;
  $: intern = sag.forloeb === "Intern";
  $: kanHandle = kanRedigere && !afsluttet;


  // -----------------------------
  // Steps — where the case is in its flow
  // -----------------------------

  $: trin = intern
    ? ["Ansøgning", "Sprogvurdering", "Breve", "Afgørelse"]
    : ["Ansøgning", "Sprogscreening", "Skoletilbud", "Breve"];

  // The step being worked on now (0-based); trin.length when the case is closed.
  $: aktueltTrin = afsluttet
    ? trin.length
    : intern
      ? sag.skolens_sprogvurdering === null
        ? 1
        : sag.skolens_sprogvurdering === "Fortsat behov for sprogstøtte" && !sag.sprogstoettebrev_sendt
          ? 2
          : 3
      : sag.samlet_resultat === null
        ? 1
        : !harSkoletilbud
          ? 2
          : 3;

  $: harSkoletilbud = sag.skoletilbud_matrikel_id !== null && sag.skoletilbudstype_id !== null && sag.dato_skoletilbud !== null;

  // Ekstern, no free place: the contacted school has two days to answer.
  $: svarfrist = sag.dato_kontakt_skole ? plusDage(sag.dato_kontakt_skole, SVARFRIST_DAGE) : null;
  $: fristOverskredet = svarfrist !== null && !harSkoletilbud && svarfrist < iDagISO();

  function plusDage(iso: string, dage: number): string {
    const [y, m, d] = iso.slice(0, 10).split("-").map(Number);
    const ny = new Date(y, m - 1, d + dage);
    return [ny.getFullYear(), String(ny.getMonth() + 1).padStart(2, "0"), String(ny.getDate()).padStart(2, "0")].join("-");
  }


  // -----------------------------
  // Editing — a copy of the editable fields while "Redigér" is on
  // -----------------------------

  type JaNej = "" | "ja" | "nej";

  type Form = {
    variant: string;
    sagsbehandler_id: number | "";
    andet_modersmaal: JaNej;
    dato_forespoergsel_skole: string;
    dato_svar_skole: string;
    skolens_sprogvurdering: string;
    dato_indkaldelse_screening: string;
    screeningsdato: string;
    point_1: string; resultat_1: string;
    point_2: string; resultat_2: string;
    point_3: string; resultat_3: string;
    samlet_resultat: string;
    ledig_plads: JaNej;
    kontaktet_skole_matrikel_id: number | "";
    dato_kontakt_skole: string;
    midlertidigt_skoletilbud_matrikel_id: number | "";
    start_visitationsklasse: string;
    skoletilbud_matrikel_id: number | "";
    skoletilbudstype_id: number | "";
    dato_skoletilbud: string;
    klassetrin: string;
    spor: string;
    optagelsesbrev_sendt: string;
    sprogstoettebrev_sendt: string;
    partshoeringsbrev_sendt: string;
    krav_paa_befordring: JaNej;
    befordring_bemaerkning: string;
    bemaerkning: string;
  };

  let redigerer = false;
  let form: Form;

  const tekst = (v: unknown) => (v === null || v === undefined ? "" : String(v).replace(".", ","));
  const jaNejForm = (v: boolean | null): JaNej => (v === null ? "" : v ? "ja" : "nej");

  function startRedigering() {
    form = {
      variant: sag.variant,
      sagsbehandler_id: sag.sagsbehandler_id ?? "",
      andet_modersmaal: jaNejForm(sag.andet_modersmaal),
      dato_forespoergsel_skole: sag.dato_forespoergsel_skole ?? "",
      dato_svar_skole: sag.dato_svar_skole ?? "",
      skolens_sprogvurdering: sag.skolens_sprogvurdering ?? "",
      dato_indkaldelse_screening: sag.dato_indkaldelse_screening ?? "",
      screeningsdato: sag.screeningsdato ?? "",
      point_1: tekst(sag.point_1), resultat_1: sag.resultat_1 ?? "",
      point_2: tekst(sag.point_2), resultat_2: sag.resultat_2 ?? "",
      point_3: tekst(sag.point_3), resultat_3: sag.resultat_3 ?? "",
      samlet_resultat: sag.samlet_resultat ?? "",
      ledig_plads: jaNejForm(sag.ledig_plads),
      kontaktet_skole_matrikel_id: sag.kontaktet_skole_matrikel_id ?? "",
      dato_kontakt_skole: sag.dato_kontakt_skole ?? "",
      midlertidigt_skoletilbud_matrikel_id: sag.midlertidigt_skoletilbud_matrikel_id ?? "",
      start_visitationsklasse: sag.start_visitationsklasse ?? "",
      skoletilbud_matrikel_id: sag.skoletilbud_matrikel_id ?? "",
      skoletilbudstype_id: sag.skoletilbudstype_id ?? "",
      dato_skoletilbud: sag.dato_skoletilbud ?? "",
      klassetrin: sag.klassetrin ?? "",
      spor: sag.spor ?? "",
      optagelsesbrev_sendt: sag.optagelsesbrev_sendt ?? "",
      sprogstoettebrev_sendt: sag.sprogstoettebrev_sendt ?? "",
      partshoeringsbrev_sendt: sag.partshoeringsbrev_sendt ?? "",
      krav_paa_befordring: jaNejForm(sag.krav_paa_befordring),
      befordring_bemaerkning: sag.befordring_bemaerkning ?? "",
      bemaerkning: sag.bemaerkning ?? ""
    };
    besked = null;
    redigerer = true;
  }

  function annullerRedigering() {
    redigerer = false;
    besked = null;
  }

  // A reloaded case (after a save elsewhere, close or reopen) ends editing.
  let viserFor = "";
  $: if (`${sag.skoleskifter_id}-${sag.updated_at}` !== viserFor) {
    viserFor = `${sag.skoleskifter_id}-${sag.updated_at}`;
    redigerer = false;
  }

  const tomTilNull = (v: string) => v.trim() || null;
  const tal = (v: string) => (v.trim() === "" ? null : Number(v.trim().replace(",", ".")));
  const idEllerNull = (v: number | "") => (v === "" ? null : Number(v));
  const boolEllerNull = (v: JaNej) => (v === "" ? null : v === "ja");

  // Dates of something done — not later than today (see gem).
  const UDFOERT_NAVNE: Record<string, string> = {
    dato_forespoergsel_skole: "Forespørgsel sendt til skolen",
    dato_svar_skole: "Skolen svarede",
    dato_indkaldelse_screening: "Indkaldt til screening",
    screeningsdato: "Screening gennemført",
    dato_kontakt_skole: "Kontaktet",
    optagelsesbrev_sendt: "Optagelsesbrev",
    sprogstoettebrev_sendt: "Brev om sprogstøtte",
    partshoeringsbrev_sendt: "Partshøringsbrev"
  };
  const UDFOERT_DATOER = Object.keys(UDFOERT_NAVNE);

  const DATOFELTER = [
    "dato_forespoergsel_skole", "dato_svar_skole", "dato_indkaldelse_screening", "screeningsdato",
    "dato_kontakt_skole", "start_visitationsklasse", "dato_skoletilbud",
    "optagelsesbrev_sendt", "sprogstoettebrev_sendt", "partshoeringsbrev_sendt"
  ];


  // -----------------------------
  // Talking to the API
  // -----------------------------

  let besked: { type: "ok" | "fejl"; tekst: string } | null = null;
  let arbejder = false;

  async function kald(path: string, init: RequestInit, okTekst: (svar: any) => string) {
    if (arbejder) return;
    arbejder = true;
    besked = null;
    try {
      const res = await backendFetch(path, init);
      if (!res.ok) {
        besked = { type: "fejl", tekst: await fejltekst(res) };
        return;
      }
      const svar = await res.json();
      besked = { type: "ok", tekst: okTekst(svar) };
      await invalidateAll();
    } finally {
      arbejder = false;
    }
  }

  const json = (method: string, body: object) => ({
    method,
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body)
  });

  function gem() {
    const point = [form.point_1, form.point_2, form.point_3].map(tal);
    if (point.some((p) => p !== null && Number.isNaN(p))) {
      besked = { type: "fejl", tekst: "Point skal være tal, fx 12,5." };
      return;
    }

    const felter: Record<string, unknown> = {
      variant: form.variant,
      sagsbehandler_id: idEllerNull(form.sagsbehandler_id),
      andet_modersmaal: boolEllerNull(form.andet_modersmaal),
      dato_forespoergsel_skole: form.dato_forespoergsel_skole || null,
      dato_svar_skole: form.dato_svar_skole || null,
      skolens_sprogvurdering: form.skolens_sprogvurdering || null,
      dato_indkaldelse_screening: form.dato_indkaldelse_screening || null,
      screeningsdato: form.screeningsdato || null,
      point_1: point[0], resultat_1: tomTilNull(form.resultat_1),
      point_2: point[1], resultat_2: tomTilNull(form.resultat_2),
      point_3: point[2], resultat_3: tomTilNull(form.resultat_3),
      samlet_resultat: form.samlet_resultat || null,
      ledig_plads: boolEllerNull(form.ledig_plads),
      kontaktet_skole_matrikel_id: idEllerNull(form.kontaktet_skole_matrikel_id),
      dato_kontakt_skole: form.dato_kontakt_skole || null,
      midlertidigt_skoletilbud_matrikel_id: idEllerNull(form.midlertidigt_skoletilbud_matrikel_id),
      start_visitationsklasse: form.start_visitationsklasse || null,
      skoletilbud_matrikel_id: idEllerNull(form.skoletilbud_matrikel_id),
      skoletilbudstype_id: idEllerNull(form.skoletilbudstype_id),
      dato_skoletilbud: form.dato_skoletilbud || null,
      klassetrin: tomTilNull(form.klassetrin),
      spor: tomTilNull(form.spor),
      optagelsesbrev_sendt: form.optagelsesbrev_sendt || null,
      sprogstoettebrev_sendt: form.sprogstoettebrev_sendt || null,
      partshoeringsbrev_sendt: form.partshoeringsbrev_sendt || null,
      krav_paa_befordring: boolEllerNull(form.krav_paa_befordring),
      befordring_bemaerkning: tomTilNull(form.befordring_bemaerkning),
      bemaerkning: tomTilNull(form.bemaerkning)
    };

    // As everywhere: the picker's bounds do not stop a typed date, this does.
    const ugyldig = firstInvalidDate(felter, DATOFELTER) ?? firstOutOfRangeDate(felter, DATOFELTER);
    if (ugyldig) {
      besked = { type: "fejl", tekst: `Ugyldig dato: ${ugyldig[1]}` };
      return;
    }

    // A request, a reply or a letter is registered once it has happened.
    const fremtidig = UDFOERT_DATOER.find((f) => typeof felter[f] === "string" && (felter[f] as string) > iDag);
    if (fremtidig) {
      besked = { type: "fejl", tekst: `${UDFOERT_NAVNE[fremtidig]} kan ikke ligge efter i dag.` };
      return;
    }

    kald(`/skoleskifter/${sag.skoleskifter_id}`, json("PUT", felter), (svar) => `Gemt — status: ${svar.status_tekst}.`);
  }

  function saetStatus(status: string, okTekst: string) {
    kald(`/skoleskifter/${sag.skoleskifter_id}`, json("PUT", { manuel_status: status }), () => okTekst);
  }

  function afslut(begrundelse: string | null, spoergsmaal: string) {
    if (!confirm(spoergsmaal)) return;
    kald(`/skoleskifter/${sag.skoleskifter_id}/afslut`, json("POST", { begrundelse }), () => "Sagen er afsluttet.");
  }

  // The reason written to the case log when the caseworker closes it from
  // the header — said for them where the case makes it plain.
  $: afslutBegrundelse = intern
    ? sag.skolens_sprogvurdering
      ? `Skolens sprogvurdering: ${sag.skolens_sprogvurdering}`
      : null
    : sag.samlet_resultat === ALDERSSVARENDE
      ? "Alderssvarende dansk — optagelsesbrev sendt"
      : null;

  function genaabn() {
    if (!confirm("Genåbn sagen, så den kan ændres?")) return;
    kald(`/skoleskifter/${sag.skoleskifter_id}/genaabn`, { method: "POST" }, (svar) => `Sagen er genåbnet — status: ${svar.status_tekst}.`);
  }

  let kommentar = "";
  function tilfoejKommentar() {
    const t = kommentar.trim();
    if (!t) return;
    kald(
      `/aktivitet/${sag.cpr}`,
      json("POST", { aktivitetstype: "Kommentar", kommentar: t, fagomraade_id: fagomraadeId, relateret_sag_id: sag.skoleskifter_id }),
      () => {
        kommentar = "";
        return "Kommentaren er tilføjet.";
      }
    );
  }


  // -----------------------------
  // Display helpers
  // -----------------------------

  const jaNej = (v: boolean | null | undefined) => (v === null || v === undefined ? "—" : v ? "Ja" : "Nej");
  const vis = (v: unknown) => (v === null || v === undefined || v === "" ? "—" : String(v));
  const point = (v: number | null) => (v === null ? "—" : String(v).replace(".", ","));
  const sendt = (v: string | null) => (v ? `Sendt ${dato(v)}` : "Ikke sendt");

  // The three screening materials: point and result field names.
  const MATERIALER = [
    ["point_1", "resultat_1"],
    ["point_2", "resultat_2"],
    ["point_3", "resultat_3"]
  ] as const;

  // Dates that record something done (a request, a reply, a letter) cannot be
  // ahead; the picker stops at today. The offer date and visitationsklasse
  // start can be.
  const iDag = iDagISO();

  const input = "w-full border border-gray-300 rounded px-2.5 py-1.5 text-sm bg-white";
</script>


<div class="grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_22rem] gap-5 items-start">

  <article class="rounded-lg overflow-hidden kort">

    <!-- ================= Header ================= -->
    <header class="flex flex-wrap items-center justify-between gap-3 px-6 py-4 border-b border-gray-100">
      <div class="flex flex-wrap items-center gap-3">
        {#if redigerer}
          <select class="border border-gray-300 rounded px-2 py-1 text-sm bg-white" bind:value={form.variant} aria-label="Type">
            {#each VARIANTER as v}<option value={v}>{v}</option>{/each}
          </select>
        {:else}
          <span class="font-mono text-xs rounded px-2 py-0.5 text-white" style="background-color: #3b2168;">{sag.variant}</span>
        {/if}
        <span class="inline-block px-2 py-0.5 rounded text-xs font-medium {getStatusBadgeClass(sag.status_tekst)}">{sag.status_tekst}</span>
        <span class="text-gray-300 select-none">|</span>
        {#if sag.esdh_url && sag.esdh_noegle}
          <a href={sag.esdh_url} target="_blank" rel="noopener noreferrer" title="Åbn sagen i GO" class="font-mono text-sm text-sky-600 hover:underline">{sag.esdh_noegle}</a>
        {:else}
          <span class="font-mono text-sm text-gray-500">{sag.esdh_noegle ?? "Intet Sags-ID"}</span>
        {/if}
        <span class="text-sm text-gray-500">Modtaget {dato(sag.modtaget_tidspunkt)} · {sag.ventetid_dage ?? "—"} dage</span>
      </div>

      {#if kanRedigere}
        <div class="flex flex-wrap items-center gap-2">
          {#if afsluttet}
            <button type="button" class="px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-50" disabled={arbejder} on:click={genaabn}>
              Genåbn sag
            </button>
          {:else if redigerer}
            <button type="button" class="px-3 py-1.5 text-sm font-medium bg-green-600 hover:bg-green-700 text-white rounded disabled:opacity-50" disabled={arbejder} on:click={gem}>
              {arbejder ? "Gemmer…" : "Gem"}
            </button>
            <button type="button" class="px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50" disabled={arbejder} on:click={annullerRedigering}>
              Annullér
            </button>
          {:else}
            <button type="button" class="px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-50" disabled={arbejder} on:click={startRedigering}>
              Redigér
            </button>
            <span class="w-px h-5 bg-gray-200 mx-1"></span>
            {#if sag.status_tekst === "Sendt til PPR"}
              <button type="button" class="px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-50" disabled={arbejder}
                on:click={() => saetStatus("Ny", "Sagen er tilbage fra PPR.")}>Tilbage fra PPR</button>
            {:else}
              <button type="button" class="px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-50" disabled={arbejder}
                on:click={() => saetStatus("Sendt til PPR", "Sagen er sendt til PPR.")}>Send til PPR</button>
            {/if}
            <button type="button" class="px-3 py-1.5 text-sm font-medium rounded text-white bg-dsa-700 hover:bg-dsa-800 disabled:opacity-50" disabled={arbejder}
              on:click={() => afslut(afslutBegrundelse, "Afslut sagen?")}>Afslut sag</button>
          {/if}
        </div>
      {/if}
    </header>

    <!-- Caseworker, and where the case is in its flow -->
    <div class="flex flex-wrap items-center justify-between gap-4 px-6 py-3 border-b border-gray-100 bg-gray-50/60">
      <ol class="flex flex-wrap items-center gap-x-2 gap-y-1 text-[12px]" aria-label="Sagens forløb">
        {#each trin as t, i}
          <li class="flex items-center gap-2">
            <span
              class="inline-flex items-center justify-center w-5 h-5 rounded-full text-[11px] font-bold
                {i < aktueltTrin ? 'bg-dsa-600 text-white' : i === aktueltTrin ? 'bg-white border-2 border-dsa-600 text-dsa-700' : 'bg-white border border-gray-300 text-gray-400'}"
              aria-current={i === aktueltTrin ? "step" : undefined}
            >{i < aktueltTrin ? "✓" : i + 1}</span>
            <span class={i === aktueltTrin ? "font-semibold text-dsa-800" : i < aktueltTrin ? "text-gray-700" : "text-gray-400"}>{t}</span>
            {#if i < trin.length - 1}<span class="text-gray-300">›</span>{/if}
          </li>
        {/each}
        <li class="ml-2 text-gray-400">{intern ? "Internt forløb" : "Eksternt forløb"}</li>
      </ol>

      <label class="flex items-center gap-2 text-sm">
        <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500">Sagsbehandler</span>
        {#if redigerer}
          <select class="border border-gray-300 rounded px-2 py-1 text-sm bg-white" bind:value={form.sagsbehandler_id}>
            <option value="">— Ingen —</option>
            {#each lookups.sagsbehandlere as o}<option value={o.id}>{o.label}</option>{/each}
          </select>
        {:else}
          <span class="text-gray-800">{sag.sagsbehandler_tekst ?? "Ikke tildelt"}</span>
        {/if}
      </label>
    </div>

    {#if besked}
      <div
        class="mx-6 mt-4 px-3 py-2 text-sm rounded border {besked.type === 'ok' ? 'bg-emerald-50 text-emerald-800 border-emerald-100' : 'bg-red-50 text-red-700 border-red-200'}"
        role={besked.type === "fejl" ? "alert" : "status"}
      >{besked.tekst}</div>
    {/if}

    {#if afsluttet}
      <p class="mx-6 mt-4 text-sm text-gray-500">Afsluttet {dato(sag.afsluttet_dato)} — genåbn sagen for at ændre den.</p>
    {/if}


    <!-- ================= 1. Ansøgning ================= -->
    <section class="sektion">
      <h3 class="sektionstitel"><span class="nr">1</span> Ansøgning</h3>
      <div class="felter">
        <Felt label="Indgang">{sag.indgang === "Modtagelsesklasse" ? "Fra forældre (modtagelsesklasse)" : "Via skolens afgørelse"}</Felt>
        <Felt label="Skoleår">{sag.skoleaar === null ? "—" : skoleaarTekst(sag.skoleaar)}</Felt>
        <Felt label="Nuværende skole">{vis(sag.nuvaerende_skole)}{#if sag.nuvaerende_kommune && sag.nuvaerende_kommune !== "Aarhus Kommune"}<span class="block text-gray-500 text-xs">{sag.nuvaerende_kommune}</span>{/if}</Felt>
        <Felt label="Nuværende klasse">{vis(sag.klassetrin_ansoegning)}{sag.nuvaerende_skoletilbud ? ` · ${sag.nuvaerende_skoletilbud}` : ""}</Felt>
        <Felt label="Ønsket skole">{vis(sag.oensket_skole)}</Felt>
        <Felt label="Skolens afgørelse">{vis(sag.skolens_afgoerelse)}</Felt>
        <Felt label="Søskende på skolen">{sag.soeskende_paa_skolen ? `Ja${sag.soeskende_klasse ? ` · ${sag.soeskende_klasse}` : ""}` : jaNej(sag.soeskende_paa_skolen)}</Felt>
        <Felt label="Modersmål (TEA)">
          {sag.modersmaal ?? "Ikke registreret"}
          {#if sag.modersmaal_foraelder}<span class="block text-gray-500 text-xs">Forældre: {sag.modersmaal_foraelder}</span>{/if}
          {#if sag.modersmaal_skole}<span class="block text-gray-500 text-xs">Skolen: {sag.modersmaal_skole}</span>{/if}
        </Felt>
        {#if !intern}
          <Felt label="Andet modersmål end dansk">
            {#if redigerer}
              <select class={input} bind:value={form.andet_modersmaal}>
                <option value="">— Ikke vurderet —</option><option value="ja">Ja</option><option value="nej">Nej</option>
              </select>
            {:else}{jaNej(sag.andet_modersmaal)}{/if}
          </Felt>
          <Felt label="Flytning">
            {#if sag.flytning}
              {dato(sag.flyttedato)}<span class="block text-gray-500 text-xs">{sag.kommende_adresse ?? "Adressen kendes endnu ikke"}</span>
            {:else}{jaNej(sag.flytning)}{/if}
          </Felt>
        {/if}
        {#if sag.nuvaerende_skoletilbud === "Modtagelsesklasse"}
          <Felt label="Kan udsluses pr.">{dato(sag.udslusningsdato)}</Felt>
        {/if}
        {#if sag.begrundelse}
          <Felt label="Forældrenes begrundelse" bred><span class="whitespace-pre-line">{sag.begrundelse}</span></Felt>
        {/if}
      </div>
    </section>


    {#if intern}

      <!-- ================= 2. Sprogvurdering på skolen (intern) ================= -->
      <section class="sektion" class:aktuel={aktueltTrin === 1}>
        <h3 class="sektionstitel"><span class="nr">2</span> Sprogvurdering på skolen</h3>
        <div class="felter">
          <Felt label="Sprogstøttebehov (TEA)">
            <span class="inline-block px-2 py-0.5 rounded text-xs font-semibold {sprogstoettebehovNu ? 'bg-amber-100 text-amber-800' : 'bg-gray-100 text-gray-600'}">
              {sprogstoettebehovNu ? "Ja" : "Nej"}
            </span>
          </Felt>
          <Felt label="Forespørgsel sendt til skolen">
            {#if redigerer}<DateInput min={MIN_DATE} max={iDag} class={input} bind:value={form.dato_forespoergsel_skole} />
            {:else}{dato(sag.dato_forespoergsel_skole)}{/if}
          </Felt>
          <Felt label="Skolen svarede">
            {#if redigerer}<DateInput min={MIN_DATE} max={iDag} class={input} bind:value={form.dato_svar_skole} />
            {:else}{dato(sag.dato_svar_skole)}{/if}
          </Felt>
          <Felt label="Skolens vurdering">
            {#if redigerer}
              <select class={input} bind:value={form.skolens_sprogvurdering}>
                <option value="">— Afventer —</option>
                {#each SKOLENS_SPROGVURDERINGER as r}<option value={r}>{r}</option>{/each}
              </select>
            {:else}
              <span class={sag.skolens_sprogvurdering ? "font-semibold" : ""}>{sag.skolens_sprogvurdering ?? "Afventer"}</span>
            {/if}
          </Felt>
        </div>

        <!-- What to do now, while this is the step -->
        {#if kanHandle && !redigerer && aktueltTrin === 1}
          {#if !sprogstoettebehovNu && !sag.dato_forespoergsel_skole}
            <div class="naeste">
              <p>Barnet har intet registreret sprogstøttebehov, så sagen er ikke DSA's.</p>
              <button type="button" class="px-3 py-1.5 text-sm font-medium rounded text-white bg-dsa-700 hover:bg-dsa-800 disabled:opacity-50" disabled={arbejder}
                on:click={() => afslut("Intet sprogstøttebehov — ikke relevant for DSA", "Afslut sagen? Barnet har intet registreret sprogstøttebehov.")}>
                Afslut: intet sprogstøttebehov
              </button>
            </div>
          {:else if !sag.dato_forespoergsel_skole}
            <p class="naeste">Kontakt skolen, bed om en sprogvurdering, og registrér datoen for henvendelsen.</p>
          {:else}
            <p class="naeste">Afventer skolens svar — registrér resultatet, når skolen melder tilbage.</p>
          {/if}
        {/if}
      </section>

      <!-- ================= 3. Breve (intern) ================= -->
      <section class="sektion" class:aktuel={aktueltTrin === 2}>
        <h3 class="sektionstitel"><span class="nr">3</span> Breve</h3>
        <div class="felter">
          <Felt label="Brev om fortsat sprogstøtte">
            {#if redigerer}<DateInput min={MIN_DATE} max={iDag} class={input} bind:value={form.sprogstoettebrev_sendt} />
            {:else}{sendt(sag.sprogstoettebrev_sendt)}{/if}
          </Felt>
        </div>
        {#if kanHandle && !redigerer && aktueltTrin === 2}
          <p class="naeste">Eleven har fortsat behov for sprogstøtte: send brev til forældrene, og registrér datoen.</p>
        {/if}
      </section>

      <!-- ================= 4. Afgørelse (intern) ================= -->
      <section class="sektion" class:aktuel={aktueltTrin === 3}>
        <h3 class="sektionstitel"><span class="nr">4</span> Afgørelse</h3>
        <div class="felter">
          <Felt label="Udfald">
            {#if sag.skolens_sprogvurdering === "Afventer optagelse i Sprog+"}Eleven afventer optagelse i Sprog+
            {:else if sag.skolens_sprogvurdering}Eleven har fortsat behov for sprogstøtte
            {:else}—{/if}
          </Felt>
        </div>
        {#if kanHandle && !redigerer && aktueltTrin === 3}
          <p class="naeste">Skolens vurdering foreligger{sag.sprogstoettebrev_sendt ? ", og brevet er sendt" : ""} — afslut sagen.</p>
        {/if}
      </section>

    {:else}

      <!-- ================= 2. Sprogscreening (ekstern) ================= -->
      <section class="sektion" class:aktuel={aktueltTrin === 1}>
        <h3 class="sektionstitel"><span class="nr">2</span> Sprogscreening</h3>
        <div class="felter">
          <Felt label="Indkaldt til screening">
            {#if redigerer}<DateInput min={MIN_DATE} max={iDag} class={input} bind:value={form.dato_indkaldelse_screening} />
            {:else}{dato(sag.dato_indkaldelse_screening)}{/if}
          </Felt>
          <Felt label="Screening gennemført">
            {#if redigerer}<DateInput min={MIN_DATE} max={iDag} class={input} bind:value={form.screeningsdato} />
            {:else}{dato(sag.screeningsdato)}{/if}
          </Felt>
          <Felt label="Samlet resultat">
            {#if redigerer}
              <select class={input} bind:value={form.samlet_resultat}>
                <option value="">— Afventer —</option>
                {#each PUF_RESULTATER as r}<option value={r}>{r}</option>{/each}
              </select>
            {:else}
              <span class={sag.samlet_resultat ? "font-semibold" : ""}>{sag.samlet_resultat ?? "Afventer"}</span>
            {/if}
          </Felt>
        </div>

        <!-- The three materials, compact -->
        <table class="materialer mx-6 mb-4 text-[13px] border-collapse">
          <thead>
            <tr class="text-left text-[10px] font-bold uppercase tracking-wider text-gray-500">
              <th class="font-bold">Materiale</th><th class="font-bold">Point</th><th class="font-bold">Resultat</th>
            </tr>
          </thead>
          <tbody>
            {#each MATERIALER as [pk, rk], i}
              <tr>
                <td class="text-gray-600">{i + 1}</td>
                {#if redigerer}
                  <td><input class="{input} w-24" inputmode="decimal" bind:value={form[pk]} /></td>
                  <td><input class="{input} w-56" maxlength="100" bind:value={form[rk]} /></td>
                {:else}
                  <td>{point(sag[pk])}</td>
                  <td>{vis(sag[rk])}</td>
                {/if}
              </tr>
            {/each}
          </tbody>
        </table>

        {#if kanHandle && !redigerer && aktueltTrin === 1}
          <p class="naeste">
            {sag.dato_indkaldelse_screening ? "Registrér screeningen og resultatet, når den er gennemført." : "Indkald barnet til sprogscreening, og registrér datoen."}
          </p>
        {/if}
      </section>

      <!-- ================= 3. Skoletilbud (ekstern) ================= -->
      <section class="sektion" class:aktuel={aktueltTrin === 2}>
        <h3 class="sektionstitel"><span class="nr">3</span> Skoletilbud</h3>
        <div class="felter">
          <Felt label="Ledig plads på ønsket skole">
            {#if redigerer}
              <select class={input} bind:value={form.ledig_plads}>
                <option value="">— Ikke afklaret —</option><option value="ja">Ja</option><option value="nej">Nej</option>
              </select>
            {:else}{jaNej(sag.ledig_plads)}{/if}
          </Felt>
          {#if (redigerer ? form.ledig_plads === "nej" : sag.ledig_plads === false) || sag.kontaktet_skole_matrikel_id}
            <Felt label="Alternativ skole kontaktet">
              {#if redigerer}
                <select class={input} bind:value={form.kontaktet_skole_matrikel_id}>
                  <option value="">— Vælg —</option>
                  {#each lookups.skolematrikel as o}<option value={o.id}>{o.label}</option>{/each}
                </select>
              {:else}{vis(sag.kontaktet_skole)}{/if}
            </Felt>
            <Felt label="Kontaktet">
              {#if redigerer}<DateInput min={MIN_DATE} max={iDag} class={input} bind:value={form.dato_kontakt_skole} />
              {:else}{dato(sag.dato_kontakt_skole)}{/if}
            </Felt>
            <Felt label="Svarfrist">
              {#if svarfrist}
                <span class={fristOverskredet ? "font-semibold text-red-700" : ""}>{dato(svarfrist)}{fristOverskredet ? " — overskredet" : ""}</span>
              {:else}—{/if}
            </Felt>
          {/if}
        </div>
        <div class="felter border-t border-dashed border-gray-200 pt-4">
          <Felt label="Skoletilbud">
            {#if redigerer}
              <select class={input} bind:value={form.skoletilbud_matrikel_id}>
                <option value="">— Vælg —</option>
                {#each lookups.skolematrikel as o}<option value={o.id}>{o.label}</option>{/each}
              </select>
            {:else}{vis(sag.skoletilbud_matrikel)}{/if}
          </Felt>
          <Felt label="Skoletilbudstype">
            {#if redigerer}
              <select class={input} bind:value={form.skoletilbudstype_id}>
                <option value="">— Vælg —</option>
                {#each lookups.skoletilbudstyper as o}<option value={o.id}>{o.label}</option>{/each}
              </select>
            {:else}{vis(sag.skoletilbudstype_tekst)}{/if}
          </Felt>
          <Felt label="Dato for skoletilbud">
            {#if redigerer}<DateInput min={MIN_DATE} max={MAX_DATE} class={input} bind:value={form.dato_skoletilbud} />
            {:else}{dato(sag.dato_skoletilbud)}{/if}
          </Felt>
          <Felt label="Klassetrin / spor">
            {#if redigerer}
              <div class="flex gap-2">
                <input class="{input} w-20" maxlength="20" placeholder="5." bind:value={form.klassetrin} />
                <input class="{input} w-24" maxlength="50" placeholder="5.B" bind:value={form.spor} />
              </div>
            {:else}{vis(sag.klassetrin)}{sag.spor ? ` · ${sag.spor}` : ""}{/if}
          </Felt>
          <Felt label="Midlertidigt skoletilbud">
            {#if redigerer}
              <select class={input} bind:value={form.midlertidigt_skoletilbud_matrikel_id}>
                <option value="">— Intet —</option>
                {#each lookups.skolematrikel as o}<option value={o.id}>{o.label}</option>{/each}
              </select>
            {:else}{vis(sag.midlertidigt_skoletilbud)}{/if}
          </Felt>
          <Felt label="Start i visitationsklasse">
            {#if redigerer}<DateInput min={MIN_DATE} max={MAX_DATE} class={input} bind:value={form.start_visitationsklasse} />
            {:else}{dato(sag.start_visitationsklasse)}{/if}
          </Felt>
        </div>
        {#if kanHandle && !redigerer && aktueltTrin === 2}
          <p class="naeste">
            {#if sag.samlet_resultat === ALDERSSVARENDE}
              Alderssvarende dansk: giv skoletilbuddet, send optagelsesbrev til skole og forældre, og afslut sagen.
            {:else if sag.ledig_plads === null}
              Sprogstøttebehov: afklar, om der er ledig plads på den ønskede skole.
            {:else if sag.ledig_plads}
              Ledig plads: eleven optages — registrér skoletilbuddet, og send brev til forældrene.
            {:else if !sag.kontaktet_skole_matrikel_id}
              Ingen ledig plads: find et alternativt skoletilbud, og registrér hvilken skole der er kontaktet.
            {:else if !sag.partshoeringsbrev_sendt}
              Skolen har {SVARFRIST_DAGE} dage til at svare — send derefter partshøringsbrev til forældrene.
            {:else}
              Partshøring sendt — registrér det endelige skoletilbud.
            {/if}
          </p>
        {/if}
      </section>

      <!-- ================= 4. Breve (ekstern) ================= -->
      <section class="sektion" class:aktuel={aktueltTrin === 3}>
        <h3 class="sektionstitel"><span class="nr">4</span> Breve</h3>
        <div class="felter">
          <Felt label="Optagelsesbrev">
            {#if redigerer}<DateInput min={MIN_DATE} max={iDag} class={input} bind:value={form.optagelsesbrev_sendt} />
            {:else}{sendt(sag.optagelsesbrev_sendt)}{/if}
          </Felt>
          <Felt label="Brev om sprogstøtte">
            {#if redigerer}<DateInput min={MIN_DATE} max={iDag} class={input} bind:value={form.sprogstoettebrev_sendt} />
            {:else}{sendt(sag.sprogstoettebrev_sendt)}{/if}
          </Felt>
          <Felt label="Partshøringsbrev">
            {#if redigerer}<DateInput min={MIN_DATE} max={iDag} class={input} bind:value={form.partshoeringsbrev_sendt} />
            {:else}{sendt(sag.partshoeringsbrev_sendt)}{/if}
          </Felt>
        </div>
        {#if kanHandle && !redigerer && aktueltTrin === 3}
          <p class="naeste">Skoletilbuddet er givet — sagen afsluttes automatisk dagen efter datoen for skoletilbud, eller afslut den nu.</p>
        {/if}
      </section>

    {/if}


    <!-- ================= Befordring and notes (both flows) ================= -->
    <section class="sektion">
      <h3 class="sektionstitel"><span class="nr">·</span> Befordring og bemærkning</h3>
      <div class="felter">
        <Felt label="Krav på befordring">
          {#if redigerer}
            <select class={input} bind:value={form.krav_paa_befordring}>
              <option value="">— Ikke vurderet —</option><option value="ja">Ja</option><option value="nej">Nej</option>
            </select>
          {:else}{sag.krav_paa_befordring === null ? "Ikke vurderet" : jaNej(sag.krav_paa_befordring)}{/if}
        </Felt>
        <Felt label="Note om befordring" bred>
          {#if redigerer}<textarea class="{input} min-h-14" bind:value={form.befordring_bemaerkning}></textarea>
          {:else}<span class="whitespace-pre-line">{vis(sag.befordring_bemaerkning)}</span>{/if}
        </Felt>
        <Felt label="Bemærkning" bred>
          {#if redigerer}<textarea class="{input} min-h-16" bind:value={form.bemaerkning}></textarea>
          {:else}<span class="whitespace-pre-line">{vis(sag.bemaerkning)}</span>{/if}
        </Felt>
      </div>
    </section>


    <!-- ================= Earlier assessments (read-only) ================= -->
    <div class="border-t-2 border-gray-200 bg-gray-50 px-6 py-4">
      <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-2">Tidligere sprogscreeninger og sprogstøtte</p>
      {#if screeninger.length === 0 && sprogstoette.length === 0}
        <p class="text-[13px] text-gray-500">Ingen tidligere sprogscreeninger eller perioder med sprogstøtte.</p>
      {:else}
        <ul class="text-[13px] space-y-1.5">
          {#each screeninger as s}
            <li class="flex flex-wrap gap-x-3">
              <span class="font-medium text-gray-800">{s.kilde}</span>
              <span class="text-gray-500">{dato(s.dato)}</span>
              <span class="font-semibold">{s.resultat ?? "—"}</span>
              {#if s.detalje}<span class="text-gray-500">{s.detalje}</span>{/if}
            </li>
          {/each}
          {#each sprogstoette as p}
            <li class="flex flex-wrap gap-x-3">
              <span class="font-medium text-gray-800">Sprogstøtte</span>
              <span class="text-gray-500">{dato(p.startdato)} – {erAabenPeriode(p.slutdato) ? "" : dato(p.slutdato)}</span>
            </li>
          {/each}
        </ul>
      {/if}
    </div>

  </article>


  <!-- ================= Sagsforløb, beside the card ================= -->
  <aside class="rounded-lg overflow-hidden kort xl:sticky xl:top-4">
    <div class="px-5 py-3 border-b border-gray-100">
      <h3 class="text-[10px] font-bold uppercase tracking-wider text-gray-500">Sagsforløb</h3>
    </div>
    <form class="px-5 pt-4 flex gap-2" on:submit|preventDefault={tilfoejKommentar}>
      <input class="flex-1 border border-gray-300 rounded px-3 py-1.5 text-sm" placeholder="Skriv en bemærkning…" bind:value={kommentar} disabled={arbejder} />
      <button type="submit" class="px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-40" disabled={arbejder || !kommentar.trim()}>Tilføj</button>
    </form>
    {#if sagsforloeb.length === 0}
      <p class="px-5 py-4 text-sm text-gray-500">Ingen hændelser endnu.</p>
    {:else}
      <ol class="px-5 py-4 space-y-3 max-h-[70vh] overflow-y-auto">
        {#each sagsforloeb as a (a.aktivitet_id)}
          <li class="text-[13px]">
            <p><span class="font-semibold text-gray-800">{a.aktivitetstype}</span></p>
            <p class="text-[11px] text-gray-500">{tidspunkt(a.oprettet_tidspunkt)} · {a.udfoert_af ?? "—"}</p>
            {#if a.kommentar}<p class="text-gray-700 mt-0.5 whitespace-pre-line">{a.kommentar}</p>{/if}
          </li>
        {/each}
      </ol>
    {/if}
  </aside>

</div>


<style>
  /* A step of the case: its title, then a grid of fields — the bevilling
     card's grid, five across on wide screens. */
  .sektion {
    border-top: 1px solid #f3f4f6;
    padding-top: 1.1rem;
  }
  .sektion:first-of-type {
    border-top: none;
  }
  /* The step being worked on now: a lavender edge, as a quiet pointer. */
  .sektion.aktuel {
    box-shadow: inset 4px 0 0 #6a3fb5;
    background-color: #fbfaff;
  }
  .sektionstitel {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0 1.5rem;
    margin-bottom: 0.9rem;
    font-size: 0.8rem;
    font-weight: 700;
    color: #3b2168;
  }
  .nr {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 1.25rem;
    height: 1.25rem;
    border-radius: 9999px;
    background-color: #ece8f7;
    color: #4a2b80;
    font-size: 0.7rem;
  }
  .felter {
    display: grid;
    grid-template-columns: repeat(1, minmax(0, 1fr));
    gap: 1.1rem 1.5rem;
    padding: 0 1.5rem 1.1rem;
  }
  @media (min-width: 640px) {
    .felter { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  }
  @media (min-width: 1024px) {
    .felter { grid-template-columns: repeat(4, minmax(0, 1fr)); }
  }
  /* What to do next, under the step it concerns. */
  .naeste {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: 0.75rem;
    margin: 0 1.5rem 1.1rem;
    padding: 0.6rem 0.9rem;
    border-radius: 0.375rem;
    background-color: #f6f4fb;
    color: #3b2168;
    font-size: 0.8125rem;
  }
  /* The global td/th rule pads 0.75rem; the materials table is compact. */
  .materialer :global(th),
  .materialer :global(td) {
    padding: 0.25rem 1rem 0.25rem 0;
    border: none;
  }
</style>
