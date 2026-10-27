<script lang="ts">
  import SkoleskifterSag from "$lib/components/SkoleskifterSag.svelte";
  import { dato } from "$lib/skolebegynder";
  import type { SkoleskifterDetail, SkoleskifterRow, Soeskende } from "$lib/skoleskifter";

  // The Skoleskiftere tab of the student page (draft). The child, stamdata
  // and warnings are the page's, above; this is the case — shared with the
  // page of a case without CPR (SkoleskifterSag).
  export let data;

  $: sag = data.sag as SkoleskifterDetail | null;
  $: sager = data.skoleskifterSager as SkoleskifterRow[];
  $: kanRedigere = data.user?.can_edit === true;
</script>


<section class="w-full">
  {#if !sag}

    <div class="rounded-2xl px-6 py-10 text-center text-gray-500 kort">
      Barnet har ingen skoleskifter- eller tilflyttersager.
    </div>

  {:else}

    {#if sager.length > 1}
      <div class="flex items-center gap-1 mb-4 text-[13px] flex-wrap">
        <span class="text-gray-500 mr-1">Sager:</span>
        {#each sager as s (s.skoleskifter_id)}
          <a
            href="?sag={s.skoleskifter_id}"
            class="px-2.5 py-1 rounded-full border {s.skoleskifter_id === sag.skoleskifter_id
              ? 'border-dsa-600 bg-dsa-50 text-dsa-800 font-semibold'
              : 'border-gray-200 bg-white text-gray-600 hover:bg-gray-50'}"
            aria-current={s.skoleskifter_id === sag.skoleskifter_id ? "page" : undefined}
          >
            {s.variant} · {dato(s.modtaget_tidspunkt)} · {s.status_tekst}
          </a>
        {/each}
      </div>
    {/if}

    <SkoleskifterSag
      {sag}
      lookups={data.lookups}
      sagsforloeb={data.sagsforloeb}
      soeskende={data.soeskende as Soeskende[]}
      {kanRedigere}
      fagomraadeId={data.fagomraadeId}
    />

  {/if}
</section>
