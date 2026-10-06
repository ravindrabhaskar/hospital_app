/**
 * Structured intake: maps dialogue into typed fields with per-field provenance.
 * Invariant: a value is only ever set from (a) the user's own words, (b) the patient's authorized
 * record, or (c) a model extraction that is verified to be grounded in the user's words.
 * Nothing is invented.
 */
import { containsKeyword, normalizeText } from '../safety/engine.js';

export interface IntakeField<T> {
  value: T | null;
  source: 'user' | 'record' | 'model_extraction' | null;
  confidence: number | null;
}

export interface Intake {
  chiefComplaint: IntakeField<string>;
  durationText: IntakeField<string>;
  severity: IntakeField<number>;
  associatedSymptoms: IntakeField<string[]>;
  relevantHistory: IntakeField<string[]>;
  currentMedications: IntakeField<string[]>;
  allergies: IntakeField<string[]>;
  missingFields: string[];
  complete: boolean;
  /**
   * Monotonic question progress over the fixed ASKED_FIELDS list: `answered` only grows and
   * `step` is the 1-based number of the question being asked (= total once complete).
   */
  progress: { step: number; total: number; answered: number };
}

export const ASKED_FIELDS = ['chiefComplaint', 'durationText', 'severity', 'associatedSymptoms'] as const;
export type AskedField = (typeof ASKED_FIELDS)[number];

const empty = <T>(): IntakeField<T> => ({ value: null, source: null, confidence: null });

export function emptyIntake(): Intake {
  const i: Intake = {
    chiefComplaint: empty(),
    durationText: empty(),
    severity: empty(),
    associatedSymptoms: empty(),
    relevantHistory: empty(),
    currentMedications: empty(),
    allergies: empty(),
    missingFields: [],
    complete: false,
    progress: { step: 1, total: ASKED_FIELDS.length, answered: 0 },
  };
  return finalize(i);
}

export function finalize(i: Intake): Intake {
  i.missingFields = ASKED_FIELDS.filter((f) => i[f].value === null);
  i.complete = i.missingFields.length === 0;
  const total = ASKED_FIELDS.length;
  const answered = total - i.missingFields.length;
  i.progress = { step: Math.min(answered + 1, total), total, answered };
  return i;
}

/** Symptom lexicon used only to recognise words the user actually typed. */
export const SYMPTOM_TERMS = [
  'headache',
  'migraine',
  'fever',
  'cough',
  'cold',
  'sore throat',
  'runny nose',
  'body ache',
  'body pain',
  'back pain',
  'joint pain',
  'knee pain',
  'stomach ache',
  'stomach pain',
  'abdominal pain',
  'chest pain',
  'vomiting',
  'nausea',
  'diarrhea',
  'diarrhoea',
  'constipation',
  'dizziness',
  'dizzy',
  'fatigue',
  'tiredness',
  'weakness',
  'rash',
  'itching',
  'acne',
  'breathlessness',
  'shortness of breath',
  'palpitations',
  'anxiety',
  'low mood',
  'sleeplessness',
  'insomnia',
  'ear pain',
  'toothache',
  'burning urination',
  'swelling',
  'wound',
  'bleeding',
  'chills',
  'loss of appetite',
];

