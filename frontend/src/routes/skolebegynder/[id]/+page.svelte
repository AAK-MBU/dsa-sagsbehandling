<script lang="ts">
  import { invalidateAll } from "$app/navigation";

  import { backendFetch } from "$lib/client/backendFetch";
  import {
    dato,
    fejltekst,
    jaNej,
    tidspunkt,
    type AendringRow,
    type SkolebegynderDetail,
    type SkolebegynderFelter
  } from "$lib/skolebegynder";
  import { formatCpr, getStatusBadgeClass } from "$lib/tableColumnConfig";

  export let data;

  $: sag = data.sag as SkolebegynderDetail;
  $: lookups = data.lookups;
  $: sagsforloeb = data.sagsforloeb as any[];
  $: aendringer = data.aendringer as AendringRow[];
  $: kanRedigere = data.user?.can_edit === true;
  $: afsluttet = sag.status_tekst === "Afsluttet";
  $: brugerNavn = data.user?.name ?? null;


  // -----------------------------
  // Case-work form — a copy of the editable fields, reset whenever the case
  // is reloaded (after a save, close or reopen).
  // -----------------------------

  type Form = {
    puf_screeningsresultat: string;
    skoletilbud_matrikel_id: number | "";
    skoletilbudstype_id: number | "";
    skoleplaceringsaarsag_id: number | "";
    brevskabelon_id: number | "";
    krav_paa_befordring: "" | "ja" | "nej";
    sagsbehandlingsdato: string;
    bemaerkning: string;
  };

  let form: Form;
  let formFor = "";

  $: if (`${sag.skolebegynder_id}-${sag.updated_at}` !== formFor) {
    formFor = `${sag.skolebegynder_id}-${sag.updated_at}`;
    form = {
      puf_screeningsresultat: sag.puf_screeningsresultat ?? "",
      skoletilbud_matrikel_id: sag.skoletilbud_matrikel_id ?? "",
      skoletilbudstype_id: sag.skoletilbudstype_id ?? "",
      skoleplaceringsaarsag_id: sag.skoleplaceringsaarsag_id ?? "",
      brevskabelon_id: sag.brevskabelon_id ?? "",
      krav_paa_befordring: sag.krav_paa_befordring === null ? "" : sag.krav_paa_befordring ? "ja" : "nej",
      sagsbehandlingsdato: sag.sagsbehandlingsdato ?? "",
      bemaerkning: sag.bemaerkning ?? ""
    };
  }

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

  function gem() {
    const felter: SkolebegynderFelter = {
      puf_screeningsresultat: form.puf_screeningsresultat.trim() || null,
      skoletilbud_matrikel_id: idEllerNull(form.skoletilbud_matrikel_id),
      skoletilbudstype_id: idEllerNull(form.skoletilbudstype_id),
      skoleplaceringsaarsag_id: idEllerNull(form.skoleplaceringsaarsag_id),
      brevskabelon_id: idEllerNull(form.brevskabelon_id),
      krav_paa_befordring: form.krav_paa_befordring === "" ? null : form.krav_paa_befordring === "ja",
      sagsbehandlingsdato: form.sagsbehandlingsdato || null,
      bemaerkning: form.bemaerkning.trim() || null
    };

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
          fagomraade_id: data.fagomraadeId,
          relateret_sag_id: sag.skolebegynder_id
        })
      },
      () => {
        kommentar = "";
        return "Kommentaren er tilføjet.";
      }
    );
  }

  function sletKommentar(aktivitetId: number) {
    if (!confirm("Slet kommentaren?")) return;
    kald(`/aktivitet/kommentar/${aktivitetId}`, { method: "DELETE" }, () => "Kommentaren er slettet.");
  }

  const procent = (v: number | null) => (v === null ? "—" : `${Math.round(v * 100)} %`);
  const tal = (v: number | null) => (v === null ? "—" : String(v));
</script>


