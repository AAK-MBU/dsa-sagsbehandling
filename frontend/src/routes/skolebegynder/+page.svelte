<script lang="ts">
  import { onMount } from "svelte";

  import { goto, invalidateAll } from "$app/navigation";
  import { page } from "$app/stores";

  import DataTable, { type DataTableColumn } from "$lib/components/DataTable.svelte";
  import ReadOnlyNotice from "$lib/components/ReadOnlyNotice.svelte";
  import { backendFetch } from "$lib/client/backendFetch";
  import { esc } from "$lib/html";
  import {
    FANER,
    aarFraQuery,
    dato,
    faneFraQuery,
    fejltekst,
    iFane,
    jaNej,
    tidspunkt,
    type AendringRow,
    type Fane,
    type SkolebegynderFelter,
    type SkolebegynderRow
  } from "$lib/skolebegynder";
  import { formatCpr, getStatusBadgeClass } from "$lib/tableColumnConfig";

  export let data;

  $: sager = data.sager as SkolebegynderRow[];
  $: aendringer = data.aendringer as AendringRow[];
  $: lookups = data.lookups;
  $: kanRedigere = data.user?.can_edit === true;


  // -----------------------------
  // School year and tab — kept in the URL so a link or a reload lands on
  // the same view.
  // -----------------------------

  $: aarListe = [...new Set(sager.map((s) => s.skoleaar))].sort((a, b) => b - a);
  $: aar = aarFraQuery($page.url.searchParams.get("aar")) ?? aarListe[0] ?? null;
  $: fane = faneFraQuery($page.url.searchParams.get("fane"));

  function skiftVisning(nyAar: number | null, nyFane: Fane) {
    const params = new URLSearchParams();
    if (nyAar !== null) params.set("aar", String(nyAar));
    params.set("fane", nyFane);
    goto(`?${params}`, { replaceState: true, noScroll: true, keepFocus: true });
  }

  $: aarSager = sager.filter((s) => s.skoleaar === aar);
  $: aarAendringer = aendringer.filter((a) => a.skoleaar === aar);
  $: faneSager = fane === "aendringer" ? [] : aarSager.filter((s) => iFane(s, fane));

  $: antal = {
    overblik: aarSager.filter((s) => iFane(s, "overblik")).length,
    "naermere-afklaring": aarSager.filter((s) => iFane(s, "naermere-afklaring")).length,
    "ikke-screenet": aarSager.filter((s) => iFane(s, "ikke-screenet")).length,
    aendringer: aarAendringer.length
  } as Record<Fane, number>;


  // -----------------------------
  // Columns
  // -----------------------------

  const jaNejOptions = [
    { value: 1, label: "Ja" },
    { value: 0, label: "Nej" }
  ];

  const toOptions = (list: { id: number; label: string }[]) =>
    list.map((o) => ({ value: o.id, label: o.label }));

  // DataTable cells are nowrap, so one long value ("Henvist til anden skole
  // end distriktsskolen") widens its whole column. Wrapped text keeps the
  // default view inside a normal screen width.
  const ombryd = (html: string, maxRem = 10) =>
    `<span style="white-space: normal; display: inline-block; max-width: ${maxRem}rem;">${html}</span>`;

  // Every value from the API goes through esc() — DataTable renders these
  // strings as HTML. See $lib/html.
  $: alleKolonner = [
    {
      key: "navn",
      label: "Navn",
      filterType: "text",
      render: (row: SkolebegynderRow) =>
        ombryd(
        `<a href="/skolebegynder/${row.skolebegynder_id}" class="font-semibold text-dsa-700 hover:underline">${esc(row.navn)}</a>` +
        (row.navne_adresse_beskyttelse
          ? ` <span title="Navne- og adressebeskyttelse" class="ml-1 px-1.5 py-0.5 rounded text-[10px] font-semibold bg-red-100 text-red-700">Beskyttet</span>`
          : "") +
        (row.aabne_aendringer > 0
          ? ` <span title="${row.aabne_aendringer} uhåndteret ændring(er)" class="ml-1 px-1.5 py-0.5 rounded text-[10px] font-bold bg-amber-100 text-amber-800">!</span>`
          : "") +
        (row.skoler_afviger
          ? ` <span title="Distriktsskole, ønsket skole og skoletilbud er ikke den samme skole" class="ml-1 px-1.5 py-0.5 rounded text-[10px] font-bold bg-fuchsia-100 text-fuchsia-800">≠</span>`
          : ""),
        14)
    },
    { key: "cpr", label: "CPR", filterType: "text", render: (row: SkolebegynderRow) => esc(formatCpr(row.cpr)) },
    {
      key: "status_tekst",
      label: "Status",
      filterType: "select",
      multiSelect: true,
      render: (row: SkolebegynderRow) =>
        `<span class="inline-block px-2 py-0.5 rounded text-xs font-medium ${getStatusBadgeClass(row.status_tekst)}">${esc(row.status_tekst)}</span>`
    },
    { key: "screeningsdato", label: "Screenet", filterType: "text", render: (row: SkolebegynderRow) => esc(dato(row.screeningsdato)) },
    { key: "samlet_resultat", label: "Samlet resultat", filterType: "select", multiSelect: true, render: (row: SkolebegynderRow) => ombryd(esc(row.samlet_resultat)) },
    {
      key: "puf_screeningsresultat",
      // Short header labels where the long word would set the column width
      // (the header does not wrap inside a word): "Screenet" for the date,
      // "PUF-resultat" for "PUF-screeningsresultat". The export keeps the full
      // names.
      label: "PUF-resultat",
      filterType: "select",
      multiSelect: true,
      editable: true,
      render: (row: SkolebegynderRow) => ombryd(esc(row.puf_screeningsresultat))
    },
    { key: "dagtilbud", label: "Indmeldt dagtilbud", filterType: "text", render: (row: SkolebegynderRow) => esc(row.dagtilbud) },
    { key: "distriktsskole", label: "Distriktsskole", filterType: "select", multiSelect: true, render: (row: SkolebegynderRow) => ombryd(esc(row.distriktsskole)) },
    {
      key: "oensket_skole",
      label: "Ønsket skole",
      filterType: "select",
      multiSelect: true,
      // The sibling's school sits under the wish rather than in a column of
      // its own: it matters for the decision only as "does the sibling
      // guarantee apply here".
      render: (row: SkolebegynderRow) =>
        ombryd(
          esc(row.oensket_skole) +
            (row.soeskende_skole
              ? row.soeskende_skolekode === row.oensket_skolekode
                ? `<br><span class="text-[11px] text-emerald-700">Søskende går her</span>`
                : `<br><span class="text-[11px] text-gray-500">Søskende på ${esc(row.soeskende_skole)}</span>`
              : "")
        )
    },
    { key: "soeskende_skole", label: "Skoleønske søskende", filterType: "select", multiSelect: true, render: (row: SkolebegynderRow) => esc(row.soeskende_skole) },
    {
      key: "skoletilbud_matrikel_id",
      label: "Skoletilbud",
      filterType: "select",
      multiSelect: true,
      editable: true,
      selectOptions: toOptions(lookups.skolematrikel),
      filterValues: (row: SkolebegynderRow) => [row.skoletilbud_matrikel ?? ""],
      render: (row: SkolebegynderRow) => ombryd(esc(row.skoletilbud_matrikel))
    },
    {
      key: "skoletilbudstype_id",
      label: "Skoletilbudstype",
      filterType: "select",
      multiSelect: true,
      editable: true,
      selectOptions: toOptions(lookups.skoletilbudstyper),
      filterValues: (row: SkolebegynderRow) => [row.skoletilbudstype_tekst ?? ""],
      render: (row: SkolebegynderRow) => ombryd(esc(row.skoletilbudstype_tekst))
    },
    {
      key: "skoleplaceringsaarsag_id",
      label: "Skoleplaceringsårsag",
      filterType: "select",
      multiSelect: true,
      editable: true,
      selectOptions: toOptions(lookups.skoleplaceringsaarsager),
      filterValues: (row: SkolebegynderRow) => [row.skoleplaceringsaarsag_tekst ?? ""],
      render: (row: SkolebegynderRow) => esc(row.skoleplaceringsaarsag_tekst)
    },
    {
      key: "krav_paa_befordring",
      label: "Krav på befordring",
      filterType: "select",
      editable: true,
      selectOptions: jaNejOptions,
      filterValues: (row: SkolebegynderRow) => [row.krav_paa_befordring === null ? "" : jaNej(row.krav_paa_befordring)],
      render: (row: SkolebegynderRow) => esc(row.krav_paa_befordring === null ? "" : jaNej(row.krav_paa_befordring))
    },
    {
      key: "brevskabelon_id",
      label: "Skabelon (til brev)",
      filterType: "select",
      multiSelect: true,
      editable: true,
      selectOptions: toOptions(lookups.brevskabeloner),
      filterValues: (row: SkolebegynderRow) => [row.brevskabelon_tekst ?? ""],
      render: (row: SkolebegynderRow) => esc(row.brevskabelon_tekst)
    },
    { key: "bemaerkning", label: "Bemærkning", filterType: "text", editable: true, render: (row: SkolebegynderRow) => esc(row.bemaerkning) },
    {
      key: "skoler_afviger",
      label: "Skoler afviger",
      filterType: "select",
      filterValues: (row: SkolebegynderRow) => [jaNej(row.skoler_afviger)],
      render: (row: SkolebegynderRow) =>
        row.skoler_afviger
          ? `<span title="Distriktsskole, ønsket skole og skoletilbud er ikke den samme skole" class="px-1.5 py-0.5 rounded text-[11px] font-semibold bg-fuchsia-100 text-fuchsia-800">Afviger</span>`
          : ""
    },
    { key: "gaaafstand_distriktsskole_km", label: "Gåafstand distriktsskole (km)", filterType: "text" },
    { key: "gaaafstand_oensket_skole_km", label: "Gåafstand ønsket skole (km)", filterType: "text" },
    { key: "gaaafstand_skoletilbud_km", label: "Gåafstand skoletilbud (km)", filterType: "text" },
    { key: "modersmaal", label: "Modersmål", filterType: "select", multiSelect: true, render: (row: SkolebegynderRow) => esc(row.modersmaal) },
    { key: "tilflyttet_dk_dato", label: "Tilflyttet DK", filterType: "text", render: (row: SkolebegynderRow) => esc(row.tilflyttet_dk_dato ? dato(row.tilflyttet_dk_dato) : "") },
    {
      key: "ppr_status",
      label: "PPR",
      filterType: "select",
      filterValues: (row: SkolebegynderRow) => [jaNej(row.ppr_status)],
      render: (row: SkolebegynderRow) => esc(row.ppr_status ? "Ja" : "")
    },
    { key: "navn_konsulent", label: "Konsulent", filterType: "select", multiSelect: true, render: (row: SkolebegynderRow) => esc(row.navn_konsulent) },
    { key: "of_percentil", label: "Ordforråd (percentil)", filterType: "text" },
    { key: "sf_percentil", label: "Sprogforståelse (percentil)", filterType: "text" },
    { key: "sagsbehandlingsdato", label: "Sagsbehandlingsdato", filterType: "text", render: (row: SkolebegynderRow) => esc(row.sagsbehandlingsdato ? dato(row.sagsbehandlingsdato) : "") }
  ] satisfies DataTableColumn[];


  // -----------------------------
  // Column chooser — per tab, remembered in this browser
  // -----------------------------

  // Overblik is where the placement decision is made, so by default it shows
  // what that decision needs and nothing else — who, the result, the schools
  // in play and what was decided — and fits a normal screen without
  // scrolling. Letter-step fields (skabelon, krav på befordring), daycare and
  // remarks are one click away in "Kolonner" and on the case page.
  // Nærmere afklaring follows the sketch: "Navn, CPR, PUF screeningsresultat,
  // Bemærkning, Tilflyttet til DK".
  const STANDARD_KOLONNER: Record<Exclude<Fane, "aendringer">, string[]> = {
    overblik: [
      "navn", "cpr", "status_tekst", "screeningsdato", "samlet_resultat", "puf_screeningsresultat",
      "distriktsskole", "oensket_skole", "skoletilbud_matrikel_id", "skoletilbudstype_id"
    ],
    "naermere-afklaring": [
      "navn", "cpr", "screeningsdato", "samlet_resultat", "puf_screeningsresultat", "bemaerkning", "tilflyttet_dk_dato"
    ],
    "ikke-screenet": ["navn", "cpr", "distriktsskole", "dagtilbud", "ppr_status", "tilflyttet_dk_dato", "bemaerkning"]
  };

  // Bumped whenever a default changes, so choices saved against the old
  // default do not hide the new one. v2: Overblik 16 -> 9 columns.
  // v3: Screeningsdato added to Overblik.
  const KOLONNE_NOEGLE = "dsa.skolebegynder.kolonner.v3";

  let synlige: Record<string, string[]> = { ...STANDARD_KOLONNER };
  let visKolonnevaelger = false;

  // Read after mount, not during setup: the server renders the defaults, and
  // swapping in the stored choice before hydration would make the two
  // disagree. Browser storage can be missing or refuse (private windows,
  // policies); the defaults then simply stay.
  onMount(() => {
    try {
      const gemt = JSON.parse(localStorage.getItem(KOLONNE_NOEGLE) ?? "null");
      if (gemt && typeof gemt === "object") synlige = { ...synlige, ...gemt };
    } catch {
      // ignore
    }
  });

  function gemKolonner() {
    try {
      localStorage.setItem(KOLONNE_NOEGLE, JSON.stringify(synlige));
    } catch {
      // ignore
    }
  }

  function toggleKolonne(key: string) {
    if (fane === "aendringer") return;
    const nu = new Set(synlige[fane] ?? STANDARD_KOLONNER[fane]);
    if (nu.has(key)) nu.delete(key);
    else nu.add(key);
    // Keep the chosen columns in the order alleKolonner defines.
    synlige = { ...synlige, [fane]: alleKolonner.map((k) => k.key).filter((k) => nu.has(k)) };
    gemKolonner();
  }

  function nulstilKolonner() {
    if (fane === "aendringer") return;
    synlige = { ...synlige, [fane]: STANDARD_KOLONNER[fane] };
    gemKolonner();
  }

  $: synligeNoegler = new Set(fane === "aendringer" ? [] : (synlige[fane] ?? STANDARD_KOLONNER[fane]));
  $: kolonner = alleKolonner.filter((k) => synligeNoegler.has(k.key));


  // -----------------------------
  // Messages
  // -----------------------------

  let besked: { type: "ok" | "fejl"; tekst: string } | null = null;

  function vis(type: "ok" | "fejl", tekst: string) {
    besked = { type, tekst };
  }


  // -----------------------------
  // Inline editing of one row (DataTable's Redigér / Gem)
  // -----------------------------

  let editingRowId: number | null = null;
  let editableRow: Record<string, any> | null = null;

  function startRedigering(row: SkolebegynderRow) {
    if (row.status_tekst === "Afsluttet") {
      vis("fejl", `${row.navn ?? "Sagen"} er afsluttet. Åbn sagen og genåbn den, før den kan ændres.`);
      return;
    }
    besked = null;
    editingRowId = row.skolebegynder_id;
    editableRow = {
      puf_screeningsresultat: row.puf_screeningsresultat,
      skoletilbud_matrikel_id: row.skoletilbud_matrikel_id,
      skoletilbudstype_id: row.skoletilbudstype_id,
      skoleplaceringsaarsag_id: row.skoleplaceringsaarsag_id,
      // The Ja/Nej select works in numbers; mapped back on save.
      krav_paa_befordring: row.krav_paa_befordring === null ? null : row.krav_paa_befordring ? 1 : 0,
      brevskabelon_id: row.brevskabelon_id,
      bemaerkning: row.bemaerkning
    };
  }

  function annullerRedigering() {
    editingRowId = null;
    editableRow = null;
  }

  function aendrFelt(key: string, value: any) {
    if (editableRow) editableRow = { ...editableRow, [key]: value };
  }

  let gemmer = false;

  async function gemRaekke(row: SkolebegynderRow) {
    if (!editableRow || gemmer) return;
    gemmer = true;

    const felter: SkolebegynderFelter = {
      puf_screeningsresultat: editableRow.puf_screeningsresultat || null,
      skoletilbud_matrikel_id: editableRow.skoletilbud_matrikel_id,
      skoletilbudstype_id: editableRow.skoletilbudstype_id,
      skoleplaceringsaarsag_id: editableRow.skoleplaceringsaarsag_id,
      krav_paa_befordring: editableRow.krav_paa_befordring === null ? null : editableRow.krav_paa_befordring === 1,
      brevskabelon_id: editableRow.brevskabelon_id,
      bemaerkning: editableRow.bemaerkning || null
    };

    try {
      const res = await backendFetch(`/skolebegynder/${row.skolebegynder_id}`, {
        method: "PUT",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(felter)
      });

      if (!res.ok) {
        vis("fejl", await fejltekst(res));
        return;
      }

      const opdateret = await res.json();
      annullerRedigering();
      vis("ok", `${opdateret.navn ?? "Sagen"} er gemt — status: ${opdateret.status_tekst}.`);
      await invalidateAll();
    } finally {
      gemmer = false;
    }
  }


  // -----------------------------
  // Selection and mass update
  // -----------------------------

  let valgte: (string | number)[] = [];

  // A new tab or year is a new list: selections from the old one must not
  // ride along invisibly into a mass update.
  $: visningsNoegle = `${aar}-${fane}`;
  let forrigeVisning = "";
  $: if (visningsNoegle !== forrigeVisning) {
    forrigeVisning = visningsNoegle;
    valgte = [];
    annullerRedigering();
  }

  // Only ids actually in the current tab are ever sent.
  $: faneIds = new Set(faneSager.map((s) => s.skolebegynder_id));
  $: valgteIFane = valgte.filter((id) => faneIds.has(Number(id))).map(Number);

  type MasseFelt = "" | number;
  let masse: {
    skoletilbud_matrikel_id: MasseFelt;
    skoletilbudstype_id: MasseFelt;
    skoleplaceringsaarsag_id: MasseFelt;
  } = {
    skoletilbud_matrikel_id: "",
    skoletilbudstype_id: "",
    skoleplaceringsaarsag_id: ""
  };

  function masseFelter(): SkolebegynderFelter {
    const felter: SkolebegynderFelter = {};
    if (masse.skoletilbud_matrikel_id !== "") felter.skoletilbud_matrikel_id = Number(masse.skoletilbud_matrikel_id);
    if (masse.skoletilbudstype_id !== "") felter.skoletilbudstype_id = Number(masse.skoletilbudstype_id);
    if (masse.skoleplaceringsaarsag_id !== "") felter.skoleplaceringsaarsag_id = Number(masse.skoleplaceringsaarsag_id);
    return felter;
  }

  $: masseKlar = Object.values(masse).some((v) => v !== "") && valgteIFane.length > 0;

  let masseopdaterer = false;

  async function masseopdater() {
    const felter = masseFelter();
    if (!masseKlar || masseopdaterer) return;

    if (!confirm(`Opdatér ${valgteIFane.length} sag(er) med de valgte værdier?`)) return;

    masseopdaterer = true;
    try {
      const res = await backendFetch("/skolebegynder/masseopdatering", {
        method: "PUT",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ skolebegynder_ids: valgteIFane, felter })
      });

      if (!res.ok) {
        vis("fejl", await fejltekst(res));
        return;
      }

      const resultat = await res.json();
      vis("ok", `${resultat.opdaterede} sag(er) opdateret, ${resultat.statusaendringer} statusændring(er).`);
      valgte = [];
      masse = { skoletilbud_matrikel_id: "", skoletilbudstype_id: "", skoleplaceringsaarsag_id: "" };
      await invalidateAll();
    } finally {
      masseopdaterer = false;
    }
  }


  // -----------------------------
  // Ændringer
  // -----------------------------

  let haandterer: number | null = null;

  async function haandter(aendring: AendringRow) {
    if (haandterer !== null) return;
    haandterer = aendring.aendring_id;
    try {
      const res = await backendFetch(`/skolebegynder/aendringer/${aendring.aendring_id}/haandter`, { method: "POST" });
      if (!res.ok) {
        vis("fejl", await fejltekst(res));
        return;
      }
      vis("ok", `Ændringen for ${aendring.navn ?? "barnet"} er markeret som håndteret.`);
      await invalidateAll();
    } finally {
      haandterer = null;
    }
  }


  // -----------------------------
  // Export
  // -----------------------------

  $: eksportUrl = `/skolebegynder/skolebegyndere.csv?${new URLSearchParams({ aar: String(aar ?? ""), fane })}`;

  let filteredCount = 0;