const NEGATIVE = /^(no|nope|none|nothing|nothing else|no other symptoms?|not really|nah|no,? that'?s it)\.?$/i;

export function findSymptoms(text: string): string[] {
  const norm = normalizeText(text);
  const found = SYMPTOM_TERMS.filter((t) => containsKeyword(norm, t));
  // Drop terms contained in a longer matched term ("pain" inside "chest pain", "dizzy" vs "dizziness").
  return found.filter((t) => !found.some((o) => o !== t && o.includes(t)));
}

const NUM_WORD = '(?:\\d+|a|an|one|two|three|four|five|six|seven|few|a few|several|couple of|a couple of)';
const UNIT = '(?:minutes?|hours?|hrs?|days?|weeks?|months?|years?)';
const DURATION_PATTERNS: RegExp[] = [
  new RegExp(`\\b(?:since|from)\\s+(?:yesterday|last night|this morning|morning|today|last week|last month|${NUM_WORD}\\s+${UNIT}(?:\\s+ago)?)`, 'i'),
  new RegExp(`\\b(?:for|past|last)\\s+(?:the\\s+)?(?:past\\s+|last\\s+)?${NUM_WORD}\\s+${UNIT}`, 'i'),
  new RegExp(`\\b${NUM_WORD}\\s+${UNIT}(?:\\s+ago)?\\b`, 'i'),
  /\b(?:since\s+)?(?:yesterday|last night|this morning|today)\b/i,
];

export function findDuration(text: string): string | null {
  for (const re of DURATION_PATTERNS) {
    const m = text.match(re);
    if (m) return m[0].trim();
  }
  return null;
}

export function findSeverity(text: string, asked: boolean): number | null {
  const explicit = text.match(/\b(\d{1,2})\s*(?:\/|out of)\s*10\b/i) ?? text.match(/\b(?:severity|pain level|pain)\s*(?:is|of|:|=)?\s*(\d{1,2})\b/i);
  if (explicit) {
    const n = Number(explicit[1]);
    if (n >= 0 && n <= 10) return n;
  }
  if (asked) {
    const nums = [...text.matchAll(/\b(\d{1,2})\b/g)].map((m) => Number(m[1])).filter((n) => n >= 0 && n <= 10);
    if (nums.length === 1) return nums[0];
    const word = severityFromWords(text);
    if (word !== null) return word;
  }
  return null;
}

/** Unambiguous severity words, safe to recognise even when another question was asked. */
const STRICT_SEVERITY = /^\W*(very\s+)?(mild|moderate|severe)\b/i;

const NUMBER_WORDS = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten'];

/**
 * Typed severity answers ("Moderate", "quite severe", "very mild", "seven"). Case-insensitive.
 * Values match the quick replies: mild 3, moderate 5, severe 8.
 */
export function severityFromWords(text: string): number | null {
  const n = text.toLowerCase();
  const w = /\b(zero|one|two|three|four|five|six|seven|eight|nine|ten)\b/.exec(n);
  if (w) return NUMBER_WORDS.indexOf(w[1]);
  if (/\b(unbearable|worst|excruciating|extreme|extremely|very (?:severe|bad|strong|painful))\b/.test(n)) return 9;
  if (/\b(severe|serious|bad|strong|intense|high)\b/.test(n)) return 8;
  if (/\b(moderate|moderately|medium|average|manageable)\b/.test(n)) return 5;
  if (/\b(very mild|barely|slight|slightly|minimal)\b/.test(n)) return 2;
  if (/\b(mild|low|light|little)\b/.test(n)) return 3;
  if (/^\s*(none|no pain|nothing)\b/.test(n)) return 0;
  return null;
}

/** Older stored intakes lack `progress`; recompute derived fields before returning them. */
export function normalizeIntake(i: Intake): Intake {
  return finalize(JSON.parse(JSON.stringify(i)) as Intake);
}

export function findAllergies(text: string): string[] {
  const m = text.match(/\ballergic to\s+([a-z][a-z\s,-]{1,60})/i);
  if (!m) return [];
  return m[1]
    .split(/,|\band\b/)
    .map((s) => s.trim().replace(/[.!]+$/, ''))
    .filter(Boolean)
    .slice(0, 5);
}

const userField = <T>(value: T, confidence = 1): IntakeField<T> => ({ value, source: 'user', confidence });

/**
 * Deterministic extraction for one user message.
 * `asked` is the field the assistant most recently asked for (if any).
 */
export function extractFromMessage(prev: Intake, text: string, asked: AskedField | null): Intake {
  const i: Intake = JSON.parse(JSON.stringify(prev));
  const trimmed = text.trim().slice(0, 300);
  const symptoms = findSymptoms(trimmed);

  if (i.chiefComplaint.value === null) {
    if (symptoms.length) {
      i.chiefComplaint = userField(symptoms[0], 0.9);
    } else if ((asked === 'chiefComplaint' || asked === null) && trimmed.length >= 3 && !NEGATIVE.test(trimmed)) {
      i.chiefComplaint = userField(trimmed, 0.6);
    }
  }
  const chief = i.chiefComplaint.value?.toLowerCase() ?? '';
  const extraSymptoms = symptoms.filter((s) => s !== chief && !chief.includes(s));

  if (i.durationText.value === null) {
    const d = findDuration(trimmed);
    // A severity-style answer ("Moderate") typed while we asked for duration is not a duration.
    const looksLikeSeverity = !d && (STRICT_SEVERITY.test(trimmed) || /\b\d{1,2}\s*(?:\/|out of)\s*10\b/i.test(trimmed));
    if (asked === 'durationText' && trimmed.length > 0 && trimmed.length <= 60 && !NEGATIVE.test(trimmed) && !looksLikeSeverity) {
      i.durationText = userField(trimmed, d ? 1 : 0.7);
    } else if (d) i.durationText = userField(d);
  }

  if (i.severity.value === null) {
    // Also accept a typed severity word when it was the whole answer to the (previous) duration question.
    const s =
      findSeverity(trimmed, asked === 'severity') ??
      (asked === 'durationText' && i.durationText.value === null && trimmed.length <= 40 && STRICT_SEVERITY.test(trimmed) ? severityFromWords(trimmed) : null);
    if (s !== null) i.severity = userField(s);
  }

  if (extraSymptoms.length) {
    const existing = i.associatedSymptoms.source === 'user' ? (i.associatedSymptoms.value ?? []) : [];
    i.associatedSymptoms = userField([...new Set([...existing, ...extraSymptoms])]);
  } else if (asked === 'associatedSymptoms' && i.associatedSymptoms.value === null) {
    if (NEGATIVE.test(trimmed)) i.associatedSymptoms = userField([]);
    else if (trimmed.length > 0 && trimmed.length <= 120) i.associatedSymptoms = userField([trimmed], 0.6);
  }

  const allergies = findAllergies(trimmed);
  if (allergies.length) {
    const existing = i.allergies.value ?? [];
    i.allergies = { value: [...new Set([...existing, ...allergies])], source: 'user', confidence: 0.9 };
  }
  return finalize(i);
}

/** Pre-fill history / medications / allergies from the patient's authorized record. */
export function prefillFromRecord(i: Intake, ctx: { conditions: string[]; medications: string[]; allergies: string[] }): Intake {
  const out: Intake = JSON.parse(JSON.stringify(i));
  if (out.relevantHistory.value === null && ctx.conditions.length) out.relevantHistory = { value: ctx.conditions, source: 'record', confidence: 1 };
  if (out.currentMedications.value === null && ctx.medications.length) out.currentMedications = { value: ctx.medications, source: 'record', confidence: 1 };
  if (out.allergies.value === null && ctx.allergies.length) out.allergies = { value: ctx.allergies, source: 'record', confidence: 1 };
  return finalize(out);
}

/**
 * Merge a model's proposed extraction, accepting ONLY values grounded in the user's own words.
 * Hallucinated values (not present in user text) are dropped.
 */
export function mergeGroundedExtraction(i: Intake, proposed: unknown, userText: string): Intake {
  if (!proposed || typeof proposed !== 'object') return i;
  const p = proposed as Record<string, unknown>;
  const out: Intake = JSON.parse(JSON.stringify(i));
  const norm = normalizeText(userText);
  const grounded = (s: unknown): s is string => typeof s === 'string' && s.trim().length > 1 && containsKeyword(norm, s);
  const model = <T>(value: T): IntakeField<T> => ({ value, source: 'model_extraction', confidence: 0.7 });

  if (out.chiefComplaint.value === null && grounded(p.chiefComplaint)) out.chiefComplaint = model(p.chiefComplaint.trim());
  if (out.durationText.value === null && grounded(p.durationText)) out.durationText = model(p.durationText.trim());
  if (out.severity.value === null && typeof p.severity === 'number' && Number.isInteger(p.severity) && p.severity >= 0 && p.severity <= 10) {
    if (new RegExp(`(^|\\D)${p.severity}(\\D|$)`).test(userText)) out.severity = model(p.severity);
  }
  const groundedList = (v: unknown): string[] => (Array.isArray(v) ? v.filter(grounded).map((s) => s.trim()) : []);
  if (out.associatedSymptoms.value === null) {
    const l = groundedList(p.associatedSymptoms);
    if (l.length) out.associatedSymptoms = model(l);
  }
  for (const key of ['relevantHistory', 'currentMedications', 'allergies'] as const) {
    const l = groundedList(p[key]);
    if (!l.length) continue;
    const cur = out[key];
    if (cur.value === null) out[key] = model(l);
    else if (cur.source !== 'record') out[key] = { ...cur, value: [...new Set([...cur.value, ...l])] };
  }
  return finalize(out);
}

export function nextQuestion(i: Intake): AskedField | null {
  return (i.missingFields[0] as AskedField | undefined) ?? null;
}

export const QUICK_REPLIES: Record<AskedField, string[]> = {
  chiefComplaint: ['Fever', 'Headache', 'Cough or cold', 'Stomach pain', 'Skin problem'],
  durationText: ['Since today', 'Since yesterday', '2-3 days', 'More than a week'],
  severity: ['Mild (3/10)', 'Moderate (5/10)', 'Severe (8/10)'],
  associatedSymptoms: ['No other symptoms', 'Fever', 'Nausea', 'Dizziness', 'Body ache'],
};

/** Specialty suggestion from the user's complaint words (routing hint only, not a diagnosis). */
export function suggestSpecialty(text: string, ageYears: number | null): string {
  const n = normalizeText(text);
  const has = (...ks: string[]) => ks.some((k) => containsKeyword(n, k));
  if (ageYears !== null && ageYears < 14) return 'pediatrician';
  if (has('rash', 'itching', 'acne', 'skin', 'pimple', 'hair fall')) return 'dermatologist';
  if (has('anxiety', 'low mood', 'depressed', 'sleeplessness', 'insomnia', 'panic', 'stress')) return 'psychiatrist';
  if (has('ear pain', 'sore throat', 'sinus', 'ear', 'throat', 'nose bleed')) return 'ent';
  if (has('joint pain', 'knee pain', 'back pain', 'fracture', 'sprain', 'shoulder pain')) return 'orthopedist';
  if (has('palpitations', 'heart')) return 'cardiologist';
  if (has('sugar', 'diabetes', 'thirst', 'blood sugar')) return 'diabetologist';
  if (has('period', 'periods', 'pregnant', 'pregnancy', 'white discharge', 'pcos')) return 'gynecologist';
  if (has('numbness', 'seizure', 'fits', 'tremor')) return 'neurologist';
  return 'general_physician';
}
