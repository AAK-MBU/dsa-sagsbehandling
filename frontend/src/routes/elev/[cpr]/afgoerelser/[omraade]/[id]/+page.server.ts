import { error, redirect } from "@sveltejs/kit";

import { OMRAADER, type Omraade } from "$lib/elevsag";
import { hentSkolebegynderSag } from "$lib/server/skolebegynderSag";
import { hentSkoleskifterSag } from "$lib/server/skoleskifterSag";

import type { PageServerLoad } from "./$types";


/**
 * One of the child's afgørelser: a closed case, shown in full and read-only,
 * with "Genåbn sag" for those who may edit.
 *
 * A case that is not closed belongs on the "Aktiv sag" tab, so this redirects
 * there. That is also what moves the caseworker along after "Genåbn sag": the
 * case component reloads the page data, this load runs again, finds the case
 * open, and sends them to the first tab, where it is now editable.
 */
export const load: PageServerLoad = async (event) => {
  const omraade = event.params.omraade as Omraade;
  const id = Number(event.params.id);

  if (!OMRAADER.includes(omraade) || !Number.isInteger(id) || id <= 0) {
    throw error(404, "Afgørelsen findes ikke");
  }

  const skolebegynder = omraade === "skolebegynder" ? await hentSkolebegynderSag(event, id) : null;
  const skoleskifter = omraade === "skoleskifter" ? await hentSkoleskifterSag(event, id) : null;
  const sag = (skolebegynder ?? skoleskifter)!.sag;

  // The URL names the child as well as the case; a case id under another
  // child's CPR is not this child's afgørelse.
  if (sag.cpr !== event.params.cpr) {
    throw error(404, "Afgørelsen findes ikke for denne elev");
  }

  if (sag.status_tekst !== "Afsluttet") {
    throw redirect(303, `/elev/${event.params.cpr}`);
  }

  return { skolebegynder, skoleskifter };
};
