/**
 * Types mirroring docs/api/API_CONTRACT.md (v1). Do not add fields that are not in the contract.
 * Section numbers refer to the contract.
 */

/* ---------- Conventions ---------- */
export type ISODateTime = string;
/** YYYY-MM-DD */
export type ISODate = string;
export type UUID = string;

export type ErrorCode =
  | "VALIDATION_ERROR"
  | "UNAUTHENTICATED"
  | "FORBIDDEN"
  | "NOT_FOUND"
  | "CONFLICT"
  | "INVALID_STATE_TRANSITION"
  | "SLOT_UNAVAILABLE"
  | "IDEMPOTENCY_MISMATCH"
  | "RATE_LIMITED"
  | "NOT_SERVICEABLE"
  | "CONSENT_REQUIRED"
  | "INTERNAL"
  | "DEPENDENCY_UNAVAILABLE";

export interface ApiErrorBody {
  error: {
    code: ErrorCode | string;
    message: string;
    details?: Record<string, unknown>;
    correlationId?: string;
  };
}

export interface ListResponse<T> {
  items: T[];
  nextCursor?: string | null;
}

export interface ListQuery {
  limit?: number;
  cursor?: string;
}

export type Role =
  | "patient"
  | "doctor"
  | "provider"
  | "coordinator"
  | "ops_admin"
  | "super_admin"
  /* v1.3 */
  | "hospital_staff"
  | "support_agent";
export const ALL_ROLES: Role[] = [
  "patient",
  "doctor",
  "provider",
  "coordinator",
  "ops_admin",
  "super_admin",
  "hospital_staff",
  "support_agent",
];

export type FamilyPermission = "view_records" | "manage_care" | "book" | "receive_alerts";
export type Language = "en" | "hi" | "te";

/* ---------- 1. System ---------- */
export interface Health {
  status: "ok";
  version: string;
}

/* ---------- 2. Auth ---------- */
export interface OtpRequestResponse {
  requestId: string;
  expiresAt: ISODateTime;
  devOtp?: string;
}

export interface Me {
  id: UUID;
  phone: string;
  name: string | null;
  email: string | null;
  roles: Role[];
  language: Language;
  selfPatientId: string | null;
  onboardingComplete: boolean;
  mfaRequired: boolean;
  /** v1.1 (§22). Optional so an older API without MFA keeps working. */
  mfaEnrolled?: boolean;
  /** v1.1 (§22): whether the current session has passed MFA. */
  mfaVerified?: boolean;
  providerId: string | null;
}

export interface AuthSession {
  accessToken: string;
  refreshToken: string;
  /** seconds */
  expiresIn: number;
  user: Me;
}

/* ---------- 4. Patients ---------- */
export type Provenance =
  | "patient_entered"
  | "clinician_verified"
  | "home_visit"
  | "imported"
  | "ai_extracted"
  | "device";

export type Gender = "male" | "female" | "other";

export interface PatientSummary {
  id: UUID;
  name: string;
  dob: ISODate | null;
  age: number | null;
  gender: Gender;
  relation: "self" | string;
  isSelf: boolean;
  permissions: FamilyPermission[];
  avatarUrl: string | null;
}

export interface Allergy {
  id: UUID;
  substance: string;
  reaction: string | null;
  severity: string | null;
  source: Provenance;
  createdAt: ISODateTime;
}

export interface Condition {
  id: UUID;
  name: string;
  since: string | null;
  source: Provenance;
  createdAt: ISODateTime;
}

export interface EmergencyContact {
  id: UUID;
  name: string;
  phone: string;
  relation: string;
}

export interface PatientProfile extends PatientSummary {
  phone: string | null;
  bloodGroup: string | null;
  heightCm: number | null;
  weightKg: number | null;
  allergies: Allergy[];
  conditions: Condition[];
  emergencyContacts: EmergencyContact[];
}

/* ---------- 5. Care episodes ---------- */
export type EpisodeStatus =
  | "NEW"
  | "INTAKE"
  | "AWAITING_CARE"
  | "CARE_SCHEDULED"
  | "UNDER_CARE"
  | "FOLLOW_UP"
  | "RESOLVED"
  | "ESCALATED"
  | "EMERGENCY"
  | "TRANSFERRED"
  | "CANCELLED";

export const EPISODE_STATUSES: EpisodeStatus[] = [
  "NEW",
  "INTAKE",
  "AWAITING_CARE",
  "CARE_SCHEDULED",
  "UNDER_CARE",
  "FOLLOW_UP",
  "RESOLVED",
  "ESCALATED",
  "EMERGENCY",
  "TRANSFERRED",
  "CANCELLED",
];

export type Priority = "routine" | "urgent" | "emergency";

export interface CareEpisode {
  id: UUID;
  patientId: UUID;
  patientName: string;
  title: string;
  concern: string;
  status: EpisodeStatus;
  priority: Priority;
  ownerUserId: string | null;
  ownerName: string | null;
  nextAction: string | null;
  createdAt: ISODateTime;
  updatedAt: ISODateTime;
  /** v1.2 (§35). Optional so an older API keeps working. */
  coordinatorUserId?: string | null;
  coordinatorName?: string | null;
}

export interface EpisodeEvent {
  id: UUID;
  type: string;
  description: string;
  actorName: string | null;
  actorRole: string | null;
  data: Record<string, unknown>;
  createdAt: ISODateTime;
}

export interface CareEpisodeDetail extends CareEpisode {
  events: EpisodeEvent[];
  appointments: Appointment[];
  homeVisits: HomeVisit[];
  carePlans: CarePlan[];
  safetyEvents: SafetyEvent[];
}

/* ---------- 6. Reference data ---------- */
export interface Specialty {
  code: string;
  name: string;
  icon: string;
}

export interface HomeVisitService {
  code: string;
  name: string;
  description: string;
  price: number;
  durationMins: number;
  icon: string;
}

/* ---------- 7. Appointments ---------- */
export type ConsultMode = "video" | "audio" | "chat" | "in_clinic";
export type AppointmentStatus =
  | "pending_payment"
  | "confirmed"
  | "in_progress"
  | "completed"
  | "cancelled"
  | "no_show";

