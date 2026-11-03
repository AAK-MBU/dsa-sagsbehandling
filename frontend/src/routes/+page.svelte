<script lang="ts">
  // Front page ("Forside") — what is waiting in each working area, with every
  // number a link to the tab that holds those cases. The numbers come from
  // +page.server.ts. Areas not built yet are one quiet line at the bottom;
  // when one is built it gets a card here. The student search is the top
  // bar's, as on every page.
  import { page } from "$app/stores";

  import { areas, type Area } from "$lib/areas";
  import { skoleaarTekst } from "$lib/skolebegynder";

  import type { PageData } from "./$types";

  export let data: PageData;

  type Linje = { antal: number; tekst: string; href: string; advarsel?: boolean };

  // First name only: "Hej, Daniel". Nothing when the token carries no name —
  // an email address in a greeting reads worse than no name.
  $: fornavn = ($page.data.user?.name ?? "").trim().split(/\s+/)[0] ?? "";

  const omraade = (href: string) => areas.find((a) => a.href === href) as Area;
  const skolebegynderOmraade = omraade("/skolebegynder");
  const skoleskifterOmraade = omraade("/skoleskiftere");

  const kommerSenere = areas.filter((a) => !a.enabled);

  $: sb = data.skolebegynder;
  $: ss = data.skoleskiftere;

  // Ordered by what to do first: the placement decision, then what PUF has
  // to assess, then changes to review. Ikke screenet is mostly waiting on SX.
  $: skolebegynderLinjer = sb
    ? ([
        { antal: sb.mangler_skoleplacering, tekst: "mangler skoleplacering", href: "/skolebegynder?fane=overblik" },
        { antal: sb.naermere_afklaring, tekst: "venter på nærmere afklaring", href: "/skolebegynder?fane=naermere-afklaring" },
        { antal: sb.aendringer, tekst: "ændringer at gennemgå", href: "/skolebegynder?fane=aendringer" },
        { antal: sb.ikke_screenet, tekst: "ikke screenet endnu", href: "/skolebegynder?fane=ikke-screenet" }
      ] satisfies Linje[])
    : [];

  $: skoleskifterLinjer = ss
    ? ([
        ...(ss.ventet_laenge > 0
          ? [{ antal: ss.ventet_laenge, tekst: "har ventet over 14 dage", href: "/skoleskiftere", advarsel: true }]
          : []),
        { antal: ss.skoleskiftere, tekst: "åbne skoleskift", href: "/skoleskiftere?fane=skoleskiftere" },
        { antal: ss.tilflyttere, tekst: "åbne tilflyttere", href: "/skoleskiftere?fane=tilflyttere" },
        { antal: ss.hos_ppr, tekst: "hos PPR", href: "/skoleskiftere?fane=hos-ppr" }
      ] satisfies Linje[])
    : [];
</script>


