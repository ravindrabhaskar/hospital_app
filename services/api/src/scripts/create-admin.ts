/**
 * Create (or promote) an administrator.
 *   npm run create-admin -- --phone +919812345678 --name "Asha Rao" [--roles super_admin,ops_admin]
 *   node dist/scripts/create-admin.js --phone +919812345678 --name "Asha Rao"      (production container)
 * Idempotent: an existing user keeps their roles and gains the requested ones. Works with PGlite and DATABASE_URL.
 */
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { eq } from 'drizzle-orm';
import { loadConfig } from '../config.js';
import { createDb, runMigrations, type Db } from '../db/client.js';
import { users, type Role } from '../db/schema.js';
import { audit } from '../lib/audit.js';
import { ensureUser } from '../modules/auth/service.js';

const ROLES: Role[] = ['patient', 'doctor', 'provider', 'coordinator', 'ops_admin', 'super_admin'];
export const CLI_ACTOR = { userId: null, name: 'system:cli', role: 'system', ip: null, correlationId: null };

export interface CreateAdminInput {
  phone: string;
  name?: string | null;
  roles: Role[];
}

export function parseArgs(argv: string[]): CreateAdminInput {
  const get = (flag: string) => {
    const i = argv.indexOf(flag);
    return i >= 0 ? argv[i + 1] : undefined;
  };
  const phone = get('--phone');
  if (!phone || !/^\+\d{10,15}$/.test(phone)) throw new Error('--phone is required in E.164 format, e.g. --phone +919812345678');
  const roles = (get('--roles') ?? 'super_admin')
    .split(',')
    .map((r) => r.trim())
    .filter(Boolean) as Role[];
  const bad = roles.filter((r) => !ROLES.includes(r));
  if (bad.length || !roles.length) throw new Error(`Invalid --roles ${bad.join(',')}. Allowed: ${ROLES.join(', ')}`);
  const name = get('--name');
  return { phone, name: name?.trim() || null, roles };
}

export async function createAdmin(db: Db, input: CreateAdminInput): Promise<{ id: string; roles: Role[]; created: boolean }> {
  return db.transaction(async (tx) => {
    const [existing] = await tx.select().from(users).where(eq(users.phone, input.phone));
    const base = existing ?? (await ensureUser(tx, input.phone, { name: input.name, roles: input.roles }));
    const roles = [...new Set([...(base.roles ?? []), ...input.roles])];
    const [u] = await tx
      .update(users)
      .set({ roles, ...(input.name ? { name: input.name } : {}) })
      .where(eq(users.id, base.id))
      .returning();
    await audit(tx, CLI_ACTOR, {
      action: existing ? 'staff.promote_cli' : 'staff.create_cli',
      entityType: 'user',
      entityId: u.id,
      metadata: { roles, added: input.roles.filter((r) => !(existing?.roles ?? []).includes(r)) },
    });
    return { id: u.id, roles: u.roles, created: !existing };
  });
}

async function main(): Promise<void> {
  const input = parseArgs(process.argv.slice(2));
  const config = loadConfig();
  const handle = await createDb({ databaseUrl: config.DATABASE_URL, pgliteDir: config.PGLITE_DIR, poolMax: 2 });
  try {
    await runMigrations(handle);
    const r = await createAdmin(handle.db, input);
    console.log(`${r.created ? 'Created' : 'Updated'} user ${r.id} with roles [${r.roles.join(', ')}] (${handle.driver}).`);
    console.log('Sign in with this phone via OTP. Staff must enrol TOTP MFA when MFA_ENFORCED=true.');
  } finally {
    await handle.close();
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((err) => {
    console.error(err instanceof Error ? err.message : err);
    process.exit(1);
  });
}