export interface Appointment {
  id: UUID;
  patientId: UUID;
  patientName: string;
  doctorId: UUID;
  doctorName: string;
  doctorSpecialty: string;
  doctorPhotoUrl: string | null;
  startAt: ISODateTime;
  endAt: ISODateTime;
  mode: ConsultMode;
  status: AppointmentStatus;
  reason: string;
  fee: number;
  careEpisodeId: UUID;
  videoRoomUrl: string | null;
  clinicianNotes: string | null;
  createdAt: ISODateTime;
}

/* ---------- 8. Home visits ---------- */
export interface Address {
  line1: string;
  line2?: string;
  landmark?: string;
  city: string;
  pincode: string;
  lat?: number;
  lng?: number;
}

export type VitalType =
  | "bp_systolic"
  | "bp_diastolic"
  | "pulse"
  | "spo2"
  | "temperature"
  | "blood_glucose"
  | "weight"
  | "respiratory_rate";

export type HomeVisitStatus =
  | "requested"
  | "assigned"
  | "accepted"
  | "en_route"
  | "arrived"
  | "in_progress"
  | "completed"
  | "unassigned"
  | "cancelled"
  | "escalated";

export const HOME_VISIT_STATUSES: HomeVisitStatus[] = [
  "requested",
  "unassigned",
  "assigned",
  "accepted",
  "en_route",
  "arrived",
  "in_progress",
  "escalated",
  "completed",
  "cancelled",
];

export interface HomeVisit {
  id: UUID;
  status: HomeVisitStatus;
  serviceCode: string;
  serviceName: string;
  price: number;
  patientId: UUID;
  patientName: string;
  reason: string;
  address: Address;
  preferredStart: ISODateTime;
  preferredEnd: ISODateTime;
  careEpisodeId: UUID;
  visitCode: string | null;
  provider: { id: UUID; name: string; qualification: string; photoUrl: string | null; phoneMasked: string } | null;
  etaMinutes: number | null;
  timeline: { status: HomeVisitStatus | string; at: ISODateTime; note: string | null }[];
  patientContext: {
    age: number | null;
    gender: Gender | string;
    allergies: string[];
    conditions: string[];
    activeMedications: string[];
  } | null;
  vitals: VitalMeasurement[];
  observations: { notes: string; checklist: Record<string, boolean | string> } | null;
  summary: string | null;
  escalation: { reason: string; severity: "urgent" | "emergency"; at: ISODateTime } | null;
  createdAt: ISODateTime;
}

/* ---------- 9. Records & vitals ---------- */
export type RecordType =
  | "lab_report"
  | "prescription"
  | "imaging"
  | "discharge_summary"
  | "visit_summary"
  | "other";

export interface MedicalRecord {
  id: UUID;
  patientId: UUID;
  type: RecordType;
  title: string;
  recordDate: ISODate;
  source: Provenance;
  uploadedByName: string | null;
  fileName: string;
  mimeType: string;
  sizeBytes: number;
  hasFile: boolean;
  aiSummary: { text: string; model: string; generatedAt: ISODateTime; disclaimer: string } | null;
  createdAt: ISODateTime;
}

export interface VitalMeasurement {
  id: UUID;
  patientId: UUID;
  type: VitalType;
  value: number;
  unit: string;
  measuredAt: ISODateTime;
  source: Provenance;
  recordedByName: string | null;
}

/* ---------- 10. AI ---------- */
export interface IntakeField<T> {
  value: T | null;
  source: "user" | "record" | "model_extraction" | null;
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
}

export type SafetyLevel = "none" | "routine" | "urgent" | "emergency";

/* ---------- 11. Care plans ---------- */
export type CareTaskType = "medication" | "test" | "follow_up" | "lifestyle" | "monitoring" | "general";
export type CareTaskOwner = "patient" | "caregiver" | "provider";
export type FollowUpMode = "video" | "in_clinic" | "home_visit";

export interface CarePlanInput {
  careEpisodeId: UUID;
  summary: string;
  instructions: string;
  tasks: {
    type: CareTaskType;
    title: string;
    description?: string;
    dueAt?: ISODateTime;
    owner: CareTaskOwner;
  }[];
  medications: {
    name: string;
    dose: string;
    frequency: string;
    times: string[];
    startDate: ISODate;
    endDate?: ISODate;
    instructions?: string;
  }[];
  followUp: { afterDays: number; mode: FollowUpMode } | null;
}

export interface CareTask {
  id: UUID;
  carePlanId: UUID;
  patientId: UUID;
  type: CareTaskType;
  title: string;
  description: string | null;
  dueAt: ISODateTime | null;
  owner: CareTaskOwner;
  status: "open" | "done" | "overdue" | "cancelled";
  completedAt: ISODateTime | null;
  completedByName: string | null;
}

export interface Medication {
  id: UUID;
  patientId: UUID;
  name: string;
  dose: string;
  frequency: string;
  times: string[];
  startDate: ISODate;
  endDate: ISODate | null;
  instructions: string | null;
  source: Provenance;
  prescribedByName: string | null;
  active: boolean;
  today: { time: string; scheduledAt: ISODateTime; status: "taken" | "skipped" | "pending" | "missed" }[];
}

export interface CarePlan {
  id: UUID;
  careEpisodeId: UUID;
  patientId: UUID;
  doctorId: UUID;
  doctorName: string;
  status: "active" | "completed" | "superseded";
  summary: string;
  instructions: string;
  tasks: CareTask[];
  medications: Medication[];
  followUpDueAt: ISODateTime | null;
  createdAt: ISODateTime;
}

/* ---------- 13. Payments ---------- */
export type PaymentStatus = "pending" | "succeeded" | "failed" | "refunded" | "partially_refunded";

export type PaymentPurpose =
  | "appointment"
  | "home_visit"
  | "pharmacy_order"
  | "subscription"
  /* v1.3 */
  | "lab_order"
  | "second_opinion"
  | "ambulance";
