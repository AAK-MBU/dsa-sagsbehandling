import {
  forwardAuthRequest,
  relayAuthResponse,
  serializeLoginAttemptCleared,
  serializeReturnToCleared
} from "$lib/server/auth";
import { LOGGED_OUT_PATH } from "$lib/server/loggedOut";

import type { RequestHandler } from "./$types";


/**
 * DSA: "Log ud" — ends the DSA session and lands on /logged-out directly.
 *
 * The backend's /auth/logout clears the session and then redirects to
 * Microsoft's end-session endpoint. Following that redirect signed the user
 * out of Microsoft as well, which on Entra ID meant an account picker, then
 * "You signed out of your account", and only sometimes the trip back to
 * /logged-out. This route calls /auth/logout server-side, so the session is
 * gone, and sends the browser to our own page instead of Microsoft's.
 *
 * The Microsoft sign-in stays alive by design. "Log ind igen" on /logged-out
 * is then a silent round trip that picks up a fresh token — new roles, new
 * name — without a password prompt. Closing the browser ends the Microsoft
 * sign-in, as the page tells users at a shared computer.
 *
 * A same-origin page route rather than /api/auth/logout: behind the edge proxy
 * /api/* goes straight to the backend and never reaches SvelteKit, so only a
 * path outside /api behaves the same locally and on the servers.
 * hooks.server.ts leaves it unguarded.
 */
export const GET: RequestHandler = async ({ request, getClientAddress }) => {
  const forwarded = await forwardAuthRequest(
    "logout",
    "",
    request.headers.get("cookie"),
    { ip: getClientAddress(), userAgent: request.headers.get("user-agent") }
  );

  // A backend failure may have left the session in place — say so rather
  // than claim a logout that did not happen. A 404 (OIDC switched off, so no
  // /auth routes) has no session to end and falls through.
  if (forwarded.response.status >= 500) {
    return relayAuthResponse(forwarded);
  }

  // Retire the guard's login markers, as the /api/auth passthrough does — see
  // its comment for why a stale login-attempt marker would misreport.
  forwarded.headers.append("set-cookie", serializeLoginAttemptCleared());
  forwarded.headers.append("set-cookie", serializeReturnToCleared());
  forwarded.headers.set("location", LOGGED_OUT_PATH);

  return new Response(null, { status: 302, headers: forwarded.headers });
};
