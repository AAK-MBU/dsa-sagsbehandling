<script lang="ts">
  import SkolebegynderSag from "$lib/components/SkolebegynderSag.svelte";
  import SkoleskifterSag from "$lib/components/SkoleskifterSag.svelte";

  /**
   * One case on the student page, whichever area it is from — what
   * hentSkolebegynderSag / hentSkoleskifterSag loaded, exactly one of them set.
   * Used by the "Aktiv sag" tab and by an afgørelse's page.
   */
  export let skolebegynder: any = null;
  export let skoleskifter: any = null;
  export let user: { can_edit?: boolean; name?: string | null } | null = null;

  $: kanRedigere = user?.can_edit === true;
</script>

{#if skolebegynder}
  <SkolebegynderSag
    sag={skolebegynder.sag}
    lookups={skolebegynder.lookups}
    sagsforloeb={skolebegynder.sagsforloeb}
    aendringer={skolebegynder.aendringer}
    fagomraadeId={skolebegynder.fagomraadeId}
    {kanRedigere}
    brugerNavn={user?.name ?? null}
  />
{:else if skoleskifter}
  <SkoleskifterSag
    sag={skoleskifter.sag}
    lookups={skoleskifter.lookups}
    sagsforloeb={skoleskifter.sagsforloeb}
    fagomraadeId={skoleskifter.fagomraadeId}
    screeninger={skoleskifter.screeninger ?? []}
    sprogstoette={skoleskifter.sprogstoette ?? []}
    sprogstoettebehovNu={skoleskifter.sprogstoettebehovNu ?? false}
    {kanRedigere}
  />
{/if}
