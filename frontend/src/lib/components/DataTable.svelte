<script module lang="ts">
  // -----------------------------
  // Types
  // -----------------------------

  // DSA: in a module script. Exported from the instance script, as in
  // befordringssystemet, it is a compile error that svelte-check reports
  // (vite build lets it through).
  export type DataTableColumn = {
    key: string;
    label: string;
    filterable?: boolean;
    filterType?: "text" | "select";
    multiSelect?: boolean;
    sortable?: boolean;
    editable?: boolean;
    render?: (row: any) => string;
    class?: string;
    selectOptions?: { value: string | number; label: string }[];
    inputType?: string;
    /**
     * For a column that holds several values per row (kørselstyper, say).
     * Returns the row's values as a list, so the filter dropdown offers each
     * one on its own rather than one compound option per combination, and a
     * row matches when *any* of its values is selected.
     */
    filterValues?: (row: any) => string[];
  };
</script>

<script lang="ts">
  import { onMount } from "svelte";

  import {
    tablePrimaryActionButtonClass,
    tableSaveActionButtonClass,
    tableCancelActionButtonClass
  } from "$lib/tableColumnConfig";

  // -----------------------------
  // Props
  // -----------------------------

  export let pageSize = 100;
  export let data: any[] = [];
  export let columns: DataTableColumn[] = [];

  export let filterable = true;

  /** Hide the pagination bar entirely. For short, fixed-length lists. */
  export let paginated = true;
  export let emptyMessage = "Ingen data fundet";

  export let editable = false;
  export let editingRowId: string | number | null = null;
  export let editableRow: any = null;

  export let getRowId: (row: any, index: number) => string | number = (_row, index) => index;

  export let onEdit: (row: any) => void = () => {};
  export let onSave: (row: any) => void = () => {};
  export let onCancel: () => void = () => {};
  export let onInputChange: (key: string, value: any) => void = () => {};

  export let rowStyle: ((row: any) => string) | null = null;

  // DSA: always-editable mode, instead of a Redigér button per row. The
  // editable columns are inputs on every row; each change is reported
  // through onCellChange and held by the caller (`drafts`, keyed by
  // getRowId, then column key) until the caller saves it, and a changed cell
  // is highlighted. isRowEditable keeps a row read-only (a closed case);
  // getEditValue maps a stored value to what the input shows (a boolean as
  // 1/0 for a Ja/Nej select). Leave `editable` off when this is on.
  export let alwaysEditable = false;
  export let drafts: Record<string | number, Record<string, any>> = {};
  export let isRowEditable: (row: any) => boolean = () => true;
  export let getEditValue: (row: any, key: string) => any = (row, key) => row[key];
  export let onCellChange: (row: any, key: string, value: any) => void = () => {};

  // DSA: compact density below Tailwind's 2xl breakpoint (1536px): tighter
  // cell padding, 13px text and narrower edit fields, so a 13" laptop
  // (1280px wide at 150% scaling) fits the grid that a large screen shows
  // unchanged. Off by default — befordringssystemet's spacing.
  export let compact = false;

  // DSA: keep the first column (and the selection checkbox before it) in view
  // while the grid scrolls sideways — the safety net for when the chosen
  // columns are wider than the screen.
  export let stickyFirstColumn = false;

  // Full class strings, so Tailwind sees them.
  $: tekstKlasse = compact ? "text-[13px] 2xl:text-sm" : "text-sm";
  $: thPad = compact ? "px-2.5 py-2.5 2xl:px-4 2xl:py-3" : "px-4 py-3";
  $: tdPad = compact ? "px-2.5 py-2 2xl:px-4 2xl:py-3" : "px-4 py-3";
  $: editPad = compact ? "px-1.5 py-1.5 2xl:px-2" : "px-2 py-1.5";
  $: filterPad = compact ? "px-2 py-2 2xl:px-3" : "px-3 py-2";
  $: selectBredde = compact ? "w-28 2xl:w-36" : "w-36";
  $: inputBredde = compact ? "w-24 2xl:w-32" : "w-32";

  // The sticky first column starts where the (fixed-width) checkbox column ends.
  $: stickyVenstre = selectable ? "left: 2.25rem;" : "left: 0;";
  const stickyKant = "shadow-[inset_-1px_0_0_#d1d5db]";
  // With collapsed borders a sticky cell's background stops at the middle of
  // its border, so scrolled content shows through the 1px line. A strip in
  // the cell's own background (bg-inherit: row colour, hover, header) covers
  // it on the outer side(s).
  const daekV = "before:content-[''] before:absolute before:inset-y-0 before:-left-px before:w-px before:bg-inherit";
  const daekH = "after:content-[''] after:absolute after:inset-y-0 after:-right-px after:w-px after:bg-inherit";

  // DSA: row selection, for mass updates. Keyed by getRowId, so give the
  // table a real id (the index default would select different rows as the
  // filter changes). The header checkbox selects every FILTERED row, not
  // just the visible page: "filter on school + result, select all, update"
  // is the workflow the skolebegynder sketch asks for.
  export let selectable = false;
  export let selectedIds: (string | number)[] = [];

  $: selectedSet = new Set(selectedIds);
  $: filteredIds = filteredData.map((row, index) => getRowId(row, index));
  $: allFilteredSelected =
    filteredIds.length > 0 && filteredIds.every((id) => selectedSet.has(id));
  $: someFilteredSelected = filteredIds.some((id) => selectedSet.has(id));

  function toggleRow(id: string | number) {
    selectedIds = selectedSet.has(id)
      ? selectedIds.filter((x) => x !== id)
      : [...selectedIds, id];
  }

  function toggleAllFiltered() {
    if (allFilteredSelected) {
      const fjern = new Set(filteredIds);
      selectedIds = selectedIds.filter((id) => !fjern.has(id));
    } else {
      selectedIds = [...new Set([...selectedIds, ...filteredIds])];
    }
  }

  // Read-only output, meant for bind:. The filtering happens in here, so a
  // caller that puts a heading or a count above the table has no other way to
  // know what is actually on screen — which is how "Alle bevillinger" came to
  // keep saying "alle" over a filtered list.
  export let filteredCount = 0;
  export let filtersActive = false;


  // -----------------------------
  // Table state
  // -----------------------------

  let filters: Record<string, string | string[]> = {};
  let currentPage = 1;

  // Multi-select filter dropdown. The menu is portalled to <body> and
  // fixed-positioned (see `portal` / `positionMenu`) so it can extend beyond
  // the table's horizontal scroll box instead of being clipped inside it.
  let openDropdown: string | null = null;
  let triggerEl: HTMLElement | null = null;
  let menuEl: HTMLElement | null = null;
  let menuStyle = "";

  $: hasActiveFilters = Object.values(filters).some((v) =>
    Array.isArray(v) ? v.length > 0 : v !== ""
  );

  function positionMenu() {
    if (!triggerEl) return;
    const r = triggerEl.getBoundingClientRect();
    menuStyle =
      `position: fixed; top: ${Math.round(r.bottom + 4)}px; ` +
      `left: ${Math.round(r.left)}px; min-width: ${Math.round(r.width)}px;`;
  }

  function toggleDropdown(key: string, event: MouseEvent) {
    if (openDropdown === key) {
      openDropdown = null;
      triggerEl = null;
      return;
    }
    openDropdown = key;
    triggerEl = event.currentTarget as HTMLElement;
    positionMenu();
  }

  // Move a node to <body> so it escapes the table's overflow/stacking context.
  function portal(node: HTMLElement) {
    document.body.appendChild(node);
    return { destroy() { node.remove(); } };
  }

  onMount(() => {
    const reposition = () => { if (openDropdown) positionMenu(); };

    const onDocClick = (e: MouseEvent) => {
      if (!openDropdown) return;
      const target = e.target as Node;
      // Ignore clicks on the trigger (it toggles itself) or inside the menu
      // (selecting checkboxes should not close it).
      if (triggerEl?.contains(target) || menuEl?.contains(target)) return;
      openDropdown = null;
      triggerEl = null;
    };

    window.addEventListener("resize", reposition);
    // capture=true so scrolling the table's own overflow box also repositions.
    document.addEventListener("scroll", reposition, true);
    // capture=true so this runs before the trigger's own click handler.
    document.addEventListener("click", onDocClick, true);

    return () => {
      window.removeEventListener("resize", reposition);
      document.removeEventListener("scroll", reposition, true);
      document.removeEventListener("click", onDocClick, true);
    };
  });

  function getUniqueOptions(column: DataTableColumn): string[] {
    const values = column.filterValues
      ? data.flatMap((row) => column.filterValues!(row))
      : data.map((row) => row[column.key]);

    return Array.from(
      new Set(values.map((value) => String(value ?? "").trim()).filter(Boolean))
    ).sort((a, b) => a.localeCompare(b, "da"));
  }

  function clearFilters() {
    filters = {};
    currentPage = 1;
  }


  // -----------------------------
  // Derived data
  // -----------------------------

  $: filteredData = data.filter((row) => {
    if (!filterable) {
      return true;
    }

    return columns.every((column) => {
      if (column.filterable === false) {
        return true;
      }

      const filterValue = filters[column.key];

      if (
        filterValue === undefined ||
        filterValue === "" ||
        (Array.isArray(filterValue) && filterValue.length === 0)
      ) {
        return true;
      }

      if (column.filterValues) {
        const rowValues = column
          .filterValues(row)
          .map((value) => String(value ?? "").trim().toLowerCase())
          .filter(Boolean);

        // A row matches on any one of its values, so filtering on
        // "Solokørsel" also returns students who have both Solokørsel and
        // Skolerejsekort.
        if (Array.isArray(filterValue)) {
          return filterValue.some((v) => rowValues.includes(v.toLowerCase()));
        }

        return rowValues.some((value) => value.includes(filterValue.toLowerCase()));
      }

      const rowValue = String(row[column.key] ?? "").toLowerCase();

      if (Array.isArray(filterValue)) {
        return filterValue.some((v) => rowValue === v.toLowerCase());
      }

      return rowValue.includes(filterValue.toLowerCase());
    });
  });

  $: filteredCount = filteredData.length;
  $: filtersActive = filterable && hasActiveFilters;

  $: totalPages = Math.max(1, Math.ceil(filteredData.length / pageSize));

  $: paginatedData = filteredData.slice(
    (currentPage - 1) * pageSize,
    currentPage * pageSize
  );

  // Reset to page 1 when filters/data shrink the result set below the current page.
  $: if (currentPage > totalPages) currentPage = 1;
