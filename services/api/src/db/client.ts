import { mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import type { NodePgDatabase } from 'drizzle-orm/node-postgres';
import * as schema from './schema.js';

export type Db = NodePgDatabase<typeof schema>;
/** A transaction handle has the same query surface as Db. */
export type Tx = Parameters<Parameters<Db['transaction']>[0]>[0];
export type DbOrTx = Db | Tx;

export interface DbHandle {
  db: Db;
  driver: 'pg' | 'pglite';
  /** Set for the pg driver (used by the worker leader election's dedicated connection). */
  connectionString?: string;
  close(): Promise<void>;
  ping(): Promise<void>;
}

const here = path.dirname(fileURLToPath(import.meta.url));
/** Works for both src/ (tsx) and dist/ (compiled) layouts: <pkg>/drizzle */
export const MIGRATIONS_DIR = path.resolve(here, '..', '..', 'drizzle');

/**
 * Driver selection: DATABASE_URL set -> node-postgres; otherwise PGlite.
 * `pgliteDir` = 'memory://' gives an in-memory database (used by tests).
 */
export async function createDb(opts: { databaseUrl?: string; pgliteDir: string; poolMax?: number }): Promise<DbHandle> {
  if (opts.databaseUrl) {
    const { Pool } = (await import('pg')).default;
    const { drizzle } = await import('drizzle-orm/node-postgres');
    const pool = new Pool({ connectionString: opts.databaseUrl, max: opts.poolMax ?? 10 });
    const db = drizzle(pool, { schema });
    return {
      db,
      driver: 'pg',
      connectionString: opts.databaseUrl,
      close: () => pool.end(),
      ping: async () => {
        await pool.query('select 1');
      },
    };
  }
  const { PGlite } = await import('@electric-sql/pglite');
  const { drizzle } = await import('drizzle-orm/pglite');
  let client: InstanceType<typeof PGlite>;
  if (opts.pgliteDir === 'memory://' || opts.pgliteDir === ':memory:') {
    client = new PGlite();
  } else {
    const dir = path.resolve(opts.pgliteDir);
    mkdirSync(dir, { recursive: true });
    client = new PGlite(dir);
  }
  await client.waitReady;
  const db = drizzle(client, { schema }) as unknown as Db;
  return {
    db,
    driver: 'pglite',
    close: () => client.close(),
    ping: async () => {
      await client.query('select 1');
    },
  };
}

export async function runMigrations(handle: DbHandle): Promise<void> {
  if (handle.driver === 'pg') {
    const { migrate } = await import('drizzle-orm/node-postgres/migrator');
    await migrate(handle.db, { migrationsFolder: MIGRATIONS_DIR });
  } else {
    const { migrate } = await import('drizzle-orm/pglite/migrator');
    await migrate(handle.db as any, { migrationsFolder: MIGRATIONS_DIR });
  }
}

export { schema };
