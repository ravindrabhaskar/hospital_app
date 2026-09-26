import { and, eq, gte, isNull, lte, or } from 'drizzle-orm';
import type { Db, DbOrTx } from '../../db/client.js';
import { knowledgeChunks, knowledgeSources } from '../../db/schema.js';
import { istDate } from '../../lib/time.js';

const STOPWORDS = new Set(
  'a an and are as at be but by for from has have i if in into is it its me my of on or so than that the their them then there these they this to too was we were what when where which while who why will with you your since yesterday today'.split(
    ' ',
  ),
);

export function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .split(/[^\p{L}\p{N}]+/u)
    .filter((t) => t.length > 2 && !STOPWORDS.has(t))
    .map((t) => (t.length > 4 && t.endsWith('s') ? t.slice(0, -1) : t));
}

export function chunkContent(content: string, maxChars = 600): string[] {
  const paras = content
    .split(/\n\s*\n/)
    .map((p) => p.trim())
    .filter(Boolean);
  const chunks: string[] = [];
  let cur = '';
  for (const p of paras) {
    if (cur && cur.length + p.length > maxChars) {
      chunks.push(cur);
      cur = '';
    }
    cur = cur ? `${cur}\n\n${p}` : p;
  }
  if (cur) chunks.push(cur);
  return chunks;
}

export interface RetrievalHit {
  sourceId: string;
  sourceTitle: string;
  chunkId: string;
  text: string;
  score: number;
}

/** BM25-style keyword retrieval over APPROVED, in-date sources only. */
export class KnowledgeService {
  constructor(private readonly db: Db) {}

  async indexSource(db: DbOrTx, sourceId: string, content: string): Promise<number> {
    await db.delete(knowledgeChunks).where(eq(knowledgeChunks.sourceId, sourceId));
    const chunks = chunkContent(content);
    for (const [i, text] of chunks.entries()) {
      const terms: Record<string, number> = {};
      const toks = tokenize(text);
      for (const tok of toks) terms[tok] = (terms[tok] ?? 0) + 1;
      await db.insert(knowledgeChunks).values({ sourceId, ordinal: i, text, terms, length: toks.length });
    }
    return chunks.length;
  }

  async retrieve(query: string, k = 3): Promise<RetrievalHit[]> {
    const qTerms = [...new Set(tokenize(query))];
    if (!qTerms.length) return [];
    const today = istDate();
    const rows = await this.db
      .select({
        chunkId: knowledgeChunks.id,
        sourceId: knowledgeChunks.sourceId,
        text: knowledgeChunks.text,
        terms: knowledgeChunks.terms,
        length: knowledgeChunks.length,
        title: knowledgeSources.title,
      })
      .from(knowledgeChunks)
      .innerJoin(knowledgeSources, eq(knowledgeSources.id, knowledgeChunks.sourceId))
      .where(
        and(
          eq(knowledgeSources.status, 'approved'),
          lte(knowledgeSources.effectiveDate, today),
          or(isNull(knowledgeSources.expiresAt), gte(knowledgeSources.expiresAt, today)),
        ),
      );
    if (!rows.length) return [];
    const N = rows.length;
    const avgdl = rows.reduce((s, r) => s + r.length, 0) / N || 1;
    const k1 = 1.2;
    const b = 0.75;
    const df = new Map<string, number>();
    for (const t of qTerms) df.set(t, rows.filter((r) => r.terms[t]).length);
    const scored = rows.map((r) => {
      let score = 0;
      for (const t of qTerms) {
        const f = r.terms[t] ?? 0;
        if (!f) continue;
        const n = df.get(t) ?? 0;
        const idf = Math.log(1 + (N - n + 0.5) / (n + 0.5));
        score += idf * ((f * (k1 + 1)) / (f + k1 * (1 - b + (b * r.length) / avgdl)));
      }
      return { sourceId: r.sourceId, sourceTitle: r.title, chunkId: r.chunkId, text: r.text, score };
    });
    return scored
      .filter((s) => s.score > 0)
      .sort((a, b2) => b2.score - a.score)
      .slice(0, k);
  }
}
