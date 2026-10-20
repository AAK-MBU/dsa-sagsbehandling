// The 6 "områder" (areas of work) shown on the front page and in the top nav.
// Single source of truth so the launcher cards and the nav bar stay in sync.
// Only Skolebegynderscreeninger is wired up so far (phase 1); the rest are
// "Kommer snart".

export type AreaLink = { label: string; href?: string };

export type Area = {
  title: string; // full title (front-page cards)
  short: string; // short label (top nav)
  accent: string; // left bar + title tint
  bg: string; // card background
  ring: string; // card border
  href?: string; // where the area navigates (when enabled)
  links: AreaLink[];
  enabled: boolean;
};

export const areas: Area[] = [
  {
    title: "Nyankomne i Modtagelsesklasse",
    short: "Modtagelsesklasse",
    accent: "#8a2b2b",
    bg: "#f9ecec",
    ring: "#e6c9c9",
    links: [{ label: "Forside" }, { label: "Rapport" }],
    enabled: false,
  },
  {
    title: "Skoleskiftere og tilflyttere",
    short: "Skoleskiftere",
    accent: "#4e7c3a",
    bg: "#eef5e9",
    ring: "#cfe2c2",
    links: [{ label: "Forside" }, { label: "Rapport" }],
    enabled: false,
  },
  {
    title: "Skolebegynderscreeninger",
    short: "Screeninger",
    accent: "#2c7d90",
    bg: "#e7f2f5",
    ring: "#c2dee5",
    href: "/skolebegynder",
    links: [{ label: "Overblik", href: "/skolebegynder" }, { label: "Rapport" }],
    enabled: true,
  },
  {
    title: "Udslusning basisundervisning",
    short: "Udslusning",
    accent: "#6a4a9c",
    bg: "#efeaf6",
    ring: "#d6cbe8",
    links: [{ label: "Forside" }, { label: "Rapport" }],
    enabled: false,
  },
  {
    title: "Sproglig udvikling",
    short: "Sproglig udvikling",
    accent: "#c2591a",
    bg: "#f9efe6",
    ring: "#eed3bd",
    links: [{ label: "Forside" }, { label: "Rapport" }],
    enabled: false,
  },
  {
    title: "Dataudtræk",
    short: "Dataudtræk",
    accent: "#bd9b16",
    bg: "#f9f3dc",
    ring: "#e9dca0",
    links: [{ label: "Rapport 1" }, { label: "Rapport 2" }],
    enabled: false,
  },
];
