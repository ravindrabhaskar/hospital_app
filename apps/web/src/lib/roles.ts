import type { Role } from "@/lib/api/types";

export type SectionKey = "clinician" | "ops" | "admin";

export type NavIcon =
  | "calendar"
  | "users"
  | "siren"
  | "gauge"
  | "home"
  | "badge"
  | "activity"
  | "clock"
  | "alert"
  | "wallet"
  | "scroll"
  | "shield"
  | "sparkles"
  | "book"
  | "toggle"
  | "chart"
  | "map"
  | "user"
  | "schedule"
  | "rupee"
  | "fileCheck"
  | "receipt"
  | "star"
  | "clipboard"
  | "messages"
  | "package"
  | "landmark";

export interface NavItem {
  href: string;
  label: string;
  icon: NavIcon;
  roles: Role[];
  /** Live counter shown next to the label (e.g. unread inbox messages). */
  badge?: "inbox";
}

export interface NavSection {
  key: SectionKey;
  label: string;
  items: NavItem[];
}

export const OPS_ROLES: Role[] = ["coordinator", "ops_admin", "super_admin"];
export const STAFF_ROLES: Role[] = ["doctor", "coordinator", "ops_admin", "super_admin"];
/** §34: staff who participate in care-team threads. */
export const INBOX_ROLES: Role[] = ["doctor", "coordinator", "ops_admin", "super_admin"];
/** §32: settlements are ops_admin / super_admin only. */
export const FINANCE_ROLES: Role[] = ["ops_admin", "super_admin"];

/**
 * Navigation. `roles` lists who can see an item. Where the contract says "(ops_admin read)",
 * ops_admin is included and the page renders read-only for them.
 */
export const NAV: NavSection[] = [
  {
    key: "clinician",
    label: "Clinician",
    items: [
      { href: "/clinician", label: "Today's queue", icon: "calendar", roles: ["doctor"] },
      { href: "/clinician/patients", label: "Patients", icon: "users", roles: ["doctor"] },
      { href: "/clinician/escalations", label: "Escalations", icon: "siren", roles: ["doctor"] },
      { href: "/inbox", label: "Inbox", icon: "messages", roles: ["doctor"], badge: "inbox" },
      { href: "/clinician/schedule", label: "Schedule & leaves", icon: "schedule", roles: ["doctor"] },
      { href: "/clinician/earnings", label: "Earnings", icon: "rupee", roles: ["doctor"] },
      { href: "/clinician/profile", label: "My profile", icon: "user", roles: ["doctor"] },
    ],
  },
  {
    key: "ops",
    label: "Operations",
    items: [
      { href: "/ops", label: "Control tower", icon: "gauge", roles: OPS_ROLES },
      { href: "/ops/home-visits", label: "Home visits", icon: "home", roles: OPS_ROLES },
      { href: "/ops/providers", label: "Providers", icon: "badge", roles: OPS_ROLES },
      { href: "/ops/safety-events", label: "Safety events", icon: "siren", roles: OPS_ROLES },
      { href: "/ops/episodes", label: "Care episodes", icon: "activity", roles: OPS_ROLES },
      { href: "/ops/tasks", label: "Overdue tasks", icon: "clock", roles: OPS_ROLES },
      { href: "/ops/incidents", label: "Incidents", icon: "alert", roles: OPS_ROLES },
      { href: "/ops/payments", label: "Payments", icon: "wallet", roles: OPS_ROLES },
      { href: "/coordinator", label: "Coordinator workspace", icon: "clipboard", roles: OPS_ROLES },
      { href: "/inbox", label: "Inbox", icon: "messages", roles: INBOX_ROLES, badge: "inbox" },
      { href: "/ops/applications", label: "Applications", icon: "fileCheck", roles: OPS_ROLES },
      { href: "/ops/reviews", label: "Reviews", icon: "star", roles: OPS_ROLES },
      { href: "/ops/settlements", label: "Settlements", icon: "receipt", roles: FINANCE_ROLES },
      { href: "/admin/doctors", label: "Doctor schedules", icon: "schedule", roles: FINANCE_ROLES },
    ],
  },
  {
    key: "admin",
    label: "Admin",
    items: [
      { href: "/admin/users", label: "Users & staff", icon: "users", roles: ["super_admin"] },
      { href: "/admin/audit-logs", label: "Audit logs", icon: "scroll", roles: ["super_admin", "ops_admin"] },
      { href: "/admin/safety-rules", label: "Safety rules", icon: "shield", roles: ["super_admin"] },
      { href: "/admin/ai", label: "AI interactions", icon: "sparkles", roles: ["super_admin"] },
      { href: "/admin/knowledge", label: "Knowledge", icon: "book", roles: ["super_admin"] },
      { href: "/admin/flags", label: "Feature flags", icon: "toggle", roles: ["super_admin"] },
      { href: "/admin/analytics", label: "Analytics", icon: "chart", roles: ["super_admin", "ops_admin"] },
      { href: "/admin/zones", label: "Service zones", icon: "map", roles: ["super_admin"] },
      { href: "/admin/plans", label: "Subscription plans", icon: "package", roles: ["super_admin"] },
      { href: "/admin/schemes", label: "Govt schemes", icon: "landmark", roles: ["super_admin"] },
    ],
  },
];

