export function formatDanishDate(dateStr: string | null | undefined): string {
  if (!dateStr) return "—";
  const parts = dateStr.split("-");
  if (parts.length !== 3) return dateStr;
  const [year, month, day] = parts;
  return `${day}-${month}-${year}`;
}


export const statusBadgeClasses: Record<string, string> = {
  "ny": "bg-dsa-100 text-dsa-800",
  "under behandling": "bg-amber-100 text-amber-800",
  "afventer ppr": "bg-fuchsia-100 text-fuchsia-800",
  "afventer konsulent": "bg-fuchsia-100 text-fuchsia-800",
  "sendt skrivelse": "bg-sky-100 text-sky-800",
  "færdigbehandlet": "bg-emerald-100 text-emerald-800",
  default: "bg-slate-100 text-slate-700"
};


export function getStatusBadgeClass(status: string | null | undefined) {
  const key = String(status ?? "").toLowerCase();

  return statusBadgeClasses[key] ?? statusBadgeClasses.default;
}
