<script lang="ts">
  import { page } from "$app/stores";

  import Elevoplysninger from "$lib/components/Elevoplysninger.svelte";
  import ReadOnlyNotice from "$lib/components/ReadOnlyNotice.svelte";
  import { areas } from "$lib/areas";
  import { formatCpr } from "$lib/tableColumnConfig";

  /**
   * The student page — one per child, for every area.
   *
   * Laid out as befordringssystemet's /sag/[cpr]: a person header with the
   * protection warnings above it and Elev / Forældremyndighed on the right,
   * then the stamdata card. Under the card, DSA's own part: a tab per area,
   * each its own route (/elev/{cpr}/<area>), so a link from an area's
   * overview lands on that area's tab, and the back button and a reload stay
   * on it.
   */
  let { data, children } = $props();

  const stamdata = $derived(data.stamdata);
  const parents = $derived(data.parents as any[]);
  const cpr = $derived(stamdata.cpr as string);

  const paaForaeldre = $derived(($page.route.id ?? "").endsWith("/foraeldremyndighed"));

  const elevFaner = areas.filter((a) => a.elevside);
  const aktivFane = $derived(elevFaner.find((a) => ($page.route.id ?? "").includes(`/${a.elevside}`))?.elevside ?? null);

  const initial = $derived((stamdata?.adresseringsnavn ?? "?").charAt(0).toUpperCase());

  // The warning names the specific parents, so the caseworker does not have
  // to look them up to see who the restriction applies to. The flag is a BIT
  // read through text(): false from SQL Server, 0 from other drivers — a
  // strict === false would miss the warning there, so test for "set and not
  // true". NULL (not registered) is not a restriction.
  const maaIkkeVide = (p: any) => p.maa_vide_barns_adresse !== null && p.maa_vide_barns_adresse !== undefined && !p.maa_vide_barns_adresse;
  const fratagne = $derived(parents.filter(maaIkkeVide));

  // As befordringssystemet: age from the first 6 digits of the CPR (DDMMYY).
  // Century: YY up to this year's two digits is this century, otherwise the
  // last. Correct for every school-age child.
  function alderFraCpr(c: string): number | null {
    if (!c || c.length < 10) return null;
    const dd = parseInt(c.slice(0, 2), 10);
    const mm = parseInt(c.slice(2, 4), 10);
    const yy = parseInt(c.slice(4, 6), 10);
    const nu = new Date();
    const aarhundrede = yy <= nu.getFullYear() % 100 ? 2000 : 1900;
    const foedt = new Date(aarhundrede + yy, mm - 1, dd);
    let alder = nu.getFullYear() - foedt.getFullYear();
    if (nu.getMonth() < foedt.getMonth() || (nu.getMonth() === foedt.getMonth() && nu.getDate() < foedt.getDate())) alder--;
    return isNaN(alder) ? null : alder;
  }

  const alder = $derived(alderFraCpr(cpr));

  const knapStil = (aktiv: boolean) =>
    aktiv
      ? "background-color: #271347; color: #ffffff; border-color: #271347;"
      : "background-color: #ffffff; color: #374151; border-color: #d1d5db;";
</script>


<main class="flex-1 min-w-0 px-6 md:px-10 py-8">
  <section class="w-full">

    <ReadOnlyNotice />

    <!-- Protection: one warning, a line per reason — impossible to miss,
         without two full-width boxes above the child's name. -->
    {#if stamdata.navne_adresse_beskyttelse || fratagne.length > 0}
      <div class="mb-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-red-900 flex gap-3" role="alert">
        <svg class="w-5 h-5 shrink-0 text-red-600 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" aria-hidden="true">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m0 3.75h.008M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" />
        </svg>
        <ul class="text-[13px] space-y-1">
          {#if stamdata.navne_adresse_beskyttelse}
            <li>Barnet har <strong>navne- og/eller adressebeskyttelse</strong>.</li>
          {/if}
          {#if fratagne.length > 0}
            <li>
              {fratagne.map((p) => `${p.adresseringsnavn ?? ""} (${formatCpr(p.cpr_foraelder)})`).join(", ")}
              må ikke kende barnets adresse, og I må derfor <strong>ikke</strong> på nogen måde videregive
              oplysninger om barnets opholdssted til {fratagne.length === 1 ? "denne forælder" : "disse forældre"}.
            </li>
          {/if}
        </ul>
      </div>
    {/if}


    <!-- Person header -->
    <div class="bg-white rounded-2xl px-4 md:px-6 py-5 mb-4 flex flex-col md:flex-row md:items-center gap-4 justify-between" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08);">
      <div class="flex items-center gap-4">
        <div class="w-12 h-12 rounded-full flex items-center justify-center text-white font-bold text-xl shrink-0" style="background-color: #3b2168;">
          {initial}
        </div>
        <div>
          <h1 class="text-xl font-bold" style="color: #271347;">{stamdata.adresseringsnavn ?? "—"}</h1>
          <p class="text-sm text-gray-500 mt-0.5">
            <span class="font-mono">{formatCpr(cpr)}</span>
            {#if alder !== null}
              <span class="mx-1.5 text-gray-300">·</span>{alder} år
            {/if}
          </p>
        </div>
      </div>

      <div class="flex gap-2 shrink-0">
        <a href="/elev/{cpr}" class="px-4 py-2 text-sm font-medium rounded border transition-colors" style={knapStil(!paaForaeldre)}>
          Elev
        </a>
        <a href="/elev/{cpr}/foraeldremyndighed" class="px-4 py-2 text-sm font-medium rounded border transition-colors" style={knapStil(paaForaeldre)}>
          Forældremyndighed
        </a>
      </div>
    </div>


    {#if paaForaeldre}

      {@render children()}

    {:else}

      <!-- Stamdata, for every area -->
      <div class="bg-white rounded-2xl px-4 md:px-6 py-5 mb-6" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08);">
        <Elevoplysninger elev={stamdata} />
      </div>

      <!-- Area tabs. Each is a route; areas not built yet are shown, dimmed
           ("Kommer snart" on hover), so the page reads as the child's page in
           every area. -->
      <nav class="flex gap-1 border-b border-dsa-100 mb-5 flex-wrap" aria-label="Områder">
        {#each elevFaner as a}
          {#if a.enabled}
            {@const antal = data.sagsantal[a.elevside ?? ""]?.alle ?? 0}
            <a
              href="/elev/{cpr}/{a.elevside}"
              class="px-4 py-2.5 text-sm font-medium -mb-px border-b-2 transition-colors {aktivFane === a.elevside
                ? 'border-dsa-600 text-dsa-800'
                : 'border-transparent text-gray-500 hover:text-dsa-700'}"
              aria-current={aktivFane === a.elevside ? "page" : undefined}
            >
              {a.short}
              <span class="ml-1.5 inline-flex items-center justify-center min-w-[1.4rem] h-5 px-1.5 rounded-full text-[11px] font-bold {antal > 0 ? 'bg-dsa-100 text-dsa-800' : 'bg-gray-100 text-gray-400'}">
                {antal}
              </span>
            </a>
          {:else}
            <span class="px-4 py-2.5 text-sm font-medium -mb-px border-b-2 border-transparent text-gray-300 cursor-default" title="Kommer snart">
              {a.short}
            </span>
          {/if}
        {/each}
      </nav>

      {@render children()}

    {/if}

  </section>
</main>
