import type {
  ApplicationDecision,
  ApplicationDecisionInput,
  ApplicationDocType,
  ApplicationStatus,
  ProviderApplication,
} from "@/lib/api/types";
import { istDayEndISO } from "@/lib/format";

export interface DecisionFormValues {
  decision: ApplicationDecision;
  note: string;
  /** YYYY-MM-DD */
  credentialExpiresAt: string;
  zoneIds: string[];
  capabilities: string[];
}

export type DecisionErrors = Partial<Record<keyof DecisionFormValues | "documents", string>>;

/** §30: approval requires at least one registration certificate and one ID proof. */
export const REQUIRED_DOCS: ApplicationDocType[] = ["registration_certificate", "id_proof"];

export const DOC_LABEL: Record<ApplicationDocType, string> = {
  registration_certificate: "Registration certificate",
  degree: "Degree",
  id_proof: "ID proof",
  experience_letter: "Experience letter",
  other: "Other",
};

export function missingRequiredDocs(app: Pick<ProviderApplication, "documents">): ApplicationDocType[] {
  return REQUIRED_DOCS.filter((t) => !app.documents.some((d) => d.docType === t));
}

/** Only open applications can be decided. */
export function isDecidable(status: ApplicationStatus): boolean {
  return status === "submitted" || status === "changes_requested";
}

/**
 * Rules for POST /ops/provider-applications/:id/decision:
 * - every decision needs a note (sent to the applicant for reject / request changes; audited for approve);
 * - approve needs a credential expiry date in the future and the required documents.
 */
export function validateDecision(
  v: DecisionFormValues,
  app: Pick<ProviderApplication, "documents">,
  today: string,
): DecisionErrors {
  const errors: DecisionErrors = {};
  const note = v.note.trim();
  if (!note) {
    errors.note =
      v.decision === "approve" ? "Add a short approval note" : v.decision === "reject" ? "Tell the applicant why" : "Describe the changes needed";
  } else if (note.length > 1000) {
    errors.note = "At most 1000 characters";
  }
  if (v.decision === "approve") {
    if (!v.credentialExpiresAt) errors.credentialExpiresAt = "Credential expiry date is required to approve";
    else if (!/^\d{4}-\d{2}-\d{2}$/.test(v.credentialExpiresAt)) errors.credentialExpiresAt = "Use a valid date";
    else if (v.credentialExpiresAt <= today) errors.credentialExpiresAt = "The expiry date must be in the future";
    const missing = missingRequiredDocs(app);
    if (missing.length) errors.documents = `Approval needs: ${missing.map((m) => DOC_LABEL[m]).join(" and ")}`;
  }
  return errors;
}

export function toDecisionInput(v: DecisionFormValues): ApplicationDecisionInput {
  const base = { decision: v.decision, note: v.note.trim() };
  if (v.decision !== "approve") return base;
  return {
    ...base,
    // The API takes an ISO datetime; the credential stays valid through the whole chosen (IST) day.
    credentialExpiresAt: istDayEndISO(v.credentialExpiresAt),
    ...(v.zoneIds.length ? { zoneIds: v.zoneIds } : {}),
    ...(v.capabilities.length ? { capabilities: v.capabilities } : {}),
  };
}
