<script lang="ts">
  import "../app.css";
  import { page } from "$app/stores";
  import TopNav from "$lib/components/TopNav.svelte";
  import { sidetitel } from "$lib/sidetitel";

  let { children } = $props();

  // The front page is itself the område-launcher, so the top nav is only
  // shown once you're inside an area.
  const showTopNav = $derived($page.url.pathname !== "/");
</script>

<div class="flex flex-col min-h-screen">
  {#if showTopNav}
    <TopNav />
  {/if}
  <div class="flex-1 flex flex-col min-h-0">
    {@render children()}
  </div>
</div>

<!-- One title for every route, from $lib/sidetitel — as in befordringssystemet,
     where per-page titles "stuck" on routes that set none. Case pages are
     named after the child: data.stamdata on the student page (/elev/[cpr]),
     data.sag where only a case is loaded. -->
<svelte:head>
  <title>{sidetitel($page.route.id, {
    navn: $page.data.stamdata?.adresseringsnavn ?? $page.data.sag?.navn,
    cpr: $page.data.sag?.cpr ?? $page.params.cpr,
  })}</title>
</svelte:head>