export const PAYMENT_PURPOSES: PaymentPurpose[] = [
  "appointment",
  "home_visit",
  "pharmacy_order",
  "subscription",
  "lab_order",
  "second_opinion",
  "ambulance",
];

export interface Payment {
  id: UUID;
  purpose: PaymentPurpose;
  refId: UUID;
  patientId: UUID;
  amount: number;
  currency: "INR";
  status: PaymentStatus;
  gateway: "mock" | "razorpay";
  gatewayOrderId: string;
  refundedAmount: number;
  createdAt: ISODateTime;
}

/* ---------- 15. Wellness / wound ---------- */
export interface MoodEntry {
  id: UUID;
  patientId: UUID;
  score: number;
  note: string | null;
  shareWithClinician: boolean;
  createdAt: ISODateTime;
}

export interface WoundCase {
  id: UUID;
  patientId: UUID;
  bodySite: string;
  note: string;
  status: "retake_required" | "pending_clinician_review" | "reviewed";
  quality: { acceptable: boolean; issues: string[] };
  clinicianReview: { reviewerName: string; notes: string; reviewedAt: ISODateTime } | null;
  imageRecordId: UUID;
  createdAt: ISODateTime;
}

/* ---------- 16. Clinician ---------- */
export type QueueItem = Appointment & {
  patientAge: number | null;
  patientGender: Gender | string;
  episodeStatus: EpisodeStatus;
  priority: Priority;
};

export type AiSourceKind = "record" | "vital" | "intake" | "home_visit" | "patient_entered";

export interface AiClaim {
  text: string;
  sources: { kind: AiSourceKind; refId: string; label: string }[];
}

export interface ClinicalSnapshot {
  patient: PatientProfile;
  activeEpisodes: CareEpisode[];
  activeMedications: Medication[];
  recentVitals: VitalMeasurement[];
  recentRecords: MedicalRecord[];
  homeVisitFindings: HomeVisit[];
  moodTrend: MoodEntry[] | null;
  aiSummary: {
    interactionId: string;
    text: string;
    advisory: true;
    model: string;
    generatedAt: ISODateTime;
    claims: AiClaim[];
  } | null;
  intake: Intake | null;
}

export type ConsultOutcome = "care_plan" | "resolved" | "refer" | "home_visit";
export type AiFeedbackDecision = "accept" | "reject" | "modify";

export interface SafetyEvent {
  id: UUID;
  patientId: UUID;
  patientName: string;
  careEpisodeId: UUID;
  level: "urgent" | "emergency";
  source: "ai_intake" | "home_visit" | "mood" | "fall" | "sos" | "checkin" | "program" | "geofence" | "sos_button";
  rules: { ruleId: string; title: string }[];
  status: "open" | "acknowledged" | "resolved";
  assignedToName: string | null;
  createdAt: ISODateTime;
  resolvedAt: ISODateTime | null;
  note: string | null;
}

/* ---------- 18. Operations ---------- */
export interface OpsOverview {
  counts: {
    activeEpisodes: number;
    openSafetyEvents: number;
    unassignedVisits: number;
    lateVisits: number;
    activeVisits: number;
    overdueTasks: number;
    todaysAppointments: number;
    pendingPayments: number;
    openIncidents: number;
    providersOnDuty: number;
  };
  sla: {
    visitAssignmentMedianMins: number | null;
    visitOnTimeRate: number | null;
    safetyAckMedianMins: number | null;
  };
  recentEvents: EpisodeEvent[];
}

export type OpsHomeVisit = HomeVisit & { slaBreached: boolean };

export type ProviderType = "nurse" | "technician" | "intern" | "physiotherapist" | "dietitian";
export type VerificationStatus = "pending" | "verified" | "rejected" | "suspended" | "expired";

export interface OpsProvider {
  id: UUID;
  name: string;
  type: ProviderType | string;
  phone: string;
  qualification: string;
  verificationStatus: VerificationStatus;
  credentialExpiresAt: ISODateTime | ISODate | null;
  onDuty: boolean;
  status: "offline" | "available" | "on_visit";
  activeVisitId: string | null;
  zones: string[];
  visitsToday: number;
  rating: number | null;
}

export type OverdueTask = CareTask & { patientName: string };

export type IncidentType = "complaint" | "incident" | "clinical_incident";
export type IncidentSeverity = "low" | "medium" | "high" | "critical";
export type IncidentStatus = "open" | "investigating" | "resolved" | "closed";

export interface Incident {
  id: UUID;
  type: IncidentType;
  title: string;
  description: string;
  severity: IncidentSeverity;
  status: IncidentStatus;
  patientId: string | null;
  patientName: string | null;
  reportedByName: string;
  notes: { text: string; authorName: string; at: ISODateTime }[];
  createdAt: ISODateTime;
  updatedAt: ISODateTime;
}

export interface CreateIncidentInput {
  type: IncidentType;
  title: string;
  description: string;
  severity: IncidentSeverity;
  patientId?: string;
  refType?: string;
  refId?: string;
}

export type OpsPayment = Payment & { patientName: string };

/* ---------- 19. Admin ---------- */
export interface AdminUser {
  id: UUID;
  phone: string;
  name: string | null;
  roles: Role[];
  createdAt: ISODateTime;
  lastLoginAt: ISODateTime | null;
  status: "active" | "disabled";
}

export interface CreateStaffInput {
  phone: string;
  name: string;
  roles: Role[];
  provider?: {
    type: string;
    qualification: string;
    specialty?: string;
    registrationNumber: string;
    zoneIds: string[];
    capabilities: string[];
    credentialExpiresAt: string;
  };
}

export interface AuditLog {
  id: UUID;
  actorId: string | null;
  actorName: string | null;
  actorRole: string | null;
  action: string;
  entityType: string;
  entityId: string | null;
  outcome: "success" | "denied" | "error";
  ip: string | null;
  correlationId: string | null;
  metadata: Record<string, unknown> | null;
  createdAt: ISODateTime;
}

export interface AuditLogQuery {
  actorId?: string;
  entityType?: string;
  entityId?: string;
  action?: string;
}

