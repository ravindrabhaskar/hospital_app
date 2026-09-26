import { z } from 'zod';
import { errors } from './errors.js';

export const zPage = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  cursor: z.string().max(200).optional(),
});

export interface Page {
  limit: number;
  offset: number;
}

export function decodeCursor(cursor: string | undefined): number {
  if (!cursor) return 0;
  try {
    const v = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8')) as { o?: unknown };
    if (typeof v.o === 'number' && v.o >= 0 && Number.isInteger(v.o)) return v.o;
  } catch {
    /* fallthrough */
  }
  throw errors.validation('Invalid cursor');
}

export function encodeCursor(offset: number): string {
  return Buffer.from(JSON.stringify({ o: offset }), 'utf8').toString('base64url');
}

export function pageFromQuery(query: unknown): Page {
  const raw = (query ?? {}) as Record<string, unknown>;
  const q = zPage.safeParse({ limit: raw.limit, cursor: raw.cursor });
  if (!q.success) throw errors.validation('Invalid pagination parameters');
  return { limit: q.data.limit, offset: decodeCursor(q.data.cursor) };
}

/** Build a list envelope from rows fetched with `limit + 1`. */
export function envelope<T>(rows: T[], page: Page): { items: T[]; nextCursor: string | null } {
  const hasMore = rows.length > page.limit;
  return { items: hasMore ? rows.slice(0, page.limit) : rows, nextCursor: hasMore ? encodeCursor(page.offset + page.limit) : null };
}

/** Paginate an in-memory array (used for merged/computed lists). */
export function paginateArray<T>(all: T[], page: Page): { items: T[]; nextCursor: string | null } {
  return envelope(all.slice(page.offset, page.offset + page.limit + 1), page);
}

/** Envelope for small, non-paginated catalogs. */
export function list<T>(items: T[]): { items: T[]; nextCursor: null } {
  return { items, nextCursor: null };
}
