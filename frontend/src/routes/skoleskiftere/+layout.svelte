<script lang="ts">
  import { page } from "$app/stores";

  let { children } = $props();

  const nav = [
    {
      href: "/skoleskiftere",
      label: "Overblik",
      enabled: true,
      icon: "M3 12l9-8 9 8M5 10v10h5v-6h4v6h5V10"
    },
    {
      href: "/skoleskiftere/sager",
      label: "Sager",
      enabled: false,
      icon: "M4 6h16M4 6v13h16V6M4 6l2-3h12l2 3M9 11h6"
    },
    {
      href: "/skoleskiftere/rapporter",
      label: "Rapporter",
      enabled: false,
      icon: "M4 20h16M6 16v-5M11 16V7M16 16v-9"
    },
    {
      href: "/skoleskiftere/indstillinger",
      label: "Indstillinger",
      enabled: false,
      icon: "M12 9a3 3 0 100 6 3 3 0 000-6zM19 12a7 7 0 01-.1 1.2l2 1.5-2 3.5-2.4-.9a7 7 0 01-2 1.2L14 21h-4l-.5-2.5a7 7 0 01-2-1.2l-2.4.9-2-3.5 2-1.5A7 7 0 015 12a7 7 0 01.1-1.2l-2-1.5 2-3.5 2.4.9a7 7 0 012-1.2L10 3h4l.5 2.5a7 7 0 012 1.2l2.4-.9 2 3.5-2 1.5A7 7 0 0119 12z"
    },
  ];

  const currentPath = $derived($page.url.pathname);
</script>

<div class="flex flex-1">

  <!-- Sidebar -->
  <aside
    class="w-60 shrink-0 flex flex-col text-white"
    style="background: linear-gradient(180deg, #3b2168 0%, #271347 100%);"
  >

    <!-- Område-overskrift (DSA-brand + områdeskift ligger i topbaren) -->
    <div class="px-6 pt-6 pb-5">
      <p class="text-[10px] uppercase tracking-wider" style="color: #bba9e2;">Område</p>
      <p class="font-bold text-[16px] mt-0.5">Skoleskiftere og tilflyttere</p>
    </div>

    <div class="mx-6 h-px" style="background: rgba(255,255,255,0.12);"></div>

    <!-- Nav -->
    <nav class="flex-1 px-3 py-4 space-y-1">
      {#each nav as item}
        {@const active = item.enabled && currentPath === item.href}
        {#if item.enabled}
          <a
            href={item.href}
            class="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors"
            style={active
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

    <!-- Footer -->
    <div class="px-6 py-5 text-[11px]" style="color: rgba(255,255,255,0.35);">
      Aarhus Kommune<br />Børn og Unge
    </div>

  </aside>


  <!-- Main content -->
  <main class="flex-1 min-w-0 px-6 md:px-10 py-8">
    {@render children()}
  </main>

</div>
