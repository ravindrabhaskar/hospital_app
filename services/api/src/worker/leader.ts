import type { DbHandle } from '../db/client.js';

/**
 * Worker leader election so that exactly one API instance runs scheduled jobs.
 * - PostgreSQL: a session-level advisory lock (`pg_try_advisory_lock`) held on a dedicated connection.
 *   If that connection drops, Postgres releases the lock and another instance takes over on its next tick.
 * - PGlite: embedded, single process: always the leader.
 */
export interface LeaderElector {
  readonly mode: 'advisory_lock' | 'single_process' | 'static';
  /** Try to become / stay leader. Cheap when already leader. */
  acquire(): Promise<boolean>;
  isLeader(): boolean;
  release(): Promise<void>;
}

export class SingleProcessLeader implements LeaderElector {
  readonly mode = 'single_process' as const;
  async acquire(): Promise<boolean> {
    return true;
  }
  isLeader(): boolean {
    return true;
  }
  async release(): Promise<void> {}
}

/** Minimal client surface we need (satisfied by pg.Client). */
export interface LockClient {
  connect(): Promise<unknown>;
  query(sql: string, params?: unknown[]): Promise<{ rows: Array<Record<string, unknown>> }>;
  end(): Promise<void>;
  on(event: 'error' | 'end', cb: (...args: unknown[]) => void): unknown;
}

export class AdvisoryLockLeader implements LeaderElector {
  readonly mode = 'advisory_lock' as const;
  private client: LockClient | null = null;
  private leader = false;

  constructor(
    private readonly makeClient: () => LockClient,
    private readonly lockKey: number,
  ) {}

  private drop(): void {
    this.leader = false;
    const c = this.client;
    this.client = null;
    if (c) void c.end().catch(() => undefined);
  }

  async acquire(): Promise<boolean> {
    try {
      if (!this.client) {
        const c = this.makeClient();
        c.on('error', () => this.drop());
        c.on('end', () => {
          if (this.client === c) this.drop();
        });
        await c.connect();
        this.client = c;
      }
      if (this.leader) {
        // Keep-alive: detects a dead connection (lock lost) before running jobs.
        await this.client.query('select 1');
        return true;
      }
      const r = await this.client.query('select pg_try_advisory_lock($1) as locked', [this.lockKey]);
      this.leader = r.rows[0]?.locked === true;
      return this.leader;
    } catch {
      this.drop();
      return false;
    }
  }

  isLeader(): boolean {
    return this.leader;
  }

  async release(): Promise<void> {
    const c = this.client;
    if (!c) return;
    try {
      if (this.leader) await c.query('select pg_advisory_unlock($1)', [this.lockKey]);
    } catch {
      // closing the session releases the lock anyway
    }
    this.leader = false;
    this.client = null;
    await c.end().catch(() => undefined);
  }
}

export async function createLeaderElector(handle: DbHandle, lockKey: number): Promise<LeaderElector> {
  if (handle.driver !== 'pg' || !handle.connectionString) return new SingleProcessLeader();
  const pg = (await import('pg')).default;
  const cs = handle.connectionString;
  return new AdvisoryLockLeader(() => new pg.Client({ connectionString: cs }) as unknown as LockClient, lockKey);
}
