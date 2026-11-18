<script lang="ts">
  import { erAabenPeriode } from "$lib/elevsag";
  import { dato } from "$lib/skolebegynder";

  /**
   * Skolehistorik — the child's schools, classes and district over time, from
   * Elev_Skolehistorik (filled by LIS, and from applications). Newest first;
   * the open period is the child's current school, the one the student card
   * above shows.
   */
  export let data;

  $: raekker = data.skolehistorik;

  const skole = (navn: string | null, kode: number | null) => navn ?? (kode ? String(kode) : "—");
  const klasse = (r: any) => [r.elevklassetrin ? `${r.elevklassetrin} klasse` : null, r.klassebetegnelse].filter(Boolean).join(" · ") || "—";
</script>


<div class="rounded-2xl overflow-hidden kort" style="border-left: 5px solid #2c7d90;">
  <div class="px-6 py-4 border-b border-gray-100">
    <h2 class="font-bold text-[15px]" style="color: #1f5d6e;">Skolehistorik</h2>
  </div>

  {#if !data.hentet}
    <p class="px-6 py-5 text-[13px] text-red-700">Skolehistorikken kunne ikke hentes.</p>
  {:else if raekker.length === 0}
    <p class="px-6 py-5 text-[13px] text-gray-500">Ingen skolehistorik registreret.</p>
  {:else}
    <div class="overflow-x-auto">
      <table class="historik w-full border-collapse text-[13px]">
        <thead>
          <tr class="text-left text-gray-500 bg-gray-50">
            <th class="font-medium">Periode</th>
            <th class="font-medium">Skole</th>
            <th class="font-medium">Klasse</th>
            <th class="font-medium">Distriktsskole</th>
            <th class="font-medium">Kilde</th>
          </tr>
        </thead>
        <tbody>
          {#each raekker as r (r.skolehistorik_id)}
            <tr>
              <td class="whitespace-nowrap">
                {dato(r.gyldig_fra)} – {erAabenPeriode(r.gyldig_til) ? "" : dato(r.gyldig_til)}
                {#if erAabenPeriode(r.gyldig_til)}
                  <span class="ml-1 px-1.5 py-0.5 rounded text-[11px] font-semibold bg-dsa-100 text-dsa-800">Nuværende</span>
                {/if}
              </td>
              <td>{skole(r.skole_navn, r.skolekode)}</td>
              <td>{klasse(r)}</td>
              <td>{skole(r.distriktsskole, r.distriktsskolekode)}</td>
              <td class="text-gray-500">{r.kilde ?? "—"}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>


<style>
  .historik :global(th),
  .historik :global(td) {
    padding: 0.55rem 0.9rem;
  }
</style>
