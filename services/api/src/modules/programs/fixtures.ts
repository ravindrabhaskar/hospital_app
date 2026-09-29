import type { ProgramMetricJson, ThresholdJson } from '../../db/schema.js';

/**
 * FIXTURE PROGRAM TEMPLATES — [REQUIRES CLINICAL GOVERNANCE].
 * Thresholds are conservative placeholders so the software can be exercised end to end. They are NOT clinically
 * validated; production refuses unapproved templates (same model as the safety rule packs, contract section 19).
 */
export const PROGRAM_FIXTURE_VERSION = 'fixture-0.1';
const G = '[REQUIRES CLINICAL GOVERNANCE]';

export interface ProgramFixture {
  code: string;
  name: string;
  description: string;
  metrics: ProgramMetricJson[];
  defaultThresholds: ThresholdJson[];
}

export const PROGRAM_FIXTURES: ProgramFixture[] = [
  {
    code: 'hypertension',
    name: 'Blood pressure monitoring',
    description: `Daily home blood pressure readings reviewed against agreed limits. ${G}`,
    metrics: [
      { type: 'bp_systolic', frequency: 'daily', unit: 'mmHg' },
      { type: 'bp_diastolic', frequency: 'daily', unit: 'mmHg' },
    ],
    defaultThresholds: [
      { type: 'bp_systolic', op: 'gt', value: 160, level: 'urgent', message: `Systolic BP above 160 mmHg: clinician review. ${G}` },
      { type: 'bp_systolic', op: 'gt', value: 180, level: 'emergency', message: `Systolic BP above 180 mmHg: urgent care. ${G}` },
      { type: 'bp_systolic', op: 'lt', value: 90, level: 'urgent', message: `Systolic BP below 90 mmHg: clinician review. ${G}` },
    ],
  },
  {
    code: 'diabetes',
    name: 'Blood sugar monitoring',
    description: `Home glucose readings twice a day reviewed against agreed limits. ${G}`,
    metrics: [{ type: 'blood_glucose', frequency: 'twice_daily', unit: 'mg/dL' }],
    defaultThresholds: [
      { type: 'blood_glucose', op: 'gt', value: 300, level: 'urgent', message: `Blood glucose above 300 mg/dL: clinician review. ${G}` },
      { type: 'blood_glucose', op: 'lt', value: 70, level: 'urgent', message: `Blood glucose below 70 mg/dL (low sugar): follow the hypo plan and review. ${G}` },
      { type: 'blood_glucose', op: 'lt', value: 54, level: 'emergency', message: `Blood glucose below 54 mg/dL: urgent care. ${G}` },
    ],
  },
  {
    code: 'heart_failure',
    name: 'Heart failure monitoring',
    description: `Daily weight, pulse and oxygen saturation. Rapid weight gain needs a clinician's trend review (not an automatic threshold). ${G}`,
    metrics: [
      { type: 'weight', frequency: 'daily', unit: 'kg' },
      { type: 'pulse', frequency: 'daily', unit: 'bpm' },
      { type: 'spo2', frequency: 'daily', unit: '%' },
    ],
    defaultThresholds: [
      { type: 'spo2', op: 'lt', value: 92, level: 'urgent', message: `SpO2 below 92%: clinician review. ${G}` },
      { type: 'spo2', op: 'lt', value: 88, level: 'emergency', message: `SpO2 below 88%: urgent care. ${G}` },
      { type: 'pulse', op: 'gt', value: 120, level: 'urgent', message: `Pulse above 120/min at rest: clinician review. ${G}` },
      { type: 'pulse', op: 'lt', value: 50, level: 'urgent', message: `Pulse below 50/min: clinician review. ${G}` },
    ],
  },
];
