<script lang="ts">
  import { goto } from "$app/navigation";
  import { page } from "$app/stores";
  import { areas } from "$lib/areas";
  import { backendFetch } from "$lib/client/backendFetch";
  import { formatCpr } from "$lib/tableColumnConfig";

  const currentPath = $derived($page.url.pathname);

  // From +layout.server.ts, which every page inherits.
  const user = $derived($page.data.user);
  const logoutUrl = $derived($page.data.logoutUrl);
  const displayName = $derived(user?.name || user?.email || user?.sub || "Ukendt bruger");
  // Below 2xl (1536px) the user is shown as initials, so the areas and the
  // search fit a 13" laptop; the full name is on hover.
  const initialer = $derived(
    displayName
      .replace(/\(.*?\)/g, "")
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((del: string) => del[0]?.toUpperCase() ?? "")
      .join("")
  );

  // An area is active on its own pages, and on the student page's tab for
  // it (/elev/{cpr}/<elevside>).
  function isActive(href?: string, elevside?: string): boolean {
    if (elevside && new RegExp(`^/elev/[^/]+/${elevside}(/|$)`).test(currentPath)) return true;
    if (!href) return false;
    return currentPath === href || currentPath.startsWith(href + "/");
  }


  // --- Global search ---
  // From befordringssystemet's +layout.svelte: a student by name or CPR,
  // from every page. DSA: in the top bar component, and a result opens the
  // student page (/elev/{cpr}) instead of /sag/{cpr}.
  let searchQuery = $state('');
  let searchResults = $state<any[]>([]);
  let searchOpen = $state(false);
  let searchLoading = $state(false);
  let searchFocused = $state(false);
  let debounceTimer: ReturnType<typeof setTimeout> | null = null;
  let highlightedIndex = $state(-1);

  function onSearchInput() {
    if (debounceTimer) clearTimeout(debounceTimer);
    highlightedIndex = -1;

    if (searchQuery.trim().length < 2) {
      searchResults = [];
      searchOpen = false;
      searchLoading = false;
      return;
    }

    searchLoading = true;
    debounceTimer = setTimeout(async () => {
      try {
        const res = await backendFetch(`/citizen/search?q=${encodeURIComponent(searchQuery.trim())}`);
        if (res.ok) {
          searchResults = await res.json();
          searchOpen = searchResults.length > 0;
        }
      } catch {
        searchResults = [];
        searchOpen = false;
      } finally {
        searchLoading = false;
      }
    }, 280);
  }

  function selectResult(cpr: string) {
    searchQuery = '';
    searchResults = [];
    searchOpen = false;
    searchFocused = false;
    highlightedIndex = -1;
    goto(`/elev/${cpr}`);
  }

  function closeSearch() {
    // Small delay so a click on a result registers before closing
    setTimeout(() => {
      searchOpen = false;
      highlightedIndex = -1;
    }, 150);
  }

  function onSearchKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      searchOpen = false;
      highlightedIndex = -1;
      (e.currentTarget as HTMLInputElement).blur();
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      highlightedIndex = Math.min(highlightedIndex + 1, searchResults.length - 1);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      highlightedIndex = Math.max(highlightedIndex - 1, -1);
    } else if (e.key === 'Enter' && highlightedIndex >= 0) {
      e.preventDefault();
      selectResult(searchResults[highlightedIndex].cpr_elev);
    } else if (e.key === 'Enter' && searchResults.length === 1) {
      e.preventDefault();
      selectResult(searchResults[0].cpr_elev);
    }
  }
</script>

<!-- Deep purple across the full width — calmer on the eyes than a white bar
     over a light page, and the same colour as the table headers, so the
     chrome reads as one frame around the light content. -->
<header
  class="w-full sticky top-0 z-30"
  style="background: linear-gradient(90deg, #271347, #3b2168); box-shadow: 0 2px 6px rgba(39,19,71,0.25);"
