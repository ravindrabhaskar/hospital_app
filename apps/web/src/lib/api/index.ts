import { HttpClient } from "./http";
import { TokenStore } from "./session";
import { createEndpoints } from "./endpoints";
import { publicEnv } from "../env";

export * from "./types";
export { ApiError, HttpClient, parseErrorResponse, buildUrl, newId } from "./http";
export { TokenStore } from "./session";
export type { StoredSession } from "./session";
export { createEndpoints } from "./endpoints";
export type { Endpoints } from "./endpoints";

export const API_BASE_URL = publicEnv.apiBaseUrl;

type ExpiredHandler = () => void;
let expiredHandler: ExpiredHandler | null = null;

/** Register the app-level handler run when a session cannot be refreshed. */
export function onSessionExpired(handler: ExpiredHandler | null) {
  expiredHandler = handler;
}

let mfaRequiredHandler: ExpiredHandler | null = null;
/** Register the app-level handler run when the API answers 403 MFA_REQUIRED (§22). */
export function onMfaRequired(handler: ExpiredHandler | null) {
  mfaRequiredHandler = handler;
}

export const tokenStore = new TokenStore();

export const http = new HttpClient({
  baseUrl: API_BASE_URL,
  tokens: tokenStore,
  onSessionExpired: () => expiredHandler?.(),
  onMfaRequired: () => mfaRequiredHandler?.(),
});

export const api = createEndpoints(http);
