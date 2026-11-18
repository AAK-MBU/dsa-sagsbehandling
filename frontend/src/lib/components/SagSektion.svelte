<script lang="ts">
  /**
   * One step of a case card (skolebegynder and skoleskifter alike): a
   * numbered title, then whatever the step holds — normally a grid of Felt
   * (class "sag-felter") and a "what to do now" line (class "sag-naeste").
   *
   * Where the step stands is read from the case's current step:
   *   done     (trin < aktueltTrin)  grey tint, muted text, ✓ and "Udført"
   *   current  (trin = aktueltTrin)  a lavender edge
   *   ahead                          white
   * A section that is not a step of the flow (trin null) is always white.
   */
  export let nr: number | string;
  export let titel: string;
  export let trin: number | null = null;
  export let aktueltTrin = 0;

  $: faerdig = trin !== null && trin < aktueltTrin;
  $: aktuel = trin !== null && trin === aktueltTrin;
</script>

<section class="sag-sektion" class:aktuel class:faerdig>
  <h3 class="sag-titel">
    <span class="sag-nr">{faerdig ? "✓" : nr}</span>
    {titel}
    {#if faerdig}<span class="sag-udfoert">Udført</span>{/if}
  </h3>
  <slot />
</section>

<style>
  /* Steps are divided by a clear rule, so each reads as its own stage. */
  .sag-sektion {
    border-top: 1px solid #e5e7eb;
    padding-top: 1.1rem;
  }
  /* The step being worked on now: a lavender edge, as a quiet pointer. */
  .sag-sektion.aktuel {
    box-shadow: inset 4px 0 0 #6a3fb5;
    background-color: #fbfaff;
  }
  /* A step already done: a grey tint and muted text, so the eye goes past it
     to the step being worked on. Still fully readable — and editable. */
  .sag-sektion.faerdig {
    background-color: #f5f5f6;
  }
  .sag-sektion.faerdig :global(.text-gray-800) {
    color: #4b5563;
  }
  .sag-titel {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0 1.5rem;
    margin-bottom: 0.9rem;
    font-size: 0.8rem;
    font-weight: 700;
    color: #3b2168;
  }
  .faerdig .sag-titel {
    color: #6b7280;
  }
  .sag-nr {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 1.25rem;
    height: 1.25rem;
    border-radius: 9999px;
    background-color: #ece8f7;
    color: #4a2b80;
    font-size: 0.7rem;
  }
  .faerdig .sag-nr {
    background-color: #d1d5db;
    color: #374151;
  }
  .sag-udfoert {
    margin-left: auto;
    font-size: 0.7rem;
    font-weight: 600;
    color: #6b7280;
  }

  /* The step's contents come from the card (slot), so these are global. */
  /* The fields: the bevilling card's grid, four across on wide screens. */
  .sag-sektion :global(.sag-felter) {
    display: grid;
    grid-template-columns: repeat(1, minmax(0, 1fr));
    gap: 1.1rem 1.5rem;
    padding: 0 1.5rem 1.1rem;
  }
  @media (min-width: 640px) {
    .sag-sektion :global(.sag-felter) { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  }
  @media (min-width: 1024px) {
    .sag-sektion :global(.sag-felter) { grid-template-columns: repeat(4, minmax(0, 1fr)); }
  }
  /* What to do next, under the step it concerns. */
  .sag-sektion :global(.sag-naeste) {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: 0.75rem;
    margin: 0 1.5rem 1.1rem;
    padding: 0.6rem 0.9rem;
    border-radius: 0.375rem;
    background-color: #f6f4fb;
    color: #3b2168;
    font-size: 0.8125rem;
  }
</style>
