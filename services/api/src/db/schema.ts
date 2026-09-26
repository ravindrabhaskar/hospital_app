/**
 * CareCompanion database schema (PostgreSQL dialect; runs on PostgreSQL or PGlite).
 * Changing this file REQUIRES a new migration: `npm run db:generate`.
 */
import { sql } from 'drizzle-orm';
import {
  boolean,
  date,
  doublePrecision,
  index,
  integer,
  jsonb,
  pgTable,
  primaryKey,
  serial,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

const ts = (name: string) => timestamp(name, { withTimezone: true, mode: 'date' });
const id = () => uuid('id').primaryKey().defaultRandom();
const createdAt = () => ts('created_at').notNull().defaultNow();

export type Role = 'patient' | 'doctor' | 'provider' | 'coordinator' | 'ops_admin' | 'super_admin';
export type FamilyPermission = 'view_records' | 'manage_care' | 'book' | 'receive_alerts';
export type Provenance = 'patient_entered' | 'clinician_verified' | 'home_visit' | 'imported' | 'ai_extracted' | 'device';

// ---------------------------------------------------------------- identity
export const users = pgTable('users', {
  id: id(),
  phone: text('phone').notNull().unique(),
  name: text('name'),
  email: text('email'),
  roles: jsonb('roles').$type<Role[]>().notNull().default(sql`'["patient"]'::jsonb`),
  language: text('language').notNull().default('en'),
  status: text('status').notNull().default('active'),
  selfPatientId: uuid('self_patient_id'),
  createdAt: createdAt(),
  lastLoginAt: ts('last_login_at'),
  // Staff MFA (TOTP). Secrets are AES-256-GCM encrypted with MFA_ENCRYPTION_KEY.
  mfaSecretEnc: text('mfa_secret_enc'),
  mfaPendingSecretEnc: text('mfa_pending_secret_enc'),
  mfaEnrolledAt: ts('mfa_enrolled_at'),
  /** Last accepted TOTP time step (replay protection). */
  mfaLastStep: integer('mfa_last_step'),
  deletedAt: ts('deleted_at'),
});

export const mfaRecoveryCodes = pgTable(
  'mfa_recovery_codes',
  {
    id: id(),
    userId: uuid('user_id').notNull().references(() => users.id),
    codeHash: text('code_hash').notNull(),
    usedAt: ts('used_at'),
    createdAt: createdAt(),
  },
  (t) => [index('mfa_recovery_user_idx').on(t.userId)],
);

/** One row per MFA code check; failures in a rolling window drive the wrong-code rate limit. */
export const mfaAttempts = pgTable(
  'mfa_attempts',
  {
    id: id(),
    userId: uuid('user_id').notNull().references(() => users.id),
    success: boolean('success').notNull(),
    createdAt: createdAt(),
  },
  (t) => [index('mfa_attempts_user_idx').on(t.userId, t.createdAt)],
);

export const accountDeletionRequests = pgTable(
  'account_deletion_requests',
  {
    id: id(),
    userId: uuid('user_id').notNull().references(() => users.id),
    status: text('status').notNull().default('scheduled'), // scheduled | cancelled | completed
    reason: text('reason'),
    requestedAt: ts('requested_at').notNull().defaultNow(),
    scheduledFor: ts('scheduled_for').notNull(),
    cancelledAt: ts('cancelled_at'),
    completedAt: ts('completed_at'),
  },
  (t) => [
    index('deletion_user_idx').on(t.userId, t.requestedAt),
    index('deletion_due_idx').on(t.status, t.scheduledFor),
    uniqueIndex('deletion_one_scheduled_uq').on(t.userId).where(sql`status = 'scheduled'`),
  ],
);

export const dataExports = pgTable(
  'data_exports',
  {
    id: id(),
    userId: uuid('user_id').notNull().references(() => users.id),
    status: text('status').notNull().default('ready'),
    storageKey: text('storage_key'),
    sizeBytes: integer('size_bytes').notNull().default(0),
    createdAt: createdAt(),
    expiresAt: ts('expires_at').notNull(),
    purgedAt: ts('purged_at'),
  },
  (t) => [index('data_exports_user_idx').on(t.userId, t.createdAt)],
);

export const otpRequests = pgTable(
  'otp_requests',
  {
    id: id(),
    phone: text('phone').notNull(),
    codeHash: text('code_hash').notNull(),
    expiresAt: ts('expires_at').notNull(),
    attempts: integer('attempts').notNull().default(0),
    consumedAt: ts('consumed_at'),
    createdAt: createdAt(),
  },
  (t) => [index('otp_phone_idx').on(t.phone, t.createdAt)],
);

export const sessions = pgTable('sessions', {
  id: id(),
  userId: uuid('user_id').notNull().references(() => users.id),
  deviceName: text('device_name'),
  createdAt: createdAt(),
  revokedAt: ts('revoked_at'),
  /** Session-level MFA claim; survives refresh-token rotation. */
  mfaVerifiedAt: ts('mfa_verified_at'),
});

export const refreshTokens = pgTable('refresh_tokens', {
  id: id(),
  sessionId: uuid('session_id').notNull().references(() => sessions.id),
  tokenHash: text('token_hash').notNull().unique(),
  expiresAt: ts('expires_at').notNull(),
  usedAt: ts('used_at'),
  revokedAt: ts('revoked_at'),
  createdAt: createdAt(),
});

export const consents = pgTable(
  'consents',
  {
    id: id(),
    userId: uuid('user_id').notNull().references(() => users.id),
    purpose: text('purpose').notNull(),
    version: text('version').notNull(),
    scope: text('scope').notNull(),
    status: text('status').notNull().default('granted'),
    grantedAt: ts('granted_at').notNull().defaultNow(),
    revokedAt: ts('revoked_at'),
  },
  (t) => [index('consents_user_idx').on(t.userId, t.purpose)],
);

// ---------------------------------------------------------------- patients
export const patients = pgTable('patients', {
  id: id(),
  name: text('name'),
  dob: date('dob', { mode: 'string' }),
  gender: text('gender').notNull().default('other'),
  phone: text('phone'),
  bloodGroup: text('blood_group'),
  heightCm: doublePrecision('height_cm'),
  weightKg: doublePrecision('weight_kg'),
  userId: uuid('user_id').references(() => users.id), // set when this is a user's self profile
  ownerUserId: uuid('owner_user_id').references(() => users.id), // managing user (self or guardian)
  ownerRelation: text('owner_relation').notNull().default('self'),
  avatarUrl: text('avatar_url'),
  /** ABHA (ABDM Health ID), contract section 39. Number stored as XX-XXXX-XXXX-XXXX. */
  abhaNumber: text('abha_number'),
  abhaAddress: text('abha_address'),
  abhaStatus: text('abha_status').notNull().default('unverified'),
  /** Legal retention hold: personal data is NOT deleted by account deletion while set. [REQUIRES LEGAL REVIEW] */
  retentionHold: boolean('retention_hold').notNull().default(false),
  anonymisedAt: ts('anonymised_at'),
  createdAt: createdAt(),
  updatedAt: ts('updated_at').notNull().defaultNow(),
});

export const allergies = pgTable('allergies', {
  id: id(),
  patientId: uuid('patient_id').notNull().references(() => patients.id),
  substance: text('substance').notNull(),
  reaction: text('reaction'),
  severity: text('severity'),
  source: text('source').$type<Provenance>().notNull(),
  createdAt: createdAt(),
});

export const conditions = pgTable('conditions', {
  id: id(),
  patientId: uuid('patient_id').notNull().references(() => patients.id),
  name: text('name').notNull(),
  since: text('since'),
  source: text('source').$type<Provenance>().notNull(),
  createdAt: createdAt(),
});

export const emergencyContacts = pgTable('emergency_contacts', {
  id: id(),
  patientId: uuid('patient_id').notNull().references(() => patients.id),
  name: text('name').notNull(),
  phone: text('phone').notNull(),
  relation: text('relation').notNull(),
  createdAt: createdAt(),
});

export const familyAccessGrants = pgTable(
  'family_access_grants',
  {
    id: id(),
    patientId: uuid('patient_id').notNull().references(() => patients.id),
    granteeUserId: uuid('grantee_user_id').notNull().references(() => users.id),
    relation: text('relation').notNull(),
    permissions: jsonb('permissions').$type<FamilyPermission[]>().notNull(),
    status: text('status').notNull().default('active'),
    createdByUserId: uuid('created_by_user_id').references(() => users.id),
    createdAt: createdAt(),
    revokedAt: ts('revoked_at'),
  },
  (t) => [index('fag_grantee_idx').on(t.granteeUserId, t.status), index('fag_patient_idx').on(t.patientId)],
);

// ---------------------------------------------------------------- care episodes
export const careEpisodes = pgTable(
  'care_episodes',
  {
    id: id(),
    patientId: uuid('patient_id').notNull().references(() => patients.id),
    title: text('title').notNull(),
    concern: text('concern').notNull(),
    status: text('status').notNull().default('NEW'),
    priority: text('priority').notNull().default('routine'),
    ownerUserId: uuid('owner_user_id').references(() => users.id),
    /** Assigned care coordinator (contract section 35). */
    coordinatorUserId: uuid('coordinator_user_id').references(() => users.id),
    nextAction: text('next_action'),
    createdByUserId: uuid('created_by_user_id').references(() => users.id),
    createdAt: createdAt(),
    updatedAt: ts('updated_at').notNull().defaultNow(),
  },
  (t) => [index('episodes_patient_idx').on(t.patientId), index('episodes_status_idx').on(t.status), index('episodes_coordinator_idx').on(t.coordinatorUserId)],
);

export const episodeEvents = pgTable(
  'episode_events',
  {
    id: id(),
    episodeId: uuid('episode_id').notNull().references(() => careEpisodes.id),
    type: text('type').notNull(),
    description: text('description').notNull(),
    actorUserId: uuid('actor_user_id'),
    actorName: text('actor_name'),
    actorRole: text('actor_role'),
    data: jsonb('data').$type<Record<string, unknown>>().notNull().default(sql`'{}'::jsonb`),
    createdAt: createdAt(),
  },
  (t) => [index('events_episode_idx').on(t.episodeId, t.createdAt)],
);

// ---------------------------------------------------------------- providers, facilities
export const specialties = pgTable('specialties', {
  code: text('code').primaryKey(),
  name: text('name').notNull(),
  icon: text('icon').notNull(),
});

export const facilities = pgTable('facilities', {
  id: id(),
  name: text('name').notNull(),
  type: text('type').notNull(),
  address: text('address').notNull(),
  area: text('area').notNull(),
  city: text('city').notNull(),
  phone: text('phone').notNull(),
  lat: doublePrecision('lat').notNull(),
  lng: doublePrecision('lng').notNull(),
  services: jsonb('services').$type<string[]>().notNull().default(sql`'[]'::jsonb`),
  emergency24x7: boolean('emergency_24x7').notNull().default(false),
  verified: boolean('verified').notNull().default(true),
});

export const serviceZones = pgTable('service_zones', {
  id: id(),
  name: text('name').notNull().unique(),
  city: text('city').notNull(),
  pincodes: jsonb('pincodes').$type<string[]>().notNull(),
  createdAt: createdAt(),
});

/** Doctors (kind=doctor) and home-care field providers (kind=field). */
export const providers = pgTable('providers', {
  id: id(),
  userId: uuid('user_id').notNull().unique().references(() => users.id),
  kind: text('kind').notNull(), // doctor | field
  type: text('type').notNull(), // doctor | nurse | technician | intern | physiotherapist
  name: text('name').notNull(),
  qualification: text('qualification').notNull(),
  specialty: text('specialty'),
  registrationNumber: text('registration_number').notNull(),
  verificationStatus: text('verification_status').notNull().default('pending'),
  verificationNote: text('verification_note'),
  credentialExpiresAt: ts('credential_expires_at').notNull(),
  onDuty: boolean('on_duty').notNull().default(false),
  capabilities: jsonb('capabilities').$type<string[]>().notNull().default(sql`'[]'::jsonb`),
  experienceYears: integer('experience_years').notNull().default(0),
  rating: doublePrecision('rating'),
  ratingCount: integer('rating_count').notNull().default(0),
  languages: jsonb('languages').$type<string[]>().notNull().default(sql`'[]'::jsonb`),
  feeVideo: integer('fee_video'),
  feeAudio: integer('fee_audio'),
  feeChat: integer('fee_chat'),
  feeInClinic: integer('fee_in_clinic'),
  bio: text('bio').notNull().default(''),
  facilityId: uuid('facility_id').references(() => facilities.id),
  photoUrl: text('photo_url'),
  /** Contract section 29: false hides the doctor from /doctors and refuses new bookings. */
  acceptingBookings: boolean('accepting_bookings').notNull().default(true),
  /**
   * Historic ratings that are not individual Review rows (imported / pre-v1.2). The published rating is
   * (ratingBaselineSum + sum of published reviews) / (ratingBaselineCount + published review count).
   */
  ratingBaselineSum: doublePrecision('rating_baseline_sum').notNull().default(0),
  ratingBaselineCount: integer('rating_baseline_count').notNull().default(0),
  lastLat: doublePrecision('last_lat'),
  lastLng: doublePrecision('last_lng'),
  lastLocationAt: ts('last_location_at'),
  createdAt: createdAt(),
});

export const providerZones = pgTable(
  'provider_zones',
  {
    providerId: uuid('provider_id').notNull().references(() => providers.id),
    zoneId: uuid('zone_id').notNull().references(() => serviceZones.id),
  },
  (t) => [primaryKey({ columns: [t.providerId, t.zoneId] })],
);

export const doctorReviews = pgTable('doctor_reviews', {
  id: id(),
  providerId: uuid('provider_id').notNull().references(() => providers.id),
  rating: integer('rating').notNull(),
  text: text('text').notNull(),
  authorLabel: text('author_label').notNull(),
  createdAt: createdAt(),
});

export const slots = pgTable(
  'slots',
  {
    id: id(),
    doctorId: uuid('doctor_id').notNull().references(() => providers.id),
    startAt: ts('start_at').notNull(),
    endAt: ts('end_at').notNull(),
    /** available | held | booked | retired (removed by a schedule change; never returned or bookable). */
    status: text('status').notNull().default('available'),
    modes: jsonb('modes').$type<string[]>().notNull().default(sql`'["video","audio","chat","in_clinic"]'::jsonb`),
  },
  (t) => [uniqueIndex('slots_doctor_start_uq').on(t.doctorId, t.startAt)],
);

// ---------------------------------------------------------------- appointments & payments
export const appointments = pgTable(
  'appointments',
  {
    id: id(),
    patientId: uuid('patient_id').notNull().references(() => patients.id),
    doctorId: uuid('doctor_id').notNull().references(() => providers.id),
    slotId: uuid('slot_id').notNull().references(() => slots.id),
    startAt: ts('start_at').notNull(),
    endAt: ts('end_at').notNull(),
    mode: text('mode').notNull(),
    status: text('status').notNull().default('pending_payment'),
    reason: text('reason').notNull(),
    fee: integer('fee').notNull(),
    careEpisodeId: uuid('care_episode_id').notNull().references(() => careEpisodes.id),
    videoRoomUrl: text('video_room_url'),
    clinicianNotes: text('clinician_notes'),
    outcome: text('outcome'),
    completedAt: ts('completed_at'),
    cancelReason: text('cancel_reason'),
    reminderSentAt: ts('reminder_sent_at'),
    createdByUserId: uuid('created_by_user_id').references(() => users.id),
    createdAt: createdAt(),
    updatedAt: ts('updated_at').notNull().defaultNow(),
  },
  (t) => [
    // Concurrency safety: at most one live appointment per slot.
    uniqueIndex('appointments_live_slot_uq').on(t.slotId).where(sql`status <> 'cancelled'`),
    index('appointments_patient_idx').on(t.patientId),
    index('appointments_doctor_idx').on(t.doctorId, t.startAt),
  ],
);

export type PaymentCheckoutJson = {
  gateway: 'razorpay';
  keyId: string;
  orderId: string;
  amountPaise: number;
  currency: 'INR';
  name: 'CareCompanion';
  description: string;
  prefill: { contact: string | null; name: string | null };
};

export const payments = pgTable(
  'payments',
  {
    id: id(),
    purpose: text('purpose').notNull(),
    refId: uuid('ref_id').notNull(),
    patientId: uuid('patient_id').notNull().references(() => patients.id),
    amount: integer('amount').notNull(), // rupees
    currency: text('currency').notNull().default('INR'),
    status: text('status').notNull().default('pending'),
    gateway: text('gateway').notNull(),
    gatewayOrderId: text('gateway_order_id').notNull(),
    gatewayPaymentId: text('gateway_payment_id'),
    refundedAmount: integer('refunded_amount').notNull().default(0),
    /** Razorpay Checkout options for clients (null for the mock gateway). */
    checkout: jsonb('checkout').$type<PaymentCheckoutJson | null>(),
    createdByUserId: uuid('created_by_user_id').references(() => users.id),
    createdAt: createdAt(),
    updatedAt: ts('updated_at').notNull().defaultNow(),
  },
  (t) => [uniqueIndex('payments_order_uq').on(t.gatewayOrderId), index('payments_patient_idx').on(t.patientId)],
);

export const paymentEvents = pgTable('payment_events', {
  id: id(),
  gatewayEventId: text('gateway_event_id').notNull().unique(),
  paymentId: uuid('payment_id').references(() => payments.id),
  type: text('type').notNull(),
  outcome: text('outcome').notNull(),
  createdAt: createdAt(),
});

export const refunds = pgTable('refunds', {
  id: id(),
  paymentId: uuid('payment_id').notNull().references(() => payments.id),
  amount: integer('amount').notNull(),
  reason: text('reason').notNull(),
  status: text('status').notNull().default('processed'),
  gatewayRefundId: text('gateway_refund_id'),
  createdByUserId: uuid('created_by_user_id'),
  createdAt: createdAt(),
});

/** Settlement ledger hook rows (for finance reconciliation). Amounts in rupees; refunds negative. */
export const settlementLedger = pgTable('settlement_ledger', {
  id: id(),
  paymentId: uuid('payment_id').notNull().references(() => payments.id),
  entryType: text('entry_type').notNull(), // capture | refund
  amount: integer('amount').notNull(),
  createdAt: createdAt(),
});

// ---------------------------------------------------------------- home visits
export const homeVisitServices = pgTable('home_visit_services', {
  code: text('code').primaryKey(),
  name: text('name').notNull(),
  description: text('description').notNull(),
  price: integer('price').notNull(),
  durationMins: integer('duration_mins').notNull(),
  icon: text('icon').notNull(),
});

export type AddressJson = {
  line1: string;
  line2?: string;
  landmark?: string;
  city: string;
  pincode: string;
  lat?: number;
  lng?: number;
};
export type TimelineEntry = { status: string; at: string; note: string | null };

export const homeVisits = pgTable(
  'home_visits',
  {
    id: id(),
    patientId: uuid('patient_id').notNull().references(() => patients.id),
    serviceCode: text('service_code').notNull().references(() => homeVisitServices.code),
    status: text('status').notNull().default('requested'),
    price: integer('price').notNull(),
    /** Family Care Plan discount in rupees already deducted from price (contract section 37). */
    discountApplied: integer('discount_applied').notNull().default(0),
    reason: text('reason').notNull(),
    address: jsonb('address').$type<AddressJson>().notNull(),
    preferredStart: ts('preferred_start').notNull(),
    preferredEnd: ts('preferred_end').notNull(),
    careEpisodeId: uuid('care_episode_id').notNull().references(() => careEpisodes.id),
    visitCode: text('visit_code').notNull(),
    providerId: uuid('provider_id').references(() => providers.id),
    rejectedProviderIds: jsonb('rejected_provider_ids').$type<string[]>().notNull().default(sql`'[]'::jsonb`),
    zoneId: uuid('zone_id').references(() => serviceZones.id),
    etaMinutes: integer('eta_minutes'),
    timeline: jsonb('timeline').$type<TimelineEntry[]>().notNull().default(sql`'[]'::jsonb`),
    observations: jsonb('observations').$type<{ notes: string; checklist: Record<string, boolean | string> } | null>(),
    summary: text('summary'),
    escalation: jsonb('escalation').$type<{ reason: string; severity: string; at: string } | null>(),
    verifyAttempts: integer('verify_attempts').notNull().default(0),
    identityVerifiedAt: ts('identity_verified_at'),
    assignedAt: ts('assigned_at'),
    arrivedAt: ts('arrived_at'),
    completedAt: ts('completed_at'),
    slaBreachedAt: ts('sla_breached_at'),
    cancelReason: text('cancel_reason'),
    createdByUserId: uuid('created_by_user_id').references(() => users.id),
    createdAt: createdAt(),
    updatedAt: ts('updated_at').notNull().defaultNow(),
  },
  (t) => [index('hv_patient_idx').on(t.patientId), index('hv_provider_idx').on(t.providerId), index('hv_status_idx').on(t.status)],
);

// ---------------------------------------------------------------- records & vitals
export const vitals = pgTable(
  'vitals',
  {
    id: id(),
    patientId: uuid('patient_id').notNull().references(() => patients.id),
    type: text('type').notNull(),
    value: doublePrecision('value').notNull(),
    unit: text('unit').notNull(),
    measuredAt: ts('measured_at').notNull(),
    source: text('source').$type<Provenance>().notNull(),
    recordedByUserId: uuid('recorded_by_user_id'),
    recordedByName: text('recorded_by_name'),
    homeVisitId: uuid('home_visit_id'),
    createdAt: createdAt(),
  },
  (t) => [index('vitals_patient_idx').on(t.patientId, t.type, t.measuredAt)],
);

export type AiSummaryJson = { text: string; model: string; generatedAt: string; disclaimer: string };

export const medicalRecords = pgTable(
  'medical_records',
  {
    id: id(),
    patientId: uuid('patient_id').notNull().references(() => patients.id),
    type: text('type').notNull(),
    title: text('title').notNull(),
    recordDate: date('record_date', { mode: 'string' }).notNull(),
    source: text('source').$type<Provenance>().notNull(),
    uploadedByUserId: uuid('uploaded_by_user_id'),
    uploadedByName: text('uploaded_by_name'),
    fileName: text('file_name').notNull(),
    mimeType: text('mime_type').notNull(),
    sizeBytes: integer('size_bytes').notNull(),
    storageKey: text('storage_key'),
    sha256: text('sha256'),
    aiSummary: jsonb('ai_summary').$type<AiSummaryJson | null>(),
    homeVisitId: uuid('home_visit_id'),
    createdAt: createdAt(),
  },
  (t) => [index('records_patient_idx').on(t.patientId, t.createdAt)],
);

export const recordShares = pgTable('record_shares', {
  id: id(),
  recordId: uuid('record_id').notNull().references(() => medicalRecords.id),
  doctorId: uuid('doctor_id').notNull().references(() => providers.id),
  expiresAt: ts('expires_at').notNull(),
  createdByUserId: uuid('created_by_user_id'),
  createdAt: createdAt(),
});

// ---------------------------------------------------------------- AI
export const conversations = pgTable('conversations', {
  id: id(),
  patientId: uuid('patient_id').notNull().references(() => patients.id),
  userId: uuid('user_id').notNull().references(() => users.id),
  status: text('status').notNull().default('active'),
  careEpisodeId: uuid('care_episode_id'),
  intake: jsonb('intake').$type<Record<string, unknown>>().notNull(),
  state: jsonb('state').$type<Record<string, unknown>>().notNull().default(sql`'{}'::jsonb`),
  createdAt: createdAt(),
  updatedAt: ts('updated_at').notNull().defaultNow(),
});

export const messages = pgTable(
  'messages',
  {
    id: id(),
    conversationId: uuid('conversation_id').notNull().references(() => conversations.id),
    role: text('role').notNull(),
    kind: text('kind').notNull(),
    text: text('text').notNull(),
    quickReplies: jsonb('quick_replies').$type<string[]>().notNull().default(sql`'[]'::jsonb`),
    routing: jsonb('routing').$type<Record<string, unknown> | null>(),
    safety: jsonb('safety').$type<Record<string, unknown> | null>(),
    seq: integer('seq').notNull().default(0),
    createdAt: createdAt(),
  },
  (t) => [index('messages_conv_idx').on(t.conversationId, t.seq)],
);

/** AI audit row per model call. MUST NOT contain raw PHI text. */
export const aiInteractions = pgTable('ai_interactions', {
  id: id(),
  useCase: text('use_case').notNull(),
  userId: uuid('user_id'),
  patientId: uuid('patient_id'),
  conversationId: uuid('conversation_id'),
  model: text('model').notNull(),
  promptVersion: text('prompt_version').notNull(),
  policyVersion: text('policy_version').notNull(),
  rulePackVersion: text('rule_pack_version').notNull(),
  safetyLevel: text('safety_level').notNull(),
  latencyMs: integer('latency_ms').notNull(),
  inputTokens: integer('input_tokens').notNull().default(0),
  outputTokens: integer('output_tokens').notNull().default(0),
  fallbackUsed: boolean('fallback_used').notNull().default(false),
  errorCode: text('error_code'),
  knowledgeSourceIds: jsonb('knowledge_source_ids').$type<string[]>().notNull().default(sql`'[]'::jsonb`),
  createdAt: createdAt(),
});

export const aiFeedback = pgTable('ai_feedback', {
  id: id(),
  aiInteractionId: uuid('ai_interaction_id').notNull().references(() => aiInteractions.id),
  userId: uuid('user_id').notNull(),
  decision: text('decision').notNull(),
  note: text('note').notNull(),
  createdAt: createdAt(),
});

export type SafetyRuleJson = {
  id: string;
  title: string;
  description: string;
  when: {
    anyKeywords?: string[];
    allKeywords?: string[];
    minSeverity?: number;
    vital?: { type: string; op: 'lt' | 'gt'; value: number };
    ageGte?: number;
  };
  level: 'routine' | 'urgent' | 'emergency';
  action: 'show_emergency' | 'escalate_clinician' | 'suggest_doctor' | 'suggest_home_visit';
};

export const safetyRulePacks = pgTable('safety_rule_packs', {
  id: id(),
  version: text('version').notNull().unique(),
  status: text('status').notNull().default('draft'),
  active: boolean('active').notNull().default(false),
  approvedBy: text('approved_by'),
  approverRegistration: text('approver_registration'),
  approvedAt: ts('approved_at'),
  rules: jsonb('rules').$type<SafetyRuleJson[]>().notNull(),
  createdAt: createdAt(),
});

export const safetyEvents = pgTable(
  'safety_events',
  {
    id: id(),
    patientId: uuid('patient_id').notNull().references(() => patients.id),
    careEpisodeId: uuid('care_episode_id'),
    level: text('level').notNull(),
    source: text('source').notNull(),
    rules: jsonb('rules').$type<{ ruleId: string; title: string }[]>().notNull(),
    status: text('status').notNull().default('open'),
    assignedToUserId: uuid('assigned_to_user_id'),
    assignedToName: text('assigned_to_name'),
    rulePackVersion: text('rule_pack_version'),
    acknowledgedAt: ts('acknowledged_at'),
    resolvedAt: ts('resolved_at'),
    note: text('note'),
    createdAt: createdAt(),
  },
  (t) => [index('safety_events_status_idx').on(t.status)],
);

export const knowledgeSources = pgTable('knowledge_sources', {
  id: id(),
  title: text('title').notNull(),
  owner: text('owner').notNull(),
  version: text('version').notNull(),
  status: text('status').notNull().default('draft'),
  effectiveDate: date('effective_date', { mode: 'string' }).notNull(),
  expiresAt: date('expires_at', { mode: 'string' }),
  content: text('content').notNull(),
  createdAt: createdAt(),
});

export const knowledgeChunks = pgTable('knowledge_chunks', {
  id: id(),
  sourceId: uuid('source_id').notNull().references(() => knowledgeSources.id),
  ordinal: integer('ordinal').notNull(),
  text: text('text').notNull(),
  terms: jsonb('terms').$type<Record<string, number>>().notNull(),
  length: integer('length').notNull(),
});

// ---------------------------------------------------------------- care plans, tasks, medications
export const carePlans = pgTable('care_plans', {
  id: id(),
  careEpisodeId: uuid('care_episode_id').notNull().references(() => careEpisodes.id),
  patientId: uuid('patient_id').notNull().references(() => patients.id),
  doctorId: uuid('doctor_id').notNull().references(() => providers.id),
  status: text('status').notNull().default('active'),
  summary: text('summary').notNull(),
  instructions: text('instructions').notNull(),
  followUp: jsonb('follow_up').$type<{ afterDays: number; mode: string } | null>(),
  followUpDueAt: ts('follow_up_due_at'),
  createdAt: createdAt(),
});

export const careTasks = pgTable(
  'care_tasks',
  {
    id: id(),
    carePlanId: uuid('care_plan_id').notNull().references(() => carePlans.id),
    patientId: uuid('patient_id').notNull().references(() => patients.id),
    type: text('type').notNull(),
    title: text('title').notNull(),
    description: text('description'),
    dueAt: ts('due_at'),
    owner: text('owner').notNull(),
    status: text('status').notNull().default('open'),
    completedAt: ts('completed_at'),
    completedByUserId: uuid('completed_by_user_id'),
    completedByName: text('completed_by_name'),
    note: text('note'),
    createdAt: createdAt(),
  },
  (t) => [index('tasks_patient_idx').on(t.patientId, t.status)],
);

export const medications = pgTable('medications', {
  id: id(),
  patientId: uuid('patient_id').notNull().references(() => patients.id),
  carePlanId: uuid('care_plan_id'),
  name: text('name').notNull(),
  dose: text('dose').notNull(),
  frequency: text('frequency').notNull(),
  times: jsonb('times').$type<string[]>().notNull(),
  startDate: date('start_date', { mode: 'string' }).notNull(),
  endDate: date('end_date', { mode: 'string' }),
  instructions: text('instructions'),
  source: text('source').$type<Provenance>().notNull(),
  prescribedByName: text('prescribed_by_name'),
  prescriptionId: uuid('prescription_id'),
  active: boolean('active').notNull().default(true),
  createdAt: createdAt(),
});

export const doseLogs = pgTable(
  'dose_logs',
  {
    id: id(),
    medicationId: uuid('medication_id').notNull().references(() => medications.id),
    scheduledAt: ts('scheduled_at').notNull(),
    status: text('status').notNull(),
    loggedAt: ts('logged_at').notNull().defaultNow(),
    loggedByUserId: uuid('logged_by_user_id'),
  },
  (t) => [uniqueIndex('dose_logs_med_sched_uq').on(t.medicationId, t.scheduledAt)],
);

// ---------------------------------------------------------------- notifications
export const notifications = pgTable(
  'notifications',
  {
    id: id(),
    userId: uuid('user_id').notNull().references(() => users.id),
    title: text('title').notNull(),
    body: text('body').notNull(),
    category: text('category').notNull(),
    critical: boolean('critical').notNull().default(false),
    read: boolean('read').notNull().default(false),
    deepLink: text('deep_link'),
    templateKey: text('template_key').notNull(),
    dedupeKey: text('dedupe_key'),
    createdAt: createdAt(),
  },
  (t) => [index('notifications_user_idx').on(t.userId, t.createdAt), uniqueIndex('notifications_dedupe_uq').on(t.userId, t.dedupeKey)],
);

export const notificationOutbox = pgTable(
  'notification_outbox',
  {
    id: id(),
    notificationId: uuid('notification_id'),
    userId: uuid('user_id'),
    channel: text('channel').notNull(),
    recipient: text('recipient'),
    lockScreenText: text('lock_screen_text').notNull(),
    critical: boolean('critical').notNull().default(false),
    status: text('status').notNull().default('pending'),
    attempts: integer('attempts').notNull().default(0),
    nextAttemptAt: ts('next_attempt_at').notNull().defaultNow(),
    lastError: text('last_error'),
    sentAt: ts('sent_at'),
    createdAt: createdAt(),
  },
  (t) => [index('outbox_status_idx').on(t.status, t.nextAttemptAt)],
);

export const devices = pgTable('devices', {
  id: id(),
  userId: uuid('user_id').notNull().references(() => users.id),
  pushToken: text('push_token').notNull().unique(),
  platform: text('platform').notNull(),
  createdAt: createdAt(),
});

export const notificationPreferences = pgTable('notification_preferences', {
  userId: uuid('user_id').primaryKey().references(() => users.id),
  push: boolean('push').notNull().default(true),
  sms: boolean('sms').notNull().default(true),
  email: boolean('email').notNull().default(false),
  whatsapp: boolean('whatsapp').notNull().default(false),
  marketing: boolean('marketing').notNull().default(false),
});

// ---------------------------------------------------------------- pharmacy
export const products = pgTable('products', {
  id: id(),
  name: text('name').notNull(),
  packSize: text('pack_size').notNull(),
  mrp: integer('mrp').notNull(),
  price: integer('price').notNull(),
  category: text('category').notNull(),
  requiresPrescription: boolean('requires_prescription').notNull().default(false),
  imageUrl: text('image_url'),
  inStock: boolean('in_stock').notNull().default(true),
});

export const pharmacyOrders = pgTable('pharmacy_orders', {
  id: id(),
  patientId: uuid('patient_id').notNull().references(() => patients.id),
  items: jsonb('items').$type<{ productId: string; name: string; qty: number; price: number }[]>().notNull(),
  total: integer('total').notNull(),
  status: text('status').notNull().default('pending_payment'),
  partnerName: text('partner_name').notNull(),
  prescriptionRecordId: uuid('prescription_record_id'),
  address: jsonb('address').$type<AddressJson>().notNull(),
  createdByUserId: uuid('created_by_user_id'),
  createdAt: createdAt(),
});

// ---------------------------------------------------------------- wellness, wound, wearables, fall, sos
export const moodEntries = pgTable('mood_entries', {
  id: id(),
  patientId: uuid('patient_id').notNull().references(() => patients.id),
  score: integer('score').notNull(),
  note: text('note'),
  shareWithClinician: boolean('share_with_clinician').notNull().default(false),
  createdByUserId: uuid('created_by_user_id'),
  createdAt: createdAt(),
});

export const woundCases = pgTable('wound_cases', {
  id: id(),
  patientId: uuid('patient_id').notNull().references(() => patients.id),
  bodySite: text('body_site').notNull(),
  note: text('note'),
  status: text('status').notNull(),
  quality: jsonb('quality').$type<{ acceptable: boolean; issues: string[] }>().notNull(),
  clinicianReview: jsonb('clinician_review').$type<{ reviewerName: string; notes: string; reviewedAt: string } | null>(),
  imageRecordId: uuid('image_record_id').notNull().references(() => medicalRecords.id),
  createdAt: createdAt(),
});

export const wearableConnections = pgTable('wearable_connections', {
  id: id(),
  patientId: uuid('patient_id').notNull().references(() => patients.id),
  provider: text('provider').notNull(),
  status: text('status').notNull().default('connected'),
  connectedAt: ts('connected_at').notNull().defaultNow(),
  lastSyncAt: ts('last_sync_at'),
  revokedAt: ts('revoked_at'),
});

export const fallEvents = pgTable('fall_events', {
  id: id(),
  patientId: uuid('patient_id').notNull().references(() => patients.id),
  status: text('status').notNull().default('awaiting_response'),
  source: text('source').notNull(),
  lat: doublePrecision('lat'),
  lng: doublePrecision('lng'),
  createdByUserId: uuid('created_by_user_id'),
  createdAt: createdAt(),
  respondedAt: ts('responded_at'),
  escalatedAt: ts('escalated_at'),
});

export const sosEvents = pgTable('sos_events', {
  id: id(),
  patientId: uuid('patient_id').notNull().references(() => patients.id),
  careEpisodeId: uuid('care_episode_id').notNull(),
  lat: doublePrecision('lat'),
  lng: doublePrecision('lng'),
  note: text('note'),
  createdByUserId: uuid('created_by_user_id'),
  createdAt: createdAt(),
});

// ---------------------------------------------------------------- operations & governance
export const incidents = pgTable('incidents', {
  id: id(),
  type: text('type').notNull(),
  title: text('title').notNull(),
  description: text('description').notNull(),
  severity: text('severity').notNull(),
  status: text('status').notNull().default('open'),
  patientId: uuid('patient_id'),
  refType: text('ref_type'),
  refId: text('ref_id'),
  reportedByUserId: uuid('reported_by_user_id'),
  reportedByName: text('reported_by_name').notNull(),
  notes: jsonb('notes').$type<{ text: string; authorName: string; at: string }[]>().notNull().default(sql`'[]'::jsonb`),
  createdAt: createdAt(),
  updatedAt: ts('updated_at').notNull().defaultNow(),
});

/** Append-only (enforced by a DB trigger in migrations). */
export const auditLogs = pgTable(
  'audit_logs',
  {
    id: id(),
    actorId: uuid('actor_id'),
    actorName: text('actor_name'),
    actorRole: text('actor_role'),
    action: text('action').notNull(),
    entityType: text('entity_type').notNull(),
    entityId: text('entity_id'),
    outcome: text('outcome').notNull(),
    ip: text('ip'),
    correlationId: text('correlation_id'),
    metadata: jsonb('metadata').$type<Record<string, unknown>>().notNull().default(sql`'{}'::jsonb`),
    createdAt: createdAt(),
  },
  (t) => [index('audit_actor_idx').on(t.actorId), index('audit_entity_idx').on(t.entityType, t.entityId), index('audit_created_idx').on(t.createdAt)],
);

export const idempotencyKeys = pgTable(
  'idempotency_keys',
  {
    id: id(),
    userId: uuid('user_id').notNull(),
    key: text('key').notNull(),
    route: text('route').notNull(),
    requestHash: text('request_hash').notNull(),
    state: text('state').notNull().default('in_progress'),
    statusCode: integer('status_code'),
    response: jsonb('response'),
    createdAt: createdAt(),
  },
  (t) => [uniqueIndex('idempotency_uq').on(t.userId, t.key, t.route)],
);

export const featureFlags = pgTable('feature_flags', {
  key: text('key').primaryKey(),
  enabled: boolean('enabled').notNull(),
  description: text('description').notNull(),
  cohort: text('cohort'),
  updatedAt: ts('updated_at').notNull().defaultNow(),
});

// ================================================================ v1.2 additions (contract sections 29-39)

export type WeeklyBlockJson = { weekday: number; start: string; end: string; slotMins: number; modes: string[] };

/** Weekly schedule template per doctor (contract section 29). One row per doctor. */
export const doctorSchedules = pgTable('doctor_schedules', {
  doctorId: uuid('doctor_id').primaryKey().references(() => providers.id),
  weekly: jsonb('weekly').$type<WeeklyBlockJson[]>().notNull().default(sql`'[]'::jsonb`),
  updatedByUserId: uuid('updated_by_user_id'),
  updatedAt: ts('updated_at').notNull().defaultNow(),
});

export const doctorLeaves = pgTable(
  'doctor_leaves',
  {
    id: id(),
    doctorId: uuid('doctor_id').notNull().references(() => providers.id),
    date: date('date', { mode: 'string' }).notNull(),
    reason: text('reason'),
    createdByUserId: uuid('created_by_user_id'),
    createdAt: createdAt(),
  },
  (t) => [uniqueIndex('doctor_leaves_doctor_date_uq').on(t.doctorId, t.date)],
);

/**
 * Publicly servable media. ONLY rows with kind='profile_photo' AND publicProfilePhoto=true whose storage key
 * lives under the dedicated `media/profile-photos/` prefix can be served by GET /media/:id. Medical records
 * never get a row here, so they can never be served publicly.
 */
export const media = pgTable('media', {
  id: id(),
  ownerUserId: uuid('owner_user_id').notNull().references(() => users.id),
  kind: text('kind').notNull(), // profile_photo
  publicProfilePhoto: boolean('public_profile_photo').notNull().default(false),
  storageKey: text('storage_key').notNull(),
  mimeType: text('mime_type').notNull(),
  sizeBytes: integer('size_bytes').notNull(),
  sha256: text('sha256'),
  createdAt: createdAt(),
});

// ---------------------------------------------------------------- onboarding applications (section 30)
export const providerApplications = pgTable(
  'provider_applications',
  {
    id: id(),
    userId: uuid('user_id').notNull().references(() => users.id),
    type: text('type').notNull(), // nurse | technician | intern | physiotherapist | doctor
    fullName: text('full_name').notNull(),
    qualification: text('qualification').notNull(),
    registrationNumber: text('registration_number').notNull(),
    registrationCouncil: text('registration_council'),
    specialty: text('specialty'),
    experienceYears: integer('experience_years').notNull().default(0),
    languages: jsonb('languages').$type<string[]>().notNull().default(sql`'[]'::jsonb`),
    preferredZoneIds: jsonb('preferred_zone_ids').$type<string[]>().notNull().default(sql`'[]'::jsonb`),
    status: text('status').notNull().default('submitted'), // submitted | changes_requested | approved | rejected
    decisionNote: text('decision_note'),
    decidedByUserId: uuid('decided_by_user_id'),
    decidedByName: text('decided_by_name'),
    decidedAt: ts('decided_at'),
    providerId: uuid('provider_id'),
    createdAt: createdAt(),
    updatedAt: ts('updated_at').notNull().defaultNow(),
  },
  (t) => [
    index('provider_applications_status_idx').on(t.status, t.createdAt),
    // At most one open or approved application per user.
    uniqueIndex('provider_applications_one_open_uq').on(t.userId).where(sql`status <> 'rejected'`),
  ],
);

export const providerApplicationDocuments = pgTable(
  'provider_application_documents',
  {
    id: id(),
    applicationId: uuid('application_id').notNull().references(() => providerApplications.id),
    docType: text('doc_type').notNull(),
    fileName: text('file_name').notNull(),
    mimeType: text('mime_type').notNull(),
    sizeBytes: integer('size_bytes').notNull(),
    storageKey: text('storage_key').notNull(),
    sha256: text('sha256'),
    uploadedAt: ts('uploaded_at').notNull().defaultNow(),
  },
  (t) => [index('provider_application_docs_app_idx').on(t.applicationId)],
);

// ---------------------------------------------------------------- e-prescriptions (section 31)
export type RxItemJson = {
  drugName: string;
  strength?: string;
  form: string;
  dose: string;
  frequency: string;
  timing?: string;
  durationDays: number;
  times: string[];
  instructions?: string;
};

export const prescriptions = pgTable(
  'prescriptions',
  {
    id: id(),
    patientId: uuid('patient_id').notNull().references(() => patients.id),
    doctorId: uuid('doctor_id').notNull().references(() => providers.id),
    appointmentId: uuid('appointment_id').notNull().references(() => appointments.id),
    careEpisodeId: uuid('care_episode_id').notNull().references(() => careEpisodes.id),
    // Snapshot of the details printed on the prescription (a legal document must not drift).
    patientName: text('patient_name').notNull(),
    patientAge: integer('patient_age'),
    patientGender: text('patient_gender').notNull(),
    doctorName: text('doctor_name').notNull(),
    doctorQualifications: text('doctor_qualifications').notNull(),
    doctorRegistration: text('doctor_registration').notNull(),
    clinicalNote: text('clinical_note'),
    items: jsonb('items').$type<RxItemJson[]>().notNull(),
    advice: text('advice'),
    followUpInDays: integer('follow_up_in_days'),
    recordId: uuid('record_id').notNull().references(() => medicalRecords.id),
    createdByUserId: uuid('created_by_user_id'),
    createdAt: createdAt(),
  },
  (t) => [index('prescriptions_patient_idx').on(t.patientId, t.createdAt)],
);

// ---------------------------------------------------------------- invoices (section 32)
/** One counter row per Indian financial year ("2026-27"); incremented atomically inside the issuing transaction. */
export const invoiceCounters = pgTable('invoice_counters', {
  fy: text('fy').primaryKey(),
  lastSeq: integer('last_seq').notNull().default(0),
});

export type InvoiceLineJson = { description: string; sacCode: string | null; amount: number; taxRate: number; taxAmount: number };

export const invoices = pgTable(
  'invoices',
  {
    id: id(),
    paymentId: uuid('payment_id').notNull().unique().references(() => payments.id),
    number: text('number').notNull().unique(),
    fy: text('fy').notNull(),
    seq: integer('seq').notNull(),
    issuedAt: ts('issued_at').notNull().defaultNow(),
    billedTo: jsonb('billed_to').$type<{ name: string; phone: string }>().notNull(),
    seller: jsonb('seller').$type<{ legalName: string; gstin: string | null; address: string }>().notNull(),
    lines: jsonb('lines').$type<InvoiceLineJson[]>().notNull(),
    subtotal: integer('subtotal').notNull(),
    tax: integer('tax').notNull(),
    total: integer('total').notNull(),
    pdfStorageKey: text('pdf_storage_key'),
    createdAt: createdAt(),
  },
  (t) => [uniqueIndex('invoices_fy_seq_uq').on(t.fy, t.seq)],
);

// ---------------------------------------------------------------- reviews (section 33)
export const reviews = pgTable(
  'reviews',
  {
    id: id(),
    targetType: text('target_type').notNull(), // appointment | home_visit
    targetId: uuid('target_id').notNull(),
    doctorId: uuid('doctor_id').references(() => providers.id),
    providerId: uuid('provider_id').references(() => providers.id),
    subjectName: text('subject_name').notNull(),
    patientId: uuid('patient_id').references(() => patients.id),
    authorUserId: uuid('author_user_id'),
    rating: integer('rating').notNull(),
    text: text('text'),
    status: text('status').notNull().default('pending'), // pending | published | rejected
    authorLabel: text('author_label').notNull().default('Verified patient'),
    moderationNote: text('moderation_note'),
    moderatedByUserId: uuid('moderated_by_user_id'),
    moderatedAt: ts('moderated_at'),
    createdAt: createdAt(),
  },
  (t) => [
    uniqueIndex('reviews_target_uq').on(t.targetType, t.targetId),
    index('reviews_doctor_idx').on(t.doctorId, t.status),
    index('reviews_provider_idx').on(t.providerId, t.status),
    index('reviews_status_idx').on(t.status, t.createdAt),
  ],
);

// ---------------------------------------------------------------- care-team messaging (section 34)
export const careMessages = pgTable(
  'care_messages',
  {
    id: id(),
    /** Strictly increasing order key (used by ?after= and read markers). */
    seq: serial('seq').notNull(),
    careEpisodeId: uuid('care_episode_id').notNull().references(() => careEpisodes.id),
    senderUserId: uuid('sender_user_id'),
    senderName: text('sender_name').notNull(),
    senderRole: text('sender_role').notNull(), // patient | family | doctor | coordinator | care_team | system
    /** text | emergency_notice (the fixed 108 safety template) | system */
    kind: text('kind').notNull().default('text'),
    text: text('text').notNull(),
    attachmentRecordId: uuid('attachment_record_id').references(() => medicalRecords.id),
    createdAt: createdAt(),
  },
  (t) => [index('care_messages_episode_idx').on(t.careEpisodeId, t.seq)],
);

export const careMessageReads = pgTable(
  'care_message_reads',
  {
    careEpisodeId: uuid('care_episode_id').notNull().references(() => careEpisodes.id),
    userId: uuid('user_id').notNull().references(() => users.id),
    lastReadSeq: integer('last_read_seq').notNull().default(0),
    updatedAt: ts('updated_at').notNull().defaultNow(),
  },
  (t) => [primaryKey({ columns: [t.careEpisodeId, t.userId] })],
);

// ---------------------------------------------------------------- coordinator workspace (section 35)
export const contactLogs = pgTable(
  'contact_logs',
  {
    id: id(),
    patientId: uuid('patient_id').notNull().references(() => patients.id),
    careEpisodeId: uuid('care_episode_id').references(() => careEpisodes.id),
    coordinatorUserId: uuid('coordinator_user_id').notNull().references(() => users.id),
    coordinatorName: text('coordinator_name').notNull(),
    channel: text('channel').notNull(),
    outcome: text('outcome').notNull(),
    note: text('note').notNull(),
    followUpAt: ts('follow_up_at'),
    createdAt: createdAt(),
  },
  (t) => [index('contact_logs_patient_idx').on(t.patientId, t.createdAt), index('contact_logs_coordinator_idx').on(t.coordinatorUserId, t.createdAt)],
);

// ---------------------------------------------------------------- referrals (section 36)
export const referrals = pgTable(
  'referrals',
  {
    id: id(),
    patientId: uuid('patient_id').notNull().references(() => patients.id),
    careEpisodeId: uuid('care_episode_id').notNull().references(() => careEpisodes.id),
    facilityId: uuid('facility_id').notNull().references(() => facilities.id),
    specialty: text('specialty'),
    urgency: text('urgency').notNull(),
    reason: text('reason').notNull(),
    clinicalSummary: text('clinical_summary'),
    status: text('status').notNull().default('created'),
    letterRecordId: uuid('letter_record_id').notNull().references(() => medicalRecords.id),
    createdByUserId: uuid('created_by_user_id').notNull().references(() => users.id),
    createdByName: text('created_by_name').notNull(),
    doctorId: uuid('doctor_id').references(() => providers.id),
    createdAt: createdAt(),
    updatedAt: ts('updated_at').notNull().defaultNow(),
  },
  (t) => [index('referrals_patient_idx').on(t.patientId, t.createdAt)],
);

// ---------------------------------------------------------------- subscriptions (section 37)
export const subscriptionPlans = pgTable('subscription_plans', {
  code: text('code').primaryKey(),
  name: text('name').notNull(),
  description: text('description').notNull(),
  priceMonthly: integer('price_monthly').notNull(),
  priceYearly: integer('price_yearly').notNull(),
  benefits: jsonb('benefits').$type<string[]>().notNull().default(sql`'[]'::jsonb`),
  maxMembers: integer('max_members').notNull(),
  coordinatorIncluded: boolean('coordinator_included').notNull().default(false),
  homeVisitDiscountPct: integer('home_visit_discount_pct').notNull().default(0),
  active: boolean('active').notNull().default(true),
  createdAt: createdAt(),
  updatedAt: ts('updated_at').notNull().defaultNow(),
});

export const subscriptions = pgTable(
  'subscriptions',
  {
    id: id(),
    userId: uuid('user_id').notNull().references(() => users.id),
    planCode: text('plan_code').notNull().references(() => subscriptionPlans.code),
    status: text('status').notNull().default('pending'), // pending | active | cancelled | expired
    billing: text('billing').notNull(), // monthly | yearly
    currentPeriodStart: ts('current_period_start'),
    currentPeriodEnd: ts('current_period_end'),
    cancelAtPeriodEnd: boolean('cancel_at_period_end').notNull().default(false),
    renewalReminderSentAt: ts('renewal_reminder_sent_at'),
    createdAt: createdAt(),
    updatedAt: ts('updated_at').notNull().defaultNow(),
  },
  (t) => [
    index('subscriptions_user_idx').on(t.userId, t.createdAt),
    // At most one active subscription per user.
    uniqueIndex('subscriptions_one_active_uq').on(t.userId).where(sql`status = 'active'`),
  ],
);

// ---------------------------------------------------------------- government schemes (section 38)
export const schemes = pgTable('schemes', {
  id: id(),
  name: text('name').notNull(),
  authority: text('authority').notNull(),
  level: text('level').notNull(), // central | state
  state: text('state'),
  summary: text('summary').notNull(),
  benefits: jsonb('benefits').$type<string[]>().notNull().default(sql`'[]'::jsonb`),
  eligibilityHints: jsonb('eligibility_hints').$type<string[]>().notNull().default(sql`'[]'::jsonb`),
  documentsTypicallyNeeded: jsonb('documents_typically_needed').$type<string[]>().notNull().default(sql`'[]'::jsonb`),
  officialUrl: text('official_url').notNull(),
  helpline: text('helpline'),
  status: text('status').notNull().default('draft'), // draft | published
  lastReviewedAt: ts('last_reviewed_at').notNull().defaultNow(),
  disclaimer: text('disclaimer').notNull(),
  /** Admin-only editorial note (never returned by the public /schemes endpoints). */
  internalNote: text('internal_note'),
  createdAt: createdAt(),
  updatedAt: ts('updated_at').notNull().defaultNow(),
});
