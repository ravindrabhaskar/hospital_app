import { beforeEach, describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { HomeVisitService, ProviderApplication, ServiceZone } from "@/lib/api/types";
import { addDays, todayIST } from "@/lib/format";
import { ToastProvider } from "./toast";
import { ApplicationDecisionForm } from "./application-decision-form";

const decide = vi.fn();
vi.mock("@/lib/api", () => ({ api: { applications: { decide: (...args: unknown[]) => decide(...args) } } }));

const baseApp: ProviderApplication = {
  id: "app1",
  userId: "u1",
  phone: "+919800000002",
  fullName: "Anita Rao",
  type: "nurse",
  qualification: "GNM",
  registrationNumber: "KNC-1234",
  registrationCouncil: "Karnataka Nursing Council",
  specialty: null,
  experienceYears: 4,
  languages: ["en", "kn"],
  preferredZoneIds: ["z1"],
  status: "submitted",
  documents: [
    { id: "d1", docType: "registration_certificate", fileName: "reg.pdf", mimeType: "application/pdf", sizeBytes: 1000, uploadedAt: "2026-09-20T05:00:00.000Z" },
    { id: "d2", docType: "id_proof", fileName: "id.jpg", mimeType: "image/jpeg", sizeBytes: 1000, uploadedAt: "2026-09-20T05:00:00.000Z" },
  ],
  decisionNote: null,
  decidedByName: null,
  createdAt: "2026-09-20T05:00:00.000Z",
  updatedAt: "2026-09-20T05:00:00.000Z",
  decidedAt: null,
};

const zones: ServiceZone[] = [
  { id: "z1", name: "Indiranagar", city: "Bengaluru", pincodes: ["560038"] },
  { id: "z2", name: "Koramangala", city: "Bengaluru", pincodes: ["560034"] },
];
const services: HomeVisitService[] = [
  { code: "wound_care", name: "Wound care", description: "", price: 800, durationMins: 45, icon: "bandage" },
  { code: "iv_therapy", name: "IV therapy", description: "", price: 1200, durationMins: 60, icon: "drip" },
];

function renderForm(app: ProviderApplication = baseApp) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}>
      <ToastProvider>
        <ApplicationDecisionForm app={app} zones={zones} services={services} />
      </ToastProvider>
    </QueryClientProvider>,
  );
}

describe("ApplicationDecisionForm", () => {
  beforeEach(() => {
    decide.mockReset();
    decide.mockResolvedValue({ ...baseApp, status: "approved" });
  });

  it("does not submit an approval without a credential expiry date", async () => {
    renderForm();
    fireEvent.click(screen.getByRole("radio", { name: /approve/i }));
    fireEvent.change(screen.getByLabelText(/approval note/i), { target: { value: "All verified" } });
    fireEvent.click(screen.getByRole("button", { name: /approve application/i }));
    expect((await screen.findAllByText(/credential expiry date is required/i)).length).toBeGreaterThan(0);
    expect(decide).not.toHaveBeenCalled();
  });

  it("submits an approval with a future expiry, zones and capabilities", async () => {
    renderForm();
    const expiry = addDays(todayIST(), 365);
    fireEvent.click(screen.getByRole("radio", { name: /approve/i }));
    fireEvent.change(screen.getByLabelText(/credential expiry date/i), { target: { value: expiry } });
    fireEvent.click(screen.getByRole("checkbox", { name: /koramangala/i }));
    fireEvent.click(screen.getByRole("checkbox", { name: /wound care/i }));
    fireEvent.change(screen.getByLabelText(/approval note/i), { target: { value: " All verified " } });
    fireEvent.click(screen.getByRole("button", { name: /approve application/i }));
    await waitFor(() => expect(decide).toHaveBeenCalledTimes(1));
    expect(decide).toHaveBeenCalledWith("app1", {
      decision: "approve",
      note: "All verified",
      credentialExpiresAt: expiry,
      zoneIds: ["z1", "z2"],
      capabilities: ["wound_care"],
    });
  });

  it("hides capabilities for doctors and switches to a reject button", () => {
    renderForm({ ...baseApp, type: "doctor" });
    expect(screen.queryByRole("checkbox", { name: /wound care/i })).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("radio", { name: /reject/i }));
    expect(screen.getByRole("button", { name: /reject application/i })).toBeInTheDocument();
    expect(screen.queryByLabelText(/credential expiry date/i)).not.toBeInTheDocument();
  });
});
