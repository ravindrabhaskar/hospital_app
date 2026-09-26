import type { DbOrTx } from '../db/client.js';
import { auditLogs } from '../db/schema.js';
import type { Actor } from './context.js';

export interface AuditEntry {
  action: string;
  entityType: string;
  entityId?: string | null;
  outcome?: 'success' | 'denied' | 'error';
  /** Must never contain PHI (names, phone numbers, free text, clinical values). */
  metadata?: Record<string, unknown>;
}

/** Append-only audit log. UPDATE/DELETE on audit_logs is blocked by a DB trigger. */
export async function audit(db: DbOrTx, actor: Actor, entry: AuditEntry): Promise<void> {
  await db.insert(auditLogs).values({
    actorId: actor.userId,
    actorName: actor.name,
    actorRole: actor.role,
    action: entry.action,
    entityType: entry.entityType,
    entityId: entry.entityId ?? null,
    outcome: entry.outcome ?? 'success',
    ip: actor.ip,
    correlationId: actor.correlationId,
    metadata: entry.metadata ?? {},
  });
}
