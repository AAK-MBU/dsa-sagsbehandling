<script lang="ts">
  // Front page ("Forside") — every område as an equal card, in the top bar's
  // order. A built område shows what is waiting in it, every number a link to
  // the tab that holds those cases (numbers from +page.server.ts); one not
  // built yet keeps its place and size, marked "Kommer snart", so the page
  // already has the shape it will have. The student search is the top bar's,
  // as on every page.
  import { page } from "$app/stores";

  import { areas, type Area } from "$lib/areas";
  import { skoleaarTekst } from "$lib/skolebegynder";

  import type { PageData } from "./$types";

  export let data: PageData;

  type Linje = { antal: number; tekst: string; href: string; advarsel?: boolean };

  /** What a built område's card shows; null numbers = could not be fetched. */
  type Indhold = { linjer: Linje[] | null; statistik: string; knap: string };

  // First name only: "Hej, Daniel". Nothing when the token carries no name —
  // an email address in a greeting reads worse than no name.
  $: fornavn = ($page.data.user?.name ?? "").trim().split(/\s+/)[0] ?? "";

  $: sb = data.skolebegynder;
  $: ss = data.skoleskiftere;

  // Keyed by the område's href. A område gets numbers here when it is built.
  $: indhold = {
    // Ordered by what to do first: the placement decision, then what PUF has
    // to assess, then changes to review. Ikke screenet is mostly waiting on SX.
    "/skolebegynder": {
      linjer: sb && [
        { antal: sb.mangler_skoleplacering, tekst: "mangler skoleplacering", href: "/skolebegynder?fane=overblik" },
        { antal: sb.naermere_afklaring, tekst: "venter på nærmere afklaring", href: "/skolebegynder?fane=naermere-afklaring" },
        { antal: sb.aendringer, tekst: "ændringer at gennemgå", href: "/skolebegynder?fane=aendringer" },
        { antal: sb.ikke_screenet, tekst: "ikke screenet endnu", href: "/skolebegynder?fane=ikke-screenet" }
      ],
      statistik: sb ? `${sb.screenet} screenet · ${sb.skoleplaceret} placeret · ${sb.afsluttet} afsluttet` : "",
      knap: "Åbn"
    },
    "/skoleskiftere": {
      linjer: ss && [
        ...(ss.ventet_laenge > 0
          ? [{ antal: ss.ventet_laenge, tekst: "har ventet over 14 dage", href: "/skoleskiftere", advarsel: true }]
          : []),
        { antal: ss.skoleskiftere, tekst: "åbne skoleskift", href: "/skoleskiftere?fane=skoleskiftere" },
        { antal: ss.tilflyttere, tekst: "åbne tilflyttere", href: "/skoleskiftere?fane=tilflyttere" },
        { antal: ss.hos_ppr, tekst: "hos PPR", href: "/skoleskiftere?fane=hos-ppr" }
      ],
      statistik: ss ? `${ss.nye} nye · ${ss.afsluttet} afsluttet` : "",
      knap: "Åbn"
    }
  } as Record<string, Indhold>;

  function kort(a: Area): Indhold | null {
    return a.enabled && a.href ? (indhold[a.href] ?? null) : null;
  }
</script>


<div class="flex-1 flex flex-col px-6 md:px-10 pt-6 pb-8">
  <div class="w-full max-w-[1800px] mx-auto flex-1 flex flex-col">

    <header class="flex flex-wrap items-end justify-between gap-x-6 gap-y-1 mb-5">
      <div>
        <h1 class="text-[24px] font-bold" style="color: #271347;">
          {fornavn ? `Hej, ${fornavn}` : "Hej"}
        </h1>
        <p class="text-[13px] text-gray-500 mt-1">
          Her er, hvad der venter. Søg en elev frem på navn eller CPR i søgefeltet øverst.
        </p>
      </div>
      {#if sb}
        <p class="text-[13px] text-gray-500">
          Skolestart <span class="font-semibold text-gray-700">{skoleaarTekst(sb.skoleaar)}</span>
        </p>
      {/if}
    </header>


    <!-- All six områder, equal size, in the top bar's order. Rows share the
         height left on the screen (auto-rows-fr), so the page fills it. -->
    <main class="flex-1 grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 auto-rows-fr gap-5">

      {#each areas as a (a.title)}
        {@const k = kort(a)}

        {#if k}
          <section
            class="rounded-2xl border bg-white flex flex-col overflow-hidden min-h-[230px]"
            style="border-color: {a.ring}; border-top: 4px solid {a.accent};"
          >
            <h2 class="px-6 pt-4 pb-1.5 font-bold text-[16px]">
              <a href={a.href} class="hover:underline" style="color: {a.accent};">{a.title}</a>
            </h2>

            {#if k.linjer}
              <ul class="px-3 flex-1">
                {#each k.linjer as l}
                  <li>
                    <a href={l.href} class="group flex items-center gap-4 px-3 py-1.5 rounded-lg hover:bg-gray-50 transition-colors">
                      <span
                        class="w-11 text-right text-[20px] font-bold tabular-nums"
                        style="color: {l.advarsel ? '#b45309' : l.antal > 0 ? a.accent : '#cbd5e1'};"
                      >{l.antal}</span>
                      <span class="flex-1 text-[14px] {l.advarsel ? 'text-amber-800 font-medium' : l.antal > 0 ? 'text-gray-700' : 'text-gray-400'}">{l.tekst}</span>
                      <span class="text-gray-300 group-hover:text-gray-500 transition-colors" aria-hidden="true">→</span>
                    </a>
                  </li>
                {/each}
              </ul>
            {:else}
              <p class="px-6 flex-1 text-[13px] text-gray-500">Tallene kunne ikke hentes lige nu.</p>
            {/if}

            <div class="mt-2 px-6 py-2.5 border-t border-gray-100 flex items-center justify-between gap-3" style="background: {a.bg};">
              <p class="flex-1 min-w-0 text-[12px] text-gray-600">{k.statistik}</p>
              <a
                href={a.href}
                class="shrink-0 text-[13px] font-semibold px-3 py-1.5 rounded-md text-white"
                style="background: {a.accent};"
              >{k.knap} {a.short.toLowerCase()}</a>
            </div>
          </section>

        {:else}
          <!-- Not built yet: same place and size, visibly waiting. -->
          <section
            class="rounded-2xl border border-dashed flex flex-col overflow-hidden min-h-[230px]"
            style="border-color: {a.ring}; background: {a.bg}80;"
            title="Kommer snart"
          >
            <div class="px-6 pt-4 pb-1.5 flex items-start justify-between gap-3">
              <h2 class="font-bold text-[16px] opacity-70" style="color: {a.accent};">{a.title}</h2>
              <span class="shrink-0 text-[10px] uppercase tracking-wider font-semibold px-2 py-0.5 rounded-full bg-white/80 text-gray-500">
                Kommer snart
              </span>
            </div>
            <div class="flex-1 flex items-center justify-center px-6 pb-6">
              <p class="text-[13px] text-gray-400 text-center">
                Området er ikke bygget endnu.<br />Her kommer overblikket over, hvad der venter.
              </p>
            </div>
          </section>
        {/if}
      {/each}

    </main>
  </div>
</div>
