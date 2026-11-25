/**
 * Remembering a table's filters between visits (browser localStorage).
 *
 * One entry per table view, under a key the page chooses ("skolebegynder.overblik.2026"):
 * each tab and each school year keeps its own filters. Everything here is
 * defensive: storage can be missing or refuse (private windows, policies), and
 * what is stored can be stale or hand-edited, so a read never throws and never
 * returns a value the table could not have produced itself.
 */

export type FilterValue = string | string[];
export type FilterState = Record<string, FilterValue>;

/** The part of a table column the filters need. */
export type FilterColumn = {
  key: string;
  filterable?: boolean;
  filterType?: "text" | "select";
  multiSelect?: boolean;
};

// Bump the version when the stored shape changes; old entries are then ignored.
export const keyprefix = "dsa.filtre.v1.";

// Ten digits as a CPR number, with or without the dash. A search for a child's
// CPR number must not stay behind in the browser, so text like this is never
// stored (or restored).
const cprpattern = /\d{6}\s*-?\s*\d{4}/;

export function isactive(value: FilterValue | undefined): boolean {
  return Array.isArray(value) ? value.length > 0 : (value ?? "") !== "";
}

/** What is worth keeping: active filters only, and no text that looks like a CPR number. */
export function tostored(filters: FilterState): FilterState {
  const out: FilterState = {};

  for (const [key, value] of Object.entries(filters)) {
    if (!isactive(value)) continue;
    if (typeof value === "string" && cprpattern.test(value)) continue;
    out[key] = value;
  }

  return out;
}

/**
 * Turn whatever was stored into filters the table can use now.
 *
 * Only columns that can be filtered are kept. A choice from a list survives
 * only while the list still offers it: a school or status that is gone would
 * otherwise leave a filter nobody can see or remove, and an empty table.
 * `optionsfor` returns the options the column offers right now.
 */
export function fromstored<C extends FilterColumn>(
  raw: unknown,
  columns: C[],
  optionsfor: (column: C) => string[]
): FilterState {
  const out: FilterState = {};

  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return out;

  const stored = raw as Record<string, unknown>;

  for (const column of columns) {
    if (column.filterable === false) continue;

    const value = stored[column.key];

    if (column.filterType === "select" && column.multiSelect) {
      if (!Array.isArray(value)) continue;
      const options = optionsfor(column);
      const keep = value.filter((item): item is string => typeof item === "string" && options.includes(item));
      if (keep.length > 0) out[column.key] = keep;
    } else if (column.filterType === "select") {
      if (typeof value === "string" && value !== "" && optionsfor(column).includes(value)) {
        out[column.key] = value;
      }
    } else if (typeof value === "string" && value !== "" && !cprpattern.test(value)) {
      out[column.key] = value;
    }
  }

  return out;
}

export function readfilters<C extends FilterColumn>(
  key: string,
  columns: C[],
  optionsfor: (column: C) => string[]
): FilterState {
  try {
    return fromstored(JSON.parse(localStorage.getItem(keyprefix + key) ?? "null"), columns, optionsfor);
  } catch {
    return {};
  }
}

export function writefilters(key: string, filters: FilterState): void {
  try {
    const stored = tostored(filters);

    if (Object.keys(stored).length > 0) {
      localStorage.setItem(keyprefix + key, JSON.stringify(stored));
    } else {
      localStorage.removeItem(keyprefix + key);
    }
  } catch {
    // Storage unavailable: the filters simply are not remembered.
  }
}
