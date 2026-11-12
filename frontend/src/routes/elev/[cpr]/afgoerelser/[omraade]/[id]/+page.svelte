<script lang="ts">
  import SagVisning from "$lib/components/SagVisning.svelte";

  // One afgørelse: the closed case in full, read-only. "Genåbn sag" in the
  // case strip reopens it, and the load then sends the page to "Aktiv sag".
  export let data;
</script>


<a href="/elev/{data.stamdata.cpr}/afgoerelser" class="inline-flex items-center gap-1 text-[13px] text-dsa-600 hover:text-dsa-800 mb-4">
  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" aria-hidden="true">
    <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" />
  </svg>
  Alle afgørelser
</a>

<SagVisning skolebegynder={data.skolebegynder} skoleskifter={data.skoleskifter} user={data.user} />
