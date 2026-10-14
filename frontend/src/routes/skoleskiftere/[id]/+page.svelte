<script lang="ts">
  import { formatDanishDate, getStatusBadgeClass } from "$lib/tableColumnConfig";
  import type { Ansoegning } from "$lib/types";

  export let data;

  $: a = data.ansoegning as Ansoegning;
  $: barn = a.barn;
  $: f = a.foraeldre;

  // Syntetisk sags-id indtil rigtige sags-numre findes.
  $: sagsId = `MK-${String(a.id).padStart(4, "0")}`;
</script>


<svelte:head>
  <title>Elevmappe – {barn.fulde_navn}</title>
</svelte:head>


<section class="w-full">

  <!-- Header -->
  <a href="/skoleskiftere" class="inline-flex items-center gap-1.5 text-[13px] text-dsa-600 hover:text-dsa-800 mb-4">
    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" />
    </svg>
    Tilbage til overblik
  </a>

  <div class="flex items-center gap-3 mb-8">
    <h1 class="text-[26px] font-bold" style="color: #271347;">Elevmappe</h1>
    <span class="text-[15px] text-gray-400">·</span>
    <span class="text-[18px] font-semibold" style="color: #3b2168;">{barn.fulde_navn}</span>
  </div>


  <!-- Stamoplysninger -->
  <h2 class="text-[13px] font-semibold uppercase tracking-wider text-gray-400 mb-3">Stamoplysninger</h2>
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-5 mb-10">

    <!-- Elev -->
    <div class="bg-white rounded-2xl overflow-hidden" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08); border-left: 5px solid #4e7c3a;">
      <div class="px-6 py-4 border-b border-gray-100">
        <h3 class="font-bold text-[15px]" style="color: #2f5325;">Elev</h3>
      </div>
      <dl class="px-6 py-5 grid grid-cols-[140px_1fr] gap-y-3 gap-x-4 text-[13px]">
        <dt class="text-gray-500">Navn</dt>
        <dd class="font-semibold" style="color:#271347;">{barn.fulde_navn}</dd>

        <dt class="text-gray-500">CPR</dt>
        <dd class="font-mono">{barn.har_cpr ? barn.cpr : "Ikke tildelt"}</dd>

        <dt class="text-gray-500">Fødselsdato</dt>
        <dd>{formatDanishDate(barn.foedselsdato)}</dd>

        {#if barn.koen}
          <dt class="text-gray-500">Køn</dt>
          <dd>{barn.koen}</dd>
        {/if}

        <dt class="text-gray-500">Nationalitet</dt>
        <dd>{barn.nationalitet}</dd>

        <dt class="text-gray-500">Modersmål</dt>
        <dd>{barn.modersmaal ?? "—"}</dd>

        <dt class="text-gray-500">Adresse</dt>
        <dd>
          {#if barn.adresse}
            {barn.adresse}<br />{barn.postnummer} {barn.by}
          {:else}—{/if}
        </dd>

        <dt class="text-gray-500">Ankomst til DK</dt>
        <dd>{formatDanishDate(barn.ankomstdato_danmark)}</dd>

        <dt class="text-gray-500">Skoleår før ankomst</dt>
        <dd>{barn.skoleaar_foer_ankomst}</dd>

        <dt class="text-gray-500">Afgangseksamen</dt>
        <dd>{barn.afsluttet_afgangseksamen ? "Ja" : "Nej"}</dd>
      </dl>
    </div>

    <!-- Forældremyndighed -->
    <div class="bg-white rounded-2xl overflow-hidden" style="box-shadow: 0 1px 3px rgba(39,19,71,0.08); border-left: 5px solid #8a2b2b;">
      <div class="px-6 py-4 border-b border-gray-100">
        <h3 class="font-bold text-[15px]" style="color: #7a2626;">Forældremyndighed</h3>
      </div>
      <dl class="px-6 py-5 grid grid-cols-[140px_1fr] gap-y-3 gap-x-4 text-[13px]">
        <dt class="text-gray-500">Forældremyndighed 1</dt>
        <dd>
          <span class="font-semibold" style="color:#271347;">{f.foraelder_1_navn ?? "—"}</span>
          {#if f.foraelder_1_cpr}<br /><span class="font-mono text-gray-500">{f.foraelder_1_cpr}</span>{/if}
        </dd>

        <dt class="text-gray-500">Forældremyndighed 2</dt>
        <dd>
          {#if f.foraelder_2_navn}
            <span class="font-semibold" style="color:#271347;">{f.foraelder_2_navn}</span>
            {#if f.foraelder_2_cpr}<br /><span class="font-mono text-gray-500">{f.foraelder_2_cpr}</span>{/if}
          {:else}—{/if}
        </dd>

        <dt class="text-gray-500">Telefon</dt>
        <dd>{f.telefon ?? "—"}</dd>

        <dt class="text-gray-500">E-mail</dt>
        <dd>{f.email}</dd>

        {#if f.kontaktperson_navn}
          <dt class="text-gray-500">Kontaktperson</dt>
          <dd>
            {f.kontaktperson_navn}
            {#if f.kontaktperson_telefon}<br /><span class="text-gray-500">{f.kontaktperson_telefon}</span>{/if}
            {#if f.kontaktperson_sprog}<br /><span class="text-gray-500">Sprog: {f.kontaktperson_sprog}</span>{/if}
          </dd>
        {/if}
      </dl>
    </div>

  </div>


  <!-- Afgørelser -->
  <h2 class="text-[13px] font-semibold uppercase tracking-wider text-gray-400 mb-3">Afgørelser</h2>

  <!-- Igangværende sager -->
  <div class="rounded-2xl overflow-hidden mb-5" style="background:#e8f2f7; border-left:5px solid #2c7d90;">
    <div class="px-6 py-4">
      <h3 class="font-bold text-[15px]" style="color:#1f5d6e;">Igangværende sager <span class="font-normal opacity-70">(åbne sager)</span></h3>
    </div>
    <div class="px-4 pb-4 space-y-2">
      <div class="bg-white rounded-xl px-5 py-3.5 flex items-center gap-4">
        <span class="text-[11px] font-mono text-gray-400 shrink-0">{sagsId}</span>
        <span class="font-semibold text-[14px]" style="color:#271347;">Skoleskifte / tilflytning</span>
        <span class="inline-block px-2.5 py-1 rounded-full text-xs font-semibold {getStatusBadgeClass(a.status)}">{a.status}</span>
        <span class="ml-auto text-[12px] text-gray-500">Modtaget {formatDanishDate(a.modtagelsesdato)}</span>
      </div>
      <p class="px-1 pt-1 text-[12px] text-gray-500">Andre sagstyper kobles på her, efterhånden som de bygges.</p>
    </div>
  </div>

  <!-- Tidligere afgørelser -->
  <div class="rounded-2xl overflow-hidden" style="background:#fbf3dc; border-left:5px solid #bd9b16;">
    <div class="px-6 py-4">
      <h3 class="font-bold text-[15px]" style="color:#8a7210;">Tidligere afgørelser</h3>
    </div>
    <div class="px-4 pb-4">
      <div class="bg-white/70 rounded-xl px-5 py-4 text-[13px] text-gray-500">
        Ingen tidligere afgørelser registreret.
      </div>
    </div>
  </div>

</section>
