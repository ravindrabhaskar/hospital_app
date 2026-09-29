/**
 * Seed lab catalogue (contract section 44). Pricing is PLACEHOLDER [REQUIRES PRICING VALIDATION]; reference ranges are
 * generic adult ranges used ONLY to draw the mock partner's watermarked SAMPLE report [REQUIRES CLINICAL GOVERNANCE].
 */
export interface LabTestFixture {
  code: string;
  name: string;
  description: string;
  category: string;
  sampleType: 'blood' | 'urine' | 'swab' | 'other';
  fastingRequired: boolean;
  fastingHours: number | null;
  turnaroundHours: number;
  price: number;
  mrp: number;
  sampleRange: { unit: string; low: number; high: number } | null;
}

const P = ' Placeholder price [REQUIRES PRICING VALIDATION].';

export const LAB_TESTS: LabTestFixture[] = [
  { code: 'CBC', name: 'Complete Blood Count (CBC)', description: `Haemoglobin, blood cell counts and platelets.${P}`, category: 'general', sampleType: 'blood', fastingRequired: false, fastingHours: null, turnaroundHours: 12, price: 299, mrp: 400, sampleRange: { unit: 'g/dL (Hb)', low: 12, high: 16 } },
  { code: 'HBA1C', name: 'HbA1c (Glycated Haemoglobin)', description: `Average blood sugar over about 3 months.${P}`, category: 'diabetes', sampleType: 'blood', fastingRequired: false, fastingHours: null, turnaroundHours: 24, price: 449, mrp: 600, sampleRange: { unit: '%', low: 4, high: 5.6 } },
  { code: 'FBS', name: 'Fasting Blood Sugar', description: `Blood glucose after overnight fasting.${P}`, category: 'diabetes', sampleType: 'blood', fastingRequired: true, fastingHours: 10, turnaroundHours: 12, price: 99, mrp: 150, sampleRange: { unit: 'mg/dL', low: 70, high: 99 } },
  { code: 'PPBS', name: 'Post-meal Blood Sugar (PPBS)', description: `Blood glucose 2 hours after a meal.${P}`, category: 'diabetes', sampleType: 'blood', fastingRequired: false, fastingHours: null, turnaroundHours: 12, price: 99, mrp: 150, sampleRange: { unit: 'mg/dL', low: 70, high: 139 } },
  { code: 'LIPID', name: 'Lipid Profile', description: `Total cholesterol, HDL, LDL and triglycerides.${P}`, category: 'heart', sampleType: 'blood', fastingRequired: true, fastingHours: 10, turnaroundHours: 24, price: 499, mrp: 700, sampleRange: { unit: 'mg/dL (total cholesterol)', low: 120, high: 199 } },
  { code: 'LFT', name: 'Liver Function Test (LFT)', description: `Liver enzymes, bilirubin and proteins.${P}`, category: 'organ', sampleType: 'blood', fastingRequired: false, fastingHours: null, turnaroundHours: 24, price: 549, mrp: 750, sampleRange: { unit: 'U/L (ALT)', low: 7, high: 56 } },
  { code: 'KFT', name: 'Kidney Function Test (KFT)', description: `Creatinine, urea and electrolytes.${P}`, category: 'organ', sampleType: 'blood', fastingRequired: false, fastingHours: null, turnaroundHours: 24, price: 549, mrp: 750, sampleRange: { unit: 'mg/dL (creatinine)', low: 0.6, high: 1.2 } },
  { code: 'TSH', name: 'Thyroid Stimulating Hormone (TSH)', description: `Screening test for thyroid function.${P}`, category: 'hormones', sampleType: 'blood', fastingRequired: false, fastingHours: null, turnaroundHours: 24, price: 299, mrp: 450, sampleRange: { unit: 'mIU/L', low: 0.4, high: 4.0 } },
  { code: 'T3T4TSH', name: 'Thyroid Profile (T3, T4, TSH)', description: `Thyroid hormone panel.${P}`, category: 'hormones', sampleType: 'blood', fastingRequired: false, fastingHours: null, turnaroundHours: 24, price: 499, mrp: 700, sampleRange: { unit: 'mIU/L (TSH)', low: 0.4, high: 4.0 } },
  { code: 'VITD', name: 'Vitamin D (25-OH)', description: `Vitamin D level.${P}`, category: 'vitamins', sampleType: 'blood', fastingRequired: false, fastingHours: null, turnaroundHours: 48, price: 899, mrp: 1200, sampleRange: { unit: 'ng/mL', low: 30, high: 100 } },
  { code: 'VITB12', name: 'Vitamin B12', description: `Vitamin B12 level.${P}`, category: 'vitamins', sampleType: 'blood', fastingRequired: false, fastingHours: null, turnaroundHours: 48, price: 699, mrp: 950, sampleRange: { unit: 'pg/mL', low: 200, high: 900 } },
  { code: 'URINE_RE', name: 'Urine Routine & Microscopy', description: `Physical, chemical and microscopic urine examination.${P}`, category: 'general', sampleType: 'urine', fastingRequired: false, fastingHours: null, turnaroundHours: 12, price: 149, mrp: 250, sampleRange: null },
  { code: 'UACR', name: 'Urine Albumin/Creatinine Ratio', description: `Early kidney screening, often for diabetes.${P}`, category: 'diabetes', sampleType: 'urine', fastingRequired: false, fastingHours: null, turnaroundHours: 24, price: 499, mrp: 650, sampleRange: { unit: 'mg/g', low: 0, high: 30 } },
  { code: 'ESR', name: 'Erythrocyte Sedimentation Rate (ESR)', description: `General inflammation marker.${P}`, category: 'general', sampleType: 'blood', fastingRequired: false, fastingHours: null, turnaroundHours: 12, price: 99, mrp: 150, sampleRange: { unit: 'mm/hr', low: 0, high: 20 } },
  { code: 'CRP', name: 'C-Reactive Protein (CRP)', description: `Inflammation marker.${P}`, category: 'general', sampleType: 'blood', fastingRequired: false, fastingHours: null, turnaroundHours: 24, price: 399, mrp: 550, sampleRange: { unit: 'mg/L', low: 0, high: 5 } },
  { code: 'IRON', name: 'Iron Studies', description: `Serum iron, TIBC and ferritin.${P}`, category: 'general', sampleType: 'blood', fastingRequired: true, fastingHours: 8, turnaroundHours: 48, price: 799, mrp: 1100, sampleRange: { unit: 'ng/mL (ferritin)', low: 30, high: 300 } },
  { code: 'ELECTRO', name: 'Serum Electrolytes', description: `Sodium, potassium and chloride.${P}`, category: 'organ', sampleType: 'blood', fastingRequired: false, fastingHours: null, turnaroundHours: 12, price: 349, mrp: 450, sampleRange: { unit: 'mmol/L (potassium)', low: 3.5, high: 5.1 } },
  { code: 'URIC', name: 'Uric Acid', description: `Serum uric acid.${P}`, category: 'organ', sampleType: 'blood', fastingRequired: false, fastingHours: null, turnaroundHours: 12, price: 149, mrp: 250, sampleRange: { unit: 'mg/dL', low: 3.5, high: 7.2 } },
  { code: 'PSA', name: 'Prostate Specific Antigen (PSA)', description: `Discuss with a doctor before screening.${P}`, category: 'screening', sampleType: 'blood', fastingRequired: false, fastingHours: null, turnaroundHours: 48, price: 699, mrp: 900, sampleRange: { unit: 'ng/mL', low: 0, high: 4 } },
  { code: 'COVID_RTPCR', name: 'COVID-19 RT-PCR (swab)', description: `Nasal/throat swab test.${P}`, category: 'infection', sampleType: 'swab', fastingRequired: false, fastingHours: null, turnaroundHours: 24, price: 499, mrp: 700, sampleRange: null },
];

