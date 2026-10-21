<script lang="ts">
  import { dato, jaNej, skoleaarTekst, type SkolebegynderRow } from "$lib/skolebegynder";
  import { formatCpr, getStatusBadgeClass } from "$lib/tableColumnConfig";

  export let data;

  // Field names follow befordringssystemet's view_Stamdata / view_ParentData.
  $: elev = data.stamdata;
  $: foraeldre = data.parents as any[];
  $: sager = data.skolebegynderSager as SkolebegynderRow[];

  $: aabne = sager.filter((s) => s.status_tekst !== "Afsluttet");
  $: afsluttede = sager.filter((s) => s.status_tekst === "Afsluttet");

  // A protected child's or parent's address is not shown — the protection is
  // the reason it is registered. The name stays: caseworkers need to know
  // whose case it is.
  const adresse = (beskyttet: boolean | null, tekst: string | null) =>
    beskyttet ? "Beskyttet" : (tekst ?? "—");
</script>


<section class="w-full max-w-6xl px-6 md:px-10 py-8">

  <div class="flex items-center gap-3 mb-8 flex-wrap">
    <h1 class="text-[26px] font-bold" style="color: #271347;">Elevmappe</h1>
    <span class="text-[15px] text-gray-400">·</span>
    <span class="text-[18px] font-semibold" style="color: #3b2168;">{elev.adresseringsnavn ?? "—"}</span>
    {#if elev.navne_adresse_beskyttelse}
      <span class="px-2 py-0.5 rounded text-xs font-semibold bg-red-100 text-red-700">Navne- og adressebeskyttet</span>
    {/if}
  </div>


  <h2 class="text-[13px] font-semibold uppercase tracking-wider text-gray-400 mb-3">Stamoplysninger</h2>
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-5 mb-10">

    <div class="bg-white rounded-2xl overflow-hidden" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08); border-left: 5px solid #4e7c3a;">
      <div class="px-6 py-4 border-b border-gray-100">
        <h3 class="font-bold text-[15px]" style="color: #2f5325;">Elev</h3>
      </div>
      <dl class="px-6 py-5 grid grid-cols-[150px_1fr] gap-y-2.5 gap-x-4 text-[13px]">
        <dt class="text-gray-500">Navn</dt><dd class="font-semibold" style="color:#271347;">{elev.adresseringsnavn ?? "—"}</dd>
        <dt class="text-gray-500">CPR</dt><dd class="font-mono">{formatCpr(elev.cpr)}</dd>
        <dt class="text-gray-500">Adresse</dt><dd>{adresse(elev.navne_adresse_beskyttelse, elev.folkeregister_adresse)}</dd>
        <dt class="text-gray-500">Køn</dt><dd>{elev.koen ?? "—"}</dd>
        <dt class="text-gray-500">Modersmål</dt><dd>{elev.modersmaal ?? "—"}</dd>
        <dt class="text-gray-500">Distriktsskole</dt><dd>{elev.distriktsskole ?? "—"}</dd>
        <dt class="text-gray-500">Aktuel skole</dt><dd>{elev.skole_navn ?? "—"}</dd>
        <dt class="text-gray-500">Klassetrin</dt><dd>{elev.elevklassetrin ?? "—"}</dd>
        <dt class="text-gray-500">Sprogstøttebehov</dt><dd>{jaNej(elev.sprogstoettebehov)}</dd>
        <dt class="text-gray-500">PPR</dt><dd>{jaNej(elev.ppr_status)}</dd>
        <dt class="text-gray-500">Tilflyttet DK</dt><dd>{elev.tilflyttet_dk_dato ? dato(elev.tilflyttet_dk_dato) : "—"}</dd>
      </dl>
    </div>

    <div class="bg-white rounded-2xl overflow-hidden" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08); border-left: 5px solid #8a2b2b;">
      <div class="px-6 py-4 border-b border-gray-100">
        <h3 class="font-bold text-[15px]" style="color: #7a2626;">Forældremyndighed</h3>
      </div>
      {#if foraeldre.length === 0}
        <p class="px-6 py-5 text-[13px] text-gray-500">Ingen forældremyndighedsindehavere registreret.</p>
      {:else}
        <ul class="px-6 py-5 space-y-4 text-[13px]">
          {#each foraeldre as f, i}
            <li>
              <p class="text-gray-500 text-xs mb-0.5">Forældremyndighed {i + 1}{f.relation ? ` · ${f.relation}` : ""}</p>
              <p class="font-semibold" style="color:#271347;">{f.adresseringsnavn ?? "—"}</p>
              <p class="font-mono text-gray-500">{formatCpr(f.cpr_foraelder)}</p>
              <p class="text-gray-600">{adresse(f.navne_adresse_beskyttelse, f.adresse_tekst)}</p>
              {#if f.maa_vide_barns_adresse === false}
                <p class="mt-1 inline-block px-2 py-0.5 rounded text-[11px] font-semibold bg-red-100 text-red-700">Må ikke kende barnets adresse</p>
              {/if}
            </li>
          {/each}
        </ul>
      {/if}
    </div>

  </div>


  <h2 class="text-[13px] font-semibold uppercase tracking-wider text-gray-400 mb-3">Sager</h2>

  <div class="rounded-2xl overflow-hidden mb-5" style="background:#e8f2f7; border-left:5px solid #2c7d90;">
    <div class="px-6 py-4">
      <h3 class="font-bold text-[15px]" style="color:#1f5d6e;">Igangværende sager</h3>
    </div>
    <div class="px-4 pb-4 space-y-2">
      {#each aabne as s (s.skolebegynder_id)}
        <a href="/skolebegynder/{s.skolebegynder_id}" class="bg-white rounded-xl px-5 py-3.5 flex items-center gap-4 hover:shadow-sm">
          <span class="font-semibold text-[14px]" style="color:#271347;">Skolebegynder {skoleaarTekst(s.skoleaar)}</span>
          <span class="inline-block px-2.5 py-1 rounded-full text-xs font-semibold {getStatusBadgeClass(s.status_tekst)}">{s.status_tekst}</span>
          <span class="ml-auto text-[12px] text-gray-500">{s.skoletilbud_matrikel ? `Skoletilbud: ${s.skoletilbud_matrikel}` : "Intet skoletilbud endnu"}</span>
        </a>
      {:else}
        <p class="px-1 text-[13px] text-gray-500">Ingen igangværende sager.</p>
      {/each}
    </div>
  </div>

  <div class="rounded-2xl overflow-hidden" style="background:#fbf3dc; border-left:5px solid #bd9b16;">
    <div class="px-6 py-4">
      <h3 class="font-bold text-[15px]" style="color:#8a7210;">Tidligere afgørelser</h3>
    </div>
    <div class="px-4 pb-4 space-y-2">
      {#each afsluttede as s (s.skolebegynder_id)}
        <a href="/skolebegynder/{s.skolebegynder_id}" class="bg-white/80 rounded-xl px-5 py-3.5 flex items-center gap-4 hover:shadow-sm">
          <span class="font-semibold text-[14px]" style="color:#271347;">Skolebegynder {skoleaarTekst(s.skoleaar)}</span>
          <span class="text-[13px]">{s.skoletilbudstype_tekst ?? "—"}</span>
          <span class="text-[13px] text-gray-600">{s.skoletilbud_matrikel ?? ""}</span>
          <span class="ml-auto text-[12px] text-gray-500">Afsluttet {dato(s.afsluttet_dato)}</span>
        </a>
      {:else}
        <p class="px-1 text-[13px] text-gray-500">Ingen tidligere afgørelser.</p>
      {/each}
    </div>
  </div>

</section>
