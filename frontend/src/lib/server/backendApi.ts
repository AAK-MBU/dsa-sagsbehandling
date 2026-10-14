import { env as publicEnv } from "$env/dynamic/public";

type FetchFunction = typeof fetch;


function getApiBaseUrl() {
  const apiBaseUrl = publicEnv.PUBLIC_API_BASE_URL;

  if (!apiBaseUrl) {
    throw new Error("Missing PUBLIC_API_BASE_URL");
  }

  return apiBaseUrl;
}


function normalizePath(path: string) {
  if (path.startsWith("/")) {
    return path;
  }

  return `/${path}`;
}


export function backendApiFetch(
  fetchFn: FetchFunction,
  path: string,
  options: RequestInit = {}
) {
  const apiBaseUrl = getApiBaseUrl();

  return fetchFn(`${apiBaseUrl}${normalizePath(path)}`, options);
}
