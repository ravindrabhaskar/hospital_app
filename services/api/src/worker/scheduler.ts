import type { FastifyBaseLogger } from 'fastify';
import type { Services } from '../services.js';
import { JOBS, type Job } from './jobs.js';
import { SingleProcessLeader, type LeaderElector } from './leader.js';

/**
 * In-process scheduler. Single-flight per tick (a tick never overlaps the previous one) and
 * leader-elected across instances (see leader.ts): only the instance holding the lock runs jobs.
 * To move to BullMQ/Redis: register each entry of JOBS as a repeatable job on its own queue and
 * call the same function from the queue processor. Jobs are idempotent by design.
 */
export class Scheduler {
  private timer: NodeJS.Timeout | null = null;
  private running = false;
  lastTickAt: Date | null = null;

  constructor(
    private readonly svc: Services,
    private readonly log: FastifyBaseLogger,
    private readonly jobs: Record<string, Job> = JOBS,
    readonly leader: LeaderElector = new SingleProcessLeader(),
  ) {}

  get started(): boolean {
    return this.timer !== null;
  }

  start(intervalMs: number): void {
    if (this.timer) return;
    this.timer = setInterval(() => void this.tick(), intervalMs);
    this.timer.unref();
    void this.tick();
  }

  async stop(): Promise<void> {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    while (this.running) await new Promise((r) => setTimeout(r, 25));
    await this.leader.release();
  }

  /** Run every job once if this instance is the leader (also used by tests). Returns per-job counts. */
  async tick(now: Date = new Date()): Promise<Record<string, number>> {
    if (this.running) return {};
    this.running = true;
    const results: Record<string, number> = {};
    try {
      const wasLeader = this.leader.isLeader();
      const leader = await this.leader.acquire();
      this.svc.metrics.workerLeader.set(leader ? 1 : 0);
      if (leader !== wasLeader) this.log.info({ leader, mode: this.leader.mode }, leader ? 'worker leadership acquired' : 'worker leadership lost');
      if (!leader) return results;
      this.lastTickAt = now;
      for (const [name, job] of Object.entries(this.jobs)) {
        try {
          results[name] = await job(this.svc, now);
        } catch (err) {
          results[name] = -1;
          this.log.error({ err, job: name }, 'worker job failed');
        }
      }
    } finally {
      this.running = false;
    }
    return results;
  }

  /** /ready: 'leader' | 'standby' | 'disabled'. */
  status(): 'leader' | 'standby' | 'disabled' {
    if (!this.started) return 'disabled';
    return this.leader.isLeader() ? 'leader' : 'standby';
  }
}
