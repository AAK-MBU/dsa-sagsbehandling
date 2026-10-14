<script lang="ts">
  import "../app.css";
  import { page } from "$app/stores";
  import TopNav from "$lib/components/TopNav.svelte";

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
