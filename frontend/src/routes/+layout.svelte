<script lang="ts">
  import "../app.css";
  import { page } from "$app/stores";
  import favicon from "$lib/assets/favicon.svg";
  import TopNav from "$lib/components/TopNav.svelte";
  import { sidetitel } from "$lib/sidetitel";

  let { children } = $props();
</script>

<!-- The top bar is on every page, the front page included: it carries the
     global student search, which must be reachable from anywhere. -->
<div class="flex flex-col min-h-screen">
  <TopNav />
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
  <!-- DSA: the tab icon — the top bar's speech bubbles (befordringssystemet:
       speedometer.png). Without one the browser showed its own default. -->
  <link rel="icon" href={favicon} type="image/svg+xml" />
</svelte:head>
