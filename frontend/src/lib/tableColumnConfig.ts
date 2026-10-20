export function formatDanishDate(dateStr: string | null | undefined): string {
  if (!dateStr) return "—";
  const parts = dateStr.split("-");
  if (parts.length !== 3) return dateStr;
  const [year, month, day] = parts;
  return `${day}-${month}-${year}`;
}


export function formatCpr(cpr: string | null | undefined): string {
  if (!cpr) return "—";
  const digits = String(cpr).replace(/\D/g, "");
  return digits.length === 10 ? `${digits.slice(0, 6)}-${digits.slice(6)}` : String(cpr);
}


// DSA: DSA's statuses (befordringssystemet maps its bevilling statuses here).
// Keys are lowercased status_tekst.
export const statusBadgeClasses: Record<string, string> = {
  "ikke screenet": "bg-slate-100 text-slate-700",
  "nærmere afklaring": "bg-amber-100 text-amber-800",
  "under behandling": "bg-dsa-100 text-dsa-800",
  skoletilbud: "bg-sky-100 text-sky-800",
  afsluttet: "bg-emerald-100 text-emerald-800",
  default: "bg-slate-100 text-slate-700"
};


export function getStatusBadgeClass(status: string | null | undefined) {
  const key = String(status ?? "").toLowerCase();
  return statusBadgeClasses[key] ?? statusBadgeClasses.default;
}


// DSA: befordringstype badges and revurderingPillHtml omitted — befordring
// domain.


// -----------------------------
// Table action buttons
// -----------------------------

export const tableActionButtonClass =
  "inline-flex min-h-8 items-center justify-center rounded px-3 py-2 text-sm font-medium transition-all focus:outline-none focus:ring-2 focus:ring-offset-2";

export const tablePrimaryActionButtonClass =
  `${tableActionButtonClass} text-blue-600 hover:bg-blue-50 focus:ring-blue-300`;

export const tableSaveActionButtonClass =
  `${tableActionButtonClass} text-green-700 hover:bg-green-50 focus:ring-green-300`;

export const tableCancelActionButtonClass =
  `${tableActionButtonClass} text-red-600 hover:bg-red-50 focus:ring-red-300`;

export const tableIconButtonClass =
  "inline-flex h-8 w-8 items-center justify-center rounded hover:bg-blue-50 focus:outline-none focus:ring-2 focus:ring-blue-300 transition-colors";
