import { describe, expect, it } from "vitest";
import { canAccessPath, canRefund, canViewInvoices, homePathFor, visibleNav } from "./roles";
import type { Role } from "./api/types";

const hrefs = (roles: Role[]) => visibleNav(roles).flatMap((s) => s.items.map((i) => i.href));
const sections = (roles: Role[]) => visibleNav(roles).map((s) => s.key);

describe("visibleNav", () => {
  it("doctor sees only the clinician section", () => {
    expect(sections(["doctor"])).toEqual(["clinician"]);
  });

  it("coordinator sees operations only", () => {
    expect(sections(["coordinator"])).toEqual(["ops"]);
    expect(hrefs(["coordinator"])).not.toContain("/admin/audit-logs");
  });

  it("ops_admin sees operations plus read-only admin pages (audit logs, analytics)", () => {
    expect(sections(["ops_admin"])).toEqual(["ops", "admin"]);
    const admin = visibleNav(["ops_admin"]).find((s) => s.key === "admin")!;
    expect(admin.items.map((i) => i.href)).toEqual(["/admin/audit-logs", "/admin/analytics"]);
  });

  it("super_admin sees operations and every admin page", () => {
    expect(sections(["super_admin"])).toEqual(["ops", "admin"]);
    expect(hrefs(["super_admin"])).toEqual(
      expect.arrayContaining(["/admin/users", "/admin/safety-rules", "/admin/flags", "/admin/zones", "/admin/ai", "/admin/knowledge"]),
    );
  });

  it("users with several roles see several sections", () => {
    expect(sections(["doctor", "super_admin"])).toEqual(["clinician", "ops", "admin"]);
  });

  it("patients and providers see nothing", () => {
    expect(visibleNav(["patient"])).toEqual([]);
    expect(visibleNav(["provider"])).toEqual([]);
  });
});

describe("route guard", () => {
  it("allows and denies by path prefix", () => {
    expect(canAccessPath("/clinician/patients/abc", ["doctor"])).toBe(true);
    expect(canAccessPath("/clinician", ["coordinator"])).toBe(false);
    expect(canAccessPath("/ops/payments", ["coordinator"])).toBe(true);
    expect(canAccessPath("/admin/users", ["ops_admin"])).toBe(false);
    expect(canAccessPath("/admin/audit-logs", ["ops_admin"])).toBe(true);
    expect(canAccessPath("/admin/analytics", ["ops_admin"])).toBe(true);
    expect(canAccessPath("/admin/flags", ["super_admin"])).toBe(true);
    expect(canAccessPath("/ops", ["patient"])).toBe(false);
  });

  it("chooses a home page by role", () => {
    expect(homePathFor(["doctor", "super_admin"])).toBe("/clinician");
    expect(homePathFor(["coordinator"])).toBe("/ops");
    expect(homePathFor(["patient"])).toBeNull();
  });

  it("only ops_admin/super_admin may refund", () => {
    expect(canRefund(["coordinator"])).toBe(false);
    expect(canRefund(["ops_admin"])).toBe(true);
  });
});

describe("canViewInvoices (QA B14)", () => {
  it("is limited to finance roles", () => {
    expect(canViewInvoices(["ops_admin"])).toBe(true);
    expect(canViewInvoices(["super_admin"])).toBe(true);
    for (const r of ["coordinator", "doctor", "support_agent", "hospital_staff"] as const) expect(canViewInvoices([r])).toBe(false);
  });
});
