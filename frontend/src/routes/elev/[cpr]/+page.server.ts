import { redirect } from "@sveltejs/kit";

import { areas } from "$lib/areas";

import type { PageServerLoad } from "./$types";


/**
 * /elev/{cpr} on its own: open the area the child has an open case in, else
 * one with any case, else the first built area. A link from an area's
 * overview goes straight to /elev/{cpr}/<area> and never comes through here.
 */
export const load: PageServerLoad = async ({ params, parent }) => {
  const { sagsantal } = await parent();

  const bygget = areas.filter((a) => a.enabled && a.elevside).map((a) => a.elevside as string);

  const fane =
    bygget.find((k) => (sagsantal[k]?.aabne ?? 0) > 0) ??
    bygget.find((k) => (sagsantal[k]?.alle ?? 0) > 0) ??
    bygget[0] ??
    "foraeldremyndighed";

  throw redirect(307, `/elev/${params.cpr}/${fane}`);
};
