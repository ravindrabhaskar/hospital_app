import { beforeEach, describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { Appointment, Prescription } from "@/lib/api/types";
import { ToastProvider } from "./toast";
import { PrescriptionWriter } from "./prescription-writer";

const mocks = vi.hoisted(() => ({
  create: vi.fn(),
  list: vi.fn(),
  pdf: vi.fn(),
  profile: vi.fn(),
  check: vi.fn(),
}));

vi.mock("@/lib/api", () => ({
  api: {
    prescriptions: { create: mocks.create, list: mocks.list, pdf: mocks.pdf, check: mocks.check },
    doctorSelf: { profile: mocks.profile },
  },
}));

const appt: Appointment = {
  id: "appt-1",
  patientId: "pt-1",
  patientName: "Lakshmi Devi",
  doctorId: "doc-1",
  doctorName: "Dr. Anil Rao",
  doctorSpecialty: "general_physician",
  doctorPhotoUrl: null,
  startAt: "2026-09-26T04:30:00.000Z",
  endAt: "2026-09-26T04:45:00.000Z",
  mode: "video",
  status: "in_progress",
  reason: "Fever",
  fee: 500,
  careEpisodeId: "ep-1",
  videoRoomUrl: null,
  clinicianNotes: null,
  createdAt: "2026-09-25T04:30:00.000Z",
};

function renderWriter(a: Appointment = appt) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}>
      <ToastProvider>
        <PrescriptionWriter appt={a} />
      </ToastProvider>
    </QueryClientProvider>,
  );
}

describe("PrescriptionWriter", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.list.mockResolvedValue({ items: [] });
    mocks.check.mockResolvedValue({ warnings: [], knowledgePack: { version: "interactions-fixture-0.1", status: "fixture_unapproved" } });
    mocks.profile.mockResolvedValue({ name: "Dr. Anil Rao", qualifications: "MBBS, MD", registrationNumber: "TSMC-12345" });
  });

  it("shows a validation error for an empty drug name and does not submit", async () => {
    renderWriter();
    fireEvent.click(screen.getByRole("button", { name: /create prescription/i }));
    expect(await screen.findByText("Drug name is required")).toBeInTheDocument();
    expect(screen.getByLabelText(/drug name/i)).toHaveAttribute("aria-invalid", "true");
    expect(mocks.create).not.toHaveBeenCalled();
  });

  it("submits a valid row with the exact §31 payload", async () => {
    const created: Prescription = {
      id: "rx-1",
      patientId: "pt-1",
      patientName: "Lakshmi Devi",
      patientAge: 64,
      patientGender: "female",
      doctorId: "doc-1",
      doctorName: "Dr. Anil Rao",
      doctorQualifications: "MBBS, MD",
      doctorRegistration: "TSMC-12345",
      appointmentId: "appt-1",
      careEpisodeId: "ep-1",
      clinicalNote: null,
      items: [],
      advice: "Plenty of fluids",
      followUpInDays: 5,
      recordId: "rec-1",
      createdAt: "2026-09-26T05:00:00.000Z",
    };
    mocks.create.mockResolvedValue(created);
    renderWriter();

    fireEvent.change(screen.getByLabelText(/drug name/i), { target: { value: " Paracetamol " } });
    fireEvent.change(screen.getByLabelText(/strength/i), { target: { value: "650 mg" } });
    fireEvent.change(screen.getByLabelText(/duration \(days\)/i), { target: { value: "3" } });
    fireEvent.change(screen.getByLabelText(/^advice/i), { target: { value: "Plenty of fluids" } });
    fireEvent.change(screen.getByLabelText(/follow-up after/i), { target: { value: "5" } });

    // Live preview reflects the row.
    expect(await screen.findByText(/1 tablet · Twice daily · After food · 3 days/)).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: /create prescription/i }));

    await waitFor(() => expect(mocks.create).toHaveBeenCalledTimes(1));
    expect(mocks.create).toHaveBeenCalledWith({
      appointmentId: "appt-1",
      advice: "Plenty of fluids",
      followUpInDays: 5,
      items: [
        {
          drugName: "Paracetamol",
          strength: "650 mg",
          form: "tablet",
          dose: "1 tablet",
          frequency: "Twice daily",
          timing: "After food",
          durationDays: 3,
          times: ["08:00", "20:00"],
        },
      ],
    });
    expect(await screen.findByText("Prescription saved")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /download pdf/i })).toBeInTheDocument();
  });

  it("explains why writing is disabled before the consultation starts", async () => {
    renderWriter({ ...appt, status: "confirmed" });
    expect(screen.getByText(/can be written once the consultation is in progress or completed/i)).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /create prescription/i })).not.toBeInTheDocument();
    expect(await screen.findByText("No prescriptions yet")).toBeInTheDocument();
  });
});
