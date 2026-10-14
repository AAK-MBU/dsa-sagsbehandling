<script lang="ts">
  import { goto } from "$app/navigation";

  export type DataTableColumn = {
    key: string;
    label: string;
    filterable?: boolean;
    render?: (row: any) => string;
    class?: string;
  };

  export let pageSize = 15;
  export let data: any[] = [];
  export let columns: DataTableColumn[] = [];

  export let filterable = true;
  export let emptyMessage = "Ingen data fundet";

  export let rowStyle: ((row: any) => string) | null = null;
  // When provided and it returns a URL, the row becomes clickable (→ navigate).
  export let rowHref: ((row: any) => string | null) | null = null;

  function handleRowClick(row: any) {
    const href = rowHref?.(row);
    if (href) goto(href);
  }


  let filters: Record<string, string> = {};
  let currentPage = 1;


  $: filteredData = data.filter((row) => {
    if (!filterable) {
      return true;
    }

    return columns.every((column) => {
      if (column.filterable === false) {
        return true;
      }

      const rowValue = String(row[column.key] ?? "").toLowerCase();
      const filterValue = String(filters[column.key] ?? "").toLowerCase();

      return rowValue.includes(filterValue);
    });
  });

  $: totalPages = Math.max(1, Math.ceil(filteredData.length / pageSize));

  $: paginatedData = filteredData.slice(
    (currentPage - 1) * pageSize,
    currentPage * pageSize
  );

  $: if (currentPage > totalPages) currentPage = 1;
</script>


<div class="w-full overflow-x-auto">

  <table class="w-full text-sm border-collapse" style="color: #3d3654;">

    <thead>

      <tr style="background:#271347;">
        {#each columns as column}
          <th class={`px-4 py-3 font-semibold whitespace-normal text-white text-[13px] ${column.class ?? "min-w-36 text-left"}`}>
            {column.label}
          </th>
        {/each}
      </tr>

      {#if filterable}
        <tr class="bg-gray-50 border-b border-gray-200">
          {#each columns as column}
            <td class="px-3 py-2">
              {#if column.filterable !== false}
                <input
                  type="text"
                  placeholder="Søg…"
                  class="w-full border border-gray-300 rounded-md px-3 py-1.5 text-xs bg-white focus:border-dsa-400 focus:outline-none focus:ring-2 focus:ring-dsa-100 transition-all"
                  bind:value={filters[column.key]}
                />
              {/if}
            </td>
          {/each}
        </tr>
      {/if}

    </thead>


    <tbody>

      {#if filteredData.length === 0}

        <tr>
          <td colspan={columns.length} class="px-4 py-10 text-center text-gray-400">
            {emptyMessage}
          </td>
        </tr>

      {:else}

        {#each paginatedData as row}

          {@const href = rowHref ? rowHref(row) : null}
          <tr
            class="border-b border-gray-100 last:border-0 hover:bg-gray-50 transition-colors {href ? 'cursor-pointer' : ''}"
            style={rowStyle ? rowStyle(row) : ""}
            role={href ? "link" : undefined}
            tabindex={href ? 0 : undefined}
            on:click={() => handleRowClick(row)}
            on:keydown={(e) => {
              if (href && (e.key === "Enter" || e.key === " ")) {
                e.preventDefault();
                handleRowClick(row);
              }
            }}
          >
            {#each columns as column}
              <td class={`px-4 py-3.5 whitespace-nowrap ${column.class ?? ""}`}>
                {#if column.render}
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

  {#if totalPages > 1}
    <div class="flex items-center justify-between px-4 py-2.5 text-xs text-gray-500 border-t border-dsa-100">
      <span>Side {currentPage} af {totalPages}</span>

      <div class="flex gap-1.5">
        <button
          type="button"
          class="px-3 py-1.5 rounded-full text-dsa-700 font-medium hover:bg-dsa-100 disabled:opacity-40 disabled:hover:bg-transparent transition-colors"
          on:click={() => currentPage--}
          disabled={currentPage === 1}
        >
          ← Forrige
        </button>

        <button
          type="button"
          class="px-3 py-1.5 rounded-full text-dsa-700 font-medium hover:bg-dsa-100 disabled:opacity-40 disabled:hover:bg-transparent transition-colors"
          on:click={() => currentPage++}
          disabled={currentPage === totalPages}
        >
          Næste →
        </button>
      </div>
    </div>
  {/if}

</div>
