<script lang="ts">
  import { goto } from "$app/navigation";
  import { page } from "$app/stores";

  import DataTable, { type DataTableColumn } from "$lib/components/DataTable.svelte";
  import ReadOnlyNotice from "$lib/components/ReadOnlyNotice.svelte";
  import { esc } from "$lib/html";
  import { dato } from "$lib/skolebegynder";
  import {
    FANER,
    VENTETID_GRAENSE,
    faneFraQuery,
    iFane,
    sagHref,
    type Fane,
    type SkoleskifterRow
  } from "$lib/skoleskifter";
  import { formatCpr, getStatusBadgeClass } from "$lib/tableColumnConfig";

  /**
   * Skoleskiftere og tilflyttere — the overview (draft).
   *
   * From the sketch: the two kinds side by side as tabs, the special view of
   * applications without CPR, and the cases with PPR with how long they have
   * been there. Read-only for now — the case is worked on its own page; the
   * area has no mass handling like skolebegyndere.
   */
  export let data;

  $: sager = data.sager as SkoleskifterRow[];
  $: fane = faneFraQuery($page.url.searchParams.get("fane"));
  $: faneSager = sager.filter((s) => iFane(s, fane));
  $: antal = Object.fromEntries(FANER.map((f) => [f.id, sager.filter((s) => iFane(s, f.id)).length])) as Record<Fane, number>;

  function skiftFane(ny: Fane) {
    goto(`?fane=${ny}`, { replaceState: true, noScroll: true, keepFocus: true });
  }

  const FAST = "w-px";
  const ombryd = (html: string, maxRem = 10) =>
    `<span style="white-space: normal; display: inline-block; max-width: ${maxRem}rem;">${html}</span>`;
  const chip = (tekst: string, klasse: string, title = "") =>
    `<span class="px-1.5 py-0.5 rounded text-[10px] font-semibold ${klasse}"${title ? ` title="${esc(title)}"` : ""}>${esc(tekst)}</span>`;

  const alleKolonner = [
    {
      key: "navn",
      label: "Navn",
      filterType: "text",
      filterValues: (r: SkoleskifterRow) => [r.navn ?? "", r.cpr ?? "", r.cpr ? formatCpr(r.cpr) : ""],
      render: (r: SkoleskifterRow) => {
        const maerker = [
          r.har_cpr ? "" : chip("Uden CPR", "bg-gray-200 text-gray-700", "Ansøgningen kom uden CPR — tilknyt CPR på sagen"),
          r.navne_adresse_beskyttelse ? chip("Beskyttet", "bg-red-100 text-red-700") : "",
          r.saerlige_behov ? chip("Særlige behov", "bg-rose-100 text-rose-800") : ""
        ].filter(Boolean);
        return ombryd(
          `<a href="${sagHref(r)}" class="font-semibold text-dsa-700 hover:underline">${esc(r.navn ?? "—")}</a>` +
            (r.cpr ? `<span class="block font-mono text-[12px] text-gray-500">${esc(formatCpr(r.cpr))}</span>` : "") +
            (maerker.length ? `<span class="mt-1 flex flex-wrap gap-1">${maerker.join("")}</span>` : ""),
          12
        );
      }
    },
    { key: "variant", label: "Type", filterType: "select", multiSelect: true, render: (r: SkoleskifterRow) => ombryd(esc(r.variant), 7) },
    {
      key: "status_tekst",
      label: "Status",
      filterType: "select",
      multiSelect: true,
      render: (r: SkoleskifterRow) =>
        `<span class="inline-block px-2 py-0.5 rounded text-xs font-medium whitespace-normal max-w-[7.5rem] ${getStatusBadgeClass(r.status_tekst)}">${esc(r.status_tekst)}</span>`
    },
    { key: "klassetrin_ansoegning", class: FAST, label: "Klassetrin", filterType: "select", multiSelect: true },
    { key: "nuvaerende_skole", label: "Nuværende skole", filterType: "select", multiSelect: true, render: (r: SkoleskifterRow) => ombryd(esc(r.nuvaerende_skole ?? "")) },
    { key: "oensket_skole", label: "Ønsket skole", filterType: "select", multiSelect: true, render: (r: SkoleskifterRow) => ombryd(esc(r.oensket_skole ?? "")) },
    { key: "dato_oensket_skolestart", class: FAST, label: "Ønsket start", filterType: "text", render: (r: SkoleskifterRow) => esc(dato(r.dato_oensket_skolestart)) },
    { key: "modtaget_tidspunkt", class: FAST, label: "Modtaget", filterType: "text", render: (r: SkoleskifterRow) => esc(dato(r.modtaget_tidspunkt)) },
    {
      key: "ventetid_dage",
      class: FAST,
      label: "Ventetid",
      filterType: "text",
      // The sketch's "14 dage": a case waiting longer is marked.
      render: (r: SkoleskifterRow) =>
        r.ventetid_dage === null
          ? ""
          : r.ventetid_dage > VENTETID_GRAENSE && r.status_tekst !== "Afsluttet"
            ? `<span class="px-1.5 py-0.5 rounded text-xs font-semibold bg-amber-100 text-amber-800">${r.ventetid_dage} dage</span>`
            : esc(`${r.ventetid_dage} dage`)
    },
    { key: "dage_hos_ppr", class: FAST, label: "Hos PPR", filterType: "text", render: (r: SkoleskifterRow) => esc(r.dage_hos_ppr === null ? "" : `${r.dage_hos_ppr} dage`) },
    { key: "skoletilbud_matrikel", label: "Skoletilbud", filterType: "select", multiSelect: true, render: (r: SkoleskifterRow) => ombryd(esc(r.skoletilbud_matrikel ?? "")) },
    { key: "skoletilbudstype_tekst", label: "Skoletilbudstype", filterType: "select", multiSelect: true, render: (r: SkoleskifterRow) => ombryd(esc(r.skoletilbudstype_tekst ?? "")) },
    { key: "esdh_noegle", class: FAST, label: "SagsID", filterType: "text", render: (r: SkoleskifterRow) => (r.esdh_noegle ? `<span class="font-mono text-[12px]">${esc(r.esdh_noegle)}</span>` : "") }
  ] satisfies DataTableColumn[];

  // Columns per tab: what the work in that tab needs.
  const KOLONNER: Record<Fane, string[]> = {
    skoleskiftere: ["navn", "variant", "status_tekst", "klassetrin_ansoegning", "nuvaerende_skole", "oensket_skole", "dato_oensket_skolestart", "modtaget_tidspunkt", "ventetid_dage", "esdh_noegle"],
    tilflyttere: ["navn", "status_tekst", "klassetrin_ansoegning", "nuvaerende_skole", "oensket_skole", "dato_oensket_skolestart", "modtaget_tidspunkt", "ventetid_dage", "esdh_noegle"],
    "uden-cpr": ["navn", "variant", "status_tekst", "klassetrin_ansoegning", "oensket_skole", "modtaget_tidspunkt", "ventetid_dage", "esdh_noegle"],
    "hos-ppr": ["navn", "variant", "klassetrin_ansoegning", "oensket_skole", "modtaget_tidspunkt", "dage_hos_ppr", "esdh_noegle"],
    afsluttede: ["navn", "variant", "klassetrin_ansoegning", "oensket_skole", "skoletilbud_matrikel", "skoletilbudstype_tekst", "modtaget_tidspunkt", "ventetid_dage", "esdh_noegle"]
  };

  $: kolonner = alleKolonner.filter((k) => KOLONNER[fane].includes(k.key));

  let filteredCount = 0;
