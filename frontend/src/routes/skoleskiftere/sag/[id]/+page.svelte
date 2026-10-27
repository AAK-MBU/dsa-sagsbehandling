<script lang="ts">
  import { goto } from "$app/navigation";

  import ReadOnlyNotice from "$lib/components/ReadOnlyNotice.svelte";
  import SkoleskifterSag from "$lib/components/SkoleskifterSag.svelte";
  import { backendFetch } from "$lib/client/backendFetch";
  import { fejltekst } from "$lib/skolebegynder";
  import type { SkoleskifterDetail } from "$lib/skoleskifter";

  // A case without CPR (draft): the case as on the student page, plus the
  // box that links it to the child. Once linked it opens on the child's page.
  export let data;

  $: sag = data.sag as SkoleskifterDetail;
  $: kanRedigere = data.user?.can_edit === true;

  let cpr = "";
  let fejl: string | null = null;
  let arbejder = false;

  async function tilknyt() {
    const ren = cpr.replace(/\D/g, "");
    if (ren.length !== 10) {
      fejl = "Et CPR-nummer har 10 cifre.";
      return;
    }
    arbejder = true;
    fejl = null;
    try {
      const res = await backendFetch(`/skoleskifter/${sag.skoleskifter_id}/cpr`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ cpr: ren })
      });
      if (!res.ok) {
        fejl = await fejltekst(res);
        return;
      }
      await goto(`/elev/${ren}/skoleskiftere?sag=${sag.skoleskifter_id}`);
    } finally {
      arbejder = false;
    }
  }
</script>


<section class="w-full">

  <ReadOnlyNotice />

  <div class="flex items-center gap-3 mb-4 flex-wrap">
    <h1 class="text-[24px] font-bold" style="color: #271347;">{sag.ansoeger_navn ?? "Ukendt ansøger"}</h1>
    <span class="px-2 py-0.5 rounded text-xs font-semibold bg-gray-200 text-gray-700">Uden CPR</span>
  </div>

  <!-- Link to the child -->
  <div class="mb-6 rounded-xl border border-amber-300 bg-amber-50 px-5 py-4 flex items-end gap-4 flex-wrap">
    <div class="text-[13px] text-amber-900 max-w-xl">
      <p class="font-semibold">Ansøgningen kom uden CPR-nummer.</p>
      <p>Tilknyt barnets CPR, så sagen flyttes til elevens side med stamdata, søskende og sagsforløb.</p>
    </div>
    {#if kanRedigere}
      <form class="flex items-end gap-2 ml-auto" on:submit|preventDefault={tilknyt}>
        <label class="flex flex-col gap-1 text-[13px] text-gray-600">
          CPR-nummer
          <input class="border border-gray-300 rounded px-2.5 py-1.5 bg-white font-mono w-40" placeholder="ddmmåå-xxxx" bind:value={cpr} disabled={arbejder} />
        </label>
        <button type="submit" class="px-4 py-2 rounded-full text-sm font-semibold text-white bg-dsa-600 hover:bg-dsa-700 disabled:opacity-40" disabled={arbejder || !cpr.trim()}>
          {arbejder ? "Tilknytter…" : "Tilknyt CPR"}
        </button>
      </form>
    {/if}
    {#if fejl}<p class="w-full text-sm text-red-700" role="alert">{fejl}</p>{/if}
  </div>

  <SkoleskifterSag
    {sag}
    lookups={data.lookups}
    sagsforloeb={data.sagsforloeb}
    soeskende={data.soeskende}
    {kanRedigere}
    fagomraadeId={data.fagomraadeId}
  />

</section>
