<script lang="ts">
  /**
   * One field on a case card: a small uppercase label over its value (or its
   * input, while the card is being edited) — the markup befordringssystemet's
   * bevilling card and Elevoplysninger use for every field.
   *
   * `bred` lets a field span the whole row (notes, reasons).
   */
  export let label: string;
  export let bred = false;
</script>

<div class={bred ? "col-span-full" : ""}>
  <p class="text-[10px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">{label}</p>
  <div class="text-sm text-gray-800 break-words"><slot /></div>
</div>
