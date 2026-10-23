<script lang="ts">
  /**
   * A student's stamdata, rendered identically wherever it appears.
   *
   * DSA: ported from befordringssystemet's Elevoplysninger — same 5 × 2 grid,
   * same labels-above-values markup — with DSA's fields. The card sits on the
   * student page above the area tabs, so it holds what is relevant to every
   * area (the "Stamdata - Barn" fields the field inventory lists for most of
   * them); what only one area uses (ønsket skole, screening, kommende
   * adresse) belongs in that area's tab.
   *
   * Takes the row as it comes off view_Stamdata, whose column names follow
   * befordringssystemet's, so there is nothing to map and therefore nothing
   * to map wrongly. Missing fields render as "—".
   *
   * Sags-ID (ESDH) keeps befordringssystemet's first box. DSA has no ESDH
   * link yet, so it shows "—" until one is delivered (esdh_noegle /
   * esdh_url on the row).
   */

  /** A view_Stamdata row. */
  export let elev: Record<string, any> | null = null;

  /** Heading above the grid. Null renders no heading. */
  export let titel: string | null = "Elevoplysninger";

  $: sagsId = elev?.esdh_noegle ?? null;
  $: sagsUrl = elev?.esdh_url ?? null;

  // A protected child's address is not shown — the protection is the reason
  // it is registered. The header says the child is protected.
  $: folkeregisteradresse = elev?.navne_adresse_beskyttelse ? "Beskyttet" : (elev?.folkeregister_adresse ?? null);

  $: klassetrin = [elev?.elevklassetrin, elev?.klassebetegnelse].filter(Boolean).join(" · ") || null;

  const jaNej = (v: boolean | null | undefined) => (v === null || v === undefined ? "—" : v ? "Ja" : "Nej");

  function dato(v: string | null | undefined) {
    if (!v) return "—";
    const [y, m, d] = v.slice(0, 10).split("-");
    return `${d}-${m}-${y}`;
  }
</script>

{#if titel}
  <div class="mb-6">
    <h2 class="font-semibold text-gray-800">{titel}</h2>
  </div>
{/if}

<div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-5 gap-x-6 gap-y-5">

  <div>
    <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Sags-ID</p>
    {#if sagsId && sagsUrl}
      <a
        href={sagsUrl}
        target="_blank"
        rel="noopener noreferrer"
        title="Åbn sagen i GO"
        class="inline-block px-2 py-0.5 rounded bg-slate-100 text-sky-600 hover:bg-slate-200 hover:underline text-xs font-mono font-medium"
      >{sagsId}</a>
    {:else}
      <span class="inline-block px-2 py-0.5 rounded bg-slate-100 text-slate-700 text-xs font-mono font-medium">
        {sagsId ?? "—"}
      </span>
    {/if}
  </div>

  <div>
    <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Folkeregisteradresse</p>
    <p class="text-sm text-gray-800 break-words" title={folkeregisteradresse ?? ""}>{folkeregisteradresse ?? "—"}</p>
  </div>

  <div>
    <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Distriktsskole</p>
    <p class="text-sm text-gray-800">
      {elev?.distriktsskole ?? "—"}{#if elev?.distriktsskolekode}<span class="ml-1 text-gray-500">({elev.distriktsskolekode})</span>{/if}
    </p>
  </div>

  <div>
    <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Aktuel skole</p>
    <p class="text-sm text-gray-800 break-words">{elev?.skole_navn ?? "—"}</p>
  </div>

  <div>
    <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Klassetrin</p>
    <p class="text-sm text-gray-800">{klassetrin ?? "—"}</p>
  </div>

  <div>
    <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Modersmål</p>
    <p class="text-sm text-gray-800">{elev?.modersmaal ?? "—"}</p>
  </div>

  <div>
    <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Tilflyttet DK</p>
    <p class="text-sm text-gray-800">{dato(elev?.tilflyttet_dk_dato)}</p>
  </div>

  <div>
    <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Sprogstøttebehov</p>
    <p class="text-sm text-gray-800">{jaNej(elev?.sprogstoettebehov)}</p>
  </div>

  <div>
    <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">PPR</p>
    <p class="text-sm text-gray-800">{jaNej(elev?.ppr_status)}</p>
  </div>

  <div>
    <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Køn</p>
    <p class="text-sm text-gray-800">{elev?.koen ?? "—"}</p>
  </div>

</div>
