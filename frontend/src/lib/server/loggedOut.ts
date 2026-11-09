import { statusPage } from "./statusPage";


/**
 * Path the logout lands on. DSA: moved here from hooks.server.ts so the
 * /logout route can share it.
 */
export const LOGGED_OUT_PATH = "/logged-out";


/**
 * Landing page after a completed logout.
 *
 * DSA: routes/logout sends the browser here directly, not via Microsoft.
 *
 * B2C sends the browser here via post_logout_redirect_uri, so this is the first
 * thing a user sees after signing out and it has to stand on its own — the
 * session is gone by now, which is why the guard treats this path as public. It
 * is a 200: logging out succeeded, nothing failed.
 *
 * The action points at "/" rather than at the login endpoint directly. The
 * guard turns that into a fresh login and then restores the destination, so a
 * user who logs back in lands on the app instead of on a bare callback.
 */
export function loggedOutPage() {
  return statusPage({
    title: "Logget ud",
    status: 200,
    heading: "Du er nu logget ud",
    bodyHtml: `
      <p>Din session er afsluttet, og du er logget ud af DSA.</p>
      <p class="note">Når du logger ind igen, hentes dine rettigheder på ny — så har en ny rolle virkning med det samme.</p>
      <p class="note">Sidder du ved en delt computer, bør du lukke browseren helt — så er du også logget ud af eventuelle andre Aarhus Kommune-systemer.</p>
    `,
    footerHtml: `<a class="btn" href="/">Log ind igen</a>`
  });
}
