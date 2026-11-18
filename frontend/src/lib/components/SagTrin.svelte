<script lang="ts">
  /**
   * The step bar under a case card's header: the flow's steps, done ones
   * ticked, the current one ringed. `etiket` names the flow after the steps;
   * the slot holds what sits on the right (e.g. the caseworker).
   */
  export let trin: string[];
  export let aktueltTrin = 0;
  export let etiket: string | null = null;
</script>

<div class="flex flex-wrap items-center justify-between gap-4 px-6 py-3 border-b border-gray-100 bg-gray-50/60">
  <ol class="flex flex-wrap items-center gap-x-2 gap-y-1 text-[12px]" aria-label="Sagens forløb">
    {#each trin as t, i}
      <li class="flex items-center gap-2">
        <span
          class="inline-flex items-center justify-center w-5 h-5 rounded-full text-[11px] font-bold
            {i < aktueltTrin ? 'bg-dsa-600 text-white' : i === aktueltTrin ? 'bg-white border-2 border-dsa-600 text-dsa-700' : 'bg-white border border-gray-300 text-gray-400'}"
          aria-current={i === aktueltTrin ? "step" : undefined}
        >{i < aktueltTrin ? "✓" : i + 1}</span>
        <span class={i === aktueltTrin ? "font-semibold text-dsa-800" : i < aktueltTrin ? "text-gray-700" : "text-gray-400"}>{t}</span>
        {#if i < trin.length - 1}<span class="text-gray-300">›</span>{/if}
      </li>
    {/each}
    {#if etiket}<li class="ml-2 text-gray-400">{etiket}</li>{/if}
  </ol>
  <slot />
</div>
