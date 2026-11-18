<script lang="ts">
  import type { Soeskende } from "$lib/skoleskifter";
  import { formatCpr } from "$lib/tableColumnConfig";

  /**
   * Søskende — children sharing a custody holder with this one (DSA has no
   * family register), each with their school and their cases in DSA. Was a
   * card inside the skoleskifter case; a tab of its own now, for every area.
   */
  export let data;

  $: soeskende = data.soeskende as Soeskende[];
</script>


<div class="rounded-2xl overflow-hidden kort" style="border-left: 5px solid #8a2b2b;">
  <div class="px-6 py-4 border-b border-gray-100">
    <h2 class="font-bold text-[15px]" style="color: #7a2626;">Søskende</h2>
  </div>
  {#if soeskende.length === 0}
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
