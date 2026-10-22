<script lang="ts">
  // Front page ("Forside") — the hub where you pick which område to enter.
  // The 6 områder live in $lib/areas (shared with the top nav). The student
  // search is the top bar's, as on every page.
  import { areas } from "$lib/areas";
</script>


<div class="flex-1 flex flex-col">

  <header class="px-6 md:px-12 pt-10 pb-6 max-w-[900px] w-full mx-auto">
    <h1 class="text-[22px] font-bold" style="color: #271347;">Vælg et område</h1>
    <p class="text-[13px] text-gray-500 mt-1">Eller søg en elev frem på navn eller CPR i søgefeltet øverst.</p>
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