export type SafetyRuleAction = "show_emergency" | "escalate_clinician" | "suggest_doctor" | "suggest_home_visit";

export interface SafetyRule {
  id: string;
  title: string;
  description: string;
  when: {
    anyKeywords?: string[];
    allKeywords?: string[];
    minSeverity?: number;
    vital?: { type: VitalType; op: "lt" | "gt"; value: number };
    ageGte?: number;
  };
  level: "routine" | "urgent" | "emergency";
  action: SafetyRuleAction;
}

export interface SafetyRulePack {
  id: UUID;
  version: string;
  status: "draft" | "fixture_unapproved" | "approved" | "retired";
  active: boolean;
  approvedBy: string | null;
  approvedAt: ISODateTime | null;
  ruleCount: number;
  rules: SafetyRule[];
}

export interface AiInteraction {
  id: UUID;
  useCase: string;
  userId: string | null;
  patientId: string | null;
  model: string;
  promptVersion: string;
  policyVersion: string;
  rulePackVersion: string;
  safetyLevel: SafetyLevel | string;
  latencyMs: number;
  inputTokens: number;
  outputTokens: number;
  fallbackUsed: boolean;
  createdAt: ISODateTime;
}

export type KnowledgeStatus = "draft" | "approved" | "deprecated";

export interface KnowledgeSource {
  id: UUID;
  title: string;
  owner: string;
  version: string;
  status: KnowledgeStatus;
  effectiveDate: ISODate;
  expiresAt: ISODate | null;
  chunkCount: number;
}

export interface CreateKnowledgeSourceInput {
  title: string;
  owner: string;
  version: string;
  effectiveDate: ISODate;
  expiresAt?: ISODate;
  content: string;
}

export interface FeatureFlag {
  key: string;
  enabled: boolean;
  description: string;
  cohort: string | null;
}

export interface Analytics {
  funnel: {
    conversationsStarted: number;
    intakesCompleted: number;
    routedToCare: number;
    appointmentsBooked: number;
    appointmentsCompleted: number;
    homeVisitsRequested: number;
    homeVisitsCompleted: number;
    carePlansCreated: number;
    episodesResolved: number;
  };
  continuity: {
    taskCompletionRate: number | null;
    followUpCompletionRate: number | null;
    medicationAdherenceRate: number | null;
  };
  safety: {
    safetyEventsTotal: number;
    emergencyEvents: number;
    medianAckMins: number | null;
    aiFallbackRate: number | null;
  };
  finance: { grossRevenue: number; refunds: number; paidEpisodes: number };
  activation: { usersTotal: number; onboardingCompleted: number; familyGrants: number };
}

/**
 * The contract lists the ServiceZone endpoint as `GET /admin/service-zones` / POST `{ name, city, pincodes }` → zone,
 * without spelling out the response shape. We assume the input fields plus `id`.
 */
export interface ServiceZone {
  id: UUID;
  name: string;
  city: string;
  pincodes: string[];
}

/* ================= v1.1 additions (§21–§28) ================= */

/* ---------- 21. Public config ---------- */
export type PublicFlagKey =
  | "ai_assistant"
  | "wound_ai_analysis"
  | "fall_detection"
  | "wearables"
  | "pharmacy_orders"
  | "mental_wellness"
  | "govt_schemes"
  | "voice_input";

export interface PublicConfig {
  flags: Record<PublicFlagKey, boolean>;
  payment: { gateway: "mock" | "razorpay"; razorpayKeyId: string | null };
  video: { provider: VideoProvider };
  push: { enabled: boolean };
  support: { phone: string; email: string; whatsapp: string | null };
  legal: { privacyUrl: string; termsUrl: string; accountDeletionUrl: string };
  minAppVersion: { patientAndroid: string; patientIos: string; providerAndroid: string; providerIos: string };
}

/* ---------- 22. Staff MFA ---------- */
export interface MfaEnrollResponse {
  secret: string;
  otpauthUrl: string;
  /** SVG markup of the otpauth QR code (rendered through an <img> data URI, never injected). */
  qrSvg: string;
}
export interface MfaConfirmResponse {
  recoveryCodes: string[];
  session: AuthSession;
}
export type MfaVerifyInput = { code: string } | { recoveryCode: string };

/* ---------- 23. Account deletion & export ---------- */
export type DeletionStatus = "scheduled" | "cancelled" | "completed";
export interface DeletionRequest {
  id: UUID;
  status: DeletionStatus;
  reason: string | null;
  requestedAt: ISODateTime;
  scheduledFor: ISODateTime;
  completedAt: ISODateTime | null;
}

/* ---------- 26. Video consultation ---------- */
export type VideoProvider = "jitsi" | "placeholder";
export interface VideoSession {
  provider: VideoProvider;
  joinUrl: string;
  roomName: string;
  token: string | null;
  opensAt: ISODateTime;
  expiresAt: ISODateTime;
}

/* ================= v1.2 additions (§29–§39) ================= */

/* ---------- 6. Doctors & facilities (used by v1.2 screens) ---------- */
export interface ConsultFees {
  video: number;
  audio: number;
  chat: number;
  inClinic: number;
}

export interface Doctor {
  id: UUID;
  name: string;
  specialty: string;
  specialtyName: string;
  qualifications: string;
  experienceYears: number;
  rating: number;
  ratingCount: number;
  languages: string[];
  fees: ConsultFees;
  photoUrl: string | null;
  verified: true;
  nextAvailableAt: ISODateTime | null;
  availableNow: boolean;
  facility: { id: UUID; name: string; area: string } | null;
  rankingFactors: string[];
}

export interface DoctorDetail extends Doctor {
  bio: string;
  registrationNumber: string;
  reviews: { id: UUID; rating: number; text: string | null; authorLabel: string; source: "verified_patient"; createdAt: ISODateTime }[];
}

export type FacilityType = "hospital" | "clinic" | "lab" | "pharmacy";

export interface Facility {
  id: UUID;
  name: string;
  type: FacilityType | string;
  address: string;
  area: string;
  city: string;
  phone: string;
  lat: number;
  lng: number;
  distanceKm: number | null;
  services: string[];
  emergency24x7: boolean;
  verified: boolean;
}

