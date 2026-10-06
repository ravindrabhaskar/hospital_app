import { describe, expect, it } from "vitest";
import type { ApplicationDocType, ProviderApplication } from "@/lib/api/types";
import { toDecisionInput, validateDecision, type DecisionFormValues } from "./application-decision";

const TODAY = "2026-09-26";

function app(docTypes: ApplicationDocType[] = ["registration_certificate", "id_proof"]): Pick<ProviderApplication, "documents"> {
  return {
    documents: docTypes.map((docType, i) => ({
      id: `d${i}`,
      docType,
      fileName: `${docType}.pdf`,
      mimeType: "application/pdf",
      sizeBytes: 1000,
      uploadedAt: "2026-09-20T05:00:00.000Z",
    })),
  };
}

function values(over: Partial<DecisionFormValues> = {}): DecisionFormValues {
  return { decision: "approve", note: "Credentials checked", credentialExpiresAt: "2027-09-30", zoneIds: [], capabilities: [], ...over };
}

describe("validateDecision", () => {
  it("approve requires a credential expiry date", () => {
    expect(validateDecision(values({ credentialExpiresAt: "" }), app(), TODAY).credentialExpiresAt).toBeTruthy();
  });

  it("approve rejects an expiry of today or in the past", () => {
    expect(validateDecision(values({ credentialExpiresAt: TODAY }), app(), TODAY).credentialExpiresAt).toBeTruthy();
    expect(validateDecision(values({ credentialExpiresAt: "2026-01-01" }), app(), TODAY).credentialExpiresAt).toBeTruthy();
  });

  it("approve accepts a future expiry with the required documents", () => {
    expect(validateDecision(values({ credentialExpiresAt: "2026-09-27" }), app(), TODAY)).toEqual({});
  });

  it("approve is blocked when a registration certificate is missing", () => {
    const errs = validateDecision(values(), app(["id_proof", "degree"]), TODAY);
    expect(errs.documents).toMatch(/registration certificate/i);
  });

  it("approve is blocked when an ID proof is missing", () => {
    const errs = validateDecision(values(), app(["registration_certificate"]), TODAY);
    expect(errs.documents).toMatch(/id proof/i);
  });

  it.each(["reject", "request_changes"] as const)("%s needs a note but no expiry or documents", (decision) => {
    const noNote = validateDecision(values({ decision, note: "  ", credentialExpiresAt: "" }), app([]), TODAY);
    expect(noNote.note).toBeTruthy();
    expect(noNote.credentialExpiresAt).toBeUndefined();
    expect(noNote.documents).toBeUndefined();
    expect(validateDecision(values({ decision, note: "Blurry scan", credentialExpiresAt: "" }), app([]), TODAY)).toEqual({});
  });
});

describe("toDecisionInput", () => {
  it("omits expiry, zones and capabilities for non-approve decisions", () => {
    const input = toDecisionInput(values({ decision: "reject", note: " Not eligible ", zoneIds: ["z1"], capabilities: ["wound_care"] }));
    expect(input).toEqual({ decision: "reject", note: "Not eligible" });
    expect(toDecisionInput(values({ decision: "request_changes", zoneIds: ["z1"] }))).toEqual({
      decision: "request_changes",
      note: "Credentials checked",
    });
  });

  it("includes expiry, zones and capabilities for approve", () => {
    expect(toDecisionInput(values({ zoneIds: ["z1", "z2"], capabilities: ["wound_care"] }))).toEqual({
      decision: "approve",
      note: "Credentials checked",
      credentialExpiresAt: "2027-09-30T18:29:59.999Z",
      zoneIds: ["z1", "z2"],
      capabilities: ["wound_care"],
    });
  });

  it("omits empty arrays for approve", () => {
    const input = toDecisionInput(values());
    expect(input).toEqual({ decision: "approve", note: "Credentials checked", credentialExpiresAt: "2027-09-30T18:29:59.999Z" });
    expect(input).not.toHaveProperty("zoneIds");
    expect(input).not.toHaveProperty("capabilities");
  });

  it("sends the expiry as a full ISO datetime the API accepts (end of the chosen IST day)", () => {
    const { credentialExpiresAt } = toDecisionInput(values({ credentialExpiresAt: "2028-12-31" }));
    expect(credentialExpiresAt).toBe("2028-12-31T18:29:59.999Z");
    // Mirrors the API's z.string().datetime({ offset: true }).
    expect(credentialExpiresAt).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/);
  });
});
