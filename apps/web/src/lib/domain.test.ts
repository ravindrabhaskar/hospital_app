import { describe, expect, it } from "vitest";
import { parseRulePackJson } from "./safety-rules";
import { isLate, credentialWarning } from "./ops";
import { formatINR, todayIST } from "./format";

describe("parseRulePackJson", () => {
  it("accepts a valid array of rules", () => {
    const r = parseRulePackJson(
      JSON.stringify([{ id: "a", title: "A", description: "", when: { anyKeywords: ["chest pain"] }, level: "emergency", action: "show_emergency" }]),
    );
    expect(r.ok).toBe(true);
  });

  it("reports JSON syntax errors, bad enums, empty conditions and duplicate ids", () => {
    expect(parseRulePackJson("[{").ok).toBe(false);
    const r = parseRulePackJson(
      JSON.stringify([
        { id: "a", title: "A", description: "", when: {}, level: "critical", action: "show_emergency" },
        { id: "a", title: "B", description: "", when: { minSeverity: 8 }, level: "urgent", action: "suggest_doctor" },
      ]),
    );
    expect(r.ok).toBe(false);
    if (!r.ok) {
      const all = r.errors.join("\n");
      expect(all).toMatch(/rules\[0\]\.level/);
      expect(all).toMatch(/at least one condition/);
      expect(all).toMatch(/duplicate rule id/);
    }
  });
});

describe("ops helpers", () => {
  const now = new Date("2026-09-26T10:00:00.000Z");
  it("flags visits that have not arrived by the window end as late", () => {
    expect(isLate({ status: "en_route", preferredEnd: "2026-09-26T09:00:00.000Z" }, now)).toBe(true);
    expect(isLate({ status: "arrived", preferredEnd: "2026-09-26T09:00:00.000Z" }, now)).toBe(false);
    expect(isLate({ status: "assigned", preferredEnd: "2026-09-26T11:00:00.000Z" }, now)).toBe(false);
  });
  it("warns on expired or soon-expiring credentials", () => {
    expect(credentialWarning({ credentialExpiresAt: "2026-09-01" }, now)).toBe("expired");
    expect(credentialWarning({ credentialExpiresAt: "2026-10-10T00:00:00.000Z" }, now)).toBe("soon");
    expect(credentialWarning({ credentialExpiresAt: "2027-09-01" }, now)).toBeNull();
  });
});

describe("format", () => {
  it("uses rupees and IST calendar dates", () => {
    expect(formatINR(499)).toBe("₹499");
    // 20:00 UTC is already the next day in Asia/Kolkata.
    expect(todayIST(new Date("2026-09-26T20:00:00.000Z"))).toBe("2026-09-27");
  });
});
