<script lang="ts">
  import { invalidateAll } from "$app/navigation";

  import { backendFetch } from "$lib/client/backendFetch";
  import { MAX_DATE, MIN_DATE, firstInvalidDate, firstOutOfRangeDate } from "$lib/dates";
  import { dato, fejltekst, jaNej, tidspunkt, type Lookups } from "$lib/skolebegynder";
  import {
    AFSLUTTET,
    MANUELLE_STATUSSER,
    vurderesAfSkolen,
    type SkoleskifterDetail,
    type Soeskende
  } from "$lib/skoleskifter";
  import { formatCpr, getStatusBadgeClass } from "$lib/tableColumnConfig";

  /**
   * One skoleskifter case (draft) — shared by the student page's
   * Skoleskiftere tab and the page of a case without CPR, so a case looks
   * the same wherever it is opened.
   *
   * Laid out as the Skolebegyndere tab: the facts and the case work in two
   * columns, the case log down the right. The language assessment follows
   * the case's kind: the current school's assessment for skoleskift internt,
   * a screening (date, points and results for up to three materials) for
   * the others — entered by hand in the draft.
   */
  export let sag: SkoleskifterDetail;
  export let lookups: Lookups;
  export let sagsforloeb: any[] = [];
  export let soeskende: Soeskende[] = [];
  export let kanRedigere = false;
  export let fagomraadeId: number | null = null;

  $: afsluttet = sag.status_tekst === AFSLUTTET;
  $: skolen = vurderesAfSkolen(sag.variant);
  $: laast = !kanRedigere || afsluttet || arbejder;

  type Form = {
    skolens_vurdering: string;
    screeningsdato: string;
    point_1: string; resultat_1: string;
    point_2: string; resultat_2: string;
    point_3: string; resultat_3: string;
    samlet_resultat: string;
    skoletilbud_matrikel_id: number | "";
    skoletilbudstype_id: number | "";
    dato_skoletilbud: string;
    start_visitationsklasse: string;
    klassetrin: string;
    spor: string;
    bemaerkning: string;
  };

  const tekst = (v: unknown) => (v === null || v === undefined ? "" : String(v).replace(".", ","));

  let form: Form;
  let formFor = "";
  $: if (`${sag.skoleskifter_id}-${sag.updated_at}` !== formFor) {
    formFor = `${sag.skoleskifter_id}-${sag.updated_at}`;
    form = {
      skolens_vurdering: sag.skolens_vurdering ?? "",
      screeningsdato: sag.screeningsdato ?? "",
      point_1: tekst(sag.point_1), resultat_1: sag.resultat_1 ?? "",
      point_2: tekst(sag.point_2), resultat_2: sag.resultat_2 ?? "",
      point_3: tekst(sag.point_3), resultat_3: sag.resultat_3 ?? "",
      samlet_resultat: sag.samlet_resultat ?? "",
      skoletilbud_matrikel_id: sag.skoletilbud_matrikel_id ?? "",
      skoletilbudstype_id: sag.skoletilbudstype_id ?? "",
      dato_skoletilbud: sag.dato_skoletilbud ?? "",
      start_visitationsklasse: sag.start_visitationsklasse ?? "",
      klassetrin: sag.klassetrin ?? "",
      spor: sag.spor ?? "",
      bemaerkning: sag.bemaerkning ?? ""
    };
  }

  const tomTilNull = (v: string) => v.trim() || null;
  const tal = (v: string) => (v.trim() === "" ? null : Number(v.trim().replace(",", ".")));
  const idEllerNull = (v: number | "") => (v === "" ? null : Number(v));

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

  const put = (body: object) => ({
    method: "PUT",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body)
  });

  function gem() {
    const point = [form.point_1, form.point_2, form.point_3].map(tal);
    if (point.some((p) => p !== null && Number.isNaN(p))) {
      besked = { type: "fejl", tekst: "Point skal være tal, fx 12,5." };
      return;
    }

    const felter = {
      skolens_vurdering: tomTilNull(form.skolens_vurdering),
      screeningsdato: form.screeningsdato || null,
      point_1: point[0], resultat_1: tomTilNull(form.resultat_1),
      point_2: point[1], resultat_2: tomTilNull(form.resultat_2),
      point_3: point[2], resultat_3: tomTilNull(form.resultat_3),
      samlet_resultat: tomTilNull(form.samlet_resultat),
      skoletilbud_matrikel_id: idEllerNull(form.skoletilbud_matrikel_id),
      skoletilbudstype_id: idEllerNull(form.skoletilbudstype_id),
      dato_skoletilbud: form.dato_skoletilbud || null,
      start_visitationsklasse: form.start_visitationsklasse || null,
      klassetrin: tomTilNull(form.klassetrin),
      spor: tomTilNull(form.spor),
      bemaerkning: tomTilNull(form.bemaerkning)
    };

    const datoer = ["screeningsdato", "dato_skoletilbud", "start_visitationsklasse"];
    const ugyldig = firstInvalidDate(felter, datoer) ?? firstOutOfRangeDate(felter, datoer);
    if (ugyldig) {
      besked = { type: "fejl", tekst: `Ugyldig dato: ${ugyldig[1]}` };
      return;
    }

    kald(`/skoleskifter/${sag.skoleskifter_id}`, put(felter), (svar) => `Gemt — status: ${svar.status_tekst}.`);
  }

  function saetStatus(status: string) {
    kald(`/skoleskifter/${sag.skoleskifter_id}`, put({ manuel_status: status }), (svar) => `Status: ${svar.status_tekst}.`);
  }

  function afslut() {
    if (!confirm("Afslut sagen manuelt? Normalt afsluttes den automatisk dagen efter dato for skoletilbud.")) return;
    kald(`/skoleskifter/${sag.skoleskifter_id}/afslut`, { method: "POST" }, () => "Sagen er afsluttet.");
  }

  function genaabn() {
    if (!confirm("Genåbn sagen, så den kan ændres?")) return;
    kald(`/skoleskifter/${sag.skoleskifter_id}/genaabn`, { method: "POST" }, (svar) => `Sagen er genåbnet — status: ${svar.status_tekst}.`);
  }

  let kommentar = "";
  function tilfoejKommentar() {
    const t = kommentar.trim();
    if (!t || !sag.cpr) return;
    kald(
      `/aktivitet/${sag.cpr}`,
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ aktivitetstype: "Kommentar", kommentar: t, fagomraade_id: fagomraadeId, relateret_sag_id: sag.skoleskifter_id })
      },
      () => {
        kommentar = "";
        return "Kommentaren er tilføjet.";
      }
    );
  }

  const felt = "border border-gray-300 rounded px-2.5 py-1.5 bg-white disabled:bg-gray-50 disabled:text-gray-600";