/** §6 Slot; v1.2 adds `modes`. */
export interface Slot {
  id: UUID;
  startAt: ISODateTime;
  endAt: ISODateTime;
  status: "available" | "booked" | "held";
  modes?: string[];
}

/* ---------- 29. Doctor self-management & schedules ---------- */
export type DoctorProfile = DoctorDetail & { acceptingBookings: boolean };

export interface DoctorProfileUpdate {
  bio?: string;
  languages?: string[];
  qualifications?: string;
  fees?: ConsultFees;
  acceptingBookings?: boolean;
}

export type Weekday = 0 | 1 | 2 | 3 | 4 | 5 | 6;
export type SlotMins = 10 | 15 | 20 | 30 | 45 | 60;
export const SLOT_MINS: SlotMins[] = [10, 15, 20, 30, 45, 60];
export const CONSULT_MODES: ConsultMode[] = ["video", "audio", "chat", "in_clinic"];

export interface WeeklyBlock {
  /** 0 = Sunday (IST) */
  weekday: Weekday;
  start: string;
  end: string;
  slotMins: SlotMins;
  modes: ConsultMode[];
}

export interface Leave {
  id: UUID;
  date: ISODate;
  reason: string | null;
}

export interface Schedule {
  weekly: WeeklyBlock[];
  leaves: Leave[];
  horizonDays: number;
  timezone: "Asia/Kolkata";
}

export interface AddLeaveResponse {
  leave: Leave;
  conflicts: Appointment[];
}

/* ---------- 30. Provider applications ---------- */
export type ApplicationType = "nurse" | "technician" | "intern" | "physiotherapist" | "doctor";
export type ApplicationStatus = "submitted" | "changes_requested" | "approved" | "rejected";
export type ApplicationDocType = "registration_certificate" | "degree" | "id_proof" | "experience_letter" | "other";

export interface ApplicationDocument {
  id: UUID;
  docType: ApplicationDocType;
  fileName: string;
  mimeType: string;
  sizeBytes: number;
  uploadedAt: ISODateTime;
}

export interface ProviderApplication {
  id: UUID;
  userId: UUID;
  phone: string;
  fullName: string;
  type: ApplicationType;
  qualification: string;
  registrationNumber: string;
  registrationCouncil: string | null;
  specialty: string | null;
  experienceYears: number;
  languages: string[];
  preferredZoneIds: string[];
  status: ApplicationStatus;
  documents: ApplicationDocument[];
  decisionNote: string | null;
  decidedByName: string | null;
  createdAt: ISODateTime;
  updatedAt: ISODateTime;
  decidedAt: ISODateTime | null;
}

export type ApplicationDecision = "approve" | "reject" | "request_changes";

export interface ApplicationDecisionInput {
  decision: ApplicationDecision;
  note: string;
  credentialExpiresAt?: string;
  zoneIds?: string[];
  capabilities?: string[];
}

/* ---------- 31. e-Prescriptions ---------- */
export type RxForm = "tablet" | "capsule" | "syrup" | "injection" | "ointment" | "drops" | "inhaler" | "other";
export const RX_FORMS: RxForm[] = ["tablet", "capsule", "syrup", "injection", "ointment", "drops", "inhaler", "other"];

export interface RxItem {
  drugName: string;
  strength?: string;
  form: RxForm;
  dose: string;
  frequency: string;
  timing?: string;
  durationDays: number;
  /** "HH:MM" reminder times */
  times: string[];
  instructions?: string;
}

export interface PrescriptionInput {
  appointmentId: UUID;
  clinicalNote?: string;
  items: RxItem[];
  advice?: string;
  followUpInDays?: number;
  /** §47: required (with `overrideReason`) when the check returns a `major` warning. */
  acknowledgedWarnings?: boolean;
  overrideReason?: string;
}

export interface Prescription {
  id: UUID;
  patientId: UUID;
  patientName: string;
  patientAge: number | null;
  patientGender: Gender | string;
  doctorId: UUID;
  doctorName: string;
  doctorQualifications: string;
  doctorRegistration: string;
  appointmentId: UUID;
  careEpisodeId: UUID;
  clinicalNote: string | null;
  items: RxItem[];
  advice: string | null;
  followUpInDays: number | null;
  recordId: UUID;
  createdAt: ISODateTime;
  /** §47: the create call also returns the check's warnings. */
  warnings?: RxWarning[];
}

/* ---------- 32. Invoices, earnings & settlements ---------- */
export interface Invoice {
  number: string;
  paymentId: UUID;
  issuedAt: ISODateTime;
  billedTo: { name: string; phone: string };
  seller: { legalName: string; gstin: string | null; address: string };
  lines: { description: string; sacCode: string | null; amount: number; taxRate: number; taxAmount: number }[];
  subtotal: number;
  tax: number;
  total: number;
  refundedAmount: number;
  currency: "INR";
}

export interface EarningsLine {
  date: ISODate | ISODateTime;
  description: string;
  refType: "appointment" | "home_visit";
  refId: UUID;
  amount: number;
  platformFee: number;
  payable: number;
}

export interface Earnings {
  providerId: UUID;
  providerName: string;
  role: "doctor" | "provider";
  from: ISODate;
  to: ISODate;
  completedServices: number;
  grossAmount: number;
  platformFee: number;
  refunds: number;
  payable: number;
  lines: EarningsLine[];
}

/* ---------- 33. Reviews ---------- */
export type ReviewStatus = "pending" | "published" | "rejected";

export interface Review {
  id: UUID;
  targetType: "appointment" | "home_visit";
  targetId: UUID;
  doctorId: string | null;
  providerId: string | null;
  subjectName: string;
  rating: number;
  text: string | null;
  status: ReviewStatus;
  authorLabel: "Verified patient" | string;
  moderationNote: string | null;
  createdAt: ISODateTime;
}

/* ---------- 34. Messaging ---------- */
export interface InboxThread {
  careEpisodeId: UUID;
  title: string;
  patientId: UUID;
  patientName: string;
  lastMessage: string | null;
  lastSenderName: string | null;
  lastAt: ISODateTime | null;
  unread: number;
}

