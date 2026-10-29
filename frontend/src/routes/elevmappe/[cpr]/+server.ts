import { redirect } from "@sveltejs/kit";

import type { RequestHandler } from "./$types";


/** The old Elevmappe — now the student page, /elev/{cpr}. */
export const GET: RequestHandler = ({ params }) => {
  throw redirect(308, `/elev/${params.cpr}`);
};