export const LAB_PACKAGES = [
  { code: 'DIABETES_CARE', name: 'Diabetes Care Package', tests: ['FBS', 'PPBS', 'HBA1C', 'UACR', 'KFT'], price: 1299, mrp: 1950, description: 'Sugar control, kidney screening. Placeholder price [REQUIRES PRICING VALIDATION].' },
  { code: 'HEART_CHECK', name: 'Heart Health Check', tests: ['LIPID', 'FBS', 'CRP', 'ELECTRO'], price: 999, mrp: 1450, description: 'Cholesterol and related markers. Placeholder price [REQUIRES PRICING VALIDATION].' },
  { code: 'SENIOR_BASIC', name: 'Senior Citizen Basic Checkup', tests: ['CBC', 'FBS', 'LIPID', 'LFT', 'KFT', 'TSH', 'URINE_RE', 'VITD'], price: 1999, mrp: 3500, description: 'A broad annual check for adults over 60. Placeholder price [REQUIRES PRICING VALIDATION].' },
  { code: 'FEVER_PANEL', name: 'Fever Panel', tests: ['CBC', 'ESR', 'CRP', 'URINE_RE'], price: 649, mrp: 950, description: 'Common tests a doctor may order for fever. Placeholder price [REQUIRES PRICING VALIDATION].' },
];