export type MessageSenderRole = "patient" | "family" | "doctor" | "coordinator" | "care_team" | "system";

export interface ChatMessage {
  id: UUID;
  careEpisodeId: UUID;
  senderUserId: string | null;
  senderName: string;
  senderRole: MessageSenderRole;
  /** `emergency_notice` is the fixed 108 safety template. Optional for older servers. */
  kind?: "text" | "emergency_notice" | "system";
  text: string;
  attachmentRecordId: string | null;
  createdAt: ISODateTime;
}

/* ---------- 35. Coordinator ---------- */
/**
 * §35 flags. `missed_checkin` and `program_breach` are the v1.3 flags the portal understands when the API returns them
 * (the contract does not enumerate new flags; unknown flags are ignored).
 */
export type CaseloadFlag =
  | "overdue_tasks"
  | "missed_doses"
  | "open_safety_event"
  | "no_contact_7d"
  | "missed_checkin"
  | "program_breach";

export interface CaseloadItem {
  patient: PatientSummary;
  episodes: CareEpisode[];
  openTasks: number;
  overdueTasks: number;
  nextFollowUpAt: ISODateTime | null;
  lastContactAt: ISODateTime | null;
  flags: CaseloadFlag[];
}

export type ContactChannel = "call" | "whatsapp" | "sms" | "home_visit" | "in_app";
export type ContactOutcome = "reached" | "no_answer" | "callback_requested" | "escalated";

export interface ContactLogInput {
  patientId: UUID;
  careEpisodeId?: UUID;
  channel: ContactChannel;
  outcome: ContactOutcome;
  note: string;
  followUpAt?: ISODateTime;
}

export interface ContactLog {
  id: UUID;
  patientId: UUID;
  careEpisodeId: string | null;
  channel: ContactChannel;
  outcome: ContactOutcome;
  note: string;
  followUpAt: ISODateTime | null;
  coordinatorName: string;
  createdAt: ISODateTime;
}

/* ---------- 36. Referrals ---------- */
export type ReferralStatus = "created" | "sent" | "accepted" | "completed" | "cancelled";

export interface ReferralInput {
  careEpisodeId: UUID;
  facilityId: UUID;
  specialty?: string;
  urgency: "routine" | "urgent";
  reason: string;
  clinicalSummary?: string;
}

export interface Referral {
  id: UUID;
  patientId: UUID;
  patientName: string;
  careEpisodeId: UUID;
  facility: Facility;
  specialty: string | null;
  urgency: "routine" | "urgent";
  reason: string;
  status: ReferralStatus;
  letterRecordId: UUID;
  createdByName: string;
  createdAt: ISODateTime;
  updatedAt: ISODateTime;
}

/* ---------- 37. Subscription plans ---------- */
export interface Plan {
  code: string;
  name: string;
  description: string;
  priceMonthly: number;
  priceYearly: number;
  benefits: string[];
  maxMembers: number;
  coordinatorIncluded: boolean;
  homeVisitDiscountPct: number;
  active: boolean;
}

/* ---------- 38. Government schemes ---------- */
export interface Scheme {
  id: UUID;
  name: string;
  authority: string;
  level: "central" | "state";
  state: string | null;
  summary: string;
  benefits: string[];
  eligibilityHints: string[];
  documentsTypicallyNeeded: string[];
  officialUrl: string;
  helpline: string | null;
  status: "draft" | "published";
  lastReviewedAt: ISODateTime | ISODate | null;
  disclaimer: string;
}

/** Body for POST/PATCH /admin/schemes (the contract lists "Scheme" fields; the server owns id and lastReviewedAt). */
export type SchemeInput = Omit<Scheme, "id" | "lastReviewedAt">;

/* ================= v1.3 additions (§41–§62) ================= */

/* ---------- 41. Daily check-in ---------- */
export interface CheckinSettings {
  patientId: UUID;
  enabled: boolean;
  windowStart: string;
  windowEnd: string;
  escalateAfterMins: number;
  notifyFamily: boolean;
  notifyCoordinator: boolean;
}
export type CheckInStatus = "ok" | "late" | "missed" | "pending";
export interface CheckIn {
  id: UUID;
  patientId: UUID;
  date: ISODate;
  status: CheckInStatus;
  checkedInAt: ISODateTime | null;
  mood: number | null;
  note: string | null;
}

/* ---------- 42. Chronic care programs ---------- */
export type MetricFrequency = "daily" | "twice_daily" | "weekly";
export type ThresholdLevel = "routine" | "urgent" | "emergency";
export interface Threshold {
  type: VitalType;
  op: "lt" | "gt";
  value: number;
  level: ThresholdLevel;
  message: string;
}
export type ContentStatus = "fixture_unapproved" | "approved";
export interface ProgramTemplate {
  code: string;
  name: string;
  description: string;
  metrics: { type: VitalType; frequency: MetricFrequency; unit: string }[];
  defaultThresholds: Threshold[];
  status: ContentStatus;
  version: string;
}
/** Body for POST /admin/care-programs/templates (the server owns `status`). */
export type ProgramTemplateInput = Omit<ProgramTemplate, "status">;
export type EnrollmentStatus = "active" | "paused" | "completed";
export interface Enrollment {
  id: UUID;
  patientId: UUID;
  patientName: string;
  templateCode: string;
  templateName: string;
  status: EnrollmentStatus;
  thresholds: Threshold[];
  thresholdsApprovedByName: string | null;
  startDate: ISODate;
  endDate: ISODate | null;
  careEpisodeId: string | null;
  adherencePct7d: number | null;
  lastReadingAt: ISODateTime | null;
  openBreaches: number;
  createdAt: ISODateTime;
}
export interface EnrollmentInput {
  patientId: UUID;
  templateCode: string;
  thresholds?: Threshold[];
  startDate: ISODate;
  endDate?: ISODate;
  careEpisodeId?: UUID;
}
export interface ProgramSummary {
  enrollmentId: UUID;
  from: ISODate;
  to: ISODate;
  expectedReadings: number;
  receivedReadings: number;
  adherencePct: number;
  breaches: { at: ISODateTime; type: VitalType; value: number; threshold: Threshold; safetyEventId: string }[];
  trend: { date: ISODate; type: VitalType; avg: number; min: number; max: number }[];
}

