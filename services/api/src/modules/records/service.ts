import { randomUUID } from 'node:crypto';
import type { DbOrTx } from '../../db/client.js';
import { medicalRecords, type Provenance } from '../../db/schema.js';
import { sha256 } from '../../lib/crypto.js';
import { iso } from '../../lib/time.js';
import type { StorageAdapter } from './storage.js';

export type RecordRow = typeof medicalRecords.$inferSelect;
export const RECORD_TYPES = ['lab_report', 'prescription', 'imaging', 'discharge_summary', 'visit_summary', 'other'] as const;

export const toRecord = (r: RecordRow) => ({
  id: r.id,
  patientId: r.patientId,
  type: r.type,
  title: r.title,
  recordDate: r.recordDate,
  source: r.source,
  uploadedByName: r.uploadedByName,
  fileName: r.fileName,
  mimeType: r.mimeType,
  sizeBytes: r.sizeBytes,
  hasFile: !!r.storageKey,
  aiSummary: r.aiSummary ?? null,
  createdAt: iso(r.createdAt),
});

/** Store an immutable original and create the record row. The storage write happens first (write-once). */
export async function storeRecord(
  db: DbOrTx,
  storage: StorageAdapter,
  p: {
    patientId: string;
    type: string;
    title: string;
    recordDate: string;
    source: Provenance;
    uploadedByUserId: string | null;
    uploadedByName: string | null;
    fileName: string;
    mimeType: string;
    data: Buffer;
    homeVisitId?: string | null;
  },
): Promise<RecordRow> {
  const id = randomUUID();
  const ext = p.fileName.includes('.') ? p.fileName.slice(p.fileName.lastIndexOf('.')).replace(/[^.a-z0-9]/gi, '').slice(0, 8) : '';
  const storageKey = `records/${p.patientId}/${id}${ext}`;
  await storage.put(storageKey, p.data, p.mimeType);
  const [row] = await db
    .insert(medicalRecords)
    .values({
      id,
      patientId: p.patientId,
      type: p.type,
      title: p.title,
      recordDate: p.recordDate,
      source: p.source,
      uploadedByUserId: p.uploadedByUserId,
      uploadedByName: p.uploadedByName,
      fileName: p.fileName.slice(0, 200),
      mimeType: p.mimeType,
      sizeBytes: p.data.length,
      storageKey,
      sha256: sha256(p.data),
      homeVisitId: p.homeVisitId ?? null,
    })
    .returning();
  return row;
}
