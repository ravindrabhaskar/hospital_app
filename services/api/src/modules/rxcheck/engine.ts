import { and, eq } from 'drizzle-orm';
import type { Config } from '../../config.js';
import type { DbOrTx } from '../../db/client.js';
import { allergies, clinicalContentPacks, medications, type RxWarningJson } from '../../db/schema.js';
import { requestJson, type FetchLike } from '../../lib/http.js';
import { istDate } from '../../lib/time.js';
import { INTERACTION_FIXTURE, INTERACTION_PACK_VERSION, type InteractionPackContent } from './fixtures.js';

/**
 * Contract section 47: drug interaction & allergy checks. The engine is deterministic; the knowledge (classes,
 * interaction pairs) is versioned data in `clinical_content_packs` (kind `interactions`), or a licensed database
 * behind the DrugKnowledgeProvider adapter.
 */
export type RxWarning = RxWarningJson;

export interface CheckInput {
  items: Array<{ drugName: string; strength?: string | null }>;
  allergies: string[];
  activeMedications: string[];
}

export interface CheckResult {
  warnings: RxWarning[];
  knowledgePack: { version: string; status: 'fixture_unapproved' | 'approved' };
}

export interface DrugKnowledgeProvider {
  readonly name: string;
  check(db: DbOrTx, input: CheckInput): Promise<CheckResult>;
}

export const normDrug = (s: string): string =>
  ` ${s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()} `;

/** Name without strength/number tokens, e.g. 'Cetirizine 10mg tablet' -> 'cetirizine tablet'. */
const baseName = (s: string) =>
  normDrug(s)
    .trim()
    .split(' ')
    .filter((t) => t && !/\d/.test(t) && !['mg', 'mcg', 'ml', 'g', 'iu', 'tablet', 'tablets', 'capsule', 'syrup'].includes(t))
    .join(' ');

const ALLERGY_ALIASES: Record<string, string> = { sulfa: 'sulfonamides', sulpha: 'sulfonamides', nsaid: 'nsaids', penicillins: 'penicillins' };

const containsTerm = (name: string, term: string) => normDrug(name).includes(normDrug(term));

/** Classes a drug name belongs to (by whole-word member match). */
export function classesOf(pack: InteractionPackContent, drug: string): string[] {
  return Object.entries(pack.classes)
    .filter(([, members]) => members.some((m) => containsTerm(drug, m)))
    .map(([c]) => c);
}

/** Canonical member names found in a drug name (e.g. "Amoxicillin 500mg" -> ["amoxicillin"]). */
function membersOf(pack: InteractionPackContent, drug: string): string[] {
  return [...new Set(Object.values(pack.classes).flat().filter((m) => containsTerm(drug, m)))];
}

function matchesSide(pack: InteractionPackContent, side: string, drug: string): boolean {
  if (side.startsWith('class:')) return classesOf(pack, drug).includes(side.slice(6));
  return containsTerm(drug, side);
}

const SEV_ORDER = { info: 0, moderate: 1, major: 2 } as const;

/** Pure check against a pack. */
export function checkWithPack(pack: InteractionPackContent, input: CheckInput, source: string): RxWarning[] {
  const out: RxWarning[] = [];
  const push = (w: RxWarning) => {
    const key = `${w.type}|${[...w.drugs].sort().join('+')}|${w.message}`;
    if (!out.some((x) => `${x.type}|${[...x.drugs].sort().join('+')}|${x.message}` === key)) out.push(w);
  };
  const newNames = input.items.map((i) => i.drugName);

  // 1. allergies: the allergy substance vs the drug name and its classes (class map)
  for (const drug of newNames) {
    const drugClasses = classesOf(pack, drug);
    for (const allergy of input.allergies) {
      const allergyClasses = [...new Set([...classesOf(pack, allergy), ...Object.entries(ALLERGY_ALIASES).filter(([k]) => containsTerm(allergy, k)).map(([, c]) => c), ...Object.keys(pack.classes).filter((c) => containsTerm(allergy, c.replace(/_/g, ' ')) || containsTerm(allergy, c.replace(/s$/, '')))])];
      const direct = containsTerm(drug, allergy) || containsTerm(allergy, drug.split(/\s+/)[0] ?? drug);
      const sameClass = drugClasses.find((c) => allergyClasses.includes(c));
      if (direct || sameClass) {
        push({
          severity: 'major',
          type: 'allergy',
          drugs: [drug],
          message: `Recorded allergy to ${allergy}: ${drug}${sameClass ? ` belongs to the same class (${sameClass.replace(/_/g, ' ')})` : ' matches the allergy'}.`,
          source,
        });
        continue;
      }
      const cross = allergyClasses.flatMap((c) => pack.crossReactivity[c] ?? []).find((c) => drugClasses.includes(c));
      if (cross) {
        push({ severity: 'moderate', type: 'allergy', drugs: [drug], message: `Recorded allergy to ${allergy}: possible cross-reactivity with ${cross.replace(/_/g, ' ')} (${drug}).`, source });
      }
    }
  }

  // 2. duplicate therapy: same drug or same class, against active medications and within the new items
  const dup = (a: string, b: string, where: string) => {
    const ma = membersOf(pack, a);
    const mb = membersOf(pack, b);
    const sameDrug = ma.some((m) => mb.includes(m)) || (baseName(a) !== '' && baseName(a) === baseName(b));
    const sharedClass = classesOf(pack, a).find((c) => classesOf(pack, b).includes(c));
    if (sameDrug) push({ severity: 'moderate', type: 'duplicate_therapy', drugs: [a, b], message: `Duplicate therapy: ${a} and ${b} (${where}) contain the same medicine.`, source });
    else if (sharedClass) push({ severity: 'moderate', type: 'duplicate_therapy', drugs: [a, b], message: `Duplicate therapy: ${a} and ${b} (${where}) are both ${sharedClass.replace(/_/g, ' ')}.`, source });
  };
  for (const drug of newNames) for (const active of input.activeMedications) dup(drug, active, 'already active');
  for (let i = 0; i < newNames.length; i++) for (let j = i + 1; j < newNames.length; j++) dup(newNames[i], newNames[j], 'in this prescription');

  // 3. interactions from the pack (new vs new and new vs active)
  const others = [...newNames.map((n) => ({ name: n, active: false })), ...input.activeMedications.map((n) => ({ name: n, active: true }))];
  for (let i = 0; i < newNames.length; i++) {
    for (let j = 0; j < others.length; j++) {
      const o = others[j];
      if (!o.active && j <= i) continue;
      for (const p of pack.pairs) {
        const hit = (matchesSide(pack, p.a, newNames[i]) && matchesSide(pack, p.b, o.name)) || (matchesSide(pack, p.b, newNames[i]) && matchesSide(pack, p.a, o.name));
        if (hit) push({ severity: p.severity, type: 'interaction', drugs: [newNames[i], o.name], message: o.active ? `${p.message} (${o.name} is already active)` : p.message, source });
      }
    }
  }
  return out.sort((a, b) => SEV_ORDER[b.severity] - SEV_ORDER[a.severity]);
}

