<script lang="ts">
  import { iDagISO } from "$lib/dates";
  import { daekkerIDag, erAabenPeriode } from "$lib/elevsag";
  import { dato } from "$lib/skolebegynder";

  /**
   * Sprog og støtte — the child's other history (migration 006, filled by
   * LIS): mother tongue over time, periods with language support, periods
   * with PPR, and arrival in Denmark. The student card above shows only
   * today's value of each; this is how it got there.
   */
  export let data;

  // An open period runs to 9999-12-31 (or NULL); it reads "–" with no end.
  const iDag = iDagISO();
  const aktuel = (fra: string, til: string | null) => daekkerIDag(fra, til, iDag);

  const periode = (fra: string, til: string | null) => `${dato(fra)} – ${erAabenPeriode(til) ? "" : dato(til)}`;
</script>


<div class="grid grid-cols-1 lg:grid-cols-2 gap-5 items-start">

  {#if !data.hentet}
    <p class="lg:col-span-2 rounded-2xl px-6 py-5 text-[13px] text-red-700 kort">Historikken kunne ikke hentes.</p>
  {/if}

  <!-- Mother tongue -->
  <div class="rounded-2xl overflow-hidden kort" style="border-left: 5px solid #6a3fb5;">
    <div class="px-6 py-4 border-b border-gray-100"><h2 class="font-bold text-[15px]" style="color: #3b2168;">Modersmål</h2></div>
    {#if data.modersmaal.length === 0}
      <p class="px-6 py-5 text-[13px] text-gray-500">Intet modersmål registreret.</p>
    {:else}
      <ul class="px-6 py-3 divide-y divide-gray-100 text-[13px]">
        {#each data.modersmaal as m (m.gyldig_fra)}
          <li class="py-2 flex items-baseline justify-between gap-4">
            <span class="font-semibold text-gray-800">
              {m.modersmaal}
              {#if aktuel(m.gyldig_fra, m.gyldig_til)}<span class="ml-1 px-1.5 py-0.5 rounded text-[11px] font-semibold bg-dsa-100 text-dsa-800">Nuværende</span>{/if}
            </span>
            <span class="text-gray-500 whitespace-nowrap">{periode(m.gyldig_fra, m.gyldig_til)}</span>
          </li>
        {/each}
      </ul>
    {/if}
  </div>

  <!-- Arrival in Denmark -->
  <div class="rounded-2xl overflow-hidden kort" style="border-left: 5px solid #4e7c3a;">
    <div class="px-6 py-4 border-b border-gray-100"><h2 class="font-bold text-[15px]" style="color: #2f5325;">Indrejse i Danmark</h2></div>
    {#if !data.indrejse}
      <p class="px-6 py-5 text-[13px] text-gray-500">Ingen indrejse registreret.</p>
    {:else}
      <dl class="px-6 py-5 grid grid-cols-[170px_1fr] gap-y-2.5 gap-x-4 text-[13px]">
        <dt class="text-gray-500">Første indrejse</dt><dd>{dato(data.indrejse.foerste_indrejse)}</dd>
        <dt class="text-gray-500">Seneste indrejse</dt><dd>{dato(data.indrejse.seneste_indrejse)}</dd>
      </dl>
    {/if}
  </div>

  <!-- Language support -->
  <div class="rounded-2xl overflow-hidden kort" style="border-left: 5px solid #2c7d90;">
    <div class="px-6 py-4 border-b border-gray-100"><h2 class="font-bold text-[15px]" style="color: #1f5d6e;">Sprogstøttebehov</h2></div>
    {#if data.sprogstoettebehov.length === 0}
      <p class="px-6 py-5 text-[13px] text-gray-500">Ingen perioder med sprogstøttebehov.</p>
    {:else}
      <ul class="px-6 py-3 divide-y divide-gray-100 text-[13px]">
        {#each data.sprogstoettebehov as p (p.startdato)}
          <li class="py-2 flex items-baseline justify-between gap-4">
            <span class="text-gray-800">{periode(p.startdato, p.slutdato)}</span>
            {#if aktuel(p.startdato, p.slutdato)}<span class="px-1.5 py-0.5 rounded text-[11px] font-semibold bg-dsa-100 text-dsa-800">Aktuel</span>{/if}
          </li>
        {/each}
      </ul>
    {/if}
  </div>

  <!-- PPR -->
  <div class="rounded-2xl overflow-hidden kort" style="border-left: 5px solid #bd9b16;">
    <div class="px-6 py-4 border-b border-gray-100"><h2 class="font-bold text-[15px]" style="color: #8a7210;">PPR</h2></div>
    {#if data.ppr.length === 0}
      <p class="px-6 py-5 text-[13px] text-gray-500">Ingen perioder med PPR.</p>
    {:else}
      <ul class="px-6 py-3 divide-y divide-gray-100 text-[13px]">
        {#each data.ppr as p (p.startdato)}
          <li class="py-2 flex items-baseline justify-between gap-4">
            <span class="text-gray-800">{periode(p.startdato, p.slutdato)}</span>
            {#if aktuel(p.startdato, p.slutdato)}<span class="px-1.5 py-0.5 rounded text-[11px] font-semibold bg-dsa-100 text-dsa-800">Aktuel</span>{/if}
          </li>
        {/each}
      </ul>
    {/if}
  </div>

</div>