/* ---------- 44. Lab tests at home ---------- */
export type LabOrderStatus = "pending_payment" | "scheduled" | "sample_collected" | "processing" | "report_ready" | "cancelled";
export const LAB_ORDER_STATUSES: LabOrderStatus[] = [
  "pending_payment",
  "scheduled",
  "sample_collected",
  "processing",
  "report_ready",
  "cancelled",
];
export interface LabOrder {
  id: UUID;
  patientId: UUID;
  patientName: string;
  tests: { id: UUID; name: string }[];
  total: number;
  discount: number;
  status: LabOrderStatus;
  collectionVisitId: string | null;
  preferredStart: ISODateTime;
  preferredEnd: ISODateTime;
  reportRecordId: string | null;
  partnerName: string;
  partnerOrderId: string | null;
  timeline: { status: LabOrderStatus | string; at: ISODateTime }[];
  careEpisodeId: string | null;
  createdAt: ISODateTime;
}

/* ---------- 46. AI scribe ---------- */
export interface SoapDraft {
  subjective: string;
  objective: string;
  assessment: string;
  plan: string;
}
export interface ScribeDraft {
  id: UUID;
  appointmentId: UUID;
  transcript: string;
  draft: SoapDraft;
  model: string;
  advisory: true;
  generatedAt: ISODateTime;
  audioRetained: false;
}

/* ---------- 47. Drug interaction & allergy checks ---------- */
export type RxWarningSeverity = "info" | "moderate" | "major";
export interface RxWarning {
  severity: RxWarningSeverity;
  type: "allergy" | "duplicate_therapy" | "interaction" | "dose_form";
  drugs: string[];
  message: string;
  source: string;
}
export interface RxCheckResponse {
  warnings: RxWarning[];
  knowledgePack: { version: string; status: ContentStatus | string };
}

/* ---------- 48. Supplies (ops side) ---------- */
export interface SupplyItem {
  code: string;
  name: string;
  unit: string;
  onHand: number;
  reorderLevel: number;
}
export interface LowStockItem {
  providerId: UUID;
  providerName: string;
  code: string;
  name: string;
  onHand: number;
  reorderLevel: number;
}

/* ---------- 49. Second opinion ---------- */
export type SecondOpinionStatus = "pending_payment" | "open" | "claimed" | "answered" | "cancelled";
export interface SecondOpinion {
  id: UUID;
  patientId: UUID;
  patientName: string;
  specialty: string;
  question: string;
  records: { id: UUID; title: string }[];
  status: SecondOpinionStatus;
  price: number;
  doctorName: string | null;
  opinion: string | null;
  recommendations: string[];
  opinionRecordId: string | null;
  dueAt: ISODateTime | null;
  createdAt: ISODateTime;
  answeredAt: ISODateTime | null;
}
export interface SecondOpinionResponseInput {
  opinion: string;
  recommendations: string[];
  suggestTeleconsult: boolean;
}

/* ---------- 51. Insurance ---------- */
export interface InsurancePolicy {
  id: UUID;
  patientId: UUID;
  insurerCode: string;
  insurerName: string;
  policyNumberMasked: string;
  planName: string | null;
  type: "individual" | "family_floater" | "corporate" | "government";
  sumInsured: number | null;
  validFrom: ISODate;
  validTo: ISODate;
  tpaName: string | null;
  cardRecordId: string | null;
  status: "active" | "expiring_soon" | "expired";
  createdAt: ISODateTime;
}

/* ---------- 52. Preventive ---------- */
export type PreventiveStatus = "upcoming" | "due" | "overdue" | "done" | "not_applicable";
export interface PreventiveItem {
  code: string;
  name: string;
  category: "vaccine" | "screening";
  description: string;
  dueDate: ISODate | null;
  status: PreventiveStatus;
  lastDoneAt: ISODateTime | ISODate | null;
  repeatEveryMonths: number | null;
}
export interface PreventiveSchedule {
  items: PreventiveItem[];
  scheduleVersion: string;
  scheduleStatus: ContentStatus | string;
}

/* ---------- 53. Exercise ---------- */
export interface Exercise {
  id: UUID;
  title: string;
  bodyArea: string;
  level: string;
  durationSecs: number;
  videoUrl: string | null;
  imageUrl: string | null;
  instructions: string[];
  precautions: string[];
}
export interface ExercisePlanItem {
  exerciseId: UUID;
  sets: number;
  reps: number;
  holdSecs?: number;
  perDay: number;
  notes?: string;
}
export interface ExercisePlanInput {
  patientId: UUID;
  careEpisodeId?: UUID;
  items: ExercisePlanItem[];
  startDate: ISODate;
  weeks: number;
}
export interface ExercisePlan {
  id: UUID;
  patientId: UUID;
  authorName: string;
  authorRole: string;
  /** The contract writes `items: [...]`; entries follow the create shape (a title may be included). */
  items: (ExercisePlanItem & { title?: string })[];
  startDate: ISODate;
  endDate: ISODate;
  status: "active" | "completed";
  createdAt: ISODateTime;
}
export interface ExerciseProgress {
  sessionsPlanned: number;
  sessionsDone: number;
  adherencePct: number;
  painTrend: { date: ISODate; painScore: number }[];
}

/* ---------- 54. Diet ---------- */
export type MealSlot = "early_morning" | "breakfast" | "mid_morning" | "lunch" | "evening" | "dinner" | "bedtime";
export const MEAL_SLOTS: MealSlot[] = ["early_morning", "breakfast", "mid_morning", "lunch", "evening", "dinner", "bedtime"];
export interface DietTemplate {
  code: string;
  name: string;
  conditions: string[];
  status: ContentStatus | string;
}
export interface Meal {
  slot: MealSlot;
  items: string[];
  notes?: string;
}
export interface DietPlanInput {
  patientId: UUID;
  templateCode?: string;
  conditions: string[];
  calorieTarget?: number;
  meals: Meal[];
  avoid: string[];
  notes?: string;
  validUntil: ISODate;
}
export interface DietPlan {
  id: UUID;
  patientId: UUID;
  authorName: string;
  authorRole: string;
  conditions: string[];
  calorieTarget: number | null;
  meals: Meal[];
  avoid: string[];
  notes: string | null;
  validUntil: ISODate;
  status: "active" | "expired";
  createdAt: ISODateTime;
}

