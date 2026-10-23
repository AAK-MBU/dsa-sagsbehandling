<script lang="ts">
  import { formatCpr } from "$lib/tableColumnConfig";

  export let data;

  // Field names follow befordringssystemet's view_ParentData.
  $: foraeldre = data.parents as any[];

  // A protected parent's address is not shown — the protection is the reason
  // it is registered. The name stays: caseworkers need to know who it is.
  const adresse = (beskyttet: boolean | null, tekst: string | null) =>
    beskyttet ? "Beskyttet" : (tekst ?? "—");
</script>


<div class="rounded-2xl overflow-hidden kort" style="border-left: 5px solid #8a2b2b;">
  <div class="px-6 py-4 border-b border-gray-100">
    <h2 class="font-bold text-[15px]" style="color: #7a2626;">Oplysninger om forældremyndige</h2>
  </div>

  {#if foraeldre.length === 0}
    <p class="px-6 py-5 text-[13px] text-gray-500">Ingen forældremyndighedsindehavere registreret.</p>
  {:else}
    <div class="px-6 py-5 grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5 text-[13px]">
      {#each foraeldre as f, i}
        <div class="rounded-xl border border-gray-200 px-5 py-4">
          <p class="text-gray-500 text-xs mb-1">Forældremyndighed {i + 1}{f.relation ? ` · ${f.relation}` : ""}</p>
          <p class="font-semibold text-[14px]" style="color:#271347;">{f.adresseringsnavn ?? "—"}</p>
          <p class="font-mono text-gray-500">{formatCpr(f.cpr_foraelder)}</p>
          <p class="text-gray-600 mt-1">{adresse(f.navne_adresse_beskyttelse, f.adresse_tekst)}</p>
          {#if f.navne_adresse_beskyttelse}
            <p class="mt-2 inline-block px-2 py-0.5 rounded text-[11px] font-semibold bg-red-100 text-red-700">Navne- og adressebeskyttet</p>
          {/if}
          {#if f.maa_vide_barns_adresse !== null && f.maa_vide_barns_adresse !== undefined && !f.maa_vide_barns_adresse}
            <p class="mt-2 inline-block px-2 py-0.5 rounded text-[11px] font-semibold bg-red-100 text-red-700">Må ikke kende barnets adresse</p>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>
