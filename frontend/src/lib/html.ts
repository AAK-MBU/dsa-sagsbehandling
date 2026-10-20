/**
 * HTML escaping for DataTable render functions.
 *
 * DataTable (ported verbatim from befordringssystemet) renders a column's
 * render() output with {@html}. Anything interpolated into that string is
 * therefore parsed as markup — and names, addresses and remarks come from
 * citizens' forms and LIS. Every value from the API that goes into a render
 * string goes through esc() first. Literal markup written in the column
 * definition itself does not.
 *
 * The same rule as statusPage.ts's escapeHtml, available client side.
 */
export function esc(value: unknown): string {
  if (value === null || value === undefined) return "";

  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
