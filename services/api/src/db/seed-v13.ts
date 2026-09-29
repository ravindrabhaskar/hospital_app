/**
 * v1.3 dev seed (contract sections 41-62). SYNTHETIC TEST DATA ONLY. Clinical content is fixture data marked
 * [REQUIRES CLINICAL GOVERNANCE]; prices are placeholders.
 */
import { eq } from 'drizzle-orm';
import { dataEncryptionKey, loadConfig } from '../config.js';
import { encryptSecret } from '../lib/crypto.js';
import { PdfBuilder } from '../lib/pdf.js';
import { addDays, istDate, istToUtc } from '../lib/time.js';
import { DIET_CONTENT_VERSION, DIET_TEMPLATES } from '../modules/diet/fixtures.js';
import { SUPPLY_CATALOG } from '../modules/fieldops/routes.js';
import { INSURERS } from '../modules/insurance/routes.js';
import { LAB_PACKAGES, LAB_TESTS } from '../modules/lab/fixtures.js';
import { EXERCISE_CONTENT_VERSION, EXERCISES } from '../modules/physio/fixtures.js';
import { PREVENTIVE_FIXTURE, PREVENTIVE_PACK_VERSION } from '../modules/preventive/fixtures.js';
import { PROGRAM_FIXTURE_VERSION, PROGRAM_FIXTURES } from '../modules/programs/fixtures.js';
import { storeRecord } from '../modules/records/service.js';
import type { StorageAdapter } from '../modules/records/storage.js';
import { INTERACTION_FIXTURE, INTERACTION_PACK_VERSION } from '../modules/rxcheck/fixtures.js';
import type { Db } from './client.js';
import * as s from './schema.js';

type Row<T extends { $inferSelect: unknown }> = T['$inferSelect'];

export const V13_PHONES = { hospitalDesk: '+919800000701', dischargePatient: '+919800000702', dischargeFamily: '+919800000703', support: '+919800000801' } as const;

