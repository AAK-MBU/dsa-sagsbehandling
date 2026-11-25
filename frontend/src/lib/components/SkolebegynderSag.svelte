<script lang="ts">
  import { invalidateAll } from "$app/navigation";

  import { backendFetch } from "$lib/client/backendFetch";
  import { MAX_DATE, MIN_DATE, firstInvalidDate, firstOutOfRangeDate } from "$lib/dates";
  import DateInput from "$lib/components/DateInput.svelte";
  import Felt from "$lib/components/Felt.svelte";
  import SagSektion from "$lib/components/SagSektion.svelte";
  import SagTrin from "$lib/components/SagTrin.svelte";
  import { erEgenKommentar } from "$lib/kommentarEjer";
  import {
    EJ_SPROGSCREENET,
    dato,
    erScreenet,
    fejltekst,
    jaNej,
    percentil,
    PUF_RESULTATER,
    skoleaarTekst,
    tidspunkt,
    type AendringRow,
    type Lookups,
    type SkolebegynderDetail,
    type SkolebegynderFelter
  } from "$lib/skolebegynder";
  import { getStatusBadgeClass } from "$lib/tableColumnConfig";

  /**
   * One skolebegynder case, as ONE card — the same layout as the skoleskifter
   * card (and befordringssystemet's bevilling card): a header row with the
   * actions, a step bar, then the case top to bottom in the order it is
   * worked, a section per step. Values are read-only until "Redigér"; the
   * case log sits beside the card.
   *
   *   1 Liste og ønsker      from the cohort list: dagtilbud, wishes (always done)
   *   2 Screening            SX: booking and result (read-only)
   *   3 Afgørelse            PUF's result, the school offer — current while
   *                          the case is "Screening afviklet"
   *   4 Brev og afslutning   the letter, then "Afslut sag" — current once
   *                          "Skoleplaceret"
   *
   * Shown on the student page: the "Aktiv sag" tab while open, Tidligere
   * afgørelser once closed (read-only, with "Genåbn sag"). Moved out of the
   * old Skolebegynder tab route when the student page dropped its area tabs.
   */
  export let sag: SkolebegynderDetail;
  export let lookups: Lookups;
  export let sagsforloeb: any[] = [];
  export let aendringer: AendringRow[] = [];
  export let kanRedigere = false;
  export let fagomraadeId: number | null = null;
  export let brugerNavn: string | null = null;

  $: afsluttet = sag.status_tekst === "Afsluttet";
  $: kanHandle = kanRedigere && !afsluttet;


  // -----------------------------
  // Steps — from the status, which the procedure derives from the data
  // -----------------------------

  const TRIN = ["Liste og ønsker", "Screening", "Afgørelse", "Brev og afslutning"];

  $: aktueltTrin = afsluttet
    ? TRIN.length
    : sag.status_tekst === "Skoleplaceret"
      ? 3
      : sag.status_tekst === "Screening afviklet"
        ? 2
        : 1;


  // -----------------------------
  // Editing — a copy of the editable fields while "Redigér" is on
  // -----------------------------

  type Form = {
    puf_screeningsresultat: string;
    skoletilbud_matrikel_id: number | "";
    skoletilbudstype_id: number | "";
    skoleplaceringsaarsag_id: number | "";
    brevskabelon_id: number | "";
    krav_paa_befordring: "" | "ja" | "nej";
    sagsbehandlingsdato: string;
    afklaring: string;
    bemaerkning: string;
  };

  let redigerer = false;
  let form: Form;

  function startRedigering() {
    form = {
      puf_screeningsresultat: sag.puf_screeningsresultat ?? "",
      skoletilbud_matrikel_id: sag.skoletilbud_matrikel_id ?? "",
      skoletilbudstype_id: sag.skoletilbudstype_id ?? "",
      skoleplaceringsaarsag_id: sag.skoleplaceringsaarsag_id ?? "",
      brevskabelon_id: sag.brevskabelon_id ?? "",
      krav_paa_befordring: sag.krav_paa_befordring === null ? "" : sag.krav_paa_befordring ? "ja" : "nej",
      sagsbehandlingsdato: sag.sagsbehandlingsdato ?? "",
      afklaring: sag.afklaring ?? "",
      bemaerkning: sag.bemaerkning ?? ""
    };
    besked = null;
    redigerer = true;
  }

  function annullerRedigering() {
    redigerer = false;
    besked = null;
  }

  // A reloaded case (after a save, close or reopen) ends editing.
  let viserFor = "";
  $: if (`${sag.skolebegynder_id}-${sag.updated_at}` !== viserFor) {
    viserFor = `${sag.skolebegynder_id}-${sag.updated_at}`;
    redigerer = false;
  }

  const idEllerNull = (v: number | "") => (v === "" ? null : Number(v));


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

  function gem() {
    const felter: SkolebegynderFelter = {
      puf_screeningsresultat: form.puf_screeningsresultat.trim() || null,
      skoletilbud_matrikel_id: idEllerNull(form.skoletilbud_matrikel_id),
      skoletilbudstype_id: idEllerNull(form.skoletilbudstype_id),
      skoleplaceringsaarsag_id: idEllerNull(form.skoleplaceringsaarsag_id),
      brevskabelon_id: idEllerNull(form.brevskabelon_id),
      krav_paa_befordring: form.krav_paa_befordring === "" ? null : form.krav_paa_befordring === "ja",
      sagsbehandlingsdato: form.sagsbehandlingsdato || null,
      afklaring: form.afklaring.trim() || null,
      bemaerkning: form.bemaerkning.trim() || null
    };

    // As befordringssystemet's forms: the picker's bounds do not stop a typed
    // or pasted value; this check is what stops a "202365" year.
    const ugyldig =
      firstInvalidDate(felter, ["sagsbehandlingsdato"]) ??
      firstOutOfRangeDate(felter, ["sagsbehandlingsdato"]);
    if (ugyldig) {
      besked = { type: "fejl", tekst: `Ugyldig sagsbehandlingsdato: ${ugyldig[1]}` };
      return;
    }

    kald(
      `/skolebegynder/${sag.skolebegynder_id}`,
      { method: "PUT", headers: { "content-type": "application/json" }, body: JSON.stringify(felter) },
      (svar) => `Gemt — status: ${svar.status_tekst}.`
    );
  }

  function afslut() {
    if (!confirm("Afslut sagen? Gør det, når afgørelsesbrevet er sendt.")) return;
    kald(`/skolebegynder/${sag.skolebegynder_id}/afslut`, { method: "POST" }, () => "Sagen er afsluttet.");
  }

  function genaabn() {
    if (!confirm("Genåbn sagen, så den kan ændres?")) return;
    kald(`/skolebegynder/${sag.skolebegynder_id}/genaabn`, { method: "POST" }, (svar) => `Sagen er genåbnet — status: ${svar.status_tekst}.`);
  }

  function haandter(a: AendringRow) {
    kald(`/skolebegynder/aendringer/${a.aendring_id}/haandter`, { method: "POST" }, () => "Ændringen er markeret som håndteret.");
  }


  // -----------------------------
  // Sagsforløb — comments
  // -----------------------------

  let kommentar = "";

  function tilfoejKommentar() {
    const tekst = kommentar.trim();
    if (!tekst) return;
    kald(
      `/aktivitet/${sag.cpr}`,
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          aktivitetstype: "Kommentar",
          kommentar: tekst,
          fagomraade_id: fagomraadeId,
          relateret_sag_id: sag.skolebegynder_id
        })
      },
      () => {
        kommentar = "";
        return "Kommentaren er tilføjet.";
      }
    );
  }

  // Comment deletion, as on befordringssystemet's sag page: permanent —
  // Sagsaktivitet has no aktiv flag — so a confirmation dialog first, and the
  // backend's own message shown in it if the delete is refused.
  let confirmingDeleteAktivitetId: number | null = null;
  let deletingAktivitet = false;
  let deleteAktivitetError: string | null = null;

  async function doDeleteKommentar() {
    if (deletingAktivitet || confirmingDeleteAktivitetId === null) {
      return;
    }

    const aktivitetId = confirmingDeleteAktivitetId;

    deletingAktivitet = true;
    deleteAktivitetError = null;

    try {
      const response = await backendFetch(`/aktivitet/kommentar/${aktivitetId}`, {
        method: "DELETE"
      });

      if (!response.ok) {
        // The backend says in Danish why it refused (not a comment / not
        // yours); keep the dialog open so the reason is read where it was
        // triggered.
        deleteAktivitetError = await fejltekst(response);
        return;
      }

      confirmingDeleteAktivitetId = null;

      await invalidateAll();
    } finally {
      deletingAktivitet = false;
    }
  }


  // -----------------------------
  // Display helpers
  // -----------------------------

  const vis = (v: unknown) => (v === null || v === undefined || v === "" ? "—" : String(v));
  const procent = (v: number | null) => (v === null ? "—" : `${Math.round(v * 100)} %`);
  const tal = (v: number | null) => (v === null ? "—" : String(v));
  const km = (v: number | null) => (v === null ? "" : `${String(v.toFixed(1)).replace(".", ",")} km`);

  const input = "w-full border border-gray-300 rounded px-2.5 py-1.5 text-sm bg-white";