>
  <div class="flex items-center px-4 md:px-6 h-14">

    <!-- DSA logo → forside -->
    <a href="/" class="flex items-center gap-2.5 pr-5 mr-3 shrink-0 border-r border-white/15" title="Til forsiden">
      <div
        class="w-9 h-9 rounded-lg flex items-center justify-center font-bold text-white"
        style="background: linear-gradient(135deg, #9a7dd2, #6a3fb5);"
      >
        D
      </div>
      <span class="font-bold text-[15px] text-white">DSA</span>
    </a>

    <!-- Områder -->
    <nav class="flex items-center gap-1 overflow-x-auto">
      {#each areas as area}
        {@const active = isActive(area.href, area.elevside)}
        {#if area.enabled && area.href}
          <!-- The active area: a light pill with a dot in the area's own colour. -->
          <a
            href={area.href}
            class="whitespace-nowrap inline-flex items-center gap-1.5 px-2.5 2xl:px-3 py-1.5 rounded-full text-[13px] font-medium transition-colors {active
              ? 'bg-white/15 text-white'
              : 'text-dsa-100 hover:bg-white/10 hover:text-white'}"
            aria-current={active ? "page" : undefined}
          >
            {#if active}<span class="w-1.5 h-1.5 rounded-full" style="background:{area.accent}; box-shadow: 0 0 0 2px rgba(255,255,255,0.6);"></span>{/if}
            {area.short}
          </a>
        {:else}
          <span
            class="whitespace-nowrap px-2.5 2xl:px-3 py-1.5 rounded-full text-[13px] font-medium text-white/35 cursor-not-allowed"
            title="Kommer snart"
          >
            {area.short}
          </span>
        {/if}
      {/each}
    </nav>

    <!-- Global search (from befordringssystemet) -->
    <div class="ml-auto pl-4 relative shrink-0">
      <div class="relative">
        <svg
          class="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 pointer-events-none"
          style="color: rgba(255,255,255,0.5);"
          fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"
        >
          <circle cx="11" cy="11" r="8"/><path stroke-linecap="round" d="M21 21l-4.35-4.35"/>
        </svg>

        {#if searchLoading}
          <svg
            class="absolute right-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 animate-spin"
            style="color: rgba(255,255,255,0.5);"
            fill="none" viewBox="0 0 24 24"
          >
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
          </svg>
        {/if}

        <input
          type="search"
          placeholder="Søg navn eller CPR…"
          aria-label="Søg elev på navn eller CPR"
          autocomplete="off"
          bind:value={searchQuery}
          oninput={onSearchInput}
          onfocus={() => { searchFocused = true; if (searchResults.length > 0) searchOpen = true; }}
          onblur={closeSearch}
          onkeydown={onSearchKeydown}
          class="w-40 2xl:w-52 pl-8 pr-3 py-1.5 rounded-full text-xs transition-all outline-none focus:w-64 placeholder:text-white/50"
          style="background: rgba(255,255,255,0.1); border: 1px solid rgba(255,255,255,0.2); color: #ffffff;"
        />
      </div>

      {#if searchOpen && searchResults.length > 0}
        <div class="absolute right-0 top-full mt-1.5 w-80 bg-white rounded-lg shadow-2xl border border-gray-200 overflow-hidden z-50">
          {#each searchResults as result, i}
            <!-- svelte-ignore a11y_click_events_have_key_events -->
            <div
              role="option"
              aria-selected={highlightedIndex === i}
              tabindex="-1"
              class="flex items-center justify-between px-4 py-3 cursor-pointer transition-colors border-b border-gray-100 last:border-0
                {highlightedIndex === i ? 'bg-dsa-50' : 'hover:bg-gray-50'}"
              onmousedown={(e) => { e.preventDefault(); selectResult(result.cpr_elev); }}
              onmouseenter={() => highlightedIndex = i}
            >
              <div class="min-w-0">
                <p class="text-sm font-semibold text-gray-900 truncate">{result.adresseringsnavn ?? '—'}</p>
                <p class="text-xs text-gray-400 mt-0.5">{formatCpr(result.cpr_elev)}</p>
              </div>
            </div>
          {/each}
        </div>
      {/if}
    </div>

    <!-- Bruger -->
    {#if user}
      <div class="flex items-center gap-3 pl-4 shrink-0 text-[13px]">
        {#if user.roles.includes("oidc-disabled")}
          <!-- Must be impossible to miss: nobody is actually logged in. -->
          <span
            class="px-2.5 py-1 rounded-full bg-amber-100 text-amber-800 font-semibold text-[11px]"
            title="Backend kører med OIDC_ENABLED=false — ingen rigtig login"
          >
            Login slået fra
          </span>
        {/if}
        <span class="hidden 2xl:inline text-dsa-100">{displayName}</span>
        <span
          class="2xl:hidden w-8 h-8 rounded-full flex items-center justify-center text-[11px] font-bold text-white"
          style="background: rgba(255,255,255,0.15);"
          title={displayName}
        >{initialer || "?"}</span>
        {#if !user.roles.includes("oidc-disabled") && logoutUrl}
          <a href={logoutUrl} class="text-white font-medium hover:underline">Log ud</a>
        {/if}
      </div>
    {/if}

  </div>
</header>