export function hasAnyRole(userRoles: readonly Role[] | undefined, allowed: readonly Role[]): boolean {
  if (!userRoles) return false;
  return userRoles.some((r) => allowed.includes(r));
}

/**
 * Sections + items the user can see. Sections without visible items are dropped.
 * An href shared by several sections (e.g. the Inbox) is shown once, in the first section that shows it.
 */
export function visibleNav(userRoles: readonly Role[]): NavSection[] {
  const seen = new Set<string>();
  return NAV.map((s) => ({
    ...s,
    items: s.items.filter((i) => {
      if (!hasAnyRole(userRoles, i.roles) || seen.has(i.href)) return false;
      seen.add(i.href);
      return true;
    }),
  })).filter((s) => s.items.length > 0);
}

/** Roles allowed on a path prefix (longest prefix wins). */
const ROUTE_RULES: { prefix: string; roles: Role[] }[] = [
  { prefix: "/clinician", roles: ["doctor"] },
  { prefix: "/ops", roles: OPS_ROLES },
  { prefix: "/ops/settlements", roles: FINANCE_ROLES },
  { prefix: "/coordinator", roles: OPS_ROLES },
  { prefix: "/inbox", roles: INBOX_ROLES },
  { prefix: "/admin/doctors", roles: FINANCE_ROLES },
  { prefix: "/admin/audit-logs", roles: ["super_admin", "ops_admin"] },
  { prefix: "/admin/analytics", roles: ["super_admin", "ops_admin"] },
  { prefix: "/admin", roles: ["super_admin"] },
];

export function canAccessPath(path: string, userRoles: readonly Role[]): boolean {
  const rule = ROUTE_RULES.filter((r) => path === r.prefix || path.startsWith(`${r.prefix}/`)).sort(
    (a, b) => b.prefix.length - a.prefix.length,
  )[0];
  if (!rule) return hasAnyRole(userRoles, STAFF_ROLES);
  return hasAnyRole(userRoles, rule.roles);
}

/** Where to land after login. `null` = no portal role (patient / provider only). */
export function homePathFor(userRoles: readonly Role[]): string | null {
  if (userRoles.includes("doctor")) return "/clinician";
  if (hasAnyRole(userRoles, OPS_ROLES)) return "/ops";
  return null;
}

export function isPortalUser(userRoles: readonly Role[]): boolean {
  return hasAnyRole(userRoles, STAFF_ROLES);
}

/** POST /payments/:id/refund is "(ops_admin)"; super_admin is treated as a superset. */
export function canRefund(userRoles: readonly Role[]) {
  return hasAnyRole(userRoles, ["ops_admin", "super_admin"]);
}
/** POST /ops/providers/:id/verification is "(ops_admin)"; super_admin is treated as a superset. */
export function canVerifyProviders(userRoles: readonly Role[]) {
  return hasAnyRole(userRoles, ["ops_admin", "super_admin"]);
}
/** POST /ops/provider-applications/:id/decision is "(ops_admin, super_admin)"; coordinators read only. */
export function canDecideApplications(userRoles: readonly Role[]) {
  return hasAnyRole(userRoles, ["ops_admin", "super_admin"]);
}
/** POST /ops/care-episodes/:id/assign-coordinator: ops_admin/super_admin assign anyone; a coordinator may assign themselves. */
export function canAssignAnyCoordinator(userRoles: readonly Role[]) {
  return hasAnyRole(userRoles, ["ops_admin", "super_admin"]);
}
export function isSuperAdmin(userRoles: readonly Role[]) {
  return userRoles.includes("super_admin");
}

export const ROLE_LABELS: Record<Role, string> = {
  patient: "Patient",
  doctor: "Doctor",
  provider: "Provider",
  coordinator: "Coordinator",
  ops_admin: "Ops admin",
  super_admin: "Super admin",
};
