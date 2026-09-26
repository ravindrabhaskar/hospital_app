import { describe, expect, it, vi, beforeEach } from "vitest";
import { render, screen, within } from "@testing-library/react";
import type { Role } from "@/lib/api/types";

const replace = vi.fn();
let pathname = "/ops";
vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace, push: vi.fn() }),
  usePathname: () => pathname,
}));

let roles: Role[] = [];
let hasSession = true;
vi.mock("@/lib/auth", () => ({
  useAuth: () => {
    const user = {
      id: "u1",
      phone: "+919800000301",
      name: "Meera",
      email: null,
      roles,
      language: "en",
      selfPatientId: null,
      onboardingComplete: true,
      mfaRequired: true,
      providerId: null,
    };
    return {
      session: hasSession ? { accessToken: "a", refreshToken: "r", expiresAt: Date.now() + 1000, user } : null,
      user: hasSession ? user : null,
      roles: hasSession ? roles : [],
      signIn: vi.fn(),
      signOut: vi.fn(),
    };
  },
}));

import { PortalShell } from "./app-shell";

function renderShell(r: Role[], path = "/ops") {
  roles = r;
  pathname = path;
  return render(
    <PortalShell>
      <p>page content</p>
    </PortalShell>,
  );
}

describe("PortalShell navigation", () => {
  beforeEach(() => {
    replace.mockReset();
    hasSession = true;
  });

  it("shows only operations links to a coordinator", () => {
    renderShell(["coordinator"]);
    const nav = screen.getAllByRole("navigation", { name: "Main" })[0]!;
    expect(within(nav).getByRole("link", { name: "Control tower" })).toHaveAttribute("aria-current", "page");
    expect(within(nav).getByRole("link", { name: "Home visits" })).toBeInTheDocument();
    expect(within(nav).queryByRole("link", { name: "Today's queue" })).not.toBeInTheDocument();
    expect(within(nav).queryByRole("link", { name: "Users & staff" })).not.toBeInTheDocument();
    expect(screen.getByText("page content")).toBeInTheDocument();
  });

  it("shows clinician, operations and admin sections to a doctor who is also super admin", () => {
    renderShell(["doctor", "super_admin"], "/clinician");
    const nav = screen.getAllByRole("navigation", { name: "Main" })[0]!;
    expect(within(nav).getByText("Clinician")).toBeInTheDocument();
    expect(within(nav).getByText("Operations")).toBeInTheDocument();
    expect(within(nav).getByText("Admin")).toBeInTheDocument();
    expect(within(nav).getByRole("link", { name: "Feature flags" })).toBeInTheDocument();
    const roleList = screen.getByRole("list", { name: "Your roles" });
    expect(within(roleList).getByText("Doctor")).toBeInTheDocument();
    expect(within(roleList).getByText("Super admin")).toBeInTheDocument();
  });

  it("gives ops_admin read-only admin links but not user management", () => {
    renderShell(["ops_admin"]);
    const nav = screen.getAllByRole("navigation", { name: "Main" })[0]!;
    expect(within(nav).getByRole("link", { name: "Audit logs" })).toBeInTheDocument();
    expect(within(nav).getByRole("link", { name: "Analytics" })).toBeInTheDocument();
    expect(within(nav).queryByRole("link", { name: "Safety rules" })).not.toBeInTheDocument();
  });

  it("renders an unauthorized state instead of the page when the role cannot access the route", () => {
    renderShell(["coordinator"], "/admin/users");
    expect(screen.queryByText("page content")).not.toBeInTheDocument();
    expect(screen.getByText(/don.t have access/i)).toBeInTheDocument();
  });

  it("redirects to login when there is no session", () => {
    hasSession = false;
    renderShell([], "/ops/incidents");
    expect(replace).toHaveBeenCalledWith("/login?next=%2Fops%2Fincidents");
    expect(screen.queryByText("page content")).not.toBeInTheDocument();
  });
});
