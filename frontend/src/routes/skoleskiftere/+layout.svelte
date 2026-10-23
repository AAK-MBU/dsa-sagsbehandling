<script lang="ts">
  // No sidebar: the area is chosen in the top bar (TopNav), and anything an
  // area needs beyond its overview — reports, say — goes there too. This
  // layout only gives the area's pages their margins, full width.
  let { children } = $props();
</script>

<main class="flex-1 min-w-0 px-6 md:px-10 py-8">
  {@render children()}
</main>
