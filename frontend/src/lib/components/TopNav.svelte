<script lang="ts">
  import { page } from "$app/stores";
  import { areas } from "$lib/areas";

  const currentPath = $derived($page.url.pathname);

  function isActive(href?: string): boolean {
    if (!href) return false;
    return currentPath === href || currentPath.startsWith(href + "/");
  }
</script>

<header
  class="w-full bg-white border-b border-dsa-100 sticky top-0 z-30"
  style="box-shadow: 0 1px 3px rgba(39,19,71,0.06);"
>
  <div class="flex items-center px-4 md:px-6 h-14">

    <!-- DSA logo → forside -->
    <a href="/" class="flex items-center gap-2.5 pr-5 mr-3 shrink-0 border-r border-dsa-100" title="Til forsiden">
      <div
        class="w-9 h-9 rounded-lg flex items-center justify-center font-bold text-white"
        style="background: linear-gradient(135deg, #9a7dd2, #6a3fb5);"
      >
        D
      </div>
      <span class="font-bold text-[15px]" style="color: #271347;">DSA</span>
    </a>

    <!-- Områder -->
    <nav class="flex items-center gap-1 overflow-x-auto">
      {#each areas as area}
        {@const active = isActive(area.href)}
        {#if area.enabled && area.href}
          <a
            href={area.href}
            class="whitespace-nowrap px-3 py-1.5 rounded-full text-[13px] font-medium transition-colors hover:bg-dsa-50"
            style={active ? `background:${area.accent}1a; color:${area.accent};` : "color:#4b5563;"}
          >
            {area.short}
          </a>
        {:else}
          <span
            class="whitespace-nowrap px-3 py-1.5 rounded-full text-[13px] font-medium text-gray-300 cursor-not-allowed"
            title="Kommer snart"
          >
            {area.short}
          </span>
        {/if}
      {/each}
    </nav>

  </div>
</header>
