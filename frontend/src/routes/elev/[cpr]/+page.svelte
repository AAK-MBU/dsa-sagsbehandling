<script lang="ts">
  import SagVisning from "$lib/components/SagVisning.svelte";
  import type { ElevSag } from "$lib/elevsag";
  import { dato, skoleaarTekst } from "$lib/skolebegynder";

  // "Aktiv sag" — the student page's first tab. The child, stamdata and the
  // tab bar are the layout's, above; this is the open case, or a note that
  // there is none.
  export let data;

  $: aktive = data.aktiveSager as ElevSag[];
  $: afgoerelser = data.afgoerelser as ElevSag[];
  $: cpr = data.stamdata.cpr as string;

  const beskriv = (s: ElevSag) =>
    `${s.type}${s.skoleaar ? ` ${skoleaarTekst(s.skoleaar)}` : ""} · modtaget ${dato(s.modtaget_tidspunkt)}`;
</script>


{#if aktive.length === 0}

  <div class="rounded-2xl px-6 py-10 text-center kort">
    <p class="text-gray-700 font-medium">Barnet har ingen aktiv sag.</p>
    {#if afgoerelser.length > 0}
      <p class="mt-2 text-sm text-gray-500">
        Se barnets
        <a href="/elev/{cpr}/afgoerelser" class="text-dsa-700 font-medium hover:underline">
          {afgoerelser.length === 1 ? "tidligere afgørelse" : `${afgoerelser.length} tidligere afgørelser`}</a>.
      </p>
    {/if}
  </div>

{:else}

  <!-- One open case per child is the rule. Should the data hold more, say
       so rather than silently show one — the others are still reachable. -->
  {#if aktive.length > 1}
    <div class="mb-5 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-[13px] text-amber-900" role="alert">
      Barnet har {aktive.length} åbne sager — der burde kun være én:
      {#each aktive as s, i (s.omraade + s.id)}
        {i > 0 ? ", " : ""}{#if `${s.omraade}-${s.id}` === data.vist}<strong>{beskriv(s)}</strong> (vist){:else}<a href="?sag={s.omraade}-{s.id}" class="font-medium underline">{beskriv(s)}</a>{/if}
      {/each}
    </div>
  {/if}

  <SagVisning skolebegynder={data.skolebegynder} skoleskifter={data.skoleskifter} user={data.user} />

{/if}
