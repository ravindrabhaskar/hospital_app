/**
 * FIXTURE PREVENTIVE SCHEDULES `preventive-fixture-0.1` — [REQUIRES CLINICAL GOVERNANCE].
 * A simplified child immunisation schedule in the style of the IAP schedule plus common adult screenings, so the
 * software can be exercised. Not complete; not a substitute for a clinician's advice.
 */
export const PREVENTIVE_PACK_VERSION = 'preventive-fixture-0.1';

export interface PreventiveDef {
  code: string;
  name: string;
  category: 'vaccine' | 'screening';
  description: string;
  sex: 'any' | 'male' | 'female';
  /** Applicable age range in months (inclusive). */
  minAgeMonths: number;
  maxAgeMonths: number | null;
  /** For scheduled vaccines: the recommended age in months. Screenings are due from minAgeMonths. */
  dueAgeMonths: number | null;
  repeatEveryMonths: number | null;
}

const G = '[REQUIRES CLINICAL GOVERNANCE]';
const child = (code: string, name: string, dueAgeMonths: number, description: string, maxAgeMonths = 72): PreventiveDef => ({
  code,
  name,
  category: 'vaccine',
  description: `${description} ${G}`,
  sex: 'any',
  minAgeMonths: 0,
  maxAgeMonths,
  dueAgeMonths,
  repeatEveryMonths: null,
});

export const PREVENTIVE_FIXTURE: PreventiveDef[] = [
  child('bcg', 'BCG', 0, 'Given at birth.', 12),
  child('hepb_birth', 'Hepatitis B (birth dose)', 0, 'Given at birth.', 12),
  child('opv0', 'OPV (birth dose)', 0, 'Oral polio vaccine at birth.', 12),
  child('dtp_hib_ipv_hepb_1', 'DTP-Hib-IPV-HepB dose 1', 1.5, 'Combination vaccine at 6 weeks.'),
  child('rota_1', 'Rotavirus dose 1', 1.5, 'At 6 weeks.', 12),
  child('pcv_1', 'Pneumococcal conjugate (PCV) dose 1', 1.5, 'At 6 weeks.', 24),
  child('dtp_hib_ipv_hepb_2', 'DTP-Hib-IPV-HepB dose 2', 2.5, 'Combination vaccine at 10 weeks.'),
  child('dtp_hib_ipv_hepb_3', 'DTP-Hib-IPV-HepB dose 3', 3.5, 'Combination vaccine at 14 weeks.'),
  child('mmr_1', 'MMR dose 1', 9, 'Measles, mumps, rubella at 9 months.'),
  child('tcv', 'Typhoid conjugate vaccine', 9, 'From 9 months.'),
  child('hepa_1', 'Hepatitis A dose 1', 12, 'From 12 months.'),
  child('mmr_2', 'MMR dose 2', 15, 'At 15 months.'),
  child('varicella_1', 'Varicella dose 1', 15, 'At 15 months.'),
  child('dtp_booster_1', 'DTP booster 1', 16, 'At 16-18 months.'),
  child('dtp_booster_2', 'DTP booster 2', 48, 'At 4-6 years.', 96),
  { code: 'tdap_10', name: 'Tdap', category: 'vaccine', description: `Tetanus, diphtheria, pertussis booster at 10-12 years. ${G}`, sex: 'any', minAgeMonths: 120, maxAgeMonths: 216, dueAgeMonths: 120, repeatEveryMonths: null },
  { code: 'hpv', name: 'HPV vaccine', category: 'vaccine', description: `From 9 years; discuss the schedule with your doctor. ${G}`, sex: 'any', minAgeMonths: 108, maxAgeMonths: 312, dueAgeMonths: 108, repeatEveryMonths: null },
  // ---- adults
  { code: 'bp_screen', name: 'Blood pressure check', category: 'screening', description: `Adults: at least once a year. ${G}`, sex: 'any', minAgeMonths: 216, maxAgeMonths: null, dueAgeMonths: null, repeatEveryMonths: 12 },
  { code: 'glucose_screen', name: 'Blood sugar screening', category: 'screening', description: `Adults 30 and over: every 3 years, or as advised. ${G}`, sex: 'any', minAgeMonths: 360, maxAgeMonths: null, dueAgeMonths: null, repeatEveryMonths: 36 },
  { code: 'lipid_screen', name: 'Cholesterol (lipid profile)', category: 'screening', description: `Adults 40 and over: every 5 years, or as advised. ${G}`, sex: 'any', minAgeMonths: 480, maxAgeMonths: null, dueAgeMonths: null, repeatEveryMonths: 60 },
  { code: 'cervical_screen', name: 'Cervical cancer screening', category: 'screening', description: `Women 30-65: every 5 years (as advised by your doctor). ${G}`, sex: 'female', minAgeMonths: 360, maxAgeMonths: 780, dueAgeMonths: null, repeatEveryMonths: 60 },
  { code: 'breast_screen', name: 'Breast cancer screening', category: 'screening', description: `Women 40-74: every 2 years (as advised by your doctor). ${G}`, sex: 'female', minAgeMonths: 480, maxAgeMonths: 888, dueAgeMonths: null, repeatEveryMonths: 24 },
  { code: 'colorectal_screen', name: 'Bowel (colorectal) cancer screening', category: 'screening', description: `Adults 45-75: stool test every year, or as advised. ${G}`, sex: 'any', minAgeMonths: 540, maxAgeMonths: 900, dueAgeMonths: null, repeatEveryMonths: 12 },
  { code: 'td_adult', name: 'Tetanus-diphtheria (Td) booster', category: 'vaccine', description: `Adults: every 10 years. ${G}`, sex: 'any', minAgeMonths: 228, maxAgeMonths: null, dueAgeMonths: null, repeatEveryMonths: 120 },
  { code: 'influenza_65', name: 'Influenza vaccine', category: 'vaccine', description: `Adults 65 and over: every year. ${G}`, sex: 'any', minAgeMonths: 780, maxAgeMonths: null, dueAgeMonths: null, repeatEveryMonths: 12 },
  { code: 'pneumococcal_65', name: 'Pneumococcal vaccine', category: 'vaccine', description: `Adults 65 and over (as advised by your doctor). ${G}`, sex: 'any', minAgeMonths: 780, maxAgeMonths: null, dueAgeMonths: null, repeatEveryMonths: null },
];
