/**
 * Dev seed (contract §20). SYNTHETIC TEST DATA ONLY — no real patients.
 *   npm run seed           -> seeds if empty (idempotent)
 *   npm run seed -- --reset -> wipes the dev database + files, re-migrates and seeds
 */
import { randomUUID } from 'node:crypto';
import { rm } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { eq, sql } from 'drizzle-orm';
import { loadConfig } from '../config.js';
import { istDate, istToUtc, addDays } from '../lib/time.js';
import { issuePrescription } from '../modules/prescriptions/service.js';
import { renderReferralPdf } from '../modules/referrals/routes.js';
import { DEFAULT_WEEKLY, regenerateSlots } from '../modules/schedules/service.js';
import { SCHEME_DISCLAIMER } from '../modules/schemes/routes.js';
import { DEFAULT_FLAGS } from '../modules/flags/service.js';
import { KnowledgeService } from '../modules/knowledge/service.js';
import { FIXTURE_PACK_VERSION, FIXTURE_RULES } from '../modules/safety/engine.js';
import { CONSENT_CATALOG } from '../modules/consent/catalog.js';
import type { StorageAdapter } from '../modules/records/storage.js';
import { createStorage } from '../modules/records/storage-factory.js';
import { storeRecord } from '../modules/records/service.js';
import { createDb, runMigrations, type Db } from './client.js';
import * as s from './schema.js';
import { seedV13 } from './seed-v13.js';

export const SEED_PHONES = {
  vaibhav: '+919800000001',
  lakshmi: '+919800000002',
  ananya: '+919800000101',
  karthik: '+919800000102',
  priya: '+919800000103',
  arjun: '+919800000104',
  sunita: '+919800000201',
  ravi: '+919800000202',
  anil: '+919800000203',
  meera: '+919800000301',
  ops: '+919800000401',
  admin: '+919800000501',
  kavya: '+919800000601',
  // v1.3
  hospitalDesk: '+919800000701',
  support: '+919800000801',
} as const;

const SPECIALTIES = [
  ['general_physician', 'General Physician', 'stethoscope'],
  ['dermatologist', 'Dermatologist', 'sparkles'],
  ['pediatrician', 'Pediatrician', 'baby'],
  ['gynecologist', 'Gynecologist', 'female'],
  ['cardiologist', 'Cardiologist', 'heart'],
  ['orthopedist', 'Orthopedist', 'bone'],
  ['psychiatrist', 'Psychiatrist', 'brain'],
  ['ent', 'ENT Specialist', 'ear'],
  ['diabetologist', 'Diabetologist', 'droplet'],
  ['neurologist', 'Neurologist', 'activity'],
] as const;

const HOME_SERVICES = [
  { code: 'vitals_check', name: 'Vitals check at home', description: 'A nurse checks BP, pulse, SpO2, temperature and blood sugar at home.', price: 499, durationMins: 30, icon: 'heart-pulse' },
  { code: 'sample_collection', name: 'Lab sample collection', description: 'A trained phlebotomist collects blood/urine samples at home.', price: 399, durationMins: 20, icon: 'test-tube' },
  { code: 'elderly_care', name: 'Elderly care visit', description: 'A nurse visit for older adults: vitals, mobility and medication review.', price: 799, durationMins: 60, icon: 'user-heart' },
  { code: 'post_report_consult', name: 'Post-report home consult', description: 'A nurse reviews your recent report with you and connects you to a doctor.', price: 599, durationMins: 45, icon: 'file-heart' },
  // v1.3 (contract section 53); also inserted by migration 0005 for existing databases.
  { code: 'physiotherapy', name: 'Physiotherapy at home', description: 'A physiotherapist assesses mobility and teaches a home exercise program.', price: 699, durationMins: 45, icon: 'activity' },
];

const PRODUCTS = [
  { name: 'Paracetamol 500mg', packSize: 'Strip of 15 tablets', mrp: 35, price: 30, category: 'fever_pain', requiresPrescription: false },
  { name: 'Vitamin D3 60K', packSize: '4 capsules', mrp: 140, price: 120, category: 'vitamins', requiresPrescription: false },
  { name: 'Azithromycin 500mg', packSize: 'Strip of 3 tablets', mrp: 72, price: 60, category: 'antibiotics', requiresPrescription: true },
  { name: 'Cetirizine 10mg', packSize: 'Strip of 10 tablets', mrp: 30, price: 25, category: 'personal_care', requiresPrescription: false },
  { name: 'ORS Sachet (Orange)', packSize: '21g sachet', mrp: 22, price: 20, category: 'fever_pain', requiresPrescription: false },
  { name: 'Metformin 500mg', packSize: 'Strip of 20 tablets', mrp: 52, price: 45, category: 'diabetes', requiresPrescription: true },
  { name: 'Amlodipine 5mg', packSize: 'Strip of 15 tablets', mrp: 48, price: 40, category: 'heart_bp', requiresPrescription: true },
  { name: 'Digital Thermometer', packSize: '1 unit', mrp: 250, price: 199, category: 'devices', requiresPrescription: false },
  { name: 'Pulse Oximeter', packSize: '1 unit', mrp: 1299, price: 999, category: 'devices', requiresPrescription: false },
  { name: 'Glucometer Test Strips', packSize: '50 strips', mrp: 750, price: 650, category: 'diabetes', requiresPrescription: false },
  { name: 'Vitamin C 500mg Chewable', packSize: '15 tablets', mrp: 110, price: 90, category: 'vitamins', requiresPrescription: false },
  { name: 'Hand Sanitizer', packSize: '500 ml', mrp: 180, price: 150, category: 'personal_care', requiresPrescription: false },
];

const FACILITIES = [
  { name: 'CareCompanion Partner Clinic', type: 'clinic', address: 'Road No. 12, Banjara Hills', area: 'Banjara Hills', lat: 17.4156, lng: 78.4347, services: ['General medicine', 'Dermatology', 'Teleconsultation'], emergency24x7: false },
  { name: 'Deccan Sunrise Multispeciality Hospital', type: 'hospital', address: 'Raj Bhavan Road, Somajiguda', area: 'Somajiguda', lat: 17.4239, lng: 78.4575, services: ['Emergency', 'Cardiology', 'ICU', 'Radiology'], emergency24x7: true },
  { name: 'Charminar City General Hospital', type: 'hospital', address: 'Abids Main Road', area: 'Abids', lat: 17.3924, lng: 78.4747, services: ['Emergency', 'General surgery', 'Paediatrics'], emergency24x7: true },
  { name: 'Himayat Diagnostics Lab', type: 'lab', address: 'Street No. 5, Himayatnagar', area: 'Himayatnagar', lat: 17.401, lng: 78.487, services: ['Blood tests', 'ECG', 'X-Ray'], emergency24x7: false },
  { name: 'Kukatpally Family Clinic', type: 'clinic', address: 'KPHB Colony, Kukatpally', area: 'Kukatpally', lat: 17.4849, lng: 78.4138, services: ['General medicine', 'Paediatrics'], emergency24x7: false },
  { name: 'Ameerpet 24x7 Pharmacy', type: 'pharmacy', address: 'Main Road, Ameerpet', area: 'Ameerpet', lat: 17.4375, lng: 78.4482, services: ['Medicines', 'Home delivery'], emergency24x7: false },
];

