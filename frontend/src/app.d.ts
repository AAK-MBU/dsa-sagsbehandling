// See https://svelte.dev/docs/kit/types#app.d.ts
// for information about these interfaces
import type { CurrentUser } from "$lib/auth";

declare global {
	namespace App {
		// interface Error {}
		interface Locals {
			// Set by the auth guard in hooks.server.ts. Always present: the guard
			// redirects to the IdP rather than resolving a request without it.
			user: CurrentUser;
		}
		// interface PageData {}
		// interface PageState {}
		// interface Platform {}
	}
}

export {};
