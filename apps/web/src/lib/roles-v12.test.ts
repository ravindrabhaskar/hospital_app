import { describe, expect, it } from "vitest";
import { canAccessPath, canAssignAnyCoordinator, canDecideApplications, visibleNav } from "./roles";
import type { Role } from "./api/types";

const hrefs = (roles: Role[]) => visibleNav(roles).flatMap((s) => s.items.map((i) => i.href));

describe("v1.2 navigation", () => {
  it("doctor sees profile, schedule, earnings and the inbox (once)", () => {
    const h = hrefs(["doctor"]);
    expect(h).toEqual(expect.arrayContaining(["/clinician/profile", "/clinician/schedule", "/clinician/earnings", "/inbox"]));
    expect(h.filter((x) => x === "/inbox")).toHaveLength(1);
    expect(h).not.toContain("/coordinator");
    expect(h).not.toContain("/ops/applications");
  });

  it("coordinator sees the workspace, inbox, applications and reviews but not settlements or admin pages", () => {
    const h = hrefs(["coordinator"]);
    expect(h).toEqual(expect.arrayContaining(["/coordinator", "/inbox", "/ops/applications", "/ops/reviews"]));
    expect(h).not.toContain("/ops/settlements");
    expect(h).not.toContain("/admin/doctors");
    expect(h).not.toContain("/admin/plans");
  });

  it("ops_admin also sees settlements and doctor schedules, not plans or schemes", () => {
    const h = hrefs(["ops_admin"]);
    expect(h).toEqual(expect.arrayContaining(["/coordinator", "/ops/settlements", "/admin/doctors"]));
    expect(h).not.toContain("/admin/plans");
    expect(h).not.toContain("/admin/schemes");
  });

  it("super_admin sees plans and schemes; a doctor + super_admin sees the inbox once, under Clinician", () => {
    expect(hrefs(["super_admin"])).toEqual(expect.arrayContaining(["/admin/plans", "/admin/schemes", "/ops/settlements"]));
    const nav = visibleNav(["doctor", "super_admin"]);
    const inboxSections = nav.filter((s) => s.items.some((i) => i.href === "/inbox")).map((s) => s.key);
    expect(inboxSections).toEqual(["clinician"]);
  });

  it("patients and providers see none of the new pages", () => {
    expect(hrefs(["patient"])).toEqual([]);
    expect(hrefs(["provider"])).toEqual([]);
  });
});

describe("v1.2 route guard", () => {
  it.each<[string, Role[], boolean]>([
    ["/clinician/schedule", ["doctor"], true],
    ["/clinician/earnings", ["coordinator"], false],
    ["/coordinator", ["coordinator"], true],
    ["/coordinator", ["ops_admin"], true],
    ["/coordinator", ["doctor"], false],
    ["/inbox", ["doctor"], true],
    ["/inbox", ["coordinator"], true],
    ["/inbox", ["patient"], false],
    ["/ops/settlements", ["coordinator"], false],
    ["/ops/settlements", ["ops_admin"], true],
    ["/ops/applications/abc", ["coordinator"], true],
    ["/admin/doctors/d1/schedule", ["ops_admin"], true],
    ["/admin/doctors/d1/schedule", ["coordinator"], false],
    ["/admin/plans", ["ops_admin"], false],
    ["/admin/schemes", ["super_admin"], true],
  ])("%s for %j → %s", (path, roles, allowed) => {
    expect(canAccessPath(path, roles)).toBe(allowed);
  });

  it("only ops_admin/super_admin decide applications or assign any coordinator", () => {
    expect(canDecideApplications(["coordinator"])).toBe(false);
    expect(canDecideApplications(["ops_admin"])).toBe(true);
    expect(canAssignAnyCoordinator(["coordinator"])).toBe(false);
    expect(canAssignAnyCoordinator(["super_admin"])).toBe(true);
  });
});
