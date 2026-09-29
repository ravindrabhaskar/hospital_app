import type { HttpClient, QueryValue } from "./http";
import type * as T from "./types";

type Q = Record<string, QueryValue>;

/**
 * Typed endpoint functions, one per contract row used by the web portal.
 * Section numbers refer to docs/api/API_CONTRACT.md.
 */
export function createEndpoints(http: HttpClient) {
  const get = <R>(path: string, query?: object) => http.request<R>(path, { query: query as Q | undefined });
  const post = <R>(path: string, body?: unknown, extra?: { idempotencyKey?: boolean | string }) =>
    http.request<R>(path, { method: "POST", body, ...extra });

  return {
    /* 1. System */
    system: {
      health: () => http.request<T.Health>("/health", { anonymous: true }),
    },

    /* 2. Auth */
    auth: {
      requestOtp: (phone: string) =>
        http.request<T.OtpRequestResponse>("/auth/otp/request", { method: "POST", body: { phone }, anonymous: true }),
      verifyOtp: (input: { phone: string; otp: string; deviceName?: string }) =>
        http.request<T.AuthSession>("/auth/otp/verify", { method: "POST", body: input, anonymous: true }),
      logout: (refreshToken: string) =>
        http.request<void>("/auth/logout", { method: "POST", body: { refreshToken }, anonymous: true }),
      me: () => get<T.Me>("/me"),
      updateMe: (input: { name?: string; language?: T.Language; email?: string }) =>
        http.request<T.Me>("/me", { method: "PATCH", body: input }),

      /* 22. Staff MFA (TOTP) */
      mfaEnroll: () => post<T.MfaEnrollResponse>("/auth/mfa/totp/enroll"),
      mfaConfirm: (code: string) => post<T.MfaConfirmResponse>("/auth/mfa/totp/confirm", { code }),
      mfaVerify: (input: T.MfaVerifyInput) => post<T.AuthSession>("/auth/mfa/verify", input),
    },

    /* 21. Public config (no auth) */
    config: {
      public: () => http.request<T.PublicConfig>("/config/public", { anonymous: true }),
    },

    /* 3. Consents (used only as a cheap authenticated probe for MFA enforcement) */
    consents: {
      list: () => get<{ items: unknown[] }>("/consents"),
    },

    /* 23. Account deletion */
    account: {
      deletionRequest: () => get<T.DeletionRequest>("/me/deletion-request"),
      requestDeletion: (reason?: string) => post<T.DeletionRequest>("/me/deletion-request", reason ? { reason } : {}),
      cancelDeletion: () => post<T.DeletionRequest>("/me/deletion-request/cancel"),
    },

    /* 6. Reference data */
    reference: {
      specialties: () => get<{ items: T.Specialty[] }>("/specialties"),
      homeVisitServices: () => get<{ items: T.HomeVisitService[] }>("/home-visit/services"),
    },

    /* 4. Patients */
    patients: {
      get: (id: string) => get<T.PatientProfile>(`/patients/${enc(id)}`),
    },

    /* 5. Care episodes */
    episodes: {
      list: (q: { patientId?: string; status?: T.EpisodeStatus; active?: boolean } & T.ListQuery = {}) =>
        get<T.ListResponse<T.CareEpisode>>("/care-episodes", q),
      get: (id: string) => get<T.CareEpisodeDetail>(`/care-episodes/${enc(id)}`),
      transition: (id: string, input: { to: T.EpisodeStatus; reason: string }) =>
        post<T.CareEpisode>(`/care-episodes/${enc(id)}/transition`, input),
      addNote: (id: string, text: string) => post<T.EpisodeEvent>(`/care-episodes/${enc(id)}/notes`, { text }),
    },

    /* 7. Appointments */
    appointments: {
      get: (id: string) => get<T.Appointment>(`/appointments/${enc(id)}`),
      /* 26. Video consultation */
      videoSession: (id: string) => get<T.VideoSession>(`/appointments/${enc(id)}/video-session`),
    },

    /* 8. Home visits */
    homeVisits: {
      get: (id: string) => get<T.HomeVisit>(`/home-visits/${enc(id)}`),
      assign: (id: string, providerId: string) => post<T.HomeVisit>(`/home-visits/${enc(id)}/assign`, { providerId }),
      cancel: (id: string, reason: string) => post<T.HomeVisit>(`/home-visits/${enc(id)}/cancel`, { reason }),
    },

    /* 9. Records & vitals */
    records: {
      list: (q: { patientId: string; type?: T.RecordType } & T.ListQuery) =>
        get<T.ListResponse<T.MedicalRecord>>("/records", q),
      get: (id: string) => get<T.MedicalRecord>(`/records/${enc(id)}`),
      file: (id: string) => http.request<Blob>(`/records/${enc(id)}/file`, { responseType: "blob" }),
    },
    vitals: {
      list: (q: { patientId: string; type?: T.VitalType } & T.ListQuery) =>
        get<T.ListResponse<T.VitalMeasurement>>("/vitals", q),
    },

    /* 11. Care plans */
    carePlans: {
      list: (q: { patientId?: string; careEpisodeId?: string } & T.ListQuery) =>
        get<T.ListResponse<T.CarePlan>>("/care-plans", q),
      create: (input: T.CarePlanInput) => post<T.CarePlan>("/care-plans", input),
    },

    /* 15. Wound cases */
    wounds: {
      list: (q: { patientId: string } & T.ListQuery) => get<T.ListResponse<T.WoundCase>>("/wound-cases", q),
      get: (id: string) => get<T.WoundCase>(`/wound-cases/${enc(id)}`),
      review: (id: string, notes: string) => post<T.WoundCase>(`/wound-cases/${enc(id)}/review`, { notes }),
    },

    /* 16. Clinician */
    clinician: {
      queue: (date: string) => get<T.ListResponse<T.QueueItem>>("/clinician/queue", { date }),
      patients: (q: { q?: string } & T.ListQuery = {}) =>
        get<T.ListResponse<T.PatientSummary>>("/clinician/patients", q),
      snapshot: (patientId: string) => get<T.ClinicalSnapshot>(`/clinician/patients/${enc(patientId)}/snapshot`),
      start: (appointmentId: string) => post<T.Appointment>(`/clinician/appointments/${enc(appointmentId)}/start`),
      complete: (appointmentId: string, input: { notes: string; outcome: T.ConsultOutcome }) =>
        post<T.Appointment>(`/clinician/appointments/${enc(appointmentId)}/complete`, input),
      escalations: (q: T.ListQuery = {}) => get<T.ListResponse<T.SafetyEvent>>("/clinician/escalations", q),
      aiFeedback: (input: { aiInteractionId: string; decision: T.AiFeedbackDecision; note: string }) =>
        post<{ id: string }>("/clinician/ai-feedback", input),
    },

    /* 18. Operations */
    ops: {
      overview: () => get<T.OpsOverview>("/ops/overview"),
      homeVisits: (q: { status?: T.HomeVisitStatus } & T.ListQuery = {}) =>
        get<T.ListResponse<T.OpsHomeVisit>>("/ops/home-visits", q),
      providers: (q: { status?: string } & T.ListQuery = {}) =>
        get<T.ListResponse<T.OpsProvider>>("/ops/providers", q),
      verifyProvider: (id: string, input: { status: "verified" | "rejected" | "suspended"; note: string }) =>
        post<T.OpsProvider>(`/ops/providers/${enc(id)}/verification`, input),
      safetyEvents: (q: { status?: T.SafetyEvent["status"] } & T.ListQuery = {}) =>
        get<T.ListResponse<T.SafetyEvent>>("/ops/safety-events", q),
      acknowledgeSafetyEvent: (id: string) => post<T.SafetyEvent>(`/ops/safety-events/${enc(id)}/acknowledge`),
      resolveSafetyEvent: (id: string, note: string) =>
        post<T.SafetyEvent>(`/ops/safety-events/${enc(id)}/resolve`, { note }),
      episodes: (q: { status?: T.EpisodeStatus } & T.ListQuery = {}) =>
        get<T.ListResponse<T.CareEpisode>>("/ops/care-episodes", q),
      overdueTasks: (q: T.ListQuery = {}) => get<T.ListResponse<T.OverdueTask>>("/ops/overdue-tasks", q),
      incidents: (q: { status?: T.IncidentStatus } & T.ListQuery = {}) =>
        get<T.ListResponse<T.Incident>>("/ops/incidents", q),
      createIncident: (input: T.CreateIncidentInput) => post<T.Incident>("/ops/incidents", input),
      updateIncident: (id: string, input: { status?: T.IncidentStatus; note?: string }) =>
        http.request<T.Incident>(`/ops/incidents/${enc(id)}`, { method: "PATCH", body: input }),
      payments: (q: { status?: T.PaymentStatus } & T.ListQuery = {}) =>
        get<T.ListResponse<T.OpsPayment>>("/ops/payments", q),
      refund: (paymentId: string, input: { reason: string; amount?: number }) =>
        post<T.Payment>(`/payments/${enc(paymentId)}/refund`, input),
    },

    /* 19. Admin */
    admin: {
      users: (q: { q?: string; role?: T.Role } & T.ListQuery = {}) => get<T.ListResponse<T.AdminUser>>("/admin/users", q),
      setRoles: (id: string, roles: T.Role[]) =>
        http.request<T.AdminUser>(`/admin/users/${enc(id)}/roles`, { method: "PUT", body: { roles } }),
      disableUser: (id: string) => post<T.AdminUser>(`/admin/users/${enc(id)}/disable`),
      /* 22. super_admin, audited */
      resetMfa: (id: string) => post<T.AdminUser>(`/admin/users/${enc(id)}/mfa/reset`),
      createStaff: (input: T.CreateStaffInput) => post<T.AdminUser>("/admin/staff", input),
      auditLogs: (q: T.AuditLogQuery & T.ListQuery = {}) => get<T.ListResponse<T.AuditLog>>("/admin/audit-logs", { ...q }),
      rulePacks: (q: T.ListQuery = {}) => get<T.ListResponse<T.SafetyRulePack>>("/admin/safety-rule-packs", q),
      createRulePack: (input: { version: string; rules: T.SafetyRule[] }) =>
        post<T.SafetyRulePack>("/admin/safety-rule-packs", input),
      approveRulePack: (id: string, input: { approverName: string; approverRegistration: string }) =>
        post<T.SafetyRulePack>(`/admin/safety-rule-packs/${enc(id)}/approve`, input),
      activateRulePack: (id: string) => post<T.SafetyRulePack>(`/admin/safety-rule-packs/${enc(id)}/activate`),
      aiInteractions: (q: { useCase?: string; safetyLevel?: string } & T.ListQuery = {}) =>
        get<T.ListResponse<T.AiInteraction>>("/admin/ai-interactions", q),
      knowledgeSources: (q: T.ListQuery = {}) => get<T.ListResponse<T.KnowledgeSource>>("/admin/knowledge-sources", q),
      createKnowledgeSource: (input: T.CreateKnowledgeSourceInput) =>
        post<T.KnowledgeSource>("/admin/knowledge-sources", input),
      setKnowledgeStatus: (id: string, status: T.KnowledgeStatus) =>
        post<T.KnowledgeSource>(`/admin/knowledge-sources/${enc(id)}/status`, { status }),
      featureFlags: () => get<{ items: T.FeatureFlag[] }>("/admin/feature-flags"),
      setFeatureFlag: (key: string, input: { enabled: boolean; cohort?: string }) =>
        http.request<T.FeatureFlag>(`/admin/feature-flags/${enc(key)}`, { method: "PUT", body: input }),
      analytics: () => get<T.Analytics>("/admin/analytics"),
      zones: (q: T.ListQuery = {}) => get<T.ListResponse<T.ServiceZone>>("/admin/service-zones", q),
      createZone: (input: { name: string; city: string; pincodes: string[] }) =>
        post<T.ServiceZone>("/admin/service-zones", input),
    },

    /* ================= v1.2 (§29–§39) ================= */

    /* 6. Doctors & facilities (reference, used by v1.2 screens) */
    doctors: {
      list: (q: { specialty?: string; q?: string; language?: string; mode?: string } & T.ListQuery = {}) =>
        get<T.ListResponse<T.Doctor>>("/doctors", q),
      get: (id: string) => get<T.DoctorDetail>(`/doctors/${enc(id)}`),
      slots: (id: string, date: string) => get<{ items: T.Slot[] }>(`/doctors/${enc(id)}/slots`, { date }),
    },
    facilities: {
      list: (q: { type?: T.FacilityType; q?: string } & T.ListQuery = {}) => get<T.ListResponse<T.Facility>>("/facilities", q),
    },

    /* 29. Doctor self-management, schedules & photos */
    doctorSelf: {
      profile: () => get<T.DoctorProfile>("/doctor/me/profile"),
      updateProfile: (input: T.DoctorProfileUpdate) =>
        http.request<T.DoctorProfile>("/doctor/me/profile", { method: "PATCH", body: input }),
      schedule: () => get<T.Schedule>("/doctor/me/schedule"),
      saveSchedule: (weekly: T.WeeklyBlock[]) =>
        http.request<T.Schedule>("/doctor/me/schedule", { method: "PUT", body: { weekly } }),
      addLeave: (input: { date: string; reason?: string }) => post<T.AddLeaveResponse>("/doctor/me/leaves", input),
      removeLeave: (id: string) => http.request<void>(`/doctor/me/leaves/${enc(id)}`, { method: "DELETE" }),
    },
    media: {
      uploadPhoto: (file: File | Blob) => {
        const fd = new FormData();
        fd.append("image", file);
        return post<{ photoUrl: string }>("/me/photo", fd);
      },
    },

    /* 30. Provider applications (ops side) */
    applications: {
      list: (q: { status?: T.ApplicationStatus } & T.ListQuery = {}) =>
        get<T.ListResponse<T.ProviderApplication>>("/ops/provider-applications", q),
      get: (id: string) => get<T.ProviderApplication>(`/ops/provider-applications/${enc(id)}`),
      documentFile: (id: string, docId: string) =>
        http.request<Blob>(`/ops/provider-applications/${enc(id)}/documents/${enc(docId)}/file`, { responseType: "blob" }),
      decide: (id: string, input: T.ApplicationDecisionInput) =>
        post<T.ProviderApplication>(`/ops/provider-applications/${enc(id)}/decision`, input),
    },

    /* 31. e-Prescriptions */
    prescriptions: {
      create: (input: T.PrescriptionInput) => post<T.Prescription>("/clinician/prescriptions", input),
      /* 47. Interaction & allergy check */
      check: (input: { patientId: string; items: { drugName: string; strength?: string }[] }, signal?: AbortSignal) =>
        http.request<T.RxCheckResponse>("/clinician/prescriptions/check", { method: "POST", body: input, signal }),
      list: (q: { patientId: string } & T.ListQuery) => get<T.ListResponse<T.Prescription>>("/prescriptions", q),
      get: (id: string) => get<T.Prescription>(`/prescriptions/${enc(id)}`),
      pdf: (id: string) => http.request<Blob>(`/prescriptions/${enc(id)}/pdf`, { responseType: "blob" }),
    },

    /* 32. Invoices, earnings & settlements */
    invoices: {
      get: (paymentId: string) => get<T.Invoice>(`/payments/${enc(paymentId)}/invoice`),
      pdf: (paymentId: string) => http.request<Blob>(`/payments/${enc(paymentId)}/invoice.pdf`, { responseType: "blob" }),
    },
    earnings: {
      mine: (q: { from?: string; to?: string } = {}) => get<T.Earnings>("/provider/earnings", q),
      settlements: (q: { from?: string; to?: string } & T.ListQuery = {}) =>
        get<T.ListResponse<T.Earnings>>("/ops/settlements", q),
      settlementsCsv: (q: { from?: string; to?: string } = {}) =>
        http.request<Blob>("/ops/settlements.csv", { query: q as Q, responseType: "blob" }),
    },

    /* 33. Reviews (moderation) */
    reviews: {
      list: (q: { status?: T.ReviewStatus } & T.ListQuery = {}) => get<T.ListResponse<T.Review>>("/ops/reviews", q),
      moderate: (id: string, input: { status: "published" | "rejected"; note?: string }) =>
        post<T.Review>(`/ops/reviews/${enc(id)}/moderate`, input),
    },

    /* 34. Care-team messaging */
    messages: {
      inbox: (q: T.ListQuery = {}) => get<T.ListResponse<T.InboxThread>>("/inbox", q),
      list: (careEpisodeId: string, after?: string) =>
        get<{ items: T.ChatMessage[] }>(`/care-episodes/${enc(careEpisodeId)}/messages`, { after }),
      send: (careEpisodeId: string, input: { text: string; attachmentRecordId?: string }) =>
        post<T.ChatMessage>(`/care-episodes/${enc(careEpisodeId)}/messages`, input),
      markRead: (careEpisodeId: string) => post<void>(`/care-episodes/${enc(careEpisodeId)}/messages/read`),
    },

    /* 35. Coordinator workspace */
    coordinator: {
      assign: (careEpisodeId: string, userId: string) =>
        post<T.CareEpisode>(`/ops/care-episodes/${enc(careEpisodeId)}/assign-coordinator`, { userId }),
      caseload: (q: T.ListQuery = {}) => get<T.ListResponse<T.CaseloadItem>>("/coordinator/caseload", q),
      logContact: (input: T.ContactLogInput) => post<T.ContactLog>("/coordinator/contacts", input),
      contacts: (q: { patientId: string } & T.ListQuery) => get<T.ListResponse<T.ContactLog>>("/coordinator/contacts", q),
    },

    /* 36. Referrals */
    referrals: {
      create: (input: T.ReferralInput) => post<T.Referral>("/clinician/referrals", input),
      list: (q: { patientId: string } & T.ListQuery) => get<T.ListResponse<T.Referral>>("/referrals", q),
      update: (id: string, input: { status: Exclude<T.ReferralStatus, "created">; note?: string }) =>
        http.request<T.Referral>(`/referrals/${enc(id)}`, { method: "PATCH", body: input }),
    },

    /* 29. Admin: a doctor's schedule (super_admin, ops_admin) */
    adminSchedules: {
      get: (doctorId: string) => get<T.Schedule>(`/admin/doctors/${enc(doctorId)}/schedule`),
      save: (doctorId: string, weekly: T.WeeklyBlock[]) =>
        http.request<T.Schedule>(`/admin/doctors/${enc(doctorId)}/schedule`, { method: "PUT", body: { weekly } }),
    },

    /* 37. Subscription plans (admin) */
    plans: {
      list: (q: T.ListQuery = {}) => get<T.ListResponse<T.Plan>>("/admin/subscription-plans", q),
      create: (input: T.Plan) => post<T.Plan>("/admin/subscription-plans", input),
      update: (code: string, input: Partial<Omit<T.Plan, "code">>) =>
        http.request<T.Plan>(`/admin/subscription-plans/${enc(code)}`, { method: "PATCH", body: input }),
    },

    /* 38. Government schemes (admin) */
    schemes: {
      list: (q: T.ListQuery = {}) => get<T.ListResponse<T.Scheme>>("/admin/schemes", q),
      create: (input: T.SchemeInput) => post<T.Scheme>("/admin/schemes", input),
      update: (id: string, input: Partial<T.SchemeInput>) =>
        http.request<T.Scheme>(`/admin/schemes/${enc(id)}`, { method: "PATCH", body: input }),
    },

    /* ================= v1.3 (§41–§62) ================= */

    /* 41. Daily check-in */
    checkins: {
      settings: (patientId: string) => get<T.CheckinSettings>(`/patients/${enc(patientId)}/checkin-settings`),
      list: (patientId: string, days = 30) => get<T.ListResponse<T.CheckIn>>(`/patients/${enc(patientId)}/checkins`, { days }),
    },

    /* 42. Chronic care programs */
    programs: {
      templates: () => get<T.ListResponse<T.ProgramTemplate>>("/care-programs/templates"),
      enrollments: (q: { patientId?: string } & T.ListQuery = {}) =>
        get<T.ListResponse<T.Enrollment>>("/care-programs/enrollments", q),
      enroll: (input: T.EnrollmentInput) => post<T.Enrollment>("/care-programs/enrollments", input),
      updateEnrollment: (id: string, input: { status?: T.EnrollmentStatus; thresholds?: T.Threshold[] }) =>
        http.request<T.Enrollment>(`/care-programs/enrollments/${enc(id)}`, { method: "PATCH", body: input }),
      summary: (id: string, q: { from?: string; to?: string } = {}) =>
        get<T.ProgramSummary>(`/care-programs/enrollments/${enc(id)}/summary`, q),
    },
    adminPrograms: {
      templates: () => get<T.ListResponse<T.ProgramTemplate>>("/admin/care-programs/templates"),
      /** Creates a template (or, with an existing code, a new version for review; it starts unapproved). */
      create: (input: T.ProgramTemplateInput) => post<T.ProgramTemplate>("/admin/care-programs/templates", input),
      approve: (code: string) => post<T.ProgramTemplate>(`/admin/care-programs/templates/${enc(code)}/approve`),
    },

    /* 44. Lab tests */
    lab: {
      orders: (q: { patientId?: string } & T.ListQuery = {}) => get<T.ListResponse<T.LabOrder>>("/lab/orders", q),
      order: (id: string) => get<T.LabOrder>(`/lab/orders/${enc(id)}`),
      opsOrders: (q: { status?: T.LabOrderStatus } & T.ListQuery = {}) => get<T.ListResponse<T.LabOrder>>("/ops/lab-orders", q),
    },

    /* 46. AI scribe */
    scribe: {
      fromTranscript: (appointmentId: string, transcript: string) =>
        post<T.ScribeDraft>(`/clinician/appointments/${enc(appointmentId)}/scribe`, { transcript, consentConfirmed: true }),
      fromAudio: (appointmentId: string, audio: Blob, fileName = "consultation.webm") => {
        const fd = new FormData();
        fd.append("audio", audio, fileName);
        fd.append("consentConfirmed", "true");
        return post<T.ScribeDraft>(`/clinician/appointments/${enc(appointmentId)}/scribe`, fd);
      },
    },

    /* 48. Supplies (ops) */
    supplies: {
      lowStock: (q: T.ListQuery = {}) => get<T.ListResponse<T.LowStockItem>>("/ops/supplies/low-stock", q),
      restock: (providerId: string, items: { code: string; qty: number }[]) =>
        post<{ items: T.SupplyItem[] }>(`/ops/providers/${enc(providerId)}/supplies/restock`, { items }),
    },

    /* 49. Second opinions */
    secondOpinions: {
      forPatient: (patientId: string) => get<T.ListResponse<T.SecondOpinion>>("/second-opinions", { patientId }),
      get: (id: string) => get<T.SecondOpinion>(`/second-opinions/${enc(id)}`),
      clinicianList: (scope: "open" | "mine", q: T.ListQuery = {}) =>
        get<T.ListResponse<T.SecondOpinion>>("/clinician/second-opinions", { scope, ...q }),
      claim: (id: string) => post<T.SecondOpinion>(`/clinician/second-opinions/${enc(id)}/claim`),
      respond: (id: string, input: T.SecondOpinionResponseInput) =>
        post<T.SecondOpinion>(`/clinician/second-opinions/${enc(id)}/respond`, input),
    },

    /* 51. Insurance */
    insurance: {
      policies: (patientId: string) => get<T.ListResponse<T.InsurancePolicy>>(`/patients/${enc(patientId)}/insurance-policies`),
    },

    /* 52. Preventive */
    preventive: {
      schedule: (patientId: string) => get<T.PreventiveSchedule>(`/patients/${enc(patientId)}/preventive-schedule`),
    },

    /* 53. Exercise */
    exercise: {
      library: (q: { bodyArea?: string } = {}) => get<T.ListResponse<T.Exercise>>("/exercise-library", q),
      plans: (patientId: string) => get<T.ListResponse<T.ExercisePlan>>("/exercise-plans", { patientId }),
      create: (input: T.ExercisePlanInput) => post<T.ExercisePlan>("/exercise-plans", input),
      progress: (id: string) => get<T.ExerciseProgress>(`/exercise-plans/${enc(id)}/progress`),
    },

    /* 54. Diet */
    diet: {
      templates: () => get<T.ListResponse<T.DietTemplate>>("/diet-templates"),
      plans: (patientId: string) => get<T.ListResponse<T.DietPlan>>("/diet-plans", { patientId }),
      create: (input: T.DietPlanInput) => post<T.DietPlan>("/diet-plans", input),
      adherence: (id: string, days = 14) =>
        get<{ days: { date: string; slotsLogged: number; slotsFollowed: number }[]; adherencePct: number }>(
          `/diet-plans/${enc(id)}/adherence`,
          { days },
        ),
    },

    /* 55. Ambulance (ops) */
    ambulance: {
      opsList: (q: { status?: T.AmbulanceStatus } & T.ListQuery = {}) =>
        get<T.ListResponse<T.AmbulanceRequest>>("/ops/ambulance-requests", q),
      get: (id: string) => get<T.AmbulanceRequest>(`/ambulance/requests/${enc(id)}`),
    },

    /* 57. Organizations */
    organizations: {
      list: (q: T.ListQuery = {}) => get<T.ListResponse<T.Organization>>("/admin/organizations", q),
      create: (input: T.OrganizationInput) => post<T.Organization>("/admin/organizations", input),
      update: (id: string, input: Partial<T.OrganizationInput>) =>
        http.request<T.Organization>(`/admin/organizations/${enc(id)}`, { method: "PATCH", body: input }),
      generateCodes: (id: string, count: number) => post<{ codes: string[] }>(`/admin/organizations/${enc(id)}/codes`, { count }),
      usage: (id: string) => get<T.OrganizationUsage>(`/admin/organizations/${enc(id)}/usage`),
    },

    /* 58. Tenants */
    tenants: {
      list: (q: T.ListQuery = {}) => get<T.ListResponse<T.Tenant>>("/admin/tenants", q),
      create: (input: T.TenantInput) => post<T.Tenant>("/admin/tenants", input),
      update: (id: string, input: Partial<T.TenantInput>) =>
        http.request<T.Tenant>(`/admin/tenants/${enc(id)}`, { method: "PATCH", body: input }),
    },

    /* 59. Discharges (hospital_staff) */
    discharges: {
      list: (q: { status?: T.DischargeStatus } & T.ListQuery = {}) => get<T.ListResponse<T.Discharge>>("/discharges", q),
      get: (id: string) => get<T.Discharge>(`/discharges/${enc(id)}`),
      /** Multipart: build the FormData with `buildDischargeFormData` (src/lib/discharge.ts). */
      create: (form: FormData) => post<T.Discharge>("/discharges", form),
    },

    /* 60. Coupons */
    coupons: {
      list: (q: T.ListQuery = {}) => get<T.ListResponse<T.Coupon>>("/admin/coupons", q),
      create: (input: T.CouponInput) => post<T.Coupon>("/admin/coupons", input),
      update: (id: string, input: Partial<T.CouponInput>) =>
        http.request<T.Coupon>(`/admin/coupons/${enc(id)}`, { method: "PATCH", body: input }),
    },

    /* 61. Support desk (agent side) */
    support: {
      tickets: (q: { status?: T.TicketStatus; assignedTo?: "me" } & T.ListQuery = {}) =>
        get<T.ListResponse<T.Ticket>>("/ops/support/tickets", q),
      ticket: (id: string) => get<T.Ticket>(`/support/tickets/${enc(id)}`),
      assign: (id: string, userId: string) => post<T.Ticket>(`/ops/support/tickets/${enc(id)}/assign`, { userId }),
      reply: (id: string, input: { text: string; internal?: boolean }) =>
        post<T.TicketMessage>(`/ops/support/tickets/${enc(id)}/reply`, input),
      update: (id: string, input: { status?: T.TicketStatus; priority?: T.TicketPriority }) =>
        http.request<T.Ticket>(`/ops/support/tickets/${enc(id)}`, { method: "PATCH", body: input }),
      metrics: () => get<T.SupportMetrics>("/ops/support/metrics"),
    },
  };
}

export type Endpoints = ReturnType<typeof createEndpoints>;

function enc(s: string) {
  return encodeURIComponent(s);
}