const KNOWLEDGE = [
  {
    title: 'Staying hydrated',
    content:
      'Drinking enough water through the day helps your body regulate temperature and supports overall wellbeing. Sip water regularly rather than all at once.\n\nDuring fever, headache or hot weather, people often need more fluids. Oral rehydration solution (ORS) can help replace salts lost through sweating, vomiting or loose stools.\n\nSigns you may need more fluids include dark urine, dry mouth and feeling light-headed. If fluids cannot be kept down, speak to a doctor.',
  },
  {
    title: 'Healthy sleep habits',
    content:
      'Most adults feel best with 7 to 9 hours of sleep. Going to bed and waking up at the same time each day helps your body keep a steady rhythm.\n\nReduce screens and bright light for an hour before bed, keep the room cool and dark, and avoid heavy meals, tea or coffee late in the evening.\n\nRest in a quiet, dim room can also help when you have a headache or feel unwell. If sleep problems last for weeks, discuss them with a doctor.',
  },
  {
    title: 'Managing everyday stress',
    content:
      'Short breathing exercises, such as breathing in for four seconds and out for six seconds, can help you feel calmer within a few minutes.\n\nRegular movement like a 20 to 30 minute walk, time with friends or family, and limiting news and social media can ease day-to-day stress.\n\nIf you feel low or anxious most days, or have thoughts of harming yourself, please reach out to a doctor, a counsellor or a helpline such as Tele-MANAS (14416).',
  },
];