</script>


<!-- Case strip: which case, its status, the manual status and closing -->
<div class="flex items-center justify-between gap-4 mb-5 flex-wrap">
  <div class="flex items-center gap-3 flex-wrap">
    <a href="/skoleskiftere" class="inline-flex items-center gap-1 text-[13px] text-dsa-600 hover:text-dsa-800 mr-2">
      <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" /></svg>
      Overblik
    </a>
    <h2 class="text-[18px] font-bold" style="color: #271347;">{sag.variant}</h2>
    <span class="text-[13px] text-gray-500">modtaget {dato(sag.modtaget_tidspunkt)}</span>
    <span class="inline-block px-2.5 py-1 rounded-full text-xs font-semibold {getStatusBadgeClass(sag.status_tekst)}">{sag.status_tekst}</span>
  </div>

  {#if kanRedigere}
    <div class="flex items-center gap-2 flex-wrap">
      {#if afsluttet}
        <button type="button" class="px-4 py-2 rounded-full text-sm font-medium bg-white border border-dsa-200 text-dsa-800 hover:bg-dsa-50 disabled:opacity-50" disabled={arbejder} on:click={genaabn}>
          Genåbn sag
        </button>
      {:else}
        <!-- The manual statuses; the procedure derives the rest from the data. -->
        <label class="flex items-center gap-2 text-[13px] text-gray-600">
          Sæt status
          <select
            class="border border-gray-300 rounded-full px-3 py-1.5 text-sm bg-white"
            disabled={arbejder}
            value=""
            on:change={(e) => {
              const v = e.currentTarget.value;
              e.currentTarget.value = "";
              if (v) saetStatus(v);
            }}
          >
            <option value="">— vælg —</option>
            {#each MANUELLE_STATUSSER as st}
              <option value={st} disabled={st === sag.status_tekst}>{st}</option>
            {/each}
          </select>
        </label>
        <button type="button" class="px-4 py-2 rounded-full text-sm font-medium bg-white border border-gray-300 text-gray-700 hover:bg-gray-50 disabled:opacity-50" disabled={arbejder} on:click={afslut}>
          Afslut manuelt
        </button>
      {/if}
    </div>
  {/if}
</div>

{#if besked}
  <div
    class="mb-5 px-4 py-2.5 rounded-lg text-sm {besked.type === 'ok' ? 'bg-emerald-50 text-emerald-800 border border-emerald-100' : 'bg-red-50 text-red-800 border border-red-100'}"
    role={besked.type === "fejl" ? "alert" : "status"}
  >
    {besked.tekst}
  </div>
{/if}


<div class="grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_minmax(0,1.2fr)_minmax(0,0.9fr)] gap-5 items-start">

  <!-- Application -->
  <div class="rounded-2xl overflow-hidden kort" style="border-left: 5px solid #4e7c3a;">
    <div class="px-6 py-4 border-b border-gray-100"><h3 class="font-bold text-[15px]" style="color: #2f5325;">Ansøgning</h3></div>
    <dl class="px-6 py-5 grid grid-cols-[150px_1fr] gap-y-2.5 gap-x-4 text-[13px]">
      <dt class="text-gray-500">Type</dt><dd>{sag.variant}</dd>
      <dt class="text-gray-500">Modtaget</dt><dd>{tidspunkt(sag.modtaget_tidspunkt)}</dd>
      <dt class="text-gray-500">SagsID (GO)</dt>
      <dd>
        {#if sag.esdh_noegle && sag.esdh_url}
          <a href={sag.esdh_url} target="_blank" rel="noopener noreferrer" class="font-mono text-sky-600 hover:underline">{sag.esdh_noegle}</a>
        {:else}
          <span class="font-mono">{sag.esdh_noegle ?? "—"}</span>
        {/if}
      </dd>
      {#if !sag.cpr}
        <dt class="text-gray-500">Navn i ansøgning</dt><dd>{sag.ansoeger_navn ?? "—"}</dd>
      {/if}
      <dt class="text-gray-500">Nuværende skole</dt><dd>{sag.nuvaerende_skole ?? "—"}</dd>
      <dt class="text-gray-500">Klassetrin</dt><dd>{sag.klassetrin_ansoegning ?? "—"}</dd>
      <dt class="text-gray-500">Ønsket skole</dt><dd>{sag.oensket_skole ?? "—"}</dd>
      <dt class="text-gray-500">Ønsket skolestart</dt><dd>{dato(sag.dato_oensket_skolestart)}</dd>
      {#if sag.variant === "Tilflytter"}
        <dt class="text-gray-500">Kommende adresse</dt><dd>{sag.kommende_adresse ?? "—"}</dd>
      {/if}
      <dt class="text-gray-500">Særlige behov</dt><dd>{jaNej(sag.saerlige_behov)}</dd>
      {#if sag.ppr_sendt_dato}
        <dt class="text-gray-500">Sendt til PPR</dt><dd>{dato(sag.ppr_sendt_dato)}{sag.dage_hos_ppr !== null ? ` · ${sag.dage_hos_ppr} dage` : ""}</dd>
      {/if}
      <dt class="text-gray-500">Ventetid</dt><dd>{sag.ventetid_dage ?? "—"} dage</dd>
    </dl>
  </div>

  <!-- Language assessment -->
  <div class="rounded-2xl overflow-hidden kort" style="border-left: 5px solid #2c7d90;">
    <div class="px-6 py-4 border-b border-gray-100">
      <h3 class="font-bold text-[15px]" style="color: #1f5d6e;">Sprogvurdering</h3>
      <p class="text-[12px] text-gray-500 mt-0.5">
        {skolen ? "Skoleskift internt: den nuværende skole vurderer barnets dansk." : "Barnet sprogscreenes. Point og resultater indtastes manuelt (kladde)."}
      </p>
    </div>
    <form class="px-6 py-5 grid gap-4 text-[13px]" on:submit|preventDefault={gem}>
      <fieldset class="contents" disabled={laast}>
        {#if skolen}
          <label class="flex flex-col gap-1">
            <span class="text-gray-600">Skolens vurdering</span>
            <textarea class="{felt} min-h-20" bind:value={form.skolens_vurdering}></textarea>
          </label>
        {:else}
          <label class="flex flex-col gap-1 max-w-56">
            <span class="text-gray-600">Screeningsdato</span>
            <input type="date" min={MIN_DATE} max={MAX_DATE} class={felt} bind:value={form.screeningsdato} />
          </label>
          <table class="materialer w-full border-collapse">
            <thead><tr class="text-left text-gray-500"><th class="font-medium"></th><th class="font-medium">Point</th><th class="font-medium">Resultat</th></tr></thead>
            <tbody>
              <tr><td class="font-medium">Materiale 1</td><td><input class="{felt} w-24" inputmode="decimal" bind:value={form.point_1} /></td><td><input class="{felt} w-full" bind:value={form.resultat_1} /></td></tr>
              <tr><td class="font-medium">Materiale 2</td><td><input class="{felt} w-24" inputmode="decimal" bind:value={form.point_2} /></td><td><input class="{felt} w-full" bind:value={form.resultat_2} /></td></tr>
              <tr><td class="font-medium">Materiale 3</td><td><input class="{felt} w-24" inputmode="decimal" bind:value={form.point_3} /></td><td><input class="{felt} w-full" bind:value={form.resultat_3} /></td></tr>
            </tbody>
          </table>
          <label class="flex flex-col gap-1">
            <span class="text-gray-600">Samlet resultat</span>
            <input class={felt} bind:value={form.samlet_resultat} />
          </label>
        {/if}
      </fieldset>
      {#if kanRedigere && !afsluttet}
        <div class="flex justify-end">
          <button type="submit" class="px-5 py-2 rounded-full text-sm font-semibold text-white bg-dsa-600 hover:bg-dsa-700 disabled:opacity-40" disabled={arbejder}>{arbejder ? "Gemmer…" : "Gem"}</button>
        </div>
      {/if}
    </form>
  </div>

  <!-- Case log — the right-hand column from xl -->
  <div class="rounded-2xl overflow-hidden kort xl:col-start-3 xl:row-start-1 xl:row-span-3" style="border-left: 5px solid #bd9b16;">
    <div class="px-6 py-4 border-b border-gray-100"><h3 class="font-bold text-[15px]" style="color: #8a7210;">Sagsforløb</h3></div>
    {#if !sag.cpr}
      <p class="px-6 py-5 text-[13px] text-gray-500">Sagsforløbet starter, når der er tilknyttet et CPR-nummer.</p>
    {:else}
      <form class="px-6 pt-4 flex gap-3" on:submit|preventDefault={tilfoejKommentar}>
        <input class="flex-1 border border-gray-300 rounded px-3 py-1.5 text-sm" placeholder="Skriv en kommentar…" bind:value={kommentar} disabled={arbejder} />
        <button type="submit" class="px-4 py-1.5 rounded-full text-sm font-medium bg-white border border-dsa-200 text-dsa-800 hover:bg-dsa-50 disabled:opacity-40" disabled={arbejder || !kommentar.trim()}>Tilføj</button>
      </form>
      {#if sagsforloeb.length === 0}
        <p class="px-6 py-5 text-sm text-gray-500">Ingen hændelser endnu.</p>
      {:else}
        <ol class="px-6 py-4 space-y-3">
          {#each sagsforloeb as a (a.aktivitet_id)}
            <li class="flex gap-3 text-[13px]">
              <span class="w-28 shrink-0 text-gray-500">{tidspunkt(a.oprettet_tidspunkt)}</span>
              <div class="flex-1">
                <p><span class="font-semibold text-gray-800">{a.aktivitetstype}</span><span class="text-gray-500"> · {a.udfoert_af ?? "—"}</span></p>
                {#if a.kommentar}<p class="text-gray-700 mt-0.5 whitespace-pre-line">{a.kommentar}</p>{/if}
              </div>
            </li>
          {/each}
        </ol>
      {/if}
    {/if}
  </div>

  <!-- Decision -->
  <div class="rounded-2xl overflow-hidden kort xl:col-span-2" style="border-left: 5px solid #6a3fb5;">
    <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between gap-4">
      <h3 class="font-bold text-[15px]" style="color: #3b2168;">Afgørelse</h3>
      {#if afsluttet}<span class="text-xs text-gray-500">Afsluttet {dato(sag.afsluttet_dato)} — genåbn sagen for at ændre den.</span>{/if}
    </div>
    <form class="px-6 py-5 grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-x-6 gap-y-4 text-[13px]" on:submit|preventDefault={gem}>
      <fieldset class="contents" disabled={laast}>
        <label class="flex flex-col gap-1">
          <span class="text-gray-600">Skoletilbud (matrikel)</span>
          <select class={felt} bind:value={form.skoletilbud_matrikel_id}>
            <option value="">— Vælg —</option>
            {#each lookups.skolematrikel as o}<option value={o.id}>{o.label}</option>{/each}
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-gray-600">Skoletilbudstype</span>
          <select class={felt} bind:value={form.skoletilbudstype_id}>
            <option value="">— Vælg —</option>
            {#each lookups.skoletilbudstyper as o}<option value={o.id}>{o.label}</option>{/each}
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-gray-600">Dato for skoletilbud</span>
          <input type="date" min={MIN_DATE} max={MAX_DATE} class={felt} bind:value={form.dato_skoletilbud} />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-gray-600">Klassetrin</span>
          <input class={felt} maxlength="20" bind:value={form.klassetrin} />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-gray-600">Spor (klassebetegnelse)</span>
          <input class={felt} maxlength="50" bind:value={form.spor} />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-gray-600">Start i visitationsklasse</span>
          <input type="date" min={MIN_DATE} max={MAX_DATE} class={felt} bind:value={form.start_visitationsklasse} />
        </label>
        <label class="flex flex-col gap-1 md:col-span-2 xl:col-span-3">
          <span class="text-gray-600">Bemærkning</span>
          <textarea class="{felt} min-h-16" bind:value={form.bemaerkning}></textarea>
        </label>
      </fieldset>
      {#if kanRedigere && !afsluttet}
        <div class="md:col-span-2 xl:col-span-3 flex items-center justify-between gap-4">
          <p class="text-xs text-gray-500">Skoletilbud + type + dato giver "Skoletilbud afsendt"; sagen afsluttes automatisk dagen efter datoen.</p>
          <button type="submit" class="px-5 py-2 rounded-full text-sm font-semibold text-white bg-dsa-600 hover:bg-dsa-700 disabled:opacity-40" disabled={arbejder}>{arbejder ? "Gemmer…" : "Gem"}</button>
        </div>
      {/if}
    </form>
  </div>

  <!-- Siblings — children sharing a custody holder -->
  <div class="rounded-2xl overflow-hidden kort xl:col-span-2" style="border-left: 5px solid #8a2b2b;">
    <div class="px-6 py-4 border-b border-gray-100"><h3 class="font-bold text-[15px]" style="color: #7a2626;">Søskende</h3></div>
    {#if !sag.cpr}
      <p class="px-6 py-5 text-[13px] text-gray-500">Søskende vises, når der er tilknyttet et CPR-nummer.</p>
    {:else if soeskende.length === 0}
      <p class="px-6 py-5 text-[13px] text-gray-500">Ingen søskende registreret (børn med samme forældremyndighedsindehaver).</p>
    {:else}
      <ul class="px-6 py-4 divide-y divide-gray-100 text-[13px]">
        {#each soeskende as s (s.cpr)}
          <li class="py-2.5 flex flex-wrap items-baseline gap-x-4 gap-y-1">
            <a href="/elev/{s.cpr}" class="font-semibold text-dsa-700 hover:underline">{s.adresseringsnavn ?? "—"}</a>
            <span class="font-mono text-gray-500">{formatCpr(s.cpr)}</span>
            <span class="text-gray-600">{s.skole_navn ?? "Ingen skole"}{s.elevklassetrin ? ` · ${s.elevklassetrin} klasse` : ""}</span>
            {#each s.sager as x}
              <span class="px-2 py-0.5 rounded bg-gray-100 text-gray-700 text-[12px]">{x.beskrivelse}: {x.status_tekst}{x.skoletilbud ? ` · ${x.skoletilbud}` : ""}</span>
            {/each}
          </li>
        {/each}
      </ul>
    {/if}
  </div>

</div>


<style>
  /* Compact cells in the materials table, as the screening table on the
     Skolebegyndere tab (the global td/th rule pads 0.75rem). */
  .materialer :global(th),
  .materialer :global(td) {
    padding: 0.3rem 0.4rem;
  }
</style>