<div class="flex-1 flex flex-col">

  <!-- Same outer padding and inner width as the cards below, so the greeting
       lines up with them. -->
  <header class="px-6 md:px-12 pt-10 pb-6">
    <div class="max-w-[1000px] mx-auto flex flex-wrap items-end justify-between gap-x-6 gap-y-1">
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
    </div>
  </header>


  <main class="flex-1 px-6 md:px-12 pb-12">
    <div class="max-w-[1000px] mx-auto">

      <div class="grid grid-cols-1 md:grid-cols-2 gap-5">

        <!-- Skolebegynderscreeninger -->
        <section
          class="rounded-2xl border bg-white flex flex-col overflow-hidden"
          style="border-color: {skolebegynderOmraade.ring}; border-top: 4px solid {skolebegynderOmraade.accent};"
        >
          <h2 class="px-6 pt-5 pb-3 font-bold text-[16px]" style="color: {skolebegynderOmraade.accent};">
            {skolebegynderOmraade.title}
          </h2>

          {#if sb}
            <ul class="px-3 flex-1">
              {#each skolebegynderLinjer as l}
                <li>
                  <a href={l.href} class="group flex items-center gap-4 px-3 py-2.5 rounded-lg hover:bg-gray-50 transition-colors">
                    <span
                      class="w-12 text-right text-[22px] font-bold tabular-nums"
                      style="color: {l.antal > 0 ? skolebegynderOmraade.accent : '#cbd5e1'};"
                    >{l.antal}</span>
                    <span class="flex-1 text-[14px] {l.antal > 0 ? 'text-gray-700' : 'text-gray-400'}">{l.tekst}</span>
                    <span class="text-gray-300 group-hover:text-gray-500 transition-colors" aria-hidden="true">→</span>
                  </a>
                </li>
              {/each}
            </ul>

            <div class="mt-3 px-6 py-4 border-t border-gray-100 flex items-center justify-between gap-3" style="background: {skolebegynderOmraade.bg};">
              <p class="flex-1 min-w-0 text-[12px] text-gray-600">
                {sb.screenet} screenet · {sb.skoleplaceret} skoleplaceret · {sb.afsluttet} afsluttet
              </p>
              <a
                href="/skolebegynder"
                class="shrink-0 text-[13px] font-semibold px-3 py-1.5 rounded-md text-white"
                style="background: {skolebegynderOmraade.accent};"
              >Åbn skolebegyndere</a>
            </div>
          {:else}
            <p class="px-6 pb-6 text-[13px] text-gray-500">
              Tallene kunne ikke hentes lige nu. <a href="/skolebegynder" class="underline">Åbn skolebegyndere</a>
            </p>
          {/if}
        </section>


        <!-- Skoleskiftere og -tilflyttere -->
        <section
          class="rounded-2xl border bg-white flex flex-col overflow-hidden"
          style="border-color: {skoleskifterOmraade.ring}; border-top: 4px solid {skoleskifterOmraade.accent};"
        >
          <h2 class="px-6 pt-5 pb-3 font-bold text-[16px]" style="color: {skoleskifterOmraade.accent};">
            {skoleskifterOmraade.title}
          </h2>

          {#if ss}
            <ul class="px-3 flex-1">
              {#each skoleskifterLinjer as l}
                <li>
                  <a href={l.href} class="group flex items-center gap-4 px-3 py-2.5 rounded-lg hover:bg-gray-50 transition-colors">
                    <span
                      class="w-12 text-right text-[22px] font-bold tabular-nums"
                      style="color: {l.advarsel ? '#b45309' : l.antal > 0 ? skoleskifterOmraade.accent : '#cbd5e1'};"
                    >{l.antal}</span>
                    <span class="flex-1 text-[14px] {l.advarsel ? 'text-amber-800 font-medium' : l.antal > 0 ? 'text-gray-700' : 'text-gray-400'}">{l.tekst}</span>
                    <span class="text-gray-300 group-hover:text-gray-500 transition-colors" aria-hidden="true">→</span>
                  </a>
                </li>
              {/each}
            </ul>

            <div class="mt-3 px-6 py-4 border-t border-gray-100 flex items-center justify-between gap-3" style="background: {skoleskifterOmraade.bg};">
              <p class="flex-1 min-w-0 text-[12px] text-gray-600">
                {ss.nye} nye · {ss.afsluttet} afsluttet
              </p>
              <a
                href="/skoleskiftere"
                class="shrink-0 text-[13px] font-semibold px-3 py-1.5 rounded-md text-white"
                style="background: {skoleskifterOmraade.accent};"
              >Åbn skoleskiftere</a>
            </div>
          {:else}
            <p class="px-6 pb-6 text-[13px] text-gray-500">
              Tallene kunne ikke hentes lige nu. <a href="/skoleskiftere" class="underline">Åbn skoleskiftere</a>
            </p>
          {/if}
        </section>

      </div>


      <!-- Areas still to come: present, but not competing with the work -->
      {#if kommerSenere.length > 0}
        <p class="mt-8 text-[12px] text-gray-400">
          <span class="uppercase tracking-wider font-semibold mr-2">Kommer senere</span>
          {kommerSenere.map((a) => a.title).join(" · ")}
        </p>
      {/if}

    </div>
  </main>

</div>