</script>


<section class="w-full">

  <ReadOnlyNotice />

  <!-- Header -->
  <div class="flex items-end justify-between gap-4 mb-6 flex-wrap">
    <div>
      <h1 class="text-[26px] font-bold" style="color: #271347;">Skolebegynderscreeninger</h1>
      <p class="text-[13px] text-gray-500 mt-1">Nyeste screeningsresultater øverst.</p>
    </div>

    <div class="flex items-center gap-3">
      <label class="text-[13px] text-gray-600" for="skoleaar">Skolestart</label>
      <select
        id="skoleaar"
        class="border border-dsa-200 rounded-full bg-white px-3 py-1.5 text-sm"
        value={aar ?? ""}
        on:change={(e) => skiftVisning(Number((e.target as HTMLSelectElement).value), fane)}
      >
        {#each aarListe as a}
          <option value={a}>{a}</option>
        {/each}
      </select>

      {#if fane !== "aendringer"}
        <a
          href={eksportUrl}
          class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-full bg-white border border-dsa-200 text-dsa-800 hover:bg-dsa-50 shadow-sm"
          title="Hent fanens sager som Excel-fil"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 3v12m0 0l-4-4m4 4l4-4M4 21h16" />
          </svg>
          Eksportér
        </a>
      {/if}
    </div>
  </div>


  {#if sager.length === 0}
    <div class="bg-white rounded-2xl px-6 py-10 text-center text-gray-500" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08);">
      Der er ingen skolebegyndere i systemet endnu.
    </div>
  {:else}

    <!-- Tabs -->
    <div class="flex gap-1 border-b border-dsa-100 mb-5">
      {#each FANER as f}
        <button
          type="button"
          class="px-4 py-2.5 text-sm font-medium -mb-px border-b-2 transition-colors {fane === f.id
            ? 'border-dsa-600 text-dsa-800'
            : 'border-transparent text-gray-500 hover:text-dsa-700'}"
          on:click={() => skiftVisning(aar, f.id)}
        >
          {f.label}
          <span
            class="ml-1.5 inline-flex items-center justify-center min-w-[1.4rem] h-5 px-1.5 rounded-full text-[11px] font-bold {f.id === 'aendringer' && antal[f.id] > 0
              ? 'bg-amber-500 text-white'
              : 'bg-dsa-100 text-dsa-800'}"
          >
            {antal[f.id]}
          </span>
        </button>
      {/each}
    </div>


    {#if besked}
      <div
        class="mb-4 px-4 py-2.5 rounded-lg text-sm flex items-start justify-between gap-4 {besked.type === 'ok'
          ? 'bg-emerald-50 text-emerald-800 border border-emerald-100'
          : 'bg-red-50 text-red-800 border border-red-100'}"
        role={besked.type === "fejl" ? "alert" : "status"}
      >
        <span>{besked.tekst}</span>
        <button type="button" class="text-xs font-medium hover:underline" on:click={() => (besked = null)}>Luk</button>
      </div>
    {/if}


    {#if fane === "aendringer"}

      <!-- Ændringer -->
      <div class="bg-white rounded-2xl overflow-hidden" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08);">
        {#if aarAendringer.length === 0}
          <p class="px-6 py-10 text-center text-gray-500 text-sm">Ingen uhåndterede ændringer.</p>
        {:else}
          <table class="w-full text-sm">
            <thead>
              <tr class="text-white text-left" style="background-color: #271347;">
                <th class="px-4 py-3 font-semibold">Navn</th>
                <th class="px-4 py-3 font-semibold">CPR</th>
                <th class="px-4 py-3 font-semibold">Adresse</th>
                <th class="px-4 py-3 font-semibold">Distriktsskole</th>
                <th class="px-4 py-3 font-semibold">Ændringsårsag</th>
                <th class="px-4 py-3 font-semibold">Beskrivelse</th>
                <th class="px-4 py-3 font-semibold">Registreret</th>
                <th class="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {#each aarAendringer as a (a.aendring_id)}
                <tr class="border-b border-gray-100 last:border-0">
                  <td class="px-4 py-3">
                    <a href="/skolebegynder/{a.skolebegynder_id}" class="font-semibold text-dsa-700 hover:underline">{a.navn ?? "—"}</a>
                  </td>
                  <td class="px-4 py-3 font-mono text-[13px]">{formatCpr(a.cpr)}</td>
                  <td class="px-4 py-3">{a.navne_adresse_beskyttelse ? "Beskyttet" : (a.adresse_tekst ?? "—")}</td>
                  <td class="px-4 py-3">{a.distriktsskole ?? "—"}</td>
                  <td class="px-4 py-3">
                    <span class="px-2 py-0.5 rounded text-xs font-medium bg-amber-100 text-amber-800">{a.aendringsaarsag_tekst}</span>
                  </td>
                  <td class="px-4 py-3 text-gray-600">{a.beskrivelse ?? ""}</td>
                  <td class="px-4 py-3 text-gray-500 whitespace-nowrap">{tidspunkt(a.registreret_tidspunkt)}</td>
                  <td class="px-4 py-3 text-right">
                    {#if kanRedigere}
                      <button
                        type="button"
                        class="px-3 py-1.5 rounded-full text-xs font-medium text-dsa-700 hover:bg-dsa-50 disabled:opacity-50"
                        disabled={haandterer !== null}
                        on:click={() => haandter(a)}
                      >
                        Markér som håndteret
                      </button>
                    {/if}
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        {/if}
      </div>

    {:else}

      <!-- Toolbar: count, column chooser -->
      <div class="flex items-center justify-between gap-4 mb-3 flex-wrap">
        <p class="text-[13px] text-gray-500">
          Viser {filteredCount} af {faneSager.length} sager
        </p>

        <div class="relative">
          <button
            type="button"
            class="px-3 py-1.5 rounded-full text-[13px] font-medium bg-white border border-dsa-200 text-dsa-800 hover:bg-dsa-50"
            on:click={() => (visKolonnevaelger = !visKolonnevaelger)}
          >
            Kolonner ({kolonner.length})
          </button>

          {#if visKolonnevaelger}
            <div class="absolute right-0 z-40 mt-2 w-72 max-h-96 overflow-auto bg-white border border-gray-200 rounded-lg shadow-lg p-3">
              <div class="flex items-center justify-between mb-2">
                <span class="text-xs font-semibold text-gray-600 uppercase tracking-wider">Vis kolonner</span>
                <button type="button" class="text-xs text-dsa-700 hover:underline" on:click={nulstilKolonner}>Standard</button>
              </div>
              {#each alleKolonner as k}
                <label class="flex items-center gap-2 py-1 text-sm cursor-pointer">
                  <input type="checkbox" checked={synligeNoegler.has(k.key)} on:change={() => toggleKolonne(k.key)} />
                  {k.label}
                </label>
              {/each}
            </div>
          {/if}
        </div>
      </div>


      <!-- Mass update -->
      {#if kanRedigere && valgteIFane.length > 0}
        <div class="mb-3 px-4 py-3 rounded-xl bg-dsa-50 border border-dsa-200 flex items-end gap-3 flex-wrap">
          <div class="text-sm font-semibold text-dsa-800 self-center mr-2">
            {valgteIFane.length} valgt
          </div>

          <label class="flex flex-col text-xs text-gray-600">
            Skoletilbud
            <select class="mt-1 border border-gray-300 rounded px-2 py-1 text-sm bg-white min-w-48" bind:value={masse.skoletilbud_matrikel_id}>
              <option value="">— uændret —</option>
              {#each lookups.skolematrikel as o}
                <option value={o.id}>{o.label}</option>
              {/each}
            </select>
          </label>

          <label class="flex flex-col text-xs text-gray-600">
            Skoletilbudstype
            <select class="mt-1 border border-gray-300 rounded px-2 py-1 text-sm bg-white min-w-48" bind:value={masse.skoletilbudstype_id}>
              <option value="">— uændret —</option>
              {#each lookups.skoletilbudstyper as o}
                <option value={o.id}>{o.label}</option>
              {/each}
            </select>
          </label>

          {#if lookups.skoleplaceringsaarsager.length > 0}
            <label class="flex flex-col text-xs text-gray-600">
              Skoleplaceringsårsag
              <select class="mt-1 border border-gray-300 rounded px-2 py-1 text-sm bg-white min-w-40" bind:value={masse.skoleplaceringsaarsag_id}>
                <option value="">— uændret —</option>
                {#each lookups.skoleplaceringsaarsager as o}
                  <option value={o.id}>{o.label}</option>
                {/each}
              </select>
            </label>
          {/if}

          <!-- Skabelon and krav på befordring belong to the letter step, which
               gets its own view; they stay settable on the case page. -->

          <div class="flex gap-2 ml-auto">
            <button
              type="button"
              class="px-3 py-1.5 rounded-full text-sm text-gray-600 hover:bg-white"
              on:click={() => (valgte = [])}
            >
              Fravælg
            </button>
            <button
              type="button"
              class="px-4 py-1.5 rounded-full text-sm font-semibold text-white bg-dsa-600 hover:bg-dsa-700 disabled:opacity-40"
              disabled={!masseKlar || masseopdaterer}
              on:click={masseopdater}
            >
              {masseopdaterer ? "Opdaterer…" : `Opdatér ${valgteIFane.length} sag(er)`}
            </button>
          </div>
        </div>
      {/if}


      <!-- Grid -->
      <div class="bg-white rounded-2xl overflow-hidden" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08);">
        <DataTable
          data={faneSager}
          columns={kolonner}
          getRowId={(row) => row.skolebegynder_id}
          selectable={kanRedigere}
          bind:selectedIds={valgte}
          editable={kanRedigere}
          {editingRowId}
          {editableRow}
          onEdit={startRedigering}
          onSave={gemRaekke}
          onCancel={annullerRedigering}
          onInputChange={aendrFelt}
          bind:filteredCount
          emptyMessage="Ingen sager i denne fane"
        />
      </div>

    {/if}

  {/if}

</section>
