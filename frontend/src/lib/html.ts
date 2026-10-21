/**
 * HTML escaping — one function for the server status pages and the browser.
 *
 * escapeHtml is befordringssystemet's, from lib/server/statusPage.ts, moved
 * here so client code can use it too ($lib/server is not importable from the
 * browser). statusPage.ts re-exports it, so its callers are unchanged.
 */

export function escapeHtml(value: string) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}


/**
 * escapeHtml for a DataTable render function, taking whatever the API sent.
 *
 * DataTable (from befordringssystemet) renders a column's render() output
 * with {@html}, so every value interpolated into that string is parsed as
 * markup — and names, addresses and remarks come from citizens' forms and
 * LIS. Every API value in a render string goes through esc(). null and
 * undefined render as nothing.
 */
export function esc(value: unknown): string {
  if (value === null || value === undefined) return "";

  return escapeHtml(String(value));
}
