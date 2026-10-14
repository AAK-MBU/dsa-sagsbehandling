<script lang="ts">
  // Front page ("Forside") — the hub where you pick which område to enter.
  // The 6 områder live in $lib/areas (shared with the top nav).
  import { areas } from "$lib/areas";

  let search = $state("");
</script>


<svelte:head>
  <title>DSA – Forside</title>
</svelte:head>


<div class="flex-1 flex flex-col">

  <!-- Top bar -->
  <header class="px-6 md:px-12 pt-8 pb-6 flex items-start justify-between gap-6 flex-wrap">

    <div class="flex items-center gap-3">
      <div
        class="w-11 h-11 rounded-xl flex items-center justify-center font-bold text-lg text-white"
        style="background: linear-gradient(135deg, #9a7dd2, #6a3fb5);"
      >
        D
      </div>
      <div class="leading-tight">
        <p class="font-bold text-[17px]" style="color: #271347;">DSA</p>
        <p class="text-[12px] text-gray-500">Vælg et område</p>
      </div>
    </div>

    <!-- Søgning -->
    <div class="relative w-full max-w-sm">
      <input
        type="text"
        bind:value={search}
        placeholder="Søg på Navn eller CPR"
        class="w-full rounded-full bg-white border border-dsa-200 pl-5 pr-11 py-2.5 text-sm shadow-sm focus:border-dsa-400 focus:outline-none focus:ring-2 focus:ring-dsa-100 transition-all"
      />
      <svg
        class="w-5 h-5 absolute right-4 top-1/2 -translate-y-1/2 text-dsa-400"
        fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"
      >
        <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-4.3-4.3M11 19a8 8 0 100-16 8 8 0 000 16z" />
      </svg>
    </div>

  </header>


  <!-- Domain cards -->
  <main class="flex-1 px-6 md:px-12 pb-12">
    <div class="max-w-[900px] mx-auto grid grid-cols-1 md:grid-cols-2 gap-5">

      {#each areas as d}
        {#if d.enabled && d.href}
          <a
            href={d.href}
            class="group block rounded-2xl px-6 py-5 border transition-all hover:-translate-y-0.5 hover:shadow-md"
            style="background: {d.bg}; border-color: {d.ring}; border-left: 5px solid {d.accent};"
          >
            <h2 class="font-bold text-[16px] leading-snug" style="color: {d.accent};">
              {d.title}
            </h2>
            <div class="mt-3 flex flex-col gap-1">
              {#each d.links as link}
                <span class="text-[13px] text-gray-600 group-hover:text-gray-800">{link.label}</span>
              {/each}
            </div>
          </a>
        {:else}
          <div
            class="relative block rounded-2xl px-6 py-5 border cursor-not-allowed opacity-70"
            style="background: {d.bg}; border-color: {d.ring}; border-left: 5px solid {d.accent};"
            title="Kommer snart"
          >
            <span class="absolute top-4 right-4 text-[9px] uppercase tracking-wider font-semibold px-2 py-0.5 rounded-full bg-white/70 text-gray-500">
              Snart
            </span>
            <h2 class="font-bold text-[16px] leading-snug" style="color: {d.accent};">
              {d.title}
            </h2>
            <div class="mt-3 flex flex-col gap-1">
              {#each d.links as link}
                <span class="text-[13px] text-gray-500">{link.label}</span>
              {/each}
            </div>
          </div>
        {/if}
      {/each}

    </div>
  </main>

</div>
