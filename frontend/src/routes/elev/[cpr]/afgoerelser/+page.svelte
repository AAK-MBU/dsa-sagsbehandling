<script lang="ts">
  import { goto } from "$app/navigation";

  import { sagHref, type ElevSag } from "$lib/elevsag";
  import { dato, skoleaarTekst } from "$lib/skolebegynder";

  /**
   * Tidligere afgørelser — the child's closed cases from every area, most
   * recently closed first. A row opens the full case read-only
   * (afgoerelser/{omraade}/{id}), where it can be reopened.
   *
   * Plain table rather than DataTable: a child has a handful at most, so
   * filters and paging would be noise.
   */
  export let data;

  $: afgoerelser = data.afgoerelser as ElevSag[];
  $: cpr = data.stamdata.cpr as string;
</script>


<div class="rounded-2xl overflow-hidden kort">
  {#if afgoerelser.length === 0}
    <p class="px-6 py-10 text-center text-gray-500">Barnet har ingen tidligere afgørelser.</p>
  {:else}
    <div class="overflow-x-auto">
      <table class="afgoerelser w-full border-collapse text-[13px]">
        <thead>
          <tr class="text-left text-gray-500 bg-gray-50">
            <th class="font-medium">Sag</th>
            <th class="font-medium">Skoleår</th>
            <th class="font-medium">Modtaget</th>
            <th class="font-medium">Afsluttet</th>
            <th class="font-medium">Resultat</th>
            <th class="font-medium">Skoletilbud</th>
          </tr>
        </thead>
        <tbody>
          {#each afgoerelser as s (s.omraade + s.id)}
            {@const href = sagHref(cpr, s.omraade, s.id, s.status_tekst)}
            <!-- The whole row opens the case; the link in the first cell is
                 what a keyboard or a middle-click uses. -->
            <tr class="cursor-pointer" on:click={() => goto(href)}>
              <td><a {href} class="font-semibold text-dsa-700 hover:underline" on:click|stopPropagation>{s.type}</a></td>
              <td>{s.skoleaar ? skoleaarTekst(s.skoleaar) : "—"}</td>
              <td>{dato(s.modtaget_tidspunkt)}</td>
              <td>{dato(s.afsluttet_dato)}</td>
              <td>{s.resultat ?? "—"}</td>
              <td>{s.skoletilbud ?? "—"}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>


<style>
  /* Compact cells, as the case pages' own tables (the global td/th rule pads
     0.75rem). */
  .afgoerelser :global(th),
  .afgoerelser :global(td) {
    padding: 0.55rem 0.9rem;
  }
</style>