/** Built-in provider: the active versioned pack from the database (fixture outside production). */
export class PackDrugKnowledgeProvider implements DrugKnowledgeProvider {
  readonly name = 'pack';
  constructor(private readonly config: Config) {}

  async check(db: DbOrTx, input: CheckInput): Promise<CheckResult> {
    const [pack] = await db
      .select()
      .from(clinicalContentPacks)
      .where(and(eq(clinicalContentPacks.kind, 'interactions'), eq(clinicalContentPacks.active, true)))
      .limit(1);
    const status = (pack?.status ?? 'fixture_unapproved') as 'fixture_unapproved' | 'approved';
    const version = pack?.version ?? INTERACTION_PACK_VERSION;
    if (this.config.NODE_ENV === 'production' && status !== 'approved') {
      // Fail safe: never pretend a check happened with unapproved content.
      return {
        warnings: [
          { severity: 'moderate', type: 'interaction', drugs: input.items.map((i) => i.drugName), message: 'Automated interaction checking is unavailable (no approved knowledge pack). Check interactions manually.', source: 'failsafe' },
        ],
        knowledgePack: { version, status },
      };
    }
    const content = (pack?.content as unknown as InteractionPackContent | undefined) ?? INTERACTION_FIXTURE;
    return { warnings: checkWithPack(content, input, version), knowledgePack: { version, status } };
  }
}

/**
 * Licensed drug-database adapter (DRUG_KNOWLEDGE_PROVIDER=http): POST {items, allergies, activeMedications} and
 * expects {warnings: RxWarning[], version}. The exact vendor mapping is done when a database is licensed.
 */
export class HttpDrugKnowledgeProvider implements DrugKnowledgeProvider {
  readonly name = 'http';
  constructor(
    private readonly baseUrl: string,
    private readonly apiKey: string,
    private readonly fetchImpl: FetchLike,
  ) {}
  async check(_db: DbOrTx, input: CheckInput): Promise<CheckResult> {
    const res = await requestJson<{ warnings?: RxWarning[]; version?: string }>(this.fetchImpl, `${this.baseUrl.replace(/\/$/, '')}/interactions/check`, {
      method: 'POST',
      headers: { authorization: `Bearer ${this.apiKey}`, 'content-type': 'application/json' },
      body: JSON.stringify(input),
      timeoutMs: 8000,
    });
    return { warnings: res.warnings ?? [], knowledgePack: { version: res.version ?? 'licensed', status: 'approved' } };
  }
}

/** Allergies and active medications of a patient (active = flag set and not past its end date). */
export async function patientDrugContext(db: DbOrTx, patientId: string): Promise<{ allergies: string[]; activeMedications: string[] }> {
  const today = istDate();
  const [al, meds] = await Promise.all([
    db.select({ s: allergies.substance }).from(allergies).where(eq(allergies.patientId, patientId)),
    db.select().from(medications).where(and(eq(medications.patientId, patientId), eq(medications.active, true))),
  ]);
  return {
    allergies: al.map((a) => a.s),
    activeMedications: meds.filter((m) => !m.endDate || m.endDate >= today).map((m) => `${m.name}${m.dose && !m.name.includes(m.dose) ? ` ${m.dose}` : ''}`),
  };
}
