<script lang="ts">
  import DataTable, { type DataTableColumn } from "$lib/components/DataTable.svelte";
  import { formatDanishDate, getStatusBadgeClass } from "$lib/tableColumnConfig";
  import type { Ansoegning } from "$lib/types";

  export let data;

  $: ansoegninger = (data.ansoegninger ?? []) as Ansoegning[];

  // Flattened view of a case for the DataTable (it filters on flat keys)
  type Row = {
    id: number;
    navn: string;
    cpr: string | null;
    har_cpr: boolean;
    status: Ansoegning["status"];
    modtagelsesdato: string;
    foedselsdato: string;
    nationalitet: string;
    har_saerlige_behov: boolean;
    ansoeger_relation: string;
    sagsbehandler: string | null;
    klassetrin: string | null;
    modtagelsesskole: string | null;
    soeskende_paa_sag: boolean;
  };

  function toRow(a: Ansoegning): Row {
    return {
      id: a.id,
      navn: a.barn.fulde_navn,
      cpr: a.barn.cpr,
      har_cpr: a.barn.har_cpr,
      status: a.status,
      modtagelsesdato: a.modtagelsesdato,
      foedselsdato: a.barn.foedselsdato,
      nationalitet: a.barn.nationalitet,
      har_saerlige_behov: a.saerlige_behov.har_saerlige_behov,
      ansoeger_relation: a.ansoeger.relation_til_barnet,
      sagsbehandler: a.sagsbehandler,
      klassetrin: a.klassetrin,
      modtagelsesskole: a.modtagelsesskole,
      soeskende_paa_sag: a.soeskende_paa_sag,
    };
  }

  $: rows = ansoegninger.map(toRow);

  // "Aktiv" = the application is still being processed (not Færdigbehandlet).
  // Different meaning than in befordringssystemet, where aktiv refers to the
  // finished bevilling itself.
  $: aktiveRows = rows.filter((r) => r.status !== "Færdigbehandlet");
  $: aktiveMedCpr = aktiveRows.filter((r) => r.har_cpr);
  $: aktiveUdenCpr = aktiveRows.filter((r) => !r.har_cpr);
  // "Seneste" = ansøgninger modtaget i dag (ventetid = 0 dage).
  $: senesteRows = rows.filter((r) => daysSince(r.modtagelsesdato) === 0);

  // Søskende udledes af fælles forældre: to børn med samme forælder-CPR er
  // søskende. Nøglen er de(t) sorterede forælder-CPR.
  function foraeldreNoegle(a: Ansoegning): string | null {
    const cprs = [a.foraeldre.foraelder_1_cpr, a.foraeldre.foraelder_2_cpr]
      .filter((c): c is string => !!c)
      .sort();
    return cprs.length ? cprs.join("|") : null;
  }

  const familieFarver = ["#0ea5e9", "#d97706", "#7e57c2", "#db2777", "#0d9488"];

  // Map fra ansøgnings-id → { søskendes navne, familiefarve }.
  $: soeskende = (() => {
    const grupper = new Map<string, Ansoegning[]>();
    for (const a of ansoegninger) {
      const noegle = foraeldreNoegle(a);
      if (!noegle) continue;
      const liste = grupper.get(noegle) ?? [];
      liste.push(a);
      grupper.set(noegle, liste);
    }

    const byId = new Map<number, { navne: string[]; farve: string }>();
    let farveIndex = 0;
    for (const medlemmer of grupper.values()) {
      if (medlemmer.length < 2) continue; // ingen søskende
      const farve = familieFarver[farveIndex % familieFarver.length];
      farveIndex++;
      for (const m of medlemmer) {
        byId.set(m.id, {
          navne: medlemmer.filter((x) => x.id !== m.id).map((x) => x.barn.fulde_navn),
          farve,
        });
      }
    }
    return byId;
  })();

  function daysSince(dateStr: string | null | undefined): number | null {
    if (!dateStr) return null;
    const diff = Date.now() - new Date(dateStr).getTime();
    return Math.floor(diff / (1000 * 60 * 60 * 24));
  }

  function waitingLabel(days: number | null): string {
    if (days === null) return "—";
    if (days === 0) return "I dag";
    if (days === 1) return "1 dag";
    return `${days} dage`;
  }

  // Kun borgere med gyldigt CPR er klikbare → elevmappe (aldrig CPR i URL'en).
  function rowHref(row: Row): string | null {
    return row.har_cpr && row.cpr ? `/skoleskiftere/${row.id}` : null;
  }

  $: columns = [
    {
      key: "familie_mark",
      label: "",
      filterable: false,
      class: "w-12 text-center",
      render: (row: Row) => {
        const sib = soeskende.get(row.id);
        if (!sib) return ""; // blank — no clutter on non-sibling rows
        const title = `Søskende i processen: ${sib.navne.join(", ")}`;
        return `<span title="${title}" style="display:inline-flex;align-items:center;justify-content:center;width:22px;height:22px;border-radius:6px;background:#059669;color:#fff;">
             <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.5"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/></svg>
           </span>`;
      }
    },
    {
      key: "navn",
      label: "Navn",
      render: (row: Row) => row.har_cpr
        ? `<span class="font-semibold hover:underline" style="color:#59339c;">${row.navn}</span>`
        : `<span class="font-semibold" style="color:#271347;">${row.navn}</span>`
    },
    {
      key: "cpr",
      label: "CPR / Fødselsdato",
      render: (row: Row) => row.har_cpr
        ? `<span class="font-mono text-[13px]">${row.cpr ?? ""}</span>`
        : `<span class="text-[13px] text-gray-500">f. ${formatDanishDate(row.foedselsdato)}</span>`
    },
    {
      key: "status",
      label: "Status",
      render: (row: Row) => `
        <span class="inline-block px-2.5 py-1 rounded-full text-xs font-semibold ${getStatusBadgeClass(row.status)}">
          ${row.status}
        </span>
      `
    },
    {
      key: "modtagelsesdato",
      label: "Ventetid",
      filterable: false,
      render: (row: Row) => {
        const days = daysSince(row.modtagelsesdato);
        const color = days === null ? "#9ca3af" : days >= 14 ? "#dc2626" : days >= 7 ? "#b45309" : "#374151";
        const weight = days !== null && days >= 7 ? "600" : "400";
        return `<span class="text-[13px]" style="color:${color};font-weight:${weight};">${waitingLabel(days)}</span>`;
      }
    },
    {
      key: "modtagelsesdato",
      label: "Modtaget",
      render: (row: Row) => `<span class="text-[13px]">${formatDanishDate(row.modtagelsesdato)}</span>`
    },
    {
      key: "klassetrin",
      label: "Klassetrin",
      render: (row: Row) => row.klassetrin ?? `<span class="text-gray-300">–</span>`
    },
    {
      key: "modtagelsesskole",
      label: "Skole",
      render: (row: Row) => row.modtagelsesskole ?? `<span class="text-gray-300">–</span>`
    },
    {
      key: "sagsbehandler",
      label: "Sagsbehandler",
      render: (row: Row) => row.sagsbehandler
        ? `<span class="text-[13px]">${row.sagsbehandler}</span>`
        : `<span class="text-[13px] text-gray-300">Ikke tildelt</span>`
    },
    {
      key: "soeskende",
      label: "Søskende",
      filterable: false,
      render: (row: Row) => {
        const sib = soeskende.get(row.id);
        if (!sib) return `<span class="text-[13px] text-gray-300">–</span>`;
        return `<span class="text-[13px] text-gray-600">${sib.navne.join(", ")}</span>`;
      }
    },
    {
      key: "har_saerlige_behov",
      label: "Særlige behov",
      filterable: false,
      render: (row: Row) => row.har_saerlige_behov
        ? `<span class="text-[11px] font-semibold px-2 py-0.5 rounded border border-gray-300 text-gray-600">PPR</span>`
        : `<span class="text-[13px] text-gray-300">–</span>`
    },
  ] satisfies DataTableColumn[];