export async function seedV13(
  db: Db,
  storage: StorageAdapter,
  c: {
    now: Date;
    daysAgo: (d: number, hhmm?: string) => Date;
    vaibhav: Row<typeof s.users>;
    lakshmi: Row<typeof s.users>;
    ramesh: Row<typeof s.patients>;
    ananya: { user: Row<typeof s.users>; provider: Row<typeof s.providers> };
    sunita: { user: Row<typeof s.users>; provider: Row<typeof s.providers> };
    meera: Row<typeof s.users>;
    episode: Row<typeof s.careEpisodes>;
    facilities: Array<Row<typeof s.facilities>>;
    consent: (userId: string) => Promise<void>;
    mkUser: (phone: string, name: string, roles: s.Role[]) => Promise<Row<typeof s.users>>;
  },
): Promise<void> {
  const { now, daysAgo, ramesh, ananya, meera, episode } = c;
  const today = istDate(now);

  // ---- clinical content packs (fixtures, active in dev; production refuses them until approved)
  await db.insert(s.clinicalContentPacks).values([
    { kind: 'interactions', version: INTERACTION_PACK_VERSION, status: 'fixture_unapproved', active: true, content: INTERACTION_FIXTURE as unknown as Record<string, unknown> },
    { kind: 'preventive', version: PREVENTIVE_PACK_VERSION, status: 'fixture_unapproved', active: true, content: { items: PREVENTIVE_FIXTURE } },
  ]).onConflictDoNothing();
  for (const t of PROGRAM_FIXTURES) await db.insert(s.programTemplates).values({ ...t, version: PROGRAM_FIXTURE_VERSION, status: 'fixture_unapproved' }).onConflictDoNothing();
  for (const e of EXERCISES) {
    await db.insert(s.exercises).values({ ...e, instructions: [...e.instructions], precautions: [...e.precautions], videoUrl: null, imageUrl: null, contentVersion: EXERCISE_CONTENT_VERSION }).onConflictDoNothing();
  }
  for (const d of DIET_TEMPLATES) await db.insert(s.dietTemplates).values({ ...d, version: DIET_CONTENT_VERSION, status: 'fixture_unapproved' }).onConflictDoNothing();

  // ---- lab catalogue (placeholder pricing) and packages
  const partnerName = 'Sample Diagnostics (mock partner)';
  const testIds = new Map<string, string>();
  for (const t of LAB_TESTS) {
    const [row] = await db.insert(s.labTests).values({ ...t, partnerName }).onConflictDoNothing().returning();
    if (row) testIds.set(t.code, row.id);
  }
  for (const p of LAB_PACKAGES) {
    await db
      .insert(s.labPackages)
      .values({ code: p.code, name: p.name, testIds: p.tests.map((code) => testIds.get(code)!).filter(Boolean), price: p.price, mrp: p.mrp, description: p.description })
      .onConflictDoNothing();
  }

  // ---- insurers + cashless flags on facilities
  for (const i of INSURERS) await db.insert(s.insurers).values({ ...i }).onConflictDoNothing();
  const byName = (n: string) => c.facilities.find((f) => f.name.startsWith(n))!;
  const deccan = byName('Deccan Sunrise');
  await db.update(s.facilities).set({ cashlessInsurers: ['star_health', 'hdfc_ergo', 'icici_lombard', 'niva_bupa', 'pmjay', 'aarogyasri'] }).where(eq(s.facilities.id, deccan.id));
  await db.update(s.facilities).set({ cashlessInsurers: ['star_health', 'new_india', 'united_india', 'cghs', 'pmjay'] }).where(eq(s.facilities.id, byName('Charminar').id));
  await db.update(s.facilities).set({ cashlessInsurers: ['care_health', 'niva_bupa'] }).where(eq(s.facilities.id, byName('CareCompanion Partner Clinic').id));

  // ---- coupons
  await db.insert(s.coupons).values([
    {
      code: 'WELCOME100',
      description: 'Flat ₹100 off your first home visit.',
      type: 'flat',
      value: 100,
      minAmount: 300,
      appliesTo: ['home_visit'],
      validFrom: daysAgo(30),
      validTo: istToUtc(addDays(today, 365), '23:59'),
      perUserLimit: 1,
    },
    {
      code: 'CARE10',
      description: '10% off lab tests at home (up to ₹200).',
      type: 'percent',
      value: 10,
      maxDiscount: 200,
      appliesTo: ['lab_order'],
      validFrom: daysAgo(30),
      validTo: istToUtc(addDays(today, 180), '23:59'),
      perUserLimit: 3,
    },
  ]);

  // ---- second-opinion pricing (placeholder [REQUIRES PRICING VALIDATION])
  await db.insert(s.secondOpinionPricing).values([
    { specialty: 'general_physician', price: 699, turnaroundHours: 24 },
    { specialty: 'cardiologist', price: 1499, turnaroundHours: 48 },
    { specialty: 'dermatologist', price: 799, turnaroundHours: 48 },
    { specialty: 'orthopedist', price: 1199, turnaroundHours: 48 },
    { specialty: 'neurologist', price: 1499, turnaroundHours: 72 },
    { specialty: 'pediatrician', price: 899, turnaroundHours: 48 },
  ]).onConflictDoNothing();

  // ---- section 41: Ramesh daily check-in (08:00-10:00) with recent history (one missed day)
  await db.insert(s.checkinSettings).values({ patientId: ramesh.id, enabled: true, windowStart: '08:00', windowEnd: '10:00', escalateAfterMins: 60, updatedByUserId: c.vaibhav.id, updatedAt: daysAgo(20) });
  for (let d = 1; d <= 10; d++) {
    const date = addDays(today, -d);
    if (d === 6) {
      await db.insert(s.checkins).values({ patientId: ramesh.id, date, status: 'missed', missedAlertedAt: istToUtc(date, '10:00'), createdAt: istToUtc(date, '10:00') });
    } else {
      await db.insert(s.checkins).values({ patientId: ramesh.id, date, status: d === 3 ? 'late' : 'ok', checkedInAt: istToUtc(date, d === 3 ? '10:40' : '08:25'), mood: d % 3 === 0 ? 3 : 4, source: 'app', createdAt: istToUtc(date, '08:25') });
    }
  }

  // ---- section 42: hypertension enrollment (fixture thresholds, approved by Dr. Ananya) with 14 days of readings
  const hyper = PROGRAM_FIXTURES.find((p) => p.code === 'hypertension')!;
  await db.insert(s.programEnrollments).values({
    patientId: ramesh.id,
    templateCode: 'hypertension',
    templateVersion: PROGRAM_FIXTURE_VERSION,
    thresholds: hyper.defaultThresholds,
    thresholdsApprovedByUserId: ananya.user.id,
    thresholdsApprovedByName: ananya.provider.name,
    startDate: addDays(today, -14),
    careEpisodeId: episode.id,
    createdByUserId: ananya.user.id,
    createdAt: daysAgo(14, '09:00'),
  });
  // The core seed already has readings on days 1, 3, 8, 11 and 14; fill the other days.
  const extra: Array<[number, number, number]> = [
    [2, 136, 86],
    [4, 138, 87],
    [5, 140, 88],
    [6, 139, 88],
    [7, 141, 89],
    [9, 143, 90],
    [10, 144, 90],
    [12, 145, 91],
    [13, 147, 92],
  ];
  for (const [d, sys, dia] of extra) {
    for (const [type, value] of [['bp_systolic', sys], ['bp_diastolic', dia]] as const) {
      await db.insert(s.vitals).values({ patientId: ramesh.id, type, value, unit: 'mmHg', measuredAt: daysAgo(d, '08:10'), source: 'device', recordedByName: 'Health Connect (Android)' });
    }
  }

  // ---- section 48: supplies for Sunita (two items at or below the reorder level)
  const stock: Record<string, [number, number]> = {
    gloves: [40, 20],
    masks: [30, 20],
    alcohol_swabs: [60, 30],
    cotton: [4, 5],
    syringes_5ml: [25, 10],
    vacutainer: [30, 15],
    tourniquet: [2, 1],
    glucose_strips: [8, 25],
    lancets: [45, 25],
    bandage: [6, 3],
    dressing_pads: [20, 10],
    sanitizer: [3, 2],
  };
  for (const code of Object.keys(SUPPLY_CATALOG)) {
    const [onHand, reorderLevel] = stock[code] ?? [10, 5];
    await db.insert(s.providerSupplies).values({ providerId: c.sunita.provider.id, code, onHand, reorderLevel });
  }
  await db.insert(s.providerAttendance).values([
    { providerId: c.sunita.provider.id, action: 'check_in', at: daysAgo(5, '08:30'), lat: 17.4239, lng: 78.4575 },
    { providerId: c.sunita.provider.id, action: 'check_out', at: daysAgo(5, '17:10'), lat: 17.4239, lng: 78.4575 },
  ]);

  // ---- section 51: insurance policy for Ramesh (expires within 30 days -> renewal reminders)
  const key = dataEncryptionKey(loadConfig());
  await db.insert(s.insurancePolicies).values({
    patientId: ramesh.id,
    insurerCode: 'star_health',
    policyNumberEnc: encryptSecret(key, 'P/SAMPLE/2025/004821'),
    policyNumberLast4: '4821',
    planName: 'Family Health Optima (sample)',
    type: 'family_floater',
    sumInsured: 500000,
    validFrom: addDays(today, -340),
    validTo: addDays(today, 25),
    tpaName: 'Sample TPA Services',
    membersCovered: ['Ramesh Kumar', 'Vaibhav Kumar'],
    createdByUserId: c.vaibhav.id,
  });

  // ---- section 52: preventive records for Ramesh
  await db.insert(s.preventiveRecords).values([
    { patientId: ramesh.id, code: 'bp_screen', doneAt: addDays(today, -5), notes: 'Home visit BP check', createdByUserId: c.vaibhav.id },
    { patientId: ramesh.id, code: 'glucose_screen', doneAt: addDays(today, -11), createdByUserId: c.vaibhav.id },
    { patientId: ramesh.id, code: 'lipid_screen', doneAt: addDays(today, -700), createdByUserId: c.vaibhav.id },
    { patientId: ramesh.id, code: 'influenza_65', doneAt: addDays(today, -400), notes: 'Last season', createdByUserId: c.vaibhav.id },
    { patientId: ramesh.id, code: 'td_adult', doneAt: addDays(today, -1100), createdByUserId: c.vaibhav.id },
  ]);

  // ---- section 58: tenant for Deccan Sunrise
  await db.insert(s.tenants).values({
    code: 'deccan-sunrise',
    displayName: 'Deccan Sunrise Multispeciality',
    primaryColor: '#B45309',
    facilityIds: [deccan.id],
    supportPhone: deccan.phone,
    supportEmail: 'care@deccansunrise.example',
  });

  // ---- section 59: hospital discharge desk + one active discharge
  const desk = await c.mkUser(V13_PHONES.hospitalDesk, 'Hospital Discharge Desk', ['hospital_staff']);
  await db.update(s.users).set({ facilityId: deccan.id }).where(eq(s.users.id, desk.id));
  await c.consent(desk.id);
  const dpUser = await c.mkUser(V13_PHONES.dischargePatient, 'Sarojini Rao', ['patient']);
  const [dp] = await db
    .insert(s.patients)
    .values({ name: 'Sarojini Rao', dob: '1954-08-12', gender: 'female', phone: dpUser.phone, userId: dpUser.id, ownerUserId: dpUser.id, ownerRelation: 'self', tenantCode: 'deccan-sunrise' })
    .returning();
  await db.update(s.users).set({ selfPatientId: dp.id }).where(eq(s.users.id, dpUser.id));
  await c.consent(dpUser.id);
  const famUser = await c.mkUser(V13_PHONES.dischargeFamily, 'Kiran Rao', ['patient']);
  const [famSelf] = await db.insert(s.patients).values({ name: 'Kiran Rao', phone: famUser.phone, userId: famUser.id, ownerUserId: famUser.id, ownerRelation: 'self' }).returning();
  await db.update(s.users).set({ selfPatientId: famSelf.id }).where(eq(s.users.id, famUser.id));
  await db.insert(s.familyAccessGrants).values({ patientId: dp.id, granteeUserId: famUser.id, relation: 'family (hospital discharge)', permissions: ['view_records', 'manage_care', 'receive_alerts'], createdByUserId: desk.id });
  await db.insert(s.conditions).values({ patientId: dp.id, name: 'Heart failure', since: '2026', source: 'imported' });
  const dischargeDate = addDays(today, -5);
  const [dEp] = await db
    .insert(s.careEpisodes)
    .values({
      patientId: dp.id,
      title: `Post-discharge care (${deccan.name})`,
      concern: 'Admitted with breathlessness; treated for acute heart failure. Discharged stable.',
      status: 'FOLLOW_UP',
      coordinatorUserId: meera.id,
      tenantCode: 'deccan-sunrise',
      nextAction: 'Daily check-in and follow-up tasks',
      createdByUserId: desk.id,
      createdAt: istToUtc(dischargeDate, '12:00'),
      updatedAt: istToUtc(dischargeDate, '12:05'),
    })
    .returning();
  await db.insert(s.episodeEvents).values([
    { episodeId: dEp.id, type: 'created', description: 'Care episode created', actorUserId: desk.id, actorName: desk.name, actorRole: 'hospital_staff', createdAt: istToUtc(dischargeDate, '12:00') },
    { episodeId: dEp.id, type: 'care_plan_created', description: 'Hospital-issued care plan created', actorUserId: desk.id, actorName: desk.name, actorRole: 'hospital_staff', createdAt: istToUtc(dischargeDate, '12:01') },
    { episodeId: dEp.id, type: 'coordinator_assigned', description: `Care coordinator assigned: ${meera.name}`, actorName: 'System', actorRole: 'system', data: { coordinatorUserId: meera.id }, createdAt: istToUtc(dischargeDate, '12:02') },
  ]);
  const [dPlan] = await db
    .insert(s.carePlans)
    .values({
      careEpisodeId: dEp.id,
      patientId: dp.id,
      doctorId: null,
      issuedBy: `Dr. S. Menon (Hospital-issued, ${deccan.name})`,
      summary: 'Hospital-issued follow-up plan: acute heart failure, stabilised.',
      instructions: `Hospital-issued by ${deccan.name}. Weigh yourself every morning, follow the fluid limit and take medicines as prescribed. In an emergency call 108.`,
      followUp: { afterDays: 7, mode: 'in_clinic' },
      followUpDueAt: istToUtc(addDays(dischargeDate, 7), '10:00'),
      createdAt: istToUtc(dischargeDate, '12:01'),
    })
    .returning();
  await db.insert(s.careTasks).values([
    { carePlanId: dPlan.id, patientId: dp.id, type: 'monitoring', title: 'Record weight every morning', dueAt: istToUtc(addDays(dischargeDate, 1), '10:00'), owner: 'patient', status: 'done', completedAt: istToUtc(addDays(dischargeDate, 1), '08:30'), completedByName: 'Kiran Rao' },
    { carePlanId: dPlan.id, patientId: dp.id, type: 'test', title: 'Kidney function and electrolytes blood test', dueAt: istToUtc(addDays(dischargeDate, 5), '10:00'), owner: 'patient' },
    { carePlanId: dPlan.id, patientId: dp.id, type: 'follow_up', title: 'Hospital follow-up visit (day 7)', description: `Follow-up at ${deccan.name}`, dueAt: istToUtc(addDays(dischargeDate, 7), '10:00'), owner: 'patient' },
    { carePlanId: dPlan.id, patientId: dp.id, type: 'follow_up', title: 'Hospital follow-up visit (day 30)', description: `Follow-up at ${deccan.name}`, dueAt: istToUtc(addDays(dischargeDate, 30), '10:00'), owner: 'patient' },
  ]);
  await db.insert(s.medications).values([
    { patientId: dp.id, carePlanId: dPlan.id, name: 'Furosemide', dose: '40mg', frequency: 'Once daily', times: ['08:00'], startDate: dischargeDate, endDate: addDays(dischargeDate, 29), source: 'imported', prescribedByName: 'Dr. S. Menon' },
    { patientId: dp.id, carePlanId: dPlan.id, name: 'Bisoprolol', dose: '2.5mg', frequency: 'Once daily', times: ['09:00'], startDate: dischargeDate, source: 'imported', prescribedByName: 'Dr. S. Menon' },
  ]);
  await db.insert(s.checkinSettings).values({ patientId: dp.id, enabled: true, activeUntil: addDays(dischargeDate, 30), updatedByUserId: desk.id, updatedAt: istToUtc(dischargeDate, '12:00') });
  const hf = PROGRAM_FIXTURES.find((p) => p.code === 'heart_failure')!;
  const [dEn] = await db
    .insert(s.programEnrollments)
    .values({
      patientId: dp.id,
      templateCode: 'heart_failure',
      templateVersion: PROGRAM_FIXTURE_VERSION,
      thresholds: hf.defaultThresholds,
      thresholdsApprovedByName: `Dr. S. Menon (${deccan.name})`,
      startDate: dischargeDate,
      endDate: addDays(dischargeDate, 30),
      careEpisodeId: dEp.id,
      createdByUserId: desk.id,
    })
    .returning();
  const summaryPdf = await (async () => {
    const b = new PdfBuilder('Discharge summary (SAMPLE)', deccan.name);
    b.watermark('SAMPLE DOCUMENT — SYNTHETIC TEST DATA');
    b.paragraph('Synthetic discharge summary for testing. Diagnosis: acute heart failure, stabilised. Follow-up in 7 days.');
    return b.finish(['Synthetic test document generated by the CareCompanion seed.']);
  })();
  const rec = await storeRecord(db, storage, {
    patientId: dp.id,
    type: 'discharge_summary',
    title: `Discharge summary - ${deccan.name}`,
    recordDate: dischargeDate,
    source: 'imported',
    uploadedByUserId: desk.id,
    uploadedByName: deccan.name,
    fileName: 'discharge-summary.pdf',
    mimeType: 'application/pdf',
    data: summaryPdf,
    importedVia: 'hospital_discharge',
  });
  await db.insert(s.discharges).values({
    facilityId: deccan.id,
    patientId: dp.id,
    dischargeDate,
    diagnosisSummary: 'Acute heart failure, stabilised on oral diuretics.',
    treatingDoctorName: 'Dr. S. Menon',
    careEpisodeId: dEp.id,
    carePlanId: dPlan.id,
    enrollmentId: dEn.id,
    recordId: rec.id,
    followUp: {
      tasks: [
        { title: 'Record weight every morning', type: 'monitoring', dayOffset: 1 },
        { title: 'Kidney function and electrolytes blood test', type: 'test', dayOffset: 5 },
      ],
      medications: [
        { name: 'Furosemide', dose: '40mg', frequency: 'Once daily', times: ['08:00'], durationDays: 30 },
        { name: 'Bisoprolol', dose: '2.5mg', frequency: 'Once daily', times: ['09:00'] },
      ],
      followUpDays: [7, 30],
    },
    invitedPhones: [V13_PHONES.dischargePatient, V13_PHONES.dischargeFamily],
    createdByUserId: desk.id,
    createdAt: istToUtc(dischargeDate, '12:05'),
  });
  for (let d = 1; d <= 4; d++) {
    const date = addDays(today, -d);
    await db.insert(s.checkins).values({ patientId: dp.id, date, status: 'ok', checkedInAt: istToUtc(date, '08:40'), source: 'app' });
  }

  // ---- section 61: support agent + 2 tickets
  const agent = await c.mkUser(V13_PHONES.support, 'Support Desk', ['support_agent']);
  await c.consent(agent.id);
  const [t1] = await db
    .insert(s.supportTickets)
    .values({
      userId: c.vaibhav.id,
      subject: 'Refund not received for a cancelled visit',
      category: 'refund',
      status: 'open',
      priority: 'normal',
      patientId: c.vaibhav.selfPatientId,
      slaDueAt: new Date(now.getTime() + 3 * 3600_000),
      createdAt: new Date(now.getTime() - 3600_000),
      updatedAt: new Date(now.getTime() - 3600_000),
    })
    .returning();
  await db.insert(s.ticketMessages).values([
    { ticketId: t1.id, authorUserId: c.vaibhav.id, authorName: c.vaibhav.name!, authorRole: 'customer', text: 'I cancelled a home visit last week but have not received the refund yet.', createdAt: new Date(now.getTime() - 3600_000) },
    { ticketId: t1.id, authorUserId: agent.id, authorName: agent.name!, authorRole: 'agent', text: 'Checked with finance: refunds take 5-7 working days. Following up.', internal: true, createdAt: new Date(now.getTime() - 1800_000) },
  ]);
  const [t2] = await db
    .insert(s.supportTickets)
    .values({
      userId: c.lakshmi.id,
      subject: 'How do I add a family member?',
      category: 'app_issue',
      status: 'resolved',
      priority: 'low',
      assignedToUserId: agent.id,
      patientId: c.lakshmi.selfPatientId,
      slaDueAt: daysAgo(3, '14:00'),
      firstResponseAt: daysAgo(3, '10:20'),
      resolvedAt: daysAgo(3, '11:00'),
      ratingScore: 5,
      ratingComment: 'Quick and clear, thank you.',
      createdAt: daysAgo(3, '10:00'),
      updatedAt: daysAgo(3, '11:00'),
    })
    .returning();
  await db.insert(s.ticketMessages).values([
    { ticketId: t2.id, authorUserId: c.lakshmi.id, authorName: c.lakshmi.name!, authorRole: 'customer', text: 'I want to add my mother to my account. Where do I do that?', createdAt: daysAgo(3, '10:00') },
    { ticketId: t2.id, authorUserId: agent.id, authorName: agent.name!, authorRole: 'agent', text: 'Open Profile > Family and tap "Add family member". You can then choose what she can see.', createdAt: daysAgo(3, '10:20') },
  ]);
}