<svelte:head>
  <title>{sag.navn ?? "Sag"} – Skolebegynder {sag.skoleaar}</title>
</svelte:head>


<section class="w-full max-w-6xl">

  <a href="/skolebegynder?aar={sag.skoleaar}" class="inline-flex items-center gap-1.5 text-[13px] text-dsa-600 hover:text-dsa-800 mb-4">
    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" />
    </svg>
    Tilbage til overblik
  </a>

  <!-- Header -->
  <div class="flex items-start justify-between gap-4 mb-6 flex-wrap">
    <div>
      <div class="flex items-center gap-3 flex-wrap">
        <h1 class="text-[26px] font-bold" style="color: #271347;">{sag.navn ?? "—"}</h1>
        <span class="inline-block px-2.5 py-1 rounded-full text-xs font-semibold {getStatusBadgeClass(sag.status_tekst)}">{sag.status_tekst}</span>
        {#if sag.navne_adresse_beskyttelse}
          <span class="px-2 py-0.5 rounded text-xs font-semibold bg-red-100 text-red-700">Navne- og adressebeskyttet</span>
        {/if}
      </div>
      <p class="text-[13px] text-gray-500 mt-1">
        <span class="font-mono">{formatCpr(sag.cpr)}</span>
        · Skolestart {sag.skoleaar}
        · <a href="/elevmappe/{sag.cpr}" class="text-dsa-700 hover:underline">Elevmappe</a>
      </p>
    </div>

    {#if kanRedigere}
      <div class="flex gap-2">
        {#if afsluttet}
          <button type="button" class="px-4 py-2 rounded-full text-sm font-medium bg-white border border-dsa-200 text-dsa-800 hover:bg-dsa-50 disabled:opacity-50" disabled={arbejder} on:click={genaabn}>
            Genåbn sag
          </button>
        {:else}
          <button
            type="button"
            class="px-4 py-2 rounded-full text-sm font-semibold text-white bg-emerald-600 hover:bg-emerald-700 disabled:opacity-40"
            disabled={arbejder || sag.status_tekst !== "Skoletilbud"}
            title={sag.status_tekst !== "Skoletilbud" ? "Kun sager med et skoletilbud kan afsluttes" : "Afslut, når brevet er sendt"}
            on:click={afslut}
          >
            Afslut sag
          </button>
        {/if}
      </div>
    {/if}
  </div>


  {#if besked}
    <div
      class="mb-5 px-4 py-2.5 rounded-lg text-sm {besked.type === 'ok'
        ? 'bg-emerald-50 text-emerald-800 border border-emerald-100'
        : 'bg-red-50 text-red-800 border border-red-100'}"
      role={besked.type === "fejl" ? "alert" : "status"}
    >
      {besked.tekst}
    </div>
  {/if}


  {#if aendringer.length > 0}
    <div class="mb-6 rounded-2xl border border-amber-200 bg-amber-50 px-5 py-4">
      <h2 class="font-bold text-[15px] text-amber-900 mb-2">Uhåndterede ændringer</h2>
      <ul class="space-y-2">
        {#each aendringer as a (a.aendring_id)}
          <li class="flex items-center justify-between gap-4 text-sm">
            <span>
              <span class="font-semibold">{a.aendringsaarsag_tekst}</span>
              {#if a.beskrivelse}<span class="text-gray-700"> — {a.beskrivelse}</span>{/if}
              <span class="text-gray-500 text-xs ml-1">({tidspunkt(a.registreret_tidspunkt)})</span>
            </span>
            {#if kanRedigere}
              <button type="button" class="px-3 py-1 rounded-full text-xs font-medium text-amber-900 hover:bg-amber-100 disabled:opacity-50" disabled={arbejder} on:click={() => haandter(a)}>
                Markér som håndteret
              </button>
            {/if}
          </li>
        {/each}
      </ul>
    </div>
  {/if}


  <div class="grid grid-cols-1 xl:grid-cols-2 gap-5 mb-6">

    <!-- Screening -->
    <div class="bg-white rounded-2xl overflow-hidden" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08); border-left: 5px solid #2c7d90;">
      <div class="px-6 py-4 border-b border-gray-100">
        <h2 class="font-bold text-[15px]" style="color: #1f5d6e;">Screening</h2>
      </div>
      {#if sag.samlet_resultat === null && sag.screeningsdato === null}
        <p class="px-6 py-5 text-sm text-gray-500">Barnet er ikke screenet endnu.</p>
      {:else}
        <dl class="px-6 py-5 grid grid-cols-[170px_1fr] gap-y-2.5 gap-x-4 text-[13px]">
          <dt class="text-gray-500">Screeningsdato</dt><dd>{dato(sag.screeningsdato)}</dd>
          <dt class="text-gray-500">Konsulent</dt><dd>{sag.navn_konsulent ?? "—"}</dd>
          <dt class="text-gray-500">Testtype</dt><dd>{sag.testtype ?? "—"}</dd>
          <dt class="text-gray-500">Alder ved screening</dt><dd>{sag.alder_mdr !== null ? `${sag.alder_mdr} mdr.` : "—"}</dd>
          <dt class="text-gray-500">Gennemført / afbrudt</dt><dd>{jaNej(sag.gennemfoert)} / {jaNej(sag.afbrudt)}</dd>
          <dt class="text-gray-500">Samlet resultat</dt><dd class="font-semibold">{sag.samlet_resultat ?? "—"}</dd>
          <dt class="text-gray-500">Sprogstøttebehov</dt><dd>{jaNej(sag.sprogstoettebehov)}</dd>
          {#if sag.screening_noter}
            <dt class="text-gray-500">Noter</dt><dd>{sag.screening_noter}</dd>
          {/if}
        </dl>

        <table class="mx-6 mb-5 text-[13px] w-[calc(100%-3rem)]">
          <thead>
            <tr class="text-left text-gray-500 border-b border-gray-100">
              <th class="py-1.5 font-medium"></th>
              <th class="py-1.5 font-medium">Percentil</th>
              <th class="py-1.5 font-medium">Korrekt</th>
              <th class="py-1.5 font-medium">Forkert</th>
              <th class="py-1.5 font-medium">Besvaret</th>
              <th class="py-1.5 font-medium">Korrekt-ratio</th>
              <th class="py-1.5 font-medium">Score</th>
            </tr>
          </thead>
          <tbody>
            <tr class="border-b border-gray-50">
              <td class="py-1.5 font-medium">Ordforråd</td>
              <td>{tal(sag.of_percentil)}</td><td>{tal(sag.of_korrekt)}</td><td>{tal(sag.of_forkert)}</td>
              <td>{tal(sag.of_besvaret)}</td><td>{procent(sag.of_korrekt_ratio)}</td><td>{tal(sag.of_score)}</td>
            </tr>
            <tr>
              <td class="py-1.5 font-medium">Sprogforståelse</td>
              <td>{tal(sag.sf_percentil)}</td><td>{tal(sag.sf_korrekt)}</td><td>{tal(sag.sf_forkert)}</td>
              <td>{tal(sag.sf_besvaret)}</td><td>{procent(sag.sf_korrekt_ratio)}</td><td>{tal(sag.sf_score)}</td>
            </tr>
          </tbody>
        </table>
      {/if}
    </div>

    <!-- Wishes and daycare -->
    <div class="bg-white rounded-2xl overflow-hidden" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08); border-left: 5px solid #4e7c3a;">
      <div class="px-6 py-4 border-b border-gray-100">
        <h2 class="font-bold text-[15px]" style="color: #2f5325;">Skoleønsker og dagtilbud</h2>
      </div>
      <dl class="px-6 py-5 grid grid-cols-[170px_1fr] gap-y-2.5 gap-x-4 text-[13px]">
        <dt class="text-gray-500">Distriktsskole</dt><dd>{sag.distriktsskole ?? "—"}</dd>
        <dt class="text-gray-500">Ønsket skole</dt><dd>{sag.oensket_skole ?? "—"}</dd>
        <dt class="text-gray-500">Søskende på skolen</dt><dd>{sag.soeskende_skole ?? "—"}</dd>
        <dt class="text-gray-500">Ansøgt anden skole</dt><dd>{jaNej(sag.ansoeger_anden_skole)}</dd>
        {#if sag.skoler_afviger}
          <dt></dt>
          <dd><span class="px-1.5 py-0.5 rounded text-[11px] font-semibold bg-fuchsia-100 text-fuchsia-800">Skolerne afviger fra hinanden</span></dd>
        {/if}
        <dt class="text-gray-500">Dagtilbud</dt>
        <dd>
          {sag.dagtilbud ?? "—"}
          {#if sag.dagtilbud_afdeling}<br /><span class="text-gray-500">{sag.dagtilbud_afdeling}</span>{/if}
        </dd>
        <dt class="text-gray-500">E-mail (PL)</dt><dd>{sag.email_pl ?? "—"}</dd>
        <dt class="text-gray-500">E-mail distriktsskole</dt><dd>{sag.email_distriktsskole ?? "—"}</dd>
        <dt class="text-gray-500">Modersmål</dt><dd>{sag.modersmaal ?? "—"}</dd>
        <dt class="text-gray-500">Tilflyttet DK</dt><dd>{sag.tilflyttet_dk_dato ? dato(sag.tilflyttet_dk_dato) : "—"}</dd>
        <dt class="text-gray-500">PPR</dt><dd>{jaNej(sag.ppr_status)}</dd>
      </dl>
    </div>

  </div>


  <!-- Case work -->
  <div class="bg-white rounded-2xl overflow-hidden mb-6" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08); border-left: 5px solid #6a3fb5;">
    <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between gap-4">
      <h2 class="font-bold text-[15px]" style="color: #3b2168;">Sagsbehandling</h2>
      {#if afsluttet}
        <span class="text-xs text-gray-500">Afsluttet {dato(sag.afsluttet_dato)} — genåbn sagen for at ændre den.</span>
      {/if}
    </div>

    <form class="px-6 py-5 grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-4 text-[13px]" on:submit|preventDefault={gem}>
      <fieldset class="contents" disabled={!kanRedigere || afsluttet || arbejder}>
        <label class="flex flex-col gap-1">
          <span class="text-gray-600">PUF-screeningsresultat</span>
          <input class="border border-gray-300 rounded px-2.5 py-1.5" maxlength="100" bind:value={form.puf_screeningsresultat} />
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-gray-600">Sagsbehandlingsdato</span>
          <input type="date" class="border border-gray-300 rounded px-2.5 py-1.5" bind:value={form.sagsbehandlingsdato} />
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-gray-600">Skoletilbud (matrikel)</span>
          <select class="border border-gray-300 rounded px-2.5 py-1.5 bg-white" bind:value={form.skoletilbud_matrikel_id}>
            <option value="">— Vælg —</option>
            {#each lookups.skolematrikel as o}
              <option value={o.id}>{o.label}</option>
            {/each}
          </select>
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-gray-600">Skoletilbudstype</span>
          <select class="border border-gray-300 rounded px-2.5 py-1.5 bg-white" bind:value={form.skoletilbudstype_id}>
            <option value="">— Vælg —</option>
            {#each lookups.skoletilbudstyper as o}
              <option value={o.id}>{o.label}</option>
            {/each}
          </select>
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-gray-600">Skoleplaceringsårsag</span>
          <select class="border border-gray-300 rounded px-2.5 py-1.5 bg-white" bind:value={form.skoleplaceringsaarsag_id}>
            <option value="">{lookups.skoleplaceringsaarsager.length ? "— Vælg —" : "Ingen værdier oprettet endnu"}</option>
            {#each lookups.skoleplaceringsaarsager as o}
              <option value={o.id}>{o.label}</option>
            {/each}
          </select>
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-gray-600">Skabelon (til brev)</span>
          <select class="border border-gray-300 rounded px-2.5 py-1.5 bg-white" bind:value={form.brevskabelon_id}>
            <option value="">{lookups.brevskabeloner.length ? "— Vælg —" : "Ingen skabeloner oprettet endnu"}</option>
            {#each lookups.brevskabeloner as o}
              <option value={o.id}>{o.label}</option>
            {/each}
          </select>
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-gray-600">Krav på befordring</span>
          <select class="border border-gray-300 rounded px-2.5 py-1.5 bg-white" bind:value={form.krav_paa_befordring}>
            <option value="">— Ikke angivet —</option>
            <option value="ja">Ja</option>
            <option value="nej">Nej</option>
          </select>
        </label>

        <label class="flex flex-col gap-1 md:col-span-2">
          <span class="text-gray-600">Bemærkning</span>
          <textarea class="border border-gray-300 rounded px-2.5 py-1.5 min-h-20" bind:value={form.bemaerkning}></textarea>
        </label>
      </fieldset>

      {#if kanRedigere && !afsluttet}
        <div class="md:col-span-2 flex items-center justify-between gap-4">
          <p class="text-xs text-gray-500">
            Status følger felterne: skoletilbud + skoletilbudstype giver "Skoletilbud".
          </p>
          <button type="submit" class="px-5 py-2 rounded-full text-sm font-semibold text-white bg-dsa-600 hover:bg-dsa-700 disabled:opacity-40" disabled={arbejder}>
            {arbejder ? "Gemmer…" : "Gem"}
          </button>
        </div>
      {/if}
    </form>
  </div>


  <!-- Sagsforløb -->
  <div class="bg-white rounded-2xl overflow-hidden" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08); border-left: 5px solid #bd9b16;">
    <div class="px-6 py-4 border-b border-gray-100">
      <h2 class="font-bold text-[15px]" style="color: #8a7210;">Sagsforløb</h2>
    </div>

    <form class="px-6 pt-4 flex gap-3" on:submit|preventDefault={tilfoejKommentar}>
      <input
        class="flex-1 border border-gray-300 rounded px-3 py-1.5 text-sm"
        placeholder="Skriv en kommentar…"
        bind:value={kommentar}
        disabled={arbejder}
      />
      <button type="submit" class="px-4 py-1.5 rounded-full text-sm font-medium bg-white border border-dsa-200 text-dsa-800 hover:bg-dsa-50 disabled:opacity-40" disabled={arbejder || !kommentar.trim()}>
        Tilføj
      </button>
    </form>

    {#if sagsforloeb.length === 0}
      <p class="px-6 py-5 text-sm text-gray-500">Ingen hændelser endnu.</p>
    {:else}
      <ol class="px-6 py-4 space-y-3">
        {#each sagsforloeb as a (a.aktivitet_id)}
          <li class="flex gap-4 text-[13px]">
            <span class="w-32 shrink-0 text-gray-500">{tidspunkt(a.oprettet_tidspunkt)}</span>
            <div class="flex-1">
              <p>
                <span class="font-semibold {a.type_kode === 'kommentar' ? 'text-dsa-800' : 'text-gray-800'}">{a.aktivitetstype}</span>
                <span class="text-gray-500"> · {a.udfoert_af ?? "—"}</span>
              </p>
              {#if a.kommentar}<p class="text-gray-700 mt-0.5 whitespace-pre-line">{a.kommentar}</p>{/if}
            </div>
            {#if a.type_kode === "kommentar" && brugerNavn && a.udfoert_af === brugerNavn}
              <button type="button" class="text-xs text-red-600 hover:underline self-start" on:click={() => sletKommentar(a.aktivitet_id)}>Slet</button>
            {/if}
          </li>
        {/each}
      </ol>
    {/if}
  </div>

</section>