/** Minimal valid PDF with a text line (synthetic sample document). */
export function samplePdf(title: string): Buffer {
  const text = `SAMPLE DOCUMENT - synthetic test data - ${title}`.replace(/[()\\]/g, '');
  const stream = `BT /F1 12 Tf 50 750 Td (${text}) Tj ET`;
  const objs = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
    `<< /Length ${stream.length} >>\nstream\n${stream}\nendstream`,
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  let out = '%PDF-1.4\n';
  const offsets: number[] = [];
  objs.forEach((o, i) => {
    offsets.push(out.length);
    out += `${i + 1} 0 obj\n${o}\nendobj\n`;
  });
  const xref = out.length;
  out += `xref\n0 ${objs.length + 1}\n0000000000 65535 f \n${offsets.map((o) => `${String(o).padStart(10, '0')} 00000 n \n`).join('')}`;
  out += `trailer\n<< /Size ${objs.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(out, 'latin1');
}

/** 1x1 PNG (synthetic image placeholder). */
export const SAMPLE_PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  'base64',
);

export async function isSeeded(db: Db): Promise<boolean> {
  const [u] = await db.select({ id: s.users.id }).from(s.users).where(eq(s.users.phone, SEED_PHONES.vaibhav));
  return !!u;
}

export async function seedDatabase(db: Db, storage: StorageAdapter, now = new Date()): Promise<void> {
  const today = istDate(now);
  const horizonDays = Number(process.env.SCHEDULE_HORIZON_DAYS) || 14;
  const daysAgo = (d: number, hhmm = '10:00') => istToUtc(addDays(today, -d), hhmm);

  // ---- catalog
  for (const [code, name, icon] of SPECIALTIES) await db.insert(s.specialties).values({ code, name, icon }).onConflictDoNothing();
  for (const f of DEFAULT_FLAGS) await db.insert(s.featureFlags).values(f).onConflictDoNothing();
  for (const hs of HOME_SERVICES) await db.insert(s.homeVisitServices).values(hs).onConflictDoNothing();
  for (const p of PRODUCTS) await db.insert(s.products).values(p);
  const facilityRows: Array<typeof s.facilities.$inferSelect> = [];
  for (const [i, f] of FACILITIES.entries()) {
    const [row] = await db.insert(s.facilities).values({ ...f, city: 'Hyderabad', phone: `+9140400000${i + 1}0`, verified: true }).returning();
    facilityRows.push(row);
  }
  const pincodes = [...Array.from({ length: 40 }, (_, i) => String(500001 + i)), '500081', '500082', '500084'];
  const [zone] = await db.insert(s.serviceZones).values({ name: 'Hyderabad-Central', city: 'Hyderabad', pincodes }).returning();

  // ---- users
  const mkUser = async (phone: string, name: string, roles: s.Role[]) => {
    const [u] = await db.insert(s.users).values({ phone, name, roles, lastLoginAt: null }).returning();
    await db.insert(s.notificationPreferences).values({ userId: u.id });
    return u;
  };
  const consent = async (userId: string, purposes: string[]) => {
    for (const p of purposes) {
      const c = CONSENT_CATALOG.find((x) => x.purpose === p)!;
      await db.insert(s.consents).values({ userId, purpose: p, version: c.version, scope: c.scope, status: 'granted', grantedAt: daysAgo(30) });
    }
  };
  const REQUIRED = ['terms', 'privacy', 'health_data_processing'];

  const vaibhav = await mkUser(SEED_PHONES.vaibhav, 'Vaibhav Kumar', ['patient']);
  const [vSelf] = await db
    .insert(s.patients)
    .values({ name: 'Vaibhav Kumar', dob: '2002-03-14', gender: 'male', phone: vaibhav.phone, bloodGroup: 'O+', heightCm: 176, weightKg: 70, userId: vaibhav.id, ownerUserId: vaibhav.id, ownerRelation: 'self' })
    .returning();
  await db.update(s.users).set({ selfPatientId: vSelf.id }).where(eq(s.users.id, vaibhav.id));
  await consent(vaibhav.id, CONSENT_CATALOG.map((c) => c.purpose));

  const [ramesh] = await db
    .insert(s.patients)
    .values({ name: 'Ramesh Kumar', dob: '1958-01-20', gender: 'male', phone: null, bloodGroup: 'B+', heightCm: 168, weightKg: 74, ownerUserId: vaibhav.id, ownerRelation: 'father' })
    .returning();
  await db.insert(s.conditions).values([
    { patientId: ramesh.id, name: 'Hypertension', since: '2015', source: 'clinician_verified' },
    { patientId: ramesh.id, name: 'Type 2 diabetes', since: '2018', source: 'clinician_verified' },
  ]);
  await db.insert(s.allergies).values({ patientId: ramesh.id, substance: 'Penicillin', reaction: 'Skin rash', severity: 'moderate', source: 'patient_entered' });
  await db.insert(s.emergencyContacts).values([
    { patientId: ramesh.id, name: 'Vaibhav Kumar', phone: SEED_PHONES.vaibhav, relation: 'son' },
    { patientId: ramesh.id, name: 'Lakshmi Kumar', phone: SEED_PHONES.lakshmi, relation: 'daughter-in-law' },
  ]);

  const lakshmi = await mkUser(SEED_PHONES.lakshmi, 'Lakshmi Kumar', ['patient']);
  const [lSelf] = await db
    .insert(s.patients)
    .values({ name: 'Lakshmi Kumar', dob: '1997-06-10', gender: 'female', phone: lakshmi.phone, userId: lakshmi.id, ownerUserId: lakshmi.id, ownerRelation: 'self' })
    .returning();
  await db.update(s.users).set({ selfPatientId: lSelf.id }).where(eq(s.users.id, lakshmi.id));
  await consent(lakshmi.id, REQUIRED);
  await db.insert(s.familyAccessGrants).values({
    patientId: ramesh.id,
    granteeUserId: lakshmi.id,
    relation: 'daughter-in-law',
    permissions: ['view_records', 'receive_alerts'],
    createdByUserId: vaibhav.id,
    createdAt: daysAgo(20),
  });

  // ---- doctors
  const credential = new Date('2028-03-31T00:00:00.000Z');
  const doctor = async (
    phone: string,
    name: string,
    d: { specialty: string; qualification: string; exp: number; rating: number; ratingCount: number; languages: string[]; fees: [number, number, number, number]; bio: string; reg: string; facility: number },
  ) => {
    const u = await mkUser(phone, name, ['doctor']);
    await consent(u.id, REQUIRED);
    const [p] = await db
      .insert(s.providers)
      .values({
        userId: u.id,
        kind: 'doctor',
        type: 'doctor',
        name,
        qualification: d.qualification,
        specialty: d.specialty,
        registrationNumber: d.reg,
        verificationStatus: 'verified',
        credentialExpiresAt: credential,
        onDuty: true,
        experienceYears: d.exp,
        rating: d.rating,
        ratingCount: d.ratingCount,
        ratingBaselineSum: d.rating * d.ratingCount,
        ratingBaselineCount: d.ratingCount,
        languages: d.languages,
        feeVideo: d.fees[0],
        feeAudio: d.fees[1],
        feeChat: d.fees[2],
        feeInClinic: d.fees[3],
        bio: d.bio,
        facilityId: facilityRows[d.facility].id,
      })
      .returning();
    // Contract section 29: seeded availability is a weekly template (Mon-Sat 09:00-13:00, 14:00-18:00, 30 min, all modes).
    await db.insert(s.doctorSchedules).values({ doctorId: p.id, weekly: DEFAULT_WEEKLY });
    await regenerateSlots(db, p.id, { now, horizonDays });
    return { user: u, provider: p };
  };
  const ananya = await doctor(SEED_PHONES.ananya, 'Dr. Ananya Rao', {
    specialty: 'general_physician',
    qualification: 'MBBS, MD (General Medicine)',
    exp: 12,
    rating: 4.8,
    ratingCount: 320,
    languages: ['English', 'Hindi', 'Telugu'],
    fees: [499, 499, 399, 599],
    bio: 'General physician focused on long-term care for blood pressure, diabetes and family health.',
    reg: 'TSMC-SAMPLE-10101',
    facility: 0,
  });
  const karthik = await doctor(SEED_PHONES.karthik, 'Dr. Karthik Mehta', {
    specialty: 'general_physician',
    qualification: 'MBBS, MD (Internal Medicine)',
    exp: 15,
    rating: 4.7,
    ratingCount: 210,
    languages: ['English', 'Hindi'],
    fees: [599, 599, 499, 699],
    bio: 'Internal medicine specialist for adults with multiple long-term conditions.',
    reg: 'TSMC-SAMPLE-10102',
    facility: 1,
  });
  await doctor(SEED_PHONES.priya, 'Dr. Priya Sharma', {
    specialty: 'dermatologist',
    qualification: 'MBBS, MD (Dermatology)',
    exp: 9,
    rating: 4.6,
    ratingCount: 185,
    languages: ['English', 'Hindi'],
    fees: [499, 499, 399, 599],
    bio: 'Dermatologist for skin, hair and nail concerns.',
    reg: 'TSMC-SAMPLE-10103',
    facility: 0,
  });
  await doctor(SEED_PHONES.arjun, 'Dr. Arjun Reddy', {
    specialty: 'pediatrician',
    qualification: 'MBBS, MD (Paediatrics)',
    exp: 11,
    rating: 4.7,
    ratingCount: 240,
    languages: ['English', 'Telugu'],
    fees: [449, 449, 349, 549],
    bio: 'Paediatrician caring for newborns, children and teenagers. Speaks Telugu.',
    reg: 'TSMC-SAMPLE-10104',
    facility: 4,
  });
  const reviews = [
    [ananya.provider.id, 5, 'Very patient and explained my father’s BP readings clearly.', 'Verified patient, Banjara Hills'],
    [ananya.provider.id, 5, 'Quick video consultation, clear follow-up plan.', 'Verified patient, Ameerpet'],
    [karthik.provider.id, 4, 'Thorough review of all my reports.', 'Verified patient, Somajiguda'],
  ] as const;
  // Contract section 33: seeded reviews are published Review rows; they are part of the displayed rating, so the
  // imported baseline excludes them (Dr. Ananya stays 4.8 from 320 ratings).
  for (const [pid, rating, text] of reviews) {
    const [doc] = await db.select().from(s.providers).where(eq(s.providers.id, pid));
    await db.insert(s.reviews).values({ targetType: 'appointment', targetId: randomUUID(), doctorId: pid, subjectName: doc.name, rating, text, status: 'published', createdAt: daysAgo(40) });
    await db
      .update(s.providers)
      .set({ ratingBaselineSum: doc.ratingBaselineSum - rating, ratingBaselineCount: doc.ratingBaselineCount - 1 })
      .where(eq(s.providers.id, pid));
  }

  // ---- field providers
  const field = async (phone: string, name: string, type: string, qualification: string, capabilities: string[], expires: Date, reg: string) => {
    const u = await mkUser(phone, name, ['provider']);
    await consent(u.id, REQUIRED);
    const [p] = await db
      .insert(s.providers)
      .values({ userId: u.id, kind: 'field', type, name, qualification, registrationNumber: reg, verificationStatus: 'verified', credentialExpiresAt: expires, onDuty: true, capabilities, rating: 4.7, ratingCount: 58, ratingBaselineSum: 4.7 * 58, ratingBaselineCount: 58 })
      .returning();
    await db.insert(s.providerZones).values({ providerId: p.id, zoneId: zone.id });
    return { user: u, provider: p };
  };
  const sunita = await field(SEED_PHONES.sunita, 'Sunita Devi', 'nurse', 'GNM (General Nursing & Midwifery)', ['vitals_check', 'elderly_care', 'post_report_consult', 'sample_collection'], credential, 'TSNC-SAMPLE-20201');
  await field(SEED_PHONES.ravi, 'Ravi Teja', 'technician', 'DMLT (Phlebotomy technician)', ['sample_collection', 'vitals_check'], credential, 'TSPMB-SAMPLE-20202');
  // Credential EXPIRED: must never be matched.
  await field(SEED_PHONES.anil, 'Anil Kumar', 'intern', 'BSc Nursing (Intern)', ['vitals_check', 'elderly_care', 'post_report_consult', 'sample_collection'], new Date('2026-06-30T00:00:00.000Z'), 'TSNC-SAMPLE-20203');

  // ---- staff
  const staff: Record<string, typeof s.users.$inferSelect> = {};
  for (const [phone, name, role] of [
    [SEED_PHONES.meera, 'Meera Nair', 'coordinator'],
    [SEED_PHONES.ops, 'Operations Admin', 'ops_admin'],
    [SEED_PHONES.admin, 'Super Admin', 'super_admin'],
  ] as const) {
    const u = await mkUser(phone, name, [role]);
    await consent(u.id, REQUIRED);
    staff[role] = u;
  }
  const meera = staff.coordinator;

  // ---- safety pack + knowledge
  await db.insert(s.safetyRulePacks).values({ version: FIXTURE_PACK_VERSION, status: 'fixture_unapproved', active: true, rules: FIXTURE_RULES });
  const knowledge = new KnowledgeService(db);
  for (const k of KNOWLEDGE) {
    const [src] = await db
      .insert(s.knowledgeSources)
      .values({ title: k.title, owner: 'Clinical Governance (placeholder)', version: '1.0', status: 'approved', effectiveDate: addDays(today, -60), expiresAt: addDays(today, 365), content: k.content })
      .returning();
    await knowledge.indexSource(db, src.id, k.content);
  }

  // ---- Ramesh: active care episode with history
  const [episode] = await db
    .insert(s.careEpisodes)
    .values({
      patientId: ramesh.id,
      title: 'Blood pressure & diabetes follow-up',
      concern: 'Raised home BP readings and fasting sugar; review of medicines.',
      status: 'FOLLOW_UP',
      priority: 'routine',
      ownerUserId: ananya.user.id,
      coordinatorUserId: meera.id,
      nextAction: 'Record BP every morning; HbA1c test this week',
      createdByUserId: vaibhav.id,
      createdAt: daysAgo(12),
      updatedAt: daysAgo(5),
    })
    .returning();
  const vActor = { actorUserId: vaibhav.id, actorName: 'Vaibhav Kumar', actorRole: 'patient' };
  const dActor = { actorUserId: ananya.user.id, actorName: 'Dr. Ananya Rao', actorRole: 'doctor' };
  const nActor = { actorUserId: sunita.user.id, actorName: 'Sunita Devi', actorRole: 'provider' };
  const ev = async (type: string, description: string, actor: typeof vActor, at: Date, data: Record<string, unknown> = {}) =>
    db.insert(s.episodeEvents).values({ episodeId: episode.id, type, description, ...actor, data, createdAt: at });

  // past appointment (completed)
  const apptStart = istToUtc(addDays(today, -10), '10:30');
  const [pastSlot] = await db
    .insert(s.slots)
    .values({ doctorId: ananya.provider.id, startAt: apptStart, endAt: new Date(apptStart.getTime() + 30 * 60_000), status: 'booked' })
    .onConflictDoNothing()
    .returning();
  const [appt] = await db
    .insert(s.appointments)
    .values({
      patientId: ramesh.id,
      doctorId: ananya.provider.id,
      slotId: pastSlot.id,
      startAt: pastSlot.startAt,
      endAt: pastSlot.endAt,
      mode: 'video',
      status: 'completed',
      reason: 'High BP readings at home',
      fee: 499,
      careEpisodeId: episode.id,
      videoRoomUrl: null,
      clinicianNotes: 'Home BP readings reviewed. Continue medicines as per care plan; daily BP log; HbA1c this week.',
      outcome: 'care_plan',
      completedAt: daysAgo(10, '10:55'),
      createdByUserId: vaibhav.id,
      createdAt: daysAgo(12),
    })
    .returning();
  const [apptPay] = await db
    .insert(s.payments)
    .values({ purpose: 'appointment', refId: appt.id, patientId: ramesh.id, amount: 499, status: 'succeeded', gateway: 'mock', gatewayOrderId: 'order_mock_seed_appt_0001', gatewayPaymentId: 'pay_mock_seed_0001', createdByUserId: vaibhav.id, createdAt: daysAgo(12) })
    .returning();
  await db.insert(s.settlementLedger).values({ paymentId: apptPay.id, entryType: 'capture', amount: 499, createdAt: daysAgo(12) });

  await ev('created', 'Care episode created', vActor, daysAgo(12, '09:00'));
  await ev('appointment_booked', 'Appointment booked with Dr. Ananya Rao', vActor, daysAgo(12, '09:05'), { appointmentId: appt.id });
  await ev('status_changed', 'Status changed from NEW to CARE_SCHEDULED', vActor, daysAgo(12, '09:06'), { from: 'NEW', to: 'CARE_SCHEDULED' });
  await ev('status_changed', 'Status changed from CARE_SCHEDULED to UNDER_CARE', dActor, daysAgo(10, '10:30'), { from: 'CARE_SCHEDULED', to: 'UNDER_CARE' });
  await ev('consultation_completed', 'Consultation completed', dActor, daysAgo(10, '10:55'), { appointmentId: appt.id, outcome: 'care_plan' });

  // care plan + tasks + medications
  const [plan] = await db
    .insert(s.carePlans)
    .values({
      careEpisodeId: episode.id,
      patientId: ramesh.id,
      doctorId: ananya.provider.id,
      status: 'active',
      summary: 'Blood pressure and sugar monitoring with regular medicines and lifestyle measures.',
      instructions: 'Take medicines as scheduled. Record BP every morning before breakfast. Low-salt diet and a 30-minute walk daily.',
      followUp: { afterDays: 14, mode: 'video' },
      followUpDueAt: istToUtc(addDays(today, 4), '10:00'),
      createdAt: daysAgo(10, '11:00'),
    })
    .returning();
  await db.insert(s.careTasks).values([
    { carePlanId: plan.id, patientId: ramesh.id, type: 'monitoring', title: 'Record BP every morning', description: 'Before breakfast, seated, after 5 minutes rest.', dueAt: istToUtc(today, '09:00'), owner: 'caregiver' },
    { carePlanId: plan.id, patientId: ramesh.id, type: 'test', title: 'HbA1c blood test', description: 'Fasting not required.', dueAt: istToUtc(addDays(today, 2), '11:00'), owner: 'patient' },
    { carePlanId: plan.id, patientId: ramesh.id, type: 'lifestyle', title: '30-minute walk', description: null, dueAt: istToUtc(today, '18:00'), owner: 'patient' },
    {
      carePlanId: plan.id,
      patientId: ramesh.id,
      type: 'monitoring',
      title: 'Upload last week BP log',
      description: null,
      dueAt: istToUtc(addDays(today, -3), '20:00'),
      owner: 'caregiver',
      status: 'done',
      completedAt: daysAgo(3, '19:00'),
      completedByName: 'Vaibhav Kumar',
    },
    { carePlanId: plan.id, patientId: ramesh.id, type: 'follow_up', title: 'Follow-up (video)', description: null, dueAt: istToUtc(addDays(today, 4), '10:00'), owner: 'patient' },
  ]);
  const medStart = addDays(today, -10);
  await db.insert(s.medications).values([
    { patientId: ramesh.id, carePlanId: plan.id, name: 'Metformin', dose: '500mg', frequency: 'Twice daily', times: ['08:00', '20:00'], startDate: medStart, instructions: 'After food', source: 'clinician_verified', prescribedByName: 'Dr. Ananya Rao', createdAt: daysAgo(10, '11:00') },
    { patientId: ramesh.id, carePlanId: plan.id, name: 'Amlodipine', dose: '5mg', frequency: 'Once daily', times: ['08:00'], startDate: medStart, instructions: 'Morning', source: 'clinician_verified', prescribedByName: 'Dr. Ananya Rao', createdAt: daysAgo(10, '11:00') },
  ]);
  await ev('care_plan_created', 'Care plan created', dActor, daysAgo(10, '11:00'), { carePlanId: plan.id });
  await ev('status_changed', 'Status changed from UNDER_CARE to FOLLOW_UP', dActor, daysAgo(10, '11:01'), { from: 'UNDER_CARE', to: 'FOLLOW_UP' });

  // completed home visit (vitals check by Sunita)
  const hvStart = istToUtc(addDays(today, -5), '09:00');
  const [hv] = await db
    .insert(s.homeVisits)
    .values({
      patientId: ramesh.id,
      serviceCode: 'vitals_check',
      status: 'completed',
      price: 499,
      reason: 'Weekly BP and sugar check',
      address: { line1: 'Flat 302, Sai Residency', line2: 'Road No. 3', landmark: 'Near Lakshmi Temple', city: 'Hyderabad', pincode: '500034', lat: 17.4126, lng: 78.4392 },
      preferredStart: hvStart,
      preferredEnd: new Date(hvStart.getTime() + 2 * 3600_000),
      careEpisodeId: episode.id,
      visitCode: '4821',
      providerId: sunita.provider.id,
      zoneId: zone.id,
      timeline: [
        { status: 'requested', at: daysAgo(6, '18:00').toISOString(), note: null },
        { status: 'assigned', at: daysAgo(6, '18:00').toISOString(), note: null },
        { status: 'accepted', at: daysAgo(6, '18:10').toISOString(), note: null },
        { status: 'en_route', at: daysAgo(5, '08:40').toISOString(), note: 'ETA 20 min' },
        { status: 'arrived', at: daysAgo(5, '09:05').toISOString(), note: null },
        { status: 'in_progress', at: daysAgo(5, '09:07').toISOString(), note: 'Identity verified, consent confirmed' },
        { status: 'completed', at: daysAgo(5, '09:40').toISOString(), note: null },
      ],
      observations: { notes: 'Patient alert and comfortable. Taking medicines regularly.', checklist: { medicationsReviewed: true, fallRiskScreen: 'low', footCheck: true } },
      summary: 'BP 138/86, pulse 78, SpO2 97%, fasting sugar 128 mg/dL. Medicines reviewed with family. Advised to continue BP log.',
      identityVerifiedAt: daysAgo(5, '09:07'),
      assignedAt: daysAgo(6, '18:00'),
      arrivedAt: daysAgo(5, '09:05'),
      completedAt: daysAgo(5, '09:40'),
      createdByUserId: vaibhav.id,
      createdAt: daysAgo(6, '18:00'),
    })
    .returning();
  const [hvPay] = await db
    .insert(s.payments)
    .values({ purpose: 'home_visit', refId: hv.id, patientId: ramesh.id, amount: 499, status: 'succeeded', gateway: 'mock', gatewayOrderId: 'order_mock_seed_hv_0001', gatewayPaymentId: 'pay_mock_seed_0002', createdByUserId: vaibhav.id, createdAt: daysAgo(6, '18:01') })
    .returning();
  await db.insert(s.settlementLedger).values({ paymentId: hvPay.id, entryType: 'capture', amount: 499, createdAt: daysAgo(6, '18:01') });
  await ev('home_visit_requested', 'Vitals check at home visit requested', vActor, daysAgo(6, '18:00'), { homeVisitId: hv.id });
  await ev('home_visit_completed', 'Home visit completed; summary added to records', nActor, daysAgo(5, '09:40'), { homeVisitId: hv.id });

  // vitals (series)
  const vit = async (type: string, value: number, unit: string, at: Date, source: s.Provenance, recordedByName: string | null, homeVisitId: string | null = null) =>
    db.insert(s.vitals).values({ patientId: ramesh.id, type, value, unit, measuredAt: at, source, recordedByName, homeVisitId });
  const bp: Array<[number, number, number]> = [
    [14, 148, 92],
    [11, 146, 90],
    [8, 142, 88],
    [3, 136, 85],
    [1, 134, 84],
  ];
  for (const [d, sys, dia] of bp) {
    await vit('bp_systolic', sys, 'mmHg', daysAgo(d, '08:15'), 'patient_entered', 'Vaibhav Kumar');
    await vit('bp_diastolic', dia, 'mmHg', daysAgo(d, '08:15'), 'patient_entered', 'Vaibhav Kumar');
  }
  await vit('blood_glucose', 142, 'mg/dL', daysAgo(11, '07:30'), 'patient_entered', 'Vaibhav Kumar');
  await vit('weight', 74, 'kg', daysAgo(11, '07:35'), 'patient_entered', 'Vaibhav Kumar');
  const hvAt = daysAgo(5, '09:15');
  await vit('bp_systolic', 138, 'mmHg', hvAt, 'home_visit', 'Sunita Devi', hv.id);
  await vit('bp_diastolic', 86, 'mmHg', hvAt, 'home_visit', 'Sunita Devi', hv.id);
  await vit('pulse', 78, 'bpm', hvAt, 'home_visit', 'Sunita Devi', hv.id);
  await vit('spo2', 97, '%', hvAt, 'home_visit', 'Sunita Devi', hv.id);
  await vit('blood_glucose', 128, 'mg/dL', hvAt, 'home_visit', 'Sunita Devi', hv.id);
  await vit('pulse', 76, 'bpm', daysAgo(1, '08:20'), 'device', 'Health Connect (Android)');

  // records
  const rec = (p: Omit<Parameters<typeof storeRecord>[2], 'patientId'>) => storeRecord(db, storage, { patientId: ramesh.id, ...p });
  await rec({ type: 'lab_report', title: 'Blood Test Report', recordDate: addDays(today, -11), source: 'imported', uploadedByUserId: vaibhav.id, uploadedByName: 'Vaibhav Kumar', fileName: 'blood-test-report.pdf', mimeType: 'application/pdf', data: samplePdf('Blood Test Report') });
  await rec({ type: 'imaging', title: 'X-Ray Chest', recordDate: addDays(today, -35), source: 'imported', uploadedByUserId: vaibhav.id, uploadedByName: 'Vaibhav Kumar', fileName: 'xray-chest.png', mimeType: 'image/png', data: SAMPLE_PNG });
  await rec({ type: 'prescription', title: 'Prescription', recordDate: addDays(today, -10), source: 'clinician_verified', uploadedByUserId: ananya.user.id, uploadedByName: 'Dr. Ananya Rao', fileName: 'prescription.pdf', mimeType: 'application/pdf', data: samplePdf('Prescription - Metformin 500mg, Amlodipine 5mg') });
  await rec({ type: 'lab_report', title: 'ECG Report', recordDate: addDays(today, -10), source: 'imported', uploadedByUserId: vaibhav.id, uploadedByName: 'Vaibhav Kumar', fileName: 'ecg-report.pdf', mimeType: 'application/pdf', data: samplePdf('ECG Report') });
  await rec({
    type: 'visit_summary',
    title: 'Home visit summary - Vitals check at home',
    recordDate: addDays(today, -5),
    source: 'home_visit',
    uploadedByUserId: sunita.user.id,
    uploadedByName: 'Sunita Devi',
    fileName: `visit-summary-${hv.id.slice(0, 8)}.txt`,
    mimeType: 'text/plain',
    data: Buffer.from(`Home visit summary: Vitals check at home\nProvider: Sunita Devi\n\n${hv.summary}`, 'utf8'),
    homeVisitId: hv.id,
  });

  // ================================================================ v1.2 demo data (contract sections 29-39)
  await seedV12(db, storage, {
    now,
    daysAgo,
    vaibhav,
    ramesh,
    ananya,
    sunita,
    meera,
    episode,
    appt,
    hv,
    facilities: facilityRows,
    zoneId: zone.id,
    consent: (userId: string) => consent(userId, REQUIRED),
    mkUser,
  });

  // ================================================================ v1.3 demo data (contract sections 41-62)
  await seedV13(db, storage, {
    now,
    daysAgo,
    vaibhav: (await db.select().from(s.users).where(eq(s.users.id, vaibhav.id)))[0],
    lakshmi: (await db.select().from(s.users).where(eq(s.users.id, lakshmi.id)))[0],
    ramesh,
    ananya,
    sunita,
    meera,
    episode,
    facilities: facilityRows,
    consent: (userId: string) => consent(userId, REQUIRED),
    mkUser,
  });

  await db.insert(s.notifications).values({
    userId: vaibhav.id,
    title: 'Welcome to CareCompanion',
    body: 'Your family care space is ready.',
    category: 'system',
    templateKey: 'welcome',
    createdAt: daysAgo(30),
  });
}

type Row<T extends { $inferSelect: unknown }> = T['$inferSelect'];

/** v1.2 demo dataset: prescription, review, messages, coordinator contact, referral, application, plans, schemes. */
async function seedV12(
  db: Db,
  storage: StorageAdapter,
  c: {
    now: Date;
    daysAgo: (d: number, hhmm?: string) => Date;
    vaibhav: Row<typeof s.users>;
    ramesh: Row<typeof s.patients>;
    ananya: { user: Row<typeof s.users>; provider: Row<typeof s.providers> };
    sunita: { user: Row<typeof s.users>; provider: Row<typeof s.providers> };
    meera: Row<typeof s.users>;
    episode: Row<typeof s.careEpisodes>;
    appt: Row<typeof s.appointments>;
    hv: Row<typeof s.homeVisits>;
    facilities: Array<Row<typeof s.facilities>>;
    zoneId: string;
    consent: (userId: string) => Promise<void>;
    mkUser: (phone: string, name: string, roles: s.Role[]) => Promise<Row<typeof s.users>>;
  },
): Promise<void> {
  const { daysAgo, ramesh, ananya, meera, episode, appt } = c;
  const dActor = { userId: ananya.user.id, name: ananya.provider.name, role: 'doctor', ip: null, correlationId: null };

  // ---- section 31: an e-prescription for Ramesh from Dr. Ananya (PDF record + medications)
  await issuePrescription(db, storage, {
    appointment: appt,
    doctor: ananya.provider,
    doctorUserId: ananya.user.id,
    patient: ramesh,
    actor: dActor,
    now: daysAgo(10, '11:05'),
    input: {
      clinicalNote: 'Seasonal allergic rhinitis symptoms; BP medicines unchanged.',
      advice: 'Continue BP and sugar medicines as per the care plan. Drink enough water, avoid dust exposure, and record BP every morning.',
      followUpInDays: 14,
      items: [
        { drugName: 'Cetirizine', strength: '10mg', form: 'tablet', dose: '1 tablet', frequency: 'Once daily', timing: 'At bedtime', durationDays: 14, times: ['21:00'], instructions: 'May cause drowsiness' },
        { drugName: 'Paracetamol', strength: '500mg', form: 'tablet', dose: '1 tablet', frequency: 'Up to 3 times a day if needed', timing: 'After food', durationDays: 5, times: [], instructions: 'Only for fever or body ache; not more than 3 tablets a day' },
      ],
    },
  });

  // ---- section 33: a pending (text) review of the completed home visit; the consultation stays reviewable
  await db.insert(s.reviews).values({
    targetType: 'home_visit',
    targetId: c.hv.id,
    providerId: c.sunita.provider.id,
    subjectName: c.sunita.provider.name,
    patientId: ramesh.id,
    authorUserId: c.vaibhav.id,
    rating: 5,
    text: 'Sunita was on time, gentle with my father and explained every reading.',
    status: 'pending',
    createdAt: daysAgo(4, '19:00'),
  });

  // ---- section 34: one care-team thread with 3 messages
  const msgs = [
    { senderUserId: c.vaibhav.id, senderName: c.vaibhav.name!, senderRole: 'family', text: "Dad's morning BP was 136/85 today. Should he continue the same medicines?", at: daysAgo(2, '08:40') },
    { senderUserId: ananya.user.id, senderName: ananya.provider.name, senderRole: 'doctor', text: 'Yes, continue the same doses and keep the daily log. We will review everything at the follow-up.', at: daysAgo(2, '12:15') },
    { senderUserId: meera.id, senderName: meera.name!, senderRole: 'coordinator', text: 'I have noted the follow-up. I will call you two days before to confirm the slot.', at: daysAgo(1, '10:05') },
  ];
  let lastSeq = 0;
  for (const m of msgs) {
    const [row] = await db
      .insert(s.careMessages)
      .values({ careEpisodeId: episode.id, senderUserId: m.senderUserId, senderName: m.senderName, senderRole: m.senderRole, kind: 'text', text: m.text, createdAt: m.at })
      .returning();
    if (m.senderUserId === c.vaibhav.id) lastSeq = row.seq;
  }
  await db.insert(s.careMessageReads).values({ careEpisodeId: episode.id, userId: c.vaibhav.id, lastReadSeq: lastSeq });

  // ---- section 35: Meera is the coordinator of the episode (set on insert) + one contact log
  await db.insert(s.episodeEvents).values({
    episodeId: episode.id,
    type: 'coordinator_assigned',
    description: `Care coordinator assigned: ${meera.name}`,
    actorName: 'Operations Admin',
    actorRole: 'ops_admin',
    data: { coordinatorUserId: meera.id },
    createdAt: daysAgo(9, '09:00'),
  });
  const [contact] = await db
    .insert(s.contactLogs)
    .values({
      patientId: ramesh.id,
      careEpisodeId: episode.id,
      coordinatorUserId: meera.id,
      coordinatorName: meera.name!,
      channel: 'call',
      outcome: 'reached',
      note: 'Spoke with Vaibhav. BP log is being maintained; reminded about the HbA1c test.',
      followUpAt: istToUtc(addDays(istDate(c.now), 3), '11:00'),
      createdAt: daysAgo(3, '11:30'),
    })
    .returning();
  await db.insert(s.episodeEvents).values({
    episodeId: episode.id,
    type: 'coordinator_contact',
    description: 'Coordinator contact (call): reached',
    actorUserId: meera.id,
    actorName: meera.name,
    actorRole: 'coordinator',
    data: { contactLogId: contact.id, channel: 'call', outcome: 'reached' },
    createdAt: daysAgo(3, '11:30'),
  });

  // ---- section 36: one referral with its letter
  const hospital = c.facilities.find((f) => f.type === 'hospital')!;
  const refId = randomUUID();
  const refAt = daysAgo(10, '11:10');
  const letter = await renderReferralPdf({
    id: refId,
    date: refAt,
    doctor: ananya.provider,
    patient: { name: ramesh.name ?? 'Patient', age: 68, gender: ramesh.gender },
    facility: hospital,
    specialtyName: 'Cardiologist',
    urgency: 'routine',
    reason: 'Long-standing hypertension with borderline readings despite two medicines; please assess cardiovascular risk.',
    clinicalSummary: 'Known hypertension (2015) and type 2 diabetes (2018). On Metformin 500mg twice daily and Amlodipine 5mg once daily. Allergy: penicillin.',
  });
  const rec = await storeRecord(db, storage, {
    patientId: ramesh.id,
    type: 'other',
    title: `Referral letter - ${hospital.name}`,
    recordDate: istDate(refAt),
    source: 'clinician_verified',
    uploadedByUserId: ananya.user.id,
    uploadedByName: ananya.provider.name,
    fileName: `referral-${refId.slice(0, 8)}.pdf`,
    mimeType: 'application/pdf',
    data: letter,
  });
  await db.insert(s.referrals).values({
    id: refId,
    patientId: ramesh.id,
    careEpisodeId: episode.id,
    facilityId: hospital.id,
    specialty: 'cardiologist',
    urgency: 'routine',
    reason: 'Long-standing hypertension with borderline readings despite two medicines; please assess cardiovascular risk.',
    clinicalSummary: 'Known hypertension and type 2 diabetes on regular medicines.',
    status: 'sent',
    letterRecordId: rec.id,
    createdByUserId: ananya.user.id,
    createdByName: ananya.provider.name,
    doctorId: ananya.provider.id,
    createdAt: refAt,
    updatedAt: daysAgo(9, '10:00'),
  });
  await db.insert(s.episodeEvents).values({
    episodeId: episode.id,
    type: 'referral_created',
    description: `Referral to ${hospital.name} (routine)`,
    actorUserId: ananya.user.id,
    actorName: ananya.provider.name,
    actorRole: 'doctor',
    data: { referralId: refId, recordId: rec.id },
    createdAt: refAt,
  });

  // ---- section 30: a submitted nurse application with 2 small generated documents
  const kavya = await c.mkUser(SEED_PHONES.kavya, 'Kavya Iyer', ['patient']);
  const [kSelf] = await db
    .insert(s.patients)
    .values({ name: 'Kavya Iyer', dob: '1998-11-02', gender: 'female', phone: kavya.phone, userId: kavya.id, ownerUserId: kavya.id, ownerRelation: 'self' })
    .returning();
  await db.update(s.users).set({ selfPatientId: kSelf.id }).where(eq(s.users.id, kavya.id));
  await c.consent(kavya.id);
  const [application] = await db
    .insert(s.providerApplications)
    .values({
      userId: kavya.id,
      type: 'nurse',
      fullName: 'Kavya Iyer',
      qualification: 'BSc Nursing',
      registrationNumber: 'TSNC-SAMPLE-30601',
      registrationCouncil: 'Telangana State Nursing Council (sample)',
      experienceYears: 4,
      languages: ['English', 'Telugu', 'Hindi'],
      preferredZoneIds: [c.zoneId],
      createdAt: daysAgo(1, '16:00'),
      updatedAt: daysAgo(1, '16:20'),
    })
    .returning();
  const docs = [
    { docType: 'registration_certificate', fileName: 'nursing-registration.pdf', mimeType: 'application/pdf', data: samplePdf('Nursing council registration certificate - SAMPLE') },
    { docType: 'id_proof', fileName: 'id-proof.png', mimeType: 'image/png', data: SAMPLE_PNG },
  ];
  for (const d of docs) {
    const id = randomUUID();
    const storageKey = `applications/${application.id}/${id}${d.mimeType === 'application/pdf' ? '.pdf' : '.png'}`;
    await storage.put(storageKey, d.data, d.mimeType);
    await db.insert(s.providerApplicationDocuments).values({ id, applicationId: application.id, docType: d.docType, fileName: d.fileName, mimeType: d.mimeType, sizeBytes: d.data.length, storageKey, uploadedAt: daysAgo(1, '16:15') });
  }

  // ---- section 37: Family Care Plans (placeholder pricing [REQUIRES PRICING VALIDATION]); no subscription is seeded
  await db
    .insert(s.subscriptionPlans)
    .values([
      {
        code: 'family_basic',
        name: 'Family Basic',
        description: 'Everyday support for your family. [REQUIRES PRICING VALIDATION]',
        priceMonthly: 299,
        priceYearly: 2999,
        benefits: ['Up to 4 family members', '10% off home visits', 'Shared family health records', 'Medicine and appointment reminders'],
        maxMembers: 4,
        coordinatorIncluded: false,
        homeVisitDiscountPct: 10,
      },
      {
        code: 'family_plus',
        name: 'Family Plus',
        description: 'Hands-on care coordination for families managing long-term conditions. [REQUIRES PRICING VALIDATION]',
        priceMonthly: 699,
        priceYearly: 6999,
        benefits: ['Up to 6 family members', '15% off home visits', 'Dedicated care coordinator', 'Shared family health records', 'Priority support'],
        maxMembers: 6,
        coordinatorIncluded: true,
        homeVisitDiscountPct: 15,
      },
    ])
    .onConflictDoNothing();

  // ---- section 38: government schemes (information only) [REQUIRES CONTENT REVIEW]
  const reviewNote = '[REQUIRES CONTENT REVIEW] Generic summary written for the pilot; verify every statement against the official source before launch.';
  await db.insert(s.schemes).values([
    {
      name: 'Ayushman Bharat Pradhan Mantri Jan Arogya Yojana (PM-JAY)',
      authority: 'National Health Authority, Government of India',
      level: 'central',
      state: null,
      summary: 'A government health assurance scheme that supports eligible families with hospital care at empanelled public and private hospitals.',
      benefits: ['Cashless treatment for covered hospital care at empanelled hospitals', 'Covers many hospitalisation procedures as listed by the scheme'],
      eligibilityHints: ['Eligibility is decided by the scheme, not by CareCompanion', 'Check your status on the official website or at an empanelled hospital help desk'],
      documentsTypicallyNeeded: ['Identity proof (for example Aadhaar)', 'Ration card or other family identification, if asked'],
      officialUrl: 'https://pmjay.gov.in',
      helpline: '14555',
      status: 'published',
      lastReviewedAt: daysAgo(7),
      disclaimer: SCHEME_DISCLAIMER,
      internalNote: reviewNote,
    },
    {
      name: 'Aarogyasri Health Care Scheme (Telangana)',
      authority: 'Aarogyasri Health Care Trust, Government of Telangana',
      level: 'state',
      state: 'Telangana',
      summary: 'A state health scheme in Telangana that supports eligible families with treatment for listed conditions at network hospitals.',
      benefits: ['Treatment for conditions listed by the scheme at network hospitals'],
      eligibilityHints: ['Eligibility is decided by the scheme, not by CareCompanion', 'Ask the Aarogyamithra help desk at a network hospital'],
      documentsTypicallyNeeded: ['Family card or eligibility card as required by the scheme', 'Identity proof'],
      officialUrl: 'https://www.aarogyasri.telangana.gov.in',
      helpline: null,
      status: 'published',
      lastReviewedAt: daysAgo(7),
      disclaimer: SCHEME_DISCLAIMER,
      internalNote: reviewNote,
    },
    {
      name: 'Central Government Health Scheme (CGHS)',
      authority: 'Ministry of Health and Family Welfare, Government of India',
      level: 'central',
      state: null,
      summary: 'A health scheme for central government employees, pensioners and their dependants in covered cities, through wellness centres and empanelled hospitals.',
      benefits: ['Outpatient care at CGHS wellness centres', 'Treatment at empanelled hospitals as per scheme rules'],
      eligibilityHints: ['Meant for categories defined by the scheme (for example central government employees and pensioners)', 'Confirm details with CGHS'],
      documentsTypicallyNeeded: ['CGHS beneficiary card', 'Identity proof'],
      officialUrl: 'https://cghs.mohfw.gov.in',
      helpline: null,
      status: 'published',
      lastReviewedAt: daysAgo(7),
      disclaimer: SCHEME_DISCLAIMER,
      internalNote: reviewNote,
    },
  ]);
}

async function main(): Promise<void> {
  const reset = process.argv.includes('--reset');
  const config = loadConfig();
  if (config.NODE_ENV === 'production') throw new Error('Refusing to seed in production');
  if (reset) {
    if (config.DATABASE_URL) {
      const h = await createDb({ databaseUrl: config.DATABASE_URL, pgliteDir: config.PGLITE_DIR });
      await h.db.execute(sql`drop schema if exists public cascade`);
      await h.db.execute(sql`drop schema if exists drizzle cascade`);
      await h.db.execute(sql`create schema public`);
      await h.close();
    } else {
      await rm(path.resolve(config.PGLITE_DIR), { recursive: true, force: true });
    }
    // Only local files can be wiped; S3 keys are unique per record, so re-seeding never collides.
    if (config.STORAGE_DRIVER === 'local') await rm(path.resolve(config.STORAGE_DIR), { recursive: true, force: true });
    console.log('Dev database and files reset.');
  }
  const handle = await createDb({ databaseUrl: config.DATABASE_URL, pgliteDir: config.PGLITE_DIR });
  await runMigrations(handle);
  if (await isSeeded(handle.db)) {
    console.log('Database already seeded (use `npm run seed -- --reset` to start fresh).');
  } else {
    // Uses the configured driver (local disk, or S3 when STORAGE_DRIVER=s3).
    await seedDatabase(handle.db, createStorage(config));
    console.log('Seed complete. All OTPs are 123456 in dev. Try +919800000001 (patient) or +919800000101 (doctor).');
  }
  await handle.close();
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