</script>


<section class="w-full">

  <ReadOnlyNotice />

  <div class="mb-6">
    <h1 class="text-[26px] font-bold" style="color: #271347;">Skoleskiftere og -tilflyttere</h1>
    <p class="text-[13px] text-gray-500 mt-1">Ældste ansøgning øverst. Kladde — sagen behandles på elevens side.</p>
  </div>

  <!-- Tabs, boxed as on the skolebegynder overview -->
  <div class="flex gap-2 mb-5 flex-wrap" role="tablist">
    {#each FANER as f}
      <button
        type="button"
        role="tab"
        aria-selected={fane === f.id}
        class="inline-flex items-center px-4 py-2 rounded-lg border text-sm font-medium transition-colors {fane === f.id
          ? 'text-white border-transparent shadow'
          : 'bg-white text-gray-700 border-[#d3cce2] shadow-sm hover:bg-dsa-50 hover:border-dsa-400 hover:text-dsa-800'}"
        style={fane === f.id ? "background-color: #271347;" : ""}
        on:click={() => skiftFane(f.id)}
      >
        {f.label}
        <span
          class="ml-2 inline-flex items-center justify-center min-w-[1.4rem] h-5 px-1.5 rounded-full text-[11px] font-bold {(f.id === 'uden-cpr' || f.id === 'hos-ppr') && antal[f.id] > 0
            ? 'bg-amber-500 text-white'
            : fane === f.id
              ? 'bg-white/20 text-white'
              : 'bg-dsa-100 text-dsa-800'}"
        >
          {antal[f.id]}
        </span>
      </button>
    {/each}
  </div>

  <p class="text-[13px] text-gray-500 mb-3">Viser {filteredCount} af {faneSager.length} sager</p>

  <div class="rounded-2xl overflow-hidden kort">
    <DataTable
      data={faneSager}
      columns={kolonner}
      getRowId={(row) => row.skoleskifter_id}
      compact
      stickyFirstColumn
      bind:filteredCount
      emptyMessage="Ingen sager i denne fane"
    />
  </div>

</section>