</script>


<div class="grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_22rem] gap-5 items-start">

  <article class="rounded-lg overflow-hidden kort">

    <!-- ================= Header ================= -->
    <header class="flex flex-wrap items-center justify-between gap-3 px-6 py-4 border-b border-gray-100">
      <div class="flex flex-wrap items-center gap-3">
        <span class="font-mono text-xs rounded px-2 py-0.5 text-white" style="background-color: #3b2168;">Skolebegynder {skoleaarTekst(sag.skoleaar)}</span>
        <span class="inline-block px-2 py-0.5 rounded text-xs font-medium {getStatusBadgeClass(sag.status_tekst)}">{sag.status_tekst}</span>
        <span class="text-gray-300 select-none">|</span>
        <span class="text-sm text-gray-500">På listen siden {dato(sag.modtaget_tidspunkt)}</span>
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
            <button
              type="button"
              class="px-3 py-1.5 text-sm font-medium rounded text-white bg-dsa-700 hover:bg-dsa-800 disabled:bg-white disabled:text-gray-400 disabled:border disabled:border-gray-300 disabled:cursor-not-allowed"
              disabled={arbejder || sag.status_tekst !== "Skoleplaceret"}
              title={sag.status_tekst !== "Skoleplaceret" ? "Kun sager med et skoletilbud kan afsluttes" : "Afslut, når brevet er sendt"}
              on:click={afslut}
            >
              Afslut sag
            </button>
          {/if}
        </div>
      {/if}
    </header>

    <SagTrin trin={TRIN} {aktueltTrin} />

    {#if besked}
      <div
        class="mx-6 mt-4 px-3 py-2 text-sm rounded border {besked.type === 'ok' ? 'bg-emerald-50 text-emerald-800 border-emerald-100' : 'bg-red-50 text-red-700 border-red-200'}"
        role={besked.type === "fejl" ? "alert" : "status"}
      >{besked.tekst}</div>
    {/if}

    {#if afsluttet}
      <p class="mx-6 mt-4 text-sm text-gray-500">Afsluttet {dato(sag.afsluttet_dato)} — genåbn sagen for at ændre den.</p>
    {/if}

    <!-- Unhandled changes to the child's data — above the steps, as they can
         change the decision. -->
    {#if aendringer.length > 0}
      <div class="mx-6 mt-4 rounded-md border border-amber-200 bg-amber-50 px-4 py-3">
        <p class="text-[10px] font-bold uppercase tracking-wider text-amber-900 mb-2">Uhåndterede ændringer</p>
        <ul class="space-y-2">
          {#each aendringer as a (a.aendring_id)}
            <li class="flex items-center justify-between gap-4 text-sm">
              <span>
                <span class="font-semibold">{a.aendringsaarsag_tekst}</span>
                {#if a.beskrivelse}<span class="text-gray-700"> — {a.beskrivelse}</span>{/if}
                <span class="text-gray-500 text-xs ml-1">({tidspunkt(a.registreret_tidspunkt)})</span>
              </span>
              {#if kanRedigere}
                <button type="button" class="px-3 py-1 rounded text-xs font-medium text-amber-900 hover:bg-amber-100 disabled:opacity-50" disabled={arbejder} on:click={() => haandter(a)}>
                  Markér som håndteret
                </button>
              {/if}
            </li>
          {/each}
        </ul>
      </div>
    {/if}

    <div class="h-4"></div>


    <!-- ================= 1. Liste og ønsker ================= -->
    <SagSektion nr={1} titel="Liste og ønsker" trin={0} {aktueltTrin}>
      <div class="sag-felter">
        <Felt label="Dagtilbud">
          {vis(sag.dagtilbud)}
          {#if sag.dagtilbud_afdeling}<span class="block text-gray-500 text-xs">{sag.dagtilbud_afdeling}</span>{/if}
        </Felt>
        <Felt label="Distriktsskole">
          {vis(sag.distriktsskole)}
          {#if sag.gaaafstand_distriktsskole_km !== null}<span class="block text-gray-500 text-xs">Gåafstand {km(sag.gaaafstand_distriktsskole_km)}</span>{/if}
        </Felt>
        <Felt label="Ønsket skole 1">
          {vis(sag.oensket_skole)}
          {#if sag.gaaafstand_oensket_skole_km !== null}<span class="block text-gray-500 text-xs">Gåafstand {km(sag.gaaafstand_oensket_skole_km)}</span>{/if}
        </Felt>
        <Felt label="Ønsket skole 2">{vis(sag.oensket_skole_2)}</Felt>
        <Felt label="Søskende på skolen">{vis(sag.soeskende_skole)}</Felt>
        <Felt label="Ansøgt anden skole">{jaNej(sag.ansoeger_anden_skole)}</Felt>
        <Felt label="E-mail (PL)">{vis(sag.email_pl)}</Felt>
        <Felt label="E-mail distriktsskole">{vis(sag.email_distriktsskole)}</Felt>
        {#if sag.skoler_afviger}
          <Felt label="Bemærk" bred>
            <span class="px-1.5 py-0.5 rounded text-[11px] font-semibold bg-fuchsia-100 text-fuchsia-800">Distriktsskole, ønsket skole og skoletilbud er ikke den samme skole</span>
          </Felt>
        {/if}
      </div>
    </SagSektion>


    <!-- ================= 2. Screening (SX, read-only) ================= -->
    <SagSektion nr={2} titel="Screening" trin={1} {aktueltTrin}>
      {#if !erScreenet(sag) && sag.screeningsdato === null}
        <div class="sag-felter">
          <Felt label="Tid booket">{sag.screening_booket_tidspunkt ? tidspunkt(sag.screening_booket_tidspunkt) : "Ingen tid booket"}</Felt>
          {#if sag.samlet_resultat === EJ_SPROGSCREENET}
            <Felt label="SX">{EJ_SPROGSCREENET}</Felt>
          {/if}
          {#if sag.screening_noter}<Felt label="Noter" bred>{sag.screening_noter}</Felt>{/if}
        </div>
        {#if !afsluttet}
          <p class="sag-naeste">
            {sag.screening_booket_tidspunkt
              ? "Barnet er ikke screenet endnu — resultatet kommer fra SX efter screeningen."
              : "Barnet er ikke screenet, og der er ikke booket en tid."}
          </p>
        {/if}
      {:else}
        <div class="sag-felter">
          <Felt label="Screeningsdato">{dato(sag.screeningsdato)}</Felt>
          <Felt label="Konsulent">{vis(sag.navn_konsulent)}</Felt>
          <Felt label="Testtype">{vis(sag.testtype)}</Felt>
          <Felt label="Alder ved screening">{sag.alder_mdr !== null ? `${sag.alder_mdr} mdr.` : "—"}</Felt>
          <Felt label="Samlet resultat (SX)"><span class="font-semibold">{vis(sag.samlet_resultat)}</span></Felt>
          <Felt label="Sprogstøttebehov">{jaNej(sag.sprogstoettebehov)}</Felt>
          <Felt label="Gennemført / afbrudt">{jaNej(sag.gennemfoert)} / {jaNej(sag.afbrudt)}</Felt>
          {#if sag.screening_noter}<Felt label="Noter">{sag.screening_noter}</Felt>{/if}
        </div>

        <div class="mx-6 mb-4 overflow-x-auto">
          <table class="screeningstabel text-[13px] border-collapse">
            <thead>
              <tr class="text-left text-[10px] font-bold uppercase tracking-wider text-gray-500">
                <th></th><th>Percentil</th><th>Korrekt</th><th>Forkert</th><th>Besvaret</th><th>Korrekt-ratio</th><th>Score</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td class="font-medium text-gray-700">Ordforråd</td>
                <td>{percentil(sag.of_percentil)}</td><td>{tal(sag.of_korrekt)}</td><td>{tal(sag.of_forkert)}</td>
                <td>{tal(sag.of_besvaret)}</td><td>{procent(sag.of_korrekt_ratio)}</td><td>{tal(sag.of_score)}</td>
              </tr>
              <tr>
                <td class="font-medium text-gray-700">Sprogforståelse</td>
                <td>{percentil(sag.sf_percentil)}</td><td>{tal(sag.sf_korrekt)}</td><td>{tal(sag.sf_forkert)}</td>
                <td>{tal(sag.sf_besvaret)}</td><td>{procent(sag.sf_korrekt_ratio)}</td><td>{tal(sag.sf_score)}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <!-- Screened, but no usable result yet (e.g. "Ej sprogscreenet", an
             interrupted screening): still the step being worked on. -->
        {#if !afsluttet && aktueltTrin === 1}
          <p class="sag-naeste">
            {sag.screening_booket_tidspunkt
              ? `Screeningen gav intet resultat — ny tid booket ${tidspunkt(sag.screening_booket_tidspunkt)}.`
              : "Screeningen gav intet resultat — book en ny tid."}
          </p>
        {/if}
      {/if}
    </SagSektion>


    <!-- ================= 3. Afgørelse ================= -->
    <SagSektion nr={3} titel="Afgørelse" trin={2} {aktueltTrin}>
      <div class="sag-felter">
        <Felt label="PUF-screeningsresultat">
          {#if redigerer}
            <select class={input} bind:value={form.puf_screeningsresultat}>
              <option value="">— Vælg —</option>
              {#each PUF_RESULTATER as r}<option value={r}>{r}</option>{/each}
            </select>
          {:else}<span class={sag.puf_screeningsresultat ? "font-semibold" : ""}>{vis(sag.puf_screeningsresultat)}</span>{/if}
        </Felt>
        <Felt label="Skoletilbud">
          {#if redigerer}
            <select class={input} bind:value={form.skoletilbud_matrikel_id}>
              <option value="">— Vælg —</option>
              {#each lookups.skolematrikel as o}<option value={o.id}>{o.label}</option>{/each}
            </select>
          {:else}
            {vis(sag.skoletilbud_matrikel)}
            {#if sag.gaaafstand_skoletilbud_km !== null}<span class="block text-gray-500 text-xs">Gåafstand {km(sag.gaaafstand_skoletilbud_km)}</span>{/if}
          {/if}
        </Felt>
        <Felt label="Skoletilbudstype">
          {#if redigerer}
            <select class={input} bind:value={form.skoletilbudstype_id}>
              <option value="">— Vælg —</option>
              {#each lookups.skoletilbudstyper as o}<option value={o.id}>{o.label}</option>{/each}
            </select>
          {:else}{vis(sag.skoletilbudstype_tekst)}{/if}
        </Felt>
        <Felt label="Skoleplaceringsårsag">
          {#if redigerer}
            <select class={input} bind:value={form.skoleplaceringsaarsag_id}>
              <option value="">{lookups.skoleplaceringsaarsager.length ? "— Vælg —" : "Ingen værdier oprettet endnu"}</option>
              {#each lookups.skoleplaceringsaarsager as o}<option value={o.id}>{o.label}</option>{/each}
            </select>
          {:else}{vis(sag.skoleplaceringsaarsag_tekst)}{/if}
        </Felt>
        <Felt label="Krav på befordring">
          {#if redigerer}
            <select class={input} bind:value={form.krav_paa_befordring}>
              <option value="">— Ikke angivet —</option><option value="ja">Ja</option><option value="nej">Nej</option>
            </select>
          {:else}{sag.krav_paa_befordring === null ? "Ikke angivet" : jaNej(sag.krav_paa_befordring)}{/if}
        </Felt>
        <Felt label="Sagsbehandlingsdato">
          {#if redigerer}<DateInput min={MIN_DATE} max={MAX_DATE} class={input} bind:value={form.sagsbehandlingsdato} />
          {:else}{dato(sag.sagsbehandlingsdato)}{/if}
        </Felt>
        <Felt label="Afklaring" bred>
          {#if redigerer}<textarea class="{input} min-h-14" placeholder="Hvis screeningsresultatet ikke er entydigt" bind:value={form.afklaring}></textarea>
          {:else}<span class="whitespace-pre-line">{vis(sag.afklaring)}</span>{/if}
        </Felt>
      </div>
      {#if kanHandle && !redigerer && aktueltTrin === 2}
        <p class="sag-naeste">
          {sag.samlet_resultat === "Nærmere afklaring" && !sag.puf_screeningsresultat
            ? "Resultatet kræver nærmere afklaring — skriv afklaringen, og vælg PUF-screeningsresultat."
            : "Vælg skoletilbud og skoletilbudstype — så bliver sagen skoleplaceret."}
        </p>
      {/if}
    </SagSektion>


    <!-- ================= 4. Brev og afslutning ================= -->
    <SagSektion nr={4} titel="Brev og afslutning" trin={3} {aktueltTrin}>
      <div class="sag-felter">
        <Felt label="Skabelon (til brev)">
          {#if redigerer}
            <select class={input} bind:value={form.brevskabelon_id}>
              <option value="">{lookups.brevskabeloner.length ? "— Vælg —" : "Ingen skabeloner oprettet endnu"}</option>
              {#each lookups.brevskabeloner as o}<option value={o.id}>{o.label}</option>{/each}
            </select>
          {:else}{vis(sag.brevskabelon_tekst)}{/if}
        </Felt>
        <Felt label="Afsluttet">{dato(sag.afsluttet_dato)}</Felt>
      </div>
      {#if kanHandle && !redigerer && aktueltTrin === 3}
        <p class="sag-naeste">Barnet er skoleplaceret — send afgørelsesbrevet, og afslut sagen.</p>
      {/if}
    </SagSektion>


    <!-- ================= Bemærkning (not a step) ================= -->
    <SagSektion nr="·" titel="Bemærkning">
      <div class="sag-felter">
        <Felt label="Bemærkning" bred>
          {#if redigerer}<textarea class="{input} min-h-16" bind:value={form.bemaerkning}></textarea>
          {:else}<span class="whitespace-pre-line">{vis(sag.bemaerkning)}</span>{/if}
        </Felt>
      </div>
    </SagSektion>

  </article>


  <!-- ================= Sagsforløb, beside the card ================= -->
  <aside class="rounded-lg overflow-hidden kort xl:sticky xl:top-4">
    <div class="px-5 py-3 border-b border-gray-100">
      <h3 class="text-[10px] font-bold uppercase tracking-wider text-gray-500">Sagsforløb</h3>
    </div>
    <form class="px-5 pt-4 flex gap-2" on:submit|preventDefault={tilfoejKommentar}>
      <input class="flex-1 border border-gray-300 rounded px-3 py-1.5 text-sm" placeholder="Skriv en kommentar…" bind:value={kommentar} disabled={arbejder} />
      <button type="submit" class="px-3 py-1.5 text-sm font-medium border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-40" disabled={arbejder || !kommentar.trim()}>Tilføj</button>
    </form>
    {#if sagsforloeb.length === 0}
      <p class="px-5 py-4 text-sm text-gray-500">Ingen hændelser endnu.</p>
    {:else}
      <ol class="px-5 py-4 space-y-3 max-h-[70vh] overflow-y-auto">
        {#each sagsforloeb as a (a.aktivitet_id)}
          <li class="flex gap-2 text-[13px]">
            <div class="flex-1">
              <p><span class="font-semibold {a.type_kode === 'kommentar' ? 'text-dsa-800' : 'text-gray-800'}">{a.aktivitetstype}</span></p>
              <p class="text-[11px] text-gray-500">{tidspunkt(a.oprettet_tidspunkt)} · {a.udfoert_af ?? "—"}</p>
              {#if a.kommentar}<p class="text-gray-700 mt-0.5 whitespace-pre-line">{a.kommentar}</p>{/if}
            </div>
            <!-- Only comments can be deleted, and only your own — erEgenKommentar
                 mirrors the backend's samme_bruger, which is what decides. -->
            {#if (a.type_kode === "kommentar" || a.aktivitetstype === "Kommentar") && erEgenKommentar(a.udfoert_af, brugerNavn)}
              <button
                type="button"
                title="Slet din kommentar"
                class="p-1 text-gray-400 hover:text-red-600 transition-colors self-start"
                on:click={() => { confirmingDeleteAktivitetId = a.aktivitet_id; deleteAktivitetError = null; }}
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
              </button>
            {/if}
          </li>
        {/each}
      </ol>
    {/if}
  </aside>

</div>


<!-- Delete kommentar confirmation modal — markup from befordringssystemet's
     sag page. -->
{#if confirmingDeleteAktivitetId !== null}
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    role="presentation"
  >
    <div
      class="w-[420px] bg-white rounded-lg shadow-2xl"
      role="dialog"
      aria-modal="true"
      tabindex="-1"
    >
      <div class="px-6 py-5 border-b border-gray-200">
        <div class="flex items-center gap-3">
          <div class="w-9 h-9 rounded-full bg-red-100 flex items-center justify-center shrink-0">
            <svg class="w-5 h-5 text-red-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </div>
          <div>
            <h3 class="text-sm font-semibold text-gray-900">Slet kommentar</h3>
            <p class="text-xs text-gray-500 mt-0.5">Kommentar #{confirmingDeleteAktivitetId}</p>
          </div>
        </div>
      </div>
      <div class="px-6 py-4">
        <p class="text-sm text-gray-700">
          Er du sikker på, at du vil slette denne kommentar?
          Den slettes permanent fra databasen og kan ikke gendannes.
        </p>
        {#if deleteAktivitetError}
          <p class="mt-3 text-sm text-red-600 bg-red-50 border border-red-200 rounded px-3 py-2">{deleteAktivitetError}</p>
        {/if}
      </div>
      <div class="flex justify-end gap-3 px-6 py-4 border-t border-gray-200 bg-gray-50 rounded-b-lg">
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium border border-gray-300 rounded hover:bg-gray-100 transition-colors"
          on:click={() => confirmingDeleteAktivitetId = null}
        >
          Annullér
        </button>
        <button
          type="button"
          disabled={deletingAktivitet}
          class="px-4 py-2 text-sm font-medium bg-red-600 hover:bg-red-700 text-white rounded transition-colors disabled:opacity-50"
          on:click={doDeleteKommentar}
        >
          {deletingAktivitet ? "Sletter…" : "Slet kommentar"}
        </button>
      </div>
    </div>
  </div>
{/if}


<style>
  /* The global td/th rule (app.css, from befordringssystemet) pads every cell
     0.75rem — too much for a seven-column table inside a step. */
  .screeningstabel :global(th),
  .screeningstabel :global(td) {
    padding: 0.3rem 1rem 0.3rem 0;
    border: none;
    font-weight: inherit;
  }
</style>
