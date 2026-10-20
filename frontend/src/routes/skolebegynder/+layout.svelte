<script lang="ts">
  import { page } from "$app/stores";

  let { children } = $props();

  const nav = [
    {
      href: "/skolebegynder",
      label: "Overblik",
      enabled: true,
      icon: "M3 12l9-8 9 8M5 10v10h5v-6h4v6h5V10"
    },
    {
      href: "/skolebegynder/rapporter",
      label: "Rapporter",
      enabled: false,
      icon: "M4 20h16M6 16v-5M11 16V7M16 16v-9"
    },
  ];

  const currentPath = $derived($page.url.pathname);

  // Overblik stays highlighted on a case page too: a case is opened from it.
  function isActive(href: string) {
    return currentPath === href || (href === "/skolebegynder" && /^\/skolebegynder\/\d+/.test(currentPath));
  }
</script>

<div class="flex flex-1">

  <!-- Sidebar -->
  <aside
    class="w-60 shrink-0 flex flex-col text-white"
    style="background: linear-gradient(180deg, #3b2168 0%, #271347 100%);"
  >

    <div class="px-6 pt-6 pb-5">
      <p class="text-[10px] uppercase tracking-wider" style="color: #bba9e2;">Område</p>
      <p class="font-bold text-[16px] mt-0.5">Skolebegynderscreeninger</p>
    </div>

    <div class="mx-6 h-px" style="background: rgba(255,255,255,0.12);"></div>

    <nav class="flex-1 px-3 py-4 space-y-1">
      {#each nav as item}
        {#if item.enabled}
          <a
            href={item.href}
            class="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors"
            style={isActive(item.href)
              ? "background: rgba(255,255,255,0.14); color: #ffffff;"
              : "color: rgba(255,255,255,0.65);"}
          >
            <svg class="w-[18px] h-[18px] shrink-0" fill="none" stroke="currentColor" stroke-width="1.8" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d={item.icon} />
            </svg>
            {item.label}
          </a>
        {:else}
          <div
            class="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium cursor-not-allowed"
            style="color: rgba(255,255,255,0.3);"
            title="Kommer senere"
          >
            <svg class="w-[18px] h-[18px] shrink-0" fill="none" stroke="currentColor" stroke-width="1.8" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d={item.icon} />
            </svg>
            {item.label}
            <span class="ml-auto text-[9px] uppercase tracking-wider" style="color: rgba(255,255,255,0.25);">Snart</span>
          </div>
        {/if}
      {/each}
    </nav>

    <div class="px-6 py-5 text-[11px]" style="color: rgba(255,255,255,0.35);">
      Aarhus Kommune<br />Børn og Unge
    </div>

  </aside>

  <main class="flex-1 min-w-0 px-6 md:px-10 py-8">
    {@render children()}
  </main>

</div>
