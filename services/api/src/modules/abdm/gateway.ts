import { errors } from '../../lib/errors.js';

/**
 * ABDM (Ayushman Bharat Digital Mission) gateway adapter, contract section 39.
 * NOT CONNECTED: the real implementation needs ABDM sandbox certification (client id/secret, callback URL,
 * HIP/HIU registration). Until then every call fails with 503 DEPENDENCY_UNAVAILABLE.
 */
export interface AbdmGateway {
  readonly name: string;
  /** Verify that an ABHA number / address belongs to the patient (e.g. via Aadhaar/mobile OTP on ABDM). */
  verifyAbha(input: { abhaNumber: string | null; abhaAddress: string | null }): Promise<{ verified: boolean; transactionId: string | null }>;
  /** Link a care context (episode) so records can be discovered by the patient's PHR app. */
  linkCareContext(input: { abhaAddress: string; careContextId: string; display: string }): Promise<void>;
}

export const ABDM_PENDING_MESSAGE = 'ABDM integration pending sandbox certification';

export class NotConnectedAbdmGateway implements AbdmGateway {
  readonly name = 'not_connected';
  async verifyAbha(_input: { abhaNumber: string | null; abhaAddress: string | null }): Promise<never> {
    throw errors.dependency(ABDM_PENDING_MESSAGE);
  }
  async linkCareContext(_input: { abhaAddress: string; careContextId: string; display: string }): Promise<never> {
    throw errors.dependency(ABDM_PENDING_MESSAGE);
  }
}

/** Normalise a 14-digit ABHA number (spaces/hyphens allowed) to XX-XXXX-XXXX-XXXX, or null when invalid. */
export function normaliseAbhaNumber(input: string): string | null {
  const digits = input.replace(/[\s-]/g, '');
  if (!/^\d{14}$/.test(digits)) return null;
  return `${digits.slice(0, 2)}-${digits.slice(2, 6)}-${digits.slice(6, 10)}-${digits.slice(10)}`;
}

/** ABHA address: `name@abdm` (production) or `name@sbx` (sandbox). Stored lower-case. */
export function normaliseAbhaAddress(input: string): string | null {
  const v = input.trim().toLowerCase();
  return /^[a-z0-9][a-z0-9._]{2,49}@(abdm|sbx)$/.test(v) ? v : null;
}
