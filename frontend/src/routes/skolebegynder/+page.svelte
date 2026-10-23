<script lang="ts">
  import { onMount } from "svelte";

  import { beforeNavigate, goto, invalidateAll } from "$app/navigation";
  import { page } from "$app/stores";

  import DataTable, { type DataTableColumn } from "$lib/components/DataTable.svelte";
  import ReadOnlyNotice from "$lib/components/ReadOnlyNotice.svelte";
  import { backendFetch } from "$lib/client/backendFetch";
  import { esc } from "$lib/html";
  import {
    FANER,
    aarFraQuery,
    brydResultat,
    dato,
    faneFraQuery,
    fejltekst,
    iFane,
    jaNej,
    kommendeSkoleaar,
    percentil,
    skoleaarTekst,
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

  // The coming school year is always offered and is the default, also before
  // its first case arrives.
  $: aarListe = [...new Set([kommendeSkoleaar(), ...sager.map((s) => s.skoleaar)])].sort((a, b) => b - a);
  $: aar = aarFraQuery($page.url.searchParams.get("aar")) ?? kommendeSkoleaar();
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
    "screening-afviklet": aarSager.filter((s) => iFane(s, "screening-afviklet")).length,
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

  // A note shown as text (a closed case's remark): wrapped like ombryd, but
  // capped at three lines, with the full text on hover — a long remark must
  // neither widen its column nor make the row tall.
  const notat = (tekst: string | null) =>
    tekst
      ? `<span class="line-clamp-3" style="white-space: normal; max-width: 16rem;" title="${esc(tekst)}">${esc(tekst)}</span>`
      : "";

  // DataTable cells are nowrap, so one long value ("Henvist til anden skole
  // end distriktsskolen") widens its whole column. Wrapped text keeps the
  // default view inside a normal screen width.
  const ombryd = (html: string, maxRem = 10) =>
    `<span style="white-space: normal; display: inline-block; max-width: ${maxRem}rem;">${html}</span>`;

  // Columns whose values have a known, short width (dates, Ja/Nej, numbers):
  // width 1px makes the browser size them to their content and give the
  // spare width to the columns that can use it (names, schools, remarks).
  const FAST = "w-px";

  // Every value from the API goes through esc() — DataTable renders these
  // strings as HTML. See $lib/html.
  $: alleKolonner = [
    {
      key: "navn",
      label: "Navn",
      filterType: "text",
      // The CPR sits under the name rather than in a column of its own — one
      // column less, which is what lets the grid fit a 13" laptop — and the
      // Navn search finds either, typed with or without the dash.
      filterValues: (row: SkolebegynderRow) => [row.navn ?? "", row.cpr, formatCpr(row.cpr)],
      render: (row: SkolebegynderRow) =>
        ombryd(
        `<a href="/elev/${esc(row.cpr)}/skolebegynder?sag=${row.skolebegynder_id}" class="font-semibold text-dsa-700 hover:underline">${esc(row.navn)}</a>` +
        (row.navne_adresse_beskyttelse
          ? ` <span title="Navne- og adressebeskyttelse" class="ml-1 px-1.5 py-0.5 rounded text-[10px] font-semibold bg-red-100 text-red-700">Beskyttet</span>`
          : "") +
        (row.aabne_aendringer > 0
          ? ` <span title="${row.aabne_aendringer} uhåndteret ændring(er)" class="ml-1 px-1.5 py-0.5 rounded text-[10px] font-bold bg-amber-100 text-amber-800">!</span>`
          : "") +
        (row.skoler_afviger
          ? ` <span title="Distriktsskole, ønsket skole og skoletilbud er ikke den samme skole" class="ml-1 px-1.5 py-0.5 rounded text-[10px] font-bold bg-fuchsia-100 text-fuchsia-800">≠</span>`
          : "") +
        `<span class="block font-mono text-[12px] text-gray-500">${esc(formatCpr(row.cpr))}</span>`,
        12)
    },
    { key: "cpr", class: FAST, label: "CPR", filterType: "text", render: (row: SkolebegynderRow) => esc(formatCpr(row.cpr)) },
    {
      key: "status_tekst",
      label: "Status",
      filterType: "select",
      multiSelect: true,
      render: (row: SkolebegynderRow) =>
        // Below 2xl a long status ("Screening afviklet") may wrap rather than
        // set the column's width — the rows are two lines tall there anyway.
        `<span class="inline-block px-2 py-0.5 rounded text-xs font-medium whitespace-normal max-w-[6.5rem] 2xl:whitespace-nowrap 2xl:max-w-none ${getStatusBadgeClass(row.status_tekst)}">${esc(row.status_tekst)}</span>`
    },
    {
      key: "screening_booket_tidspunkt",
      class: FAST,
      label: "Booket tid",
      filterType: "text",
      render: (row: SkolebegynderRow) => esc(row.screening_booket_tidspunkt ? tidspunkt(row.screening_booket_tidspunkt) : "")
    },
    { key: "screeningsdato", class: FAST, label: "Screenet", filterType: "text", render: (row: SkolebegynderRow) => esc(dato(row.screeningsdato)) },
    { key: "samlet_resultat", label: "Samlet resultat", filterType: "select", multiSelect: true, render: (row: SkolebegynderRow) => ombryd(brydResultat(esc(row.samlet_resultat))) },
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
      render: (row: SkolebegynderRow) => ombryd(brydResultat(esc(row.puf_screeningsresultat)))
    },
    { key: "dagtilbud", label: "Indmeldt dagtilbud", filterType: "text", render: (row: SkolebegynderRow) => esc(row.dagtilbud) },
    { key: "distriktsskole", label: "Distriktsskole", filterType: "select", multiSelect: true, render: (row: SkolebegynderRow) => ombryd(esc(row.distriktsskole)) },
    {
      key: "oensket_skole",
      label: "Ønsket skole",
      filterType: "select",
      multiSelect: true,
      // Parents can give two schools; the second goes under the first,
      // numbered, and the filter finds a school given as either. The
      // sibling's school sits under the wishes rather than in a column of its
      // own: it matters for the decision only as "does the sibling guarantee
      // apply here".
      filterValues: (row: SkolebegynderRow) =>
        row.oensket_skole_2 ? [row.oensket_skole ?? "", row.oensket_skole_2] : [row.oensket_skole ?? ""],
      render: (row: SkolebegynderRow) =>
        ombryd(
          (row.oensket_skole_2
            ? `1. ${esc(row.oensket_skole)}<br><span class="text-gray-600">2. ${esc(row.oensket_skole_2)}</span>`
            : esc(row.oensket_skole)) +
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
      class: FAST,
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
    { key: "afklaring", label: "Afklaring", filterType: "text", editable: true, multiline: true, render: (row: SkolebegynderRow) => notat(row.afklaring) },
    { key: "bemaerkning", label: "Bemærkning", filterType: "text", editable: true, multiline: true, render: (row: SkolebegynderRow) => notat(row.bemaerkning) },
    {
      key: "skoler_afviger",
      class: FAST,
      label: "Skoler afviger",
      filterType: "select",
      filterValues: (row: SkolebegynderRow) => [jaNej(row.skoler_afviger)],
      render: (row: SkolebegynderRow) =>
        row.skoler_afviger
          ? `<span title="Distriktsskole, ønsket skole og skoletilbud er ikke den samme skole" class="px-1.5 py-0.5 rounded text-[11px] font-semibold bg-fuchsia-100 text-fuchsia-800">Afviger</span>`
          : ""
    },
    { key: "gaaafstand_distriktsskole_km", class: FAST, label: "Gåafstand distriktsskole (km)", filterType: "text" },
    { key: "gaaafstand_oensket_skole_km", class: FAST, label: "Gåafstand ønsket skole (km)", filterType: "text" },
    { key: "gaaafstand_skoletilbud_km", class: FAST, label: "Gåafstand skoletilbud (km)", filterType: "text" },
    { key: "modersmaal", label: "Modersmål", filterType: "select", multiSelect: true, render: (row: SkolebegynderRow) => esc(row.modersmaal) },
    { key: "tilflyttet_dk_dato", class: FAST, label: "Tilflyttet DK", filterType: "text", render: (row: SkolebegynderRow) => esc(row.tilflyttet_dk_dato ? dato(row.tilflyttet_dk_dato) : "") },
    {
      key: "ppr_status",
      class: FAST,
      label: "PPR",
      filterType: "select",
      filterValues: (row: SkolebegynderRow) => [jaNej(row.ppr_status)],
      render: (row: SkolebegynderRow) => esc(row.ppr_status ? "Ja" : "")
    },
    { key: "navn_konsulent", label: "Konsulent", filterType: "select", multiSelect: true, render: (row: SkolebegynderRow) => esc(row.navn_konsulent) },
    { key: "of_percentil", class: FAST, label: "Ordforråd (percentil)", filterType: "text", render: (row: SkolebegynderRow) => esc(row.of_percentil === null ? "" : percentil(row.of_percentil)) },
    { key: "sf_percentil", class: FAST, label: "Sprogforståelse (percentil)", filterType: "text", render: (row: SkolebegynderRow) => esc(row.sf_percentil === null ? "" : percentil(row.sf_percentil)) },
    { key: "sagsbehandlingsdato", class: FAST, label: "Sagsbehandlingsdato", filterType: "text", render: (row: SkolebegynderRow) => esc(row.sagsbehandlingsdato ? dato(row.sagsbehandlingsdato) : "") }
  ] satisfies DataTableColumn[];


  // -----------------------------
  // Column chooser — per tab, remembered in this browser
  // -----------------------------

  // Overblik is where the placement decision is made, so by default it shows
  // what that decision needs and nothing else — who, the result, the schools
  // in play and what was decided — and fits a normal screen without
  // scrolling. Letter-step fields (skabelon, krav på befordring), daycare and
  // remarks are one click away in "Kolonner" and on the case page.
  // Screening afviklet is the queue those decisions are made from, so it
  // gets Overblik's columns — derived from them, so the two cannot drift —
  // with Afklaring in place of Status: every row there has the same status,
  // and the afklaring note belongs to exactly this step. Ikke screenet shows
  // the booked screening time.
  const OVERBLIK_KOLONNER = [
    "navn", "status_tekst", "screeningsdato", "samlet_resultat", "puf_screeningsresultat",
    "distriktsskole", "oensket_skole", "skoletilbud_matrikel_id", "skoletilbudstype_id"
  ];

  const STANDARD_KOLONNER: Record<Exclude<Fane, "aendringer">, string[]> = {
    overblik: OVERBLIK_KOLONNER,
    "screening-afviklet": [...OVERBLIK_KOLONNER.filter((k) => k !== "status_tekst"), "afklaring"],
    "ikke-screenet": [
      "navn", "status_tekst", "screening_booket_tidspunkt", "distriktsskole", "dagtilbud", "ppr_status",
      "tilflyttet_dk_dato", "bemaerkning"
    ]
  };

  // Bumped whenever a default changes, so choices saved against the old
  // default do not hide the new one. v2: Overblik 16 -> 9 columns.
  // v3: Screeningsdato added to Overblik. v4: the caseworkers' statuses —
  // tab "naermere-afklaring" became "screening-afviklet". v5: Screening
  // afviklet gets Overblik's columns. v6: CPR under the name, not a column
  // of its own (13" laptops).
  const KOLONNE_NOEGLE = "dsa.skolebegynder.kolonner.v6";

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
  // Editing in the grid
  //
  // No Redigér button: the editable columns are inputs on every open case.
  // Changes are held here as drafts, marked yellow in the grid, and saved
  // together from the bar under it. Nothing reaches the database before Gem
  // — the caseworkers are not all at home in spreadsheets, so an explicit
  // save is the safe default. (Double-click to edit a single cell was the
  // alternative considered; see the decision 2026-10-21.)
  // -----------------------------

  type Kladde = Record<string, any>;
  let kladder: Record<number, Kladde> = {};

  /** The value a cell's input shows for a stored row. Ja/Nej works in numbers. */
  function redigeringsvaerdi(row: SkolebegynderRow, key: string): any {
    const v = (row as Record<string, any>)[key];
    if (key === "krav_paa_befordring") return v === null || v === undefined ? null : v ? 1 : 0;
    return v ?? null;
  }

  function aendrCelle(row: SkolebegynderRow, key: string, value: any) {
    const id = row.skolebegynder_id;
    const original = redigeringsvaerdi(row, key);
    // Text is compared as typed (trimmed only on save), so the input never
    // rewrites what the caseworker is in the middle of typing.
    const somFoer = typeof value === "string" ? value === (original ?? "") : value === original;

    const kladde = { ...(kladder[id] ?? {}) };
    if (somFoer) delete kladde[key];
    else kladde[key] = value;

    const naeste = { ...kladder };
    if (Object.keys(kladde).length > 0) naeste[id] = kladde;
    else delete naeste[id];
    kladder = naeste;
  }

  $: antalAendringer = Object.values(kladder).reduce((n, k) => n + Object.keys(k).length, 0);
  $: antalSager = Object.keys(kladder).length;

  function tilFelter(kladde: Kladde): SkolebegynderFelter {
    const felter: Record<string, any> = {};
    for (const [key, v] of Object.entries(kladde)) {
      if (key === "krav_paa_befordring") felter[key] = v === null ? null : v === 1;
      else if (typeof v === "string") felter[key] = v.trim() || null;
      else felter[key] = v;
    }
    return felter;
  }

  let gemmer = false;

  // One PUT per case, each with only its changed fields. A case that fails
  // keeps its drafts, so the caseworker sees what did not get saved.
  async function gemAendringer() {
    if (gemmer || antalSager === 0) return;
    gemmer = true;
    besked = null;

    const navne = new Map(sager.map((s) => [s.skolebegynder_id, s.navn ?? "Sagen"]));
    const tilbage = { ...kladder };
    const fejl: string[] = [];
    let gemt = 0;

    try {
      for (const [id, kladde] of Object.entries(kladder)) {
        const res = await backendFetch(`/skolebegynder/${id}`, {
          method: "PUT",
          headers: { "content-type": "application/json" },
          body: JSON.stringify(tilFelter(kladde))
        });
        if (res.ok) {
          gemt++;
          delete tilbage[Number(id)];
        } else {
          fejl.push(`${navne.get(Number(id))}: ${await fejltekst(res)}`);
        }
      }
      kladder = tilbage;
      await invalidateAll();
    } finally {
      gemmer = false;
    }

    if (fejl.length > 0) {
      vis("fejl", `${gemt} sag(er) gemt. Kunne ikke gemme: ${fejl.join(" · ")}`);
    } else {
      vis("ok", `${gemt} sag(er) gemt.`);
    }
  }

  function fortrydAendringer() {
    if (antalAendringer > 3 && !confirm(`Fortryd alle ${antalAendringer} ændringer?`)) return;
    kladder = {};
  }

  // Leaving the page drops the drafts, so ask first. Switching tab or year
  // stays on the page and keeps them.
  beforeNavigate((navigation) => {
    if (antalAendringer === 0) return;
    if (navigation.type === "leave") {
      // Closing or reloading the tab: the browser shows its own warning.
      navigation.cancel();
      return;
    }
    if (navigation.to?.url.pathname === $page.url.pathname) return;
    if (!confirm(`Du har ${antalAendringer} ugemt(e) ændring(er). Vil du forlade siden uden at gemme?`)) {
      navigation.cancel();
    }
  });


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

  // Not alongside unsaved drafts: two pending ways of changing the same
  // cases at once is one too many to keep track of.
  $: masseKlar = Object.values(masse).some((v) => v !== "") && valgteIFane.length > 0 && antalAendringer === 0;

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

  // The Ændringer grid. Same DataTable as the other tabs; its cells are HTML
  // strings, so the "Markér som håndteret" button carries its id in a data
  // attribute and one click handler around the grid acts on it.
  $: aendringsKolonner = [
    {
      key: "navn",
      label: "Navn",
      filterType: "text",
      filterValues: (a: AendringRow) => [a.navn ?? "", a.cpr, formatCpr(a.cpr)],
      render: (a: AendringRow) =>
        ombryd(
          `<a href="/elev/${esc(a.cpr)}/skolebegynder?sag=${a.skolebegynder_id}" class="font-semibold text-dsa-700 hover:underline">${esc(a.navn ?? "—")}</a>` +
            `<span class="block font-mono text-[12px] text-gray-500">${esc(formatCpr(a.cpr))}</span>`,
          12
        )
    },
    {
      key: "adresse_tekst",
      label: "Adresse",
      filterType: "text",
      render: (a: AendringRow) => ombryd(esc(a.navne_adresse_beskyttelse ? "Beskyttet" : (a.adresse_tekst ?? "—")), 14)
    },
    { key: "distriktsskole", label: "Distriktsskole", filterType: "select", multiSelect: true, render: (a: AendringRow) => esc(a.distriktsskole ?? "—") },
    {
      key: "aendringsaarsag_tekst",
      label: "Ændringsårsag",
      filterType: "select",
      multiSelect: true,
      render: (a: AendringRow) =>
        ombryd(`<span class="px-2 py-0.5 rounded text-xs font-medium bg-amber-100 text-amber-800 leading-6">${esc(a.aendringsaarsag_tekst)}</span>`, 14)
    },
    { key: "beskrivelse", label: "Beskrivelse", filterType: "text", render: (a: AendringRow) => ombryd(esc(a.beskrivelse ?? ""), 20) },
    {
      key: "status_tekst",
      label: "Status",
      filterType: "select",
      multiSelect: true,
      render: (a: AendringRow) =>
        `<span class="inline-block px-2 py-0.5 rounded text-xs font-medium whitespace-normal max-w-[6.5rem] 2xl:whitespace-nowrap 2xl:max-w-none ${getStatusBadgeClass(a.status_tekst)}">${esc(a.status_tekst)}</span>`
    },
    { key: "registreret_tidspunkt", class: FAST, label: "Registreret", filterType: "text", render: (a: AendringRow) => esc(tidspunkt(a.registreret_tidspunkt)) },
    ...(kanRedigere
      ? [
          {
            key: "_haandter",
            label: "",
            filterable: false,
            sortable: false,
            render: (a: AendringRow) =>
              `<button type="button" data-haandter="${a.aendring_id}" ${haandterer !== null ? "disabled" : ""}
                 class="px-3 py-1.5 rounded-full text-xs font-semibold whitespace-nowrap border border-dsa-200 bg-white text-dsa-700 hover:bg-dsa-50 disabled:opacity-50">
                 ${haandterer === a.aendring_id ? "Markerer…" : "Markér som håndteret"}
               </button>`
          }
        ]
      : [])
  ] satisfies DataTableColumn[];

  function klikIAendringer(event: MouseEvent) {
    const knap = (event.target as HTMLElement).closest<HTMLButtonElement>("button[data-haandter]");
    if (!knap || knap.disabled) return;
    const aendring = aarAendringer.find((a) => a.aendring_id === Number(knap.dataset.haandter));
    if (aendring) haandter(aendring);
  }

  let aendringerFiltreret = 0;

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
      <label class="text-[13px] text-gray-600" for="skoleaar">Skoleår</label>
      <select
        id="skoleaar"
        class="border border-dsa-200 rounded-full bg-white px-3 py-1.5 text-sm"
        value={aar ?? ""}
        on:change={(e) => skiftVisning(Number((e.target as HTMLSelectElement).value), fane)}
      >
        {#each aarListe as a}
          <option value={a}>{skoleaarTekst(a)}</option>
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
    <div class="rounded-2xl px-6 py-10 text-center text-gray-500 kort">
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
      <p class="text-[13px] text-gray-500 mb-3">
        Viser {aendringerFiltreret} af {aarAendringer.length} uhåndterede ændringer
      </p>
      <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
      <div class="rounded-2xl overflow-hidden kort" on:click={klikIAendringer}>
        <DataTable
          data={aarAendringer}
          columns={aendringsKolonner}
          getRowId={(row) => row.aendring_id}
          compact
          stickyFirstColumn
          bind:filteredCount={aendringerFiltreret}
          emptyMessage="Ingen uhåndterede ændringer"
        />
      </div>

    {:else}

      <!-- Toolbar: count, column chooser -->
      <div class="flex items-center justify-between gap-4 mb-3 flex-wrap">
        <p class="text-[13px] text-gray-500">
          Viser {filteredCount} af {faneSager.length} sager
          {#if kanRedigere}
            · Ret felterne direkte i tabellen, og tryk <span class="font-medium text-gray-700">Gem ændringer</span>.
          {/if}
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

          <div class="flex gap-2 ml-auto items-center">
            {#if antalAendringer > 0}
              <span class="text-xs text-amber-800">Gem eller fortryd dine ændringer i tabellen først.</span>
            {/if}
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
      <div class="rounded-2xl overflow-hidden kort">
        <DataTable
          data={faneSager}
          columns={kolonner}
          getRowId={(row) => row.skolebegynder_id}
          selectable={kanRedigere}
          bind:selectedIds={valgte}
          compact
          stickyFirstColumn
          alwaysEditable={kanRedigere}
          drafts={kladder}
          isRowEditable={(row) => row.status_tekst !== "Afsluttet"}
          getEditValue={redigeringsvaerdi}
          onCellChange={aendrCelle}
          bind:filteredCount
          emptyMessage="Ingen sager i denne fane"
        />
      </div>

    {/if}


    <!-- Unsaved changes: on every tab, since drafts survive a tab switch -->
    {#if antalAendringer > 0}
      <div
        class="sticky bottom-4 z-30 mt-4 mx-auto max-w-3xl px-5 py-3 rounded-2xl bg-amber-50 border border-amber-300 flex items-center gap-4 flex-wrap"
        style="box-shadow: 0 6px 20px rgba(39,19,71,0.15);"
        role="status"
      >
        <span class="text-sm text-amber-900">
          <strong>{antalAendringer} ugemt{antalAendringer === 1 ? "" : "e"} ændring{antalAendringer === 1 ? "" : "er"}</strong>
          i {antalSager} sag{antalSager === 1 ? "" : "er"}. Ændrede felter er markeret med gult.
        </span>
        <div class="ml-auto flex gap-2">
          <button
            type="button"
            class="px-4 py-2 rounded-full text-sm font-medium text-gray-700 bg-white border border-gray-300 hover:bg-gray-50 disabled:opacity-40"
            disabled={gemmer}
            on:click={fortrydAendringer}
          >
            Fortryd
          </button>
          <button
            type="button"
            class="px-5 py-2 rounded-full text-sm font-semibold text-white bg-dsa-600 hover:bg-dsa-700 disabled:opacity-40"
            disabled={gemmer}
            on:click={gemAendringer}
          >
            {gemmer ? "Gemmer…" : "Gem ændringer"}
          </button>
        </div>
      </div>
    {/if}

  {/if}

</section>