</script>


<svelte:head>
  <title>DSA – Overblik</title>
</svelte:head>


<section class="w-full">

  <!-- Page header -->
  <div class="flex items-end justify-between mb-8">
    <h1 class="text-[26px] font-bold" style="color: #271347;">Overblik</h1>

    <button
      type="button"
      class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-full bg-white border border-dsa-200 text-dsa-800 hover:bg-dsa-50 shadow-sm transition-colors"
    >
      <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 3v12m0 0l-4-4m4 4l4-4M4 21h16" />
      </svg>
      Eksportér
    </button>
  </div>


  <!-- Summary cards -->
  <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 mb-8">

    <div class="bg-white rounded-2xl px-6 py-5 flex items-center gap-4" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08);">
      <div class="w-12 h-12 rounded-xl bg-dsa-100 flex items-center justify-center shrink-0">
        <svg class="w-6 h-6 text-dsa-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M10 6h8M10 12h8M10 18h8M5 6h.01M5 12h.01M5 18h.01" />
        </svg>
      </div>
      <div>
        <p class="text-3xl font-bold leading-none" style="color: #271347;">{aktiveMedCpr.length}</p>
        <p class="text-[13px] text-gray-500 mt-1.5">Aktive med CPR</p>
      </div>
    </div>

    <div class="bg-white rounded-2xl px-6 py-5 flex items-center gap-4" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08);">
      <div class="w-12 h-12 rounded-xl bg-amber-100 flex items-center justify-center shrink-0">
        <svg class="w-6 h-6 text-amber-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v4m0 4h.01M10.3 4.2L2.9 17a2 2 0 001.7 3h14.8a2 2 0 001.7-3L13.7 4.2a2 2 0 00-3.4 0z" />
        </svg>
      </div>
      <div>
        <p class="text-3xl font-bold leading-none" style="color: #271347;">{aktiveUdenCpr.length}</p>
        <p class="text-[13px] text-gray-500 mt-1.5">Aktive uden CPR</p>
      </div>
    </div>

    <div class="bg-white rounded-2xl px-6 py-5 flex items-center gap-4" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08);">
      <div class="w-12 h-12 rounded-xl bg-emerald-100 flex items-center justify-center shrink-0">
        <svg class="w-6 h-6 text-emerald-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
      </div>
      <div>
        <p class="text-3xl font-bold leading-none" style="color: #271347;">{rows.length}</p>
        <p class="text-[13px] text-gray-500 mt-1.5">Ansøgninger i alt</p>
      </div>
    </div>

    <div class="bg-white rounded-2xl px-6 py-5 flex items-center gap-4" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08);">
      <div class="w-12 h-12 rounded-xl bg-sky-100 flex items-center justify-center shrink-0">
        <svg class="w-6 h-6 text-sky-600" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
      </div>
      <div>
        <p class="text-3xl font-bold leading-none" style="color: #271347;">{senesteRows.length}</p>
        <p class="text-[13px] text-gray-500 mt-1.5">Seneste (modtaget i dag)</p>
      </div>
    </div>

  </div>


  <!-- Aktive ansøgninger med CPR -->
  <div class="bg-white rounded-2xl overflow-hidden mb-8" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08);">
    <div class="px-6 pt-5 pb-4 flex items-center gap-3">
      <h2 class="text-[17px] font-bold" style="color: #271347;">Aktive ansøgninger <span class="font-normal text-gray-400">med CPR</span></h2>
      <span class="inline-flex items-center justify-center min-w-[1.6rem] h-6 px-2 rounded-full bg-dsa-600 text-white text-xs font-bold">
        {aktiveMedCpr.length}
      </span>
    </div>
    <DataTable
      data={aktiveMedCpr}
      columns={columns}
      filterable={true}
      rowHref={rowHref}
      emptyMessage="Ingen aktive ansøgninger med CPR"
    />
  </div>


  <!-- Aktive ansøgninger uden CPR -->
  <div class="bg-white rounded-2xl overflow-hidden mb-8" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08);">
    <div class="px-6 pt-5 pb-4 flex items-center gap-3">
      <h2 class="text-[17px] font-bold" style="color: #271347;">Aktive ansøgninger <span class="font-normal text-gray-400">uden CPR</span></h2>
      <span class="inline-flex items-center justify-center min-w-[1.6rem] h-6 px-2 rounded-full bg-amber-500 text-white text-xs font-bold">
        {aktiveUdenCpr.length}
      </span>
      <p class="ml-auto text-xs text-gray-400">Kræver dokumentation for adresse og ophold</p>
    </div>
    <DataTable
      data={aktiveUdenCpr}
      columns={columns}
      filterable={true}
      emptyMessage="Ingen aktive ansøgninger uden CPR"
    />
  </div>

</section>
