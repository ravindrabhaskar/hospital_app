import type { Role } from '../db/schema.js';

export type Lang = 'en' | 'hi' | 'te';

export interface AuthUser {
  id: string;
  phone: string;
  name: string | null;
  roles: Role[];
  language: Lang;
  selfPatientId: string | null;
  providerId: string | null;
  sessionId: string;
}

/** Who performed an action (for audit + episode events). */
export interface Actor {
  userId: string | null;
  name: string | null;
  role: string | null;
  ip: string | null;
  correlationId: string | null;
}

export interface RequestCtx {
  user: AuthUser;
  actor: Actor;
  lang: Lang;
}

export const SYSTEM_ACTOR: Actor = { userId: null, name: 'System', role: 'system', ip: null, correlationId: null };

export const STAFF_ROLES: Role[] = ['doctor', 'coordinator', 'ops_admin', 'super_admin'];
export const OPS_ROLES: Role[] = ['coordinator', 'ops_admin', 'super_admin'];

/** Primary role used in audit rows / event actorRole. */
export function primaryRole(roles: Role[]): Role {
  const order: Role[] = ['super_admin', 'ops_admin', 'coordinator', 'doctor', 'provider', 'patient'];
  return order.find((r) => roles.includes(r)) ?? 'patient';
}

export function hasRole(user: { roles: Role[] }, ...roles: Role[]): boolean {
  return roles.some((r) => user.roles.includes(r));
}

export function parseLang(header: unknown, fallback: Lang = 'en'): Lang {
  if (typeof header !== 'string') return fallback;
  const first = header.split(',')[0]?.trim().slice(0, 2).toLowerCase();
  return first === 'hi' || first === 'te' || first === 'en' ? first : fallback;
}