</script>


<div class="w-full overflow-x-auto">

  {#if filterable && hasActiveFilters}
    <div class="flex items-center justify-between px-3 py-1.5 mb-2 rounded-md bg-sky-50 border border-sky-100 text-xs text-sky-700">
      <span>Aktive filtre</span>
      <button type="button" on:click={clearFilters} class="font-medium hover:underline">
        Ryd filtre
      </button>
    </div>
  {/if}

  <table class={`w-full ${tekstKlasse} text-gray-700 border-collapse`}>

    <thead>

      <!-- Column headers -->
      <!-- DSA: header colour from the DSA palette (befordringssystemet: #032A42). -->
      <tr class="text-white" style="background-color: #271347;">

        {#if selectable}
          <!-- DSA: select / deselect every filtered row -->
          <th class={stickyFirstColumn ? `px-0 w-9 min-w-9 text-center sticky left-0 z-20 ${daekV} ${daekH}` : "px-3 py-3 w-8 text-left"} style="background-color: #271347;">
            <input
              type="checkbox"
              aria-label="Vælg alle filtrerede rækker"
              checked={allFilteredSelected}
              indeterminate={someFilteredSelected && !allFilteredSelected}
              on:change={toggleAllFiltered}
            />
          </th>
        {/if}

        {#if editable}
          <th class="px-4 py-3 font-semibold whitespace-nowrap text-left sticky left-0 z-10" style="background-color: #271347;"></th>
        {/if}

        {#each columns as column, ci}
          {@const fast = stickyFirstColumn && ci === 0}
          <th
            class={`${thPad} font-semibold whitespace-normal min-w-24 text-left ${fast ? `sticky z-20 ${stickyKant} ${daekV}` : ""} ${column.class ?? ""}`}
            style={fast ? `${stickyVenstre} background-color: #271347;` : ""}
          >
            {column.label}
          </th>
        {/each}

      </tr>


      <!-- Optional filter row -->
      {#if filterable}
        <tr class="bg-gray-100 border-b border-gray-300">

          {#if selectable}
            <td class={stickyFirstColumn ? `px-0 w-9 min-w-9 sticky left-0 z-10 bg-gray-100 ${daekV} ${daekH}` : "px-3 py-2"}></td>
          {/if}

          {#if editable}
            <td class="px-3 py-2 sticky left-0 z-10 bg-gray-100"></td>
          {/if}

          {#each columns as column, ci}
            {@const fast = stickyFirstColumn && ci === 0}
            <td class={`${filterPad} align-top ${fast ? `sticky z-10 bg-gray-100 ${stickyKant} ${daekV}` : ""}`} style={fast ? stickyVenstre : ""}>

              {#if column.filterable !== false}

                {#if column.filterType === "select" && column.multiSelect}

                  <div class="relative">
                    <button
                      type="button"
                      class="h-7 w-full flex items-center justify-between border border-gray-200 rounded bg-white px-2 text-xs text-left"
                      on:click={(e) => toggleDropdown(column.key, e)}
                    >
                      <span class="truncate text-slate-500">
                        {Array.isArray(filters[column.key]) && (filters[column.key] as string[]).length > 0
                          ? (filters[column.key] as string[]).join("; ")
                          : "Vælg..."}
                      </span>
                      <svg class="w-3 h-3 ml-1 flex-shrink-0 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                      </svg>
                    </button>

                    {#if openDropdown === column.key}
                      <!-- Portalled to <body> and fixed-positioned so the menu can
                           extend beyond the table's overflow-x-auto scroll box. -->
                      <div
                        bind:this={menuEl}
                        use:portal
                        style={menuStyle}
                        class="z-50 max-h-72 overflow-auto bg-white border border-gray-200 rounded shadow-lg"
                      >
                        {#each getUniqueOptions(column) as option}
                          {@const isSelected = Array.isArray(filters[column.key]) && (filters[column.key] as string[]).includes(option)}
                          <label class="flex items-center gap-2 px-3 py-2 text-xs hover:bg-gray-50 cursor-pointer whitespace-nowrap">
                            <input
                              type="checkbox"
                              checked={isSelected}
                              on:change={() => {
                                const current = Array.isArray(filters[column.key]) ? (filters[column.key] as string[]) : [];
                                filters = {
                                  ...filters,
                                  [column.key]: isSelected
                                    ? current.filter((v) => v !== option)
                                    : [...current, option]
                                };
                                currentPage = 1;
                              }}
                            />
                            {option}
                          </label>
                        {/each}
                      </div>
                    {/if}
                  </div>

                {:else if column.filterType === "select"}

                  <select
                    value={filters[column.key] ?? ""}
                    on:change={(e) => {
                      filters = { ...filters, [column.key]: (e.target as HTMLSelectElement).value };
                      currentPage = 1;
                    }}
                    class="h-7 w-full border border-gray-200 rounded px-2 text-xs focus:border-blue-400 focus:ring-0 bg-white"
                  >
                    <option value="">Alle</option>
                    {#each getUniqueOptions(column) as option}
                      <option value={option}>{option}</option>
                    {/each}
                  </select>

                {:else}

                  <input
                    type="text"
                    placeholder="Søg..."
                    class="h-7 w-full border border-gray-200 rounded px-2 text-xs focus:border-blue-400 focus:ring-0 transition-colors bg-white"
                    value={typeof filters[column.key] === "string" ? filters[column.key] : ""}
                    on:input={(e) => {
                      filters = { ...filters, [column.key]: (e.target as HTMLInputElement).value };
                      currentPage = 1;
                    }}
                  />

                {/if}

              {/if}

            </td>
          {/each}

        </tr>
      {/if}

    </thead>


    <tbody>

      {#if filteredData.length === 0}

        <tr>
          <td
            colspan={columns.length + (editable ? 1 : 0) + (selectable ? 1 : 0)}
            class="px-4 py-8 text-center text-gray-500 bg-gray-50"
          >
            {emptyMessage}
          </td>
        </tr>

      {:else}

        {#each paginatedData as row, index}

          {@const rowId = getRowId(row, index)}
          {@const isEditing = editingRowId === rowId}
          {@const rowBg = index % 2 === 0 ? 'bg-white' : 'bg-gray-50'}

          <tr class={`group border-b border-gray-200 hover:bg-blue-50 transition-colors ${rowBg}`} style={rowStyle ? rowStyle(row) : ""}>

            {#if selectable}
              <!-- DSA: row selection -->
              <td class={stickyFirstColumn ? `px-0 w-9 min-w-9 text-center sticky left-0 z-10 ${rowBg} group-hover:bg-blue-50 transition-colors ${daekV} ${daekH}` : "px-3 py-3"}>
                <input
                  type="checkbox"
                  aria-label="Vælg række"
                  checked={selectedSet.has(rowId)}
                  on:change={() => toggleRow(rowId)}
                />
              </td>
            {/if}

            {#if editable}
              <td class={`px-4 py-3 whitespace-nowrap sticky left-0 z-10 ${rowBg} group-hover:bg-blue-50 transition-colors`}>

                {#if isEditing}
                  <button
                    type="button"
                    class={tableSaveActionButtonClass}
                    on:click={() => onSave(row)}
                  >
                    Gem
                  </button>

                  <button
                    type="button"
                    class={tableCancelActionButtonClass}
                    on:click={onCancel}
                  >
                    Annullér
                  </button>
                {:else}
                  <button
                    type="button"
                    class={tablePrimaryActionButtonClass}
                    on:click={() => onEdit(row)}
                  >
                    Redigér
                  </button>
                {/if}

              </td>
            {/if}


            {#each columns as column, ci}

              {@const cellEditable = alwaysEditable && column.editable === true && isRowEditable(row)}
              {@const changed = cellEditable && drafts[rowId] !== undefined && column.key in drafts[rowId]}
              {@const fast = stickyFirstColumn && ci === 0}

              <td
                class={`whitespace-nowrap ${cellEditable ? editPad : tdPad} ${changed ? "bg-amber-100" : ""} ${fast ? `sticky z-10 ${rowBg} group-hover:bg-blue-50 transition-colors ${stickyKant} ${daekV}` : ""} ${column.class ?? ""}`}
                style={fast ? stickyVenstre : ""}
              >

                {#if cellEditable}

                  <!-- DSA: always-editable cell -->
                  {@const value = changed ? drafts[rowId][column.key] : getEditValue(row, column.key)}
                  {#if column.selectOptions}
                    <!-- Narrow so a grid of them still fits the screen; the
                         title shows a long value in full on hover. -->
                    <select
                      title={column.selectOptions.find((o) => o.value === value)?.label ?? ""}
                      class={`${selectBredde} border rounded px-1.5 py-1 text-[13px] focus:ring-0 ${changed ? "border-amber-500 bg-amber-50" : "border-gray-300 bg-white focus:border-dsa-500"}`}
                      aria-label={column.label}
                      value={value ?? ""}
                      on:change={(event) => {
                        const target = event.target as HTMLSelectElement;
                        onCellChange(row, column.key, target.value === "" ? null : Number(target.value));
                      }}
                    >
                      <option value="">—</option>
                      {#each column.selectOptions as opt}
                        <option value={opt.value}>{opt.label}</option>
                      {/each}
                    </select>
                  {:else}
                    <input
                      type={column.inputType ?? "text"}
                      class={`${inputBredde} border rounded px-1.5 py-1 text-[13px] focus:ring-0 ${changed ? "border-amber-500 bg-amber-50" : "border-gray-300 bg-white focus:border-dsa-500"}`}
                      title={value ?? ""}
                      aria-label={column.label}
                      value={value ?? ""}
                      on:input={(event) => {
                        const target = event.target as HTMLInputElement;
                        onCellChange(row, column.key, target.value);
                      }}
                    />
                  {/if}

                {:else if isEditing && column.editable === true}

                  {#if column.selectOptions}
                    <select
                      class="min-w-44 border-2 border-gray-300 rounded px-2 py-1 text-sm focus:border-blue-500 focus:ring-0 bg-white"
                      value={editableRow?.[column.key] ?? ""}
                      on:change={(event) => {
                        const target = event.target as HTMLSelectElement;
                        const val = target.value === "" ? null : Number(target.value);
                        onInputChange(column.key, val);
                      }}
                    >
                      <option value="">— Vælg —</option>
                      {#each column.selectOptions as opt}
                        <option value={opt.value}>{opt.label}</option>
                      {/each}
                    </select>
                  {:else}
                    <input
                      type={column.inputType ?? "text"}
                      class="min-w-44 w-full border-2 border-gray-300 rounded px-2 py-1 text-sm focus:border-blue-500 focus:ring-0"
                      value={editableRow?.[column.key] ?? ""}
                      on:input={(event) => {
                        const target = event.target as HTMLInputElement;
                        onInputChange(column.key, target.value || null);
                      }}
                    />
                  {/if}

                {:else if column.render}

                  {@html column.render(row)}

                {:else}

                  {row[column.key] ?? ""}

                {/if}

              </td>

            {/each}

          </tr>

        {/each}

      {/if}

    </tbody>

  </table>

  {#if paginated}
  <div class="flex items-center justify-between px-3 py-2 text-xs text-gray-600 bg-gray-50 border-t border-gray-200">

    <div class="flex items-center gap-2">
      <span>Rækker pr. side:</span>
      <select
        bind:value={pageSize}
        class="h-8 border border-gray-200 rounded pl-2 pr-6 text-xs bg-white focus:border-blue-400 focus:ring-0"
      >
        <option value={10}>10</option>
        <option value={25}>25</option>
        <option value={50}>50</option>
        <option value={100}>100</option>
      </select>
    </div>

    <div class="flex items-center gap-3">
      <span>Side {currentPage} af {totalPages}</span>
      <div class="flex gap-2">
        <button
          type="button"
          class="px-2 py-1 border border-gray-300 rounded disabled:opacity-50"
          on:click={() => currentPage--}
          disabled={currentPage === 1}
        >
          Forrige
        </button>
        <button
          type="button"
          class="px-2 py-1 border border-gray-300 rounded disabled:opacity-50"
          on:click={() => currentPage++}
          disabled={currentPage === totalPages}
        >
          Næste
        </button>
      </div>
    </div>

  </div>
  {/if}

</div>

<style>
  /* Tættere celler end den globale td/th-regel i app.css.
   *
   * Den regel sætter padding: 0.75rem på hver side af hver celle, og fordi
   * den er ulaget, slår den Tailwinds px-/py-klasser i komponenten. På en
   * liste med 11 kolonner er det 24px gange 11 brugt på luft alene, og det er
   * en del af grunden til, at Nye ansøgninger ikke kan være på skærmen.
   *
   * Scoped til denne komponent, så Flowbites egne tabeller og alt andet, der
   * bygger på den globale regel, er urørt.
   */
  table :global(th),
  table :global(td) {
    padding: 0.5rem 0.625rem;
  }
</style>
