import { describe, expect, it } from "vitest";
import { canAccessPath, canUseSupportDesk, homePathFor, isPortalUser, visibleNav } from "./roles";
import type { Role } from "./api/types";

const hrefs = (roles: Role[]) => visibleNav(roles).flatMap((s) => s.items.map((i) => i.href));

describe("v1.3 roles: navigation", () => {
  it("hospital_staff sees only the hospital section", () => {
    expect(visibleNav(["hospital_staff"]).map((s) => s.key)).toEqual(["hospital"]);
    expect(hrefs(["hospital_staff"])).toEqual(["/hospital", "/hospital/new"]);
  });

  it("support_agent sees only the support desk", () => {
    expect(visibleNav(["support_agent"]).map((s) => s.key)).toEqual(["support"]);
    expect(hrefs(["support_agent"])).toEqual(["/support"]);
  });

  it("coordinators and admins get the desk once, under Operations, plus the new ops pages", () => {
    for (const r of ["coordinator", "ops_admin", "super_admin"] as Role[]) {
      const nav = visibleNav([r]);
      const withDesk = nav.filter((s) => s.items.some((i) => i.href === "/support")).map((s) => s.key);
      expect(withDesk).toEqual(["ops"]);
      expect(hrefs([r])).toEqual(expect.arrayContaining(["/ops/lab-orders", "/ops/ambulance", "/ops/supplies"]));
      expect(hrefs([r])).not.toContain("/hospital");
    }
  });

  it("super_admin sees the new admin pages; ops_admin does not; doctors get second opinions", () => {
    expect(hrefs(["super_admin"])).toEqual(expect.arrayContaining(["/admin/programs", "/admin/organizations", "/admin/tenants", "/admin/coupons"]));
    expect(hrefs(["ops_admin"])).not.toContain("/admin/coupons");
    expect(hrefs(["doctor"])).toContain("/clinician/second-opinions");
    expect(hrefs(["doctor"])).not.toContain("/support");
  });
});

describe("v1.3 roles: guards and landing", () => {
  it.each<[string, Role[], boolean]>([
    ["/hospital", ["hospital_staff"], true],
    ["/hospital/discharges/d1", ["hospital_staff"], true],
    ["/hospital/new", ["super_admin"], false],
    ["/hospital", ["doctor"], false],
    ["/support", ["support_agent"], true],
    ["/support", ["coordinator"], true],
    ["/support", ["ops_admin"], true],
    ["/support", ["doctor"], false],
    ["/support", ["hospital_staff"], false],
    ["/ops", ["support_agent"], false],
    ["/ops/ambulance", ["coordinator"], true],
    ["/admin/programs", ["super_admin"], true],
    ["/admin/coupons", ["ops_admin"], false],
    ["/clinician/second-opinions", ["doctor"], true],
    ["/clinician/second-opinions", ["support_agent"], false],
  ])("%s for %j → %s", (path, roles, allowed) => {
    expect(canAccessPath(path, roles)).toBe(allowed);
  });

  it("lands hospital staff on /hospital and support agents on /support; both may use the portal", () => {
    expect(homePathFor(["hospital_staff"])).toBe("/hospital");
    expect(homePathFor(["support_agent"])).toBe("/support");
    expect(homePathFor(["coordinator", "support_agent"])).toBe("/ops");
    expect(isPortalUser(["hospital_staff"])).toBe(true);
    expect(isPortalUser(["support_agent"])).toBe(true);
    expect(canUseSupportDesk(["coordinator"])).toBe(true);
    expect(canUseSupportDesk(["doctor"])).toBe(false);
    expect(homePathFor(["patient", "provider"])).toBeNull();
  });
});