/* ---------- 55. Ambulance ---------- */
export type AmbulanceStatus =
  | "searching"
  | "assigned"
  | "en_route"
  | "arrived"
  | "transporting"
  | "completed"
  | "cancelled"
  | "no_vehicle";
export const AMBULANCE_STATUSES: AmbulanceStatus[] = [
  "searching",
  "assigned",
  "en_route",
  "arrived",
  "transporting",
  "completed",
  "cancelled",
  "no_vehicle",
];
export interface AmbulanceRequest {
  id: UUID;
  patientId: UUID;
  patientName: string;
  type: "bls" | "als";
  status: AmbulanceStatus;
  vehicle: { number: string; driverName: string; phoneMasked: string } | null;
  etaMinutes: number | null;
  location: { lat: number; lng: number; updatedAt: ISODateTime } | null;
  pickup: { lat: number; lng: number; address: string };
  destination: Facility | null;
  partnerName: string;
  timeline: { status: AmbulanceStatus | string; at: ISODateTime }[];
  createdAt: ISODateTime;
}

/* ---------- 57. Organizations ---------- */
export interface OrganizationInput {
  name: string;
  contactName: string;
  contactEmail: string;
  planCode: string;
  seats: number;
  validFrom: ISODate;
  validTo: ISODate;
  billingNote?: string;
}
/** The contract does not spell out `Organization`; we assume the input fields plus `id`. */
export interface Organization extends Omit<OrganizationInput, "billingNote"> {
  id: UUID;
  billingNote?: string | null;
  createdAt?: ISODateTime;
}
export interface OrganizationUsage {
  seats: number;
  redeemed: number;
  activeMembers: number;
  servicesUsed: { appointments: number; homeVisits: number; labOrders: number };
}

/* ---------- 58. Tenants ---------- */
export interface TenantInput {
  code: string;
  displayName: string;
  primaryColor: string;
  logoMediaId?: string;
  facilityIds: string[];
  supportPhone?: string;
  supportEmail?: string;
}
/** The contract does not spell out `Tenant`; we assume the input fields plus `id` (and `logoUrl` when the API resolves it). */
export interface Tenant extends Omit<TenantInput, "logoMediaId" | "supportPhone" | "supportEmail"> {
  id: UUID;
  logoMediaId?: string | null;
  logoUrl?: string | null;
  supportPhone?: string | null;
  supportEmail?: string | null;
}

/* ---------- 59. Discharges ---------- */
export type DischargeStatus = "active" | "completed" | "readmitted" | "withdrawn";
export interface Discharge {
  id: UUID;
  facility: Facility;
  patientId: UUID;
  patientName: string;
  dischargeDate: ISODate;
  diagnosisSummary: string;
  treatingDoctorName: string;
  status: DischargeStatus;
  careEpisodeId: UUID;
  carePlanId: UUID;
  enrollmentId: string | null;
  day: number;
  tasksDone: number;
  tasksTotal: number;
  missedCheckins: number;
  openAlerts: number;
  invitedPhones: string[];
  createdAt: ISODateTime;
}
/** The `followUp` JSON part of POST /discharges. Tasks and medications reuse the §11 care-plan shapes. */
export interface DischargeFollowUp {
  tasks: { type: CareTaskType; title: string; description?: string; owner: CareTaskOwner }[];
  medications: CarePlanInput["medications"];
  followUpDays: number[];
}

/* ---------- 60. Coupons ---------- */
export interface CouponInput {
  code: string;
  description: string;
  type: "percent" | "flat";
  value: number;
  maxDiscount?: number;
  minAmount?: number;
  appliesTo: PaymentPurpose[];
  validFrom: ISODate;
  validTo: ISODate;
  usageLimit?: number;
  perUserLimit: number;
  active: boolean;
}
/** The contract does not spell out `Coupon`; we assume the input fields plus `id` (and a usage count when present). */
export interface Coupon extends Omit<CouponInput, "maxDiscount" | "minAmount" | "usageLimit"> {
  id: UUID;
  maxDiscount?: number | null;
  minAmount?: number | null;
  usageLimit?: number | null;
  usedCount?: number;
}

/* ---------- 61. Support desk ---------- */
export type TicketCategory = "booking" | "payment" | "refund" | "app_issue" | "clinical_concern" | "other";
export type TicketStatus = "open" | "pending_customer" | "resolved" | "closed";
export type TicketPriority = "low" | "normal" | "high" | "urgent";
export const TICKET_STATUSES: TicketStatus[] = ["open", "pending_customer", "resolved", "closed"];
export const TICKET_PRIORITIES: TicketPriority[] = ["low", "normal", "high", "urgent"];
export interface TicketMessage {
  id: UUID;
  ticketId: UUID;
  authorName: string;
  authorRole: "customer" | "agent" | "system";
  text: string;
  internal: boolean;
  at: ISODateTime;
}
export interface Ticket {
  id: UUID;
  number: string;
  userId: UUID;
  userName: string;
  subject: string;
  category: TicketCategory;
  status: TicketStatus;
  priority: TicketPriority;
  assignedToName: string | null;
  refType: string | null;
  refId: string | null;
  messages: TicketMessage[];
  rating: { score: number; comment: string | null } | null;
  slaDueAt: ISODateTime | null;
  createdAt: ISODateTime;
  updatedAt: ISODateTime;
}
export interface SupportMetrics {
  open: number;
  avgFirstResponseMins: number | null;
  avgResolutionHours: number | null;
  csatAvg: number | null;
  byCategory: Record<string, number>;
}
