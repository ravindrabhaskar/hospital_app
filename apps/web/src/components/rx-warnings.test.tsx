import { beforeEach, describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ApiError } from "@/lib/api/http";
import type { Appointment, RxWarning } from "@/lib/api/types";
import { overrideBlockReason, overrideFields, rxCheckItems, sortWarnings, warningsFromError } from "@/lib/rx-warnings";
import { ToastProvider } from "./toast";
import { PrescriptionWriter } from "./prescription-writer";

const mocks = vi.hoisted(() => ({ create: vi.fn(), list: vi.fn(), pdf: vi.fn(), check: vi.fn(), profile: vi.fn() }));
vi.mock("@/lib/api", () => ({
  api: {
    prescriptions: { create: mocks.create, list: mocks.list, pdf: mocks.pdf, check: mocks.check },
    doctorSelf: { profile: mocks.profile },
  },
}));

const major: RxWarning = { severity: "major", type: "interaction", drugs: ["Warfarin", "Aspirin"], message: "Bleeding risk", source: "interactions-fixture-0.1" };
const info: RxWarning = { severity: "info", type: "dose_form", drugs: ["Aspirin"], message: "Take with food", source: "fixture" };

const appt: Appointment = {
  id: "appt-1",
  patientId: "pt-1",
  patientName: "Ramesh",
  doctorId: "d",
  doctorName: "Dr. A",
  doctorSpecialty: "gp",
  doctorPhotoUrl: null,
  startAt: "2026-09-29T04:30:00.000Z",
  endAt: "2026-09-29T04:45:00.000Z",
  mode: "video",
  status: "in_progress",
  reason: "BP",
  fee: 500,
  careEpisodeId: "ep-1",
  videoRoomUrl: null,
  clinicianNotes: null,
  createdAt: "2026-09-28T04:30:00.000Z",
};

const rx = { id: "rx-1", patientName: "Ramesh", createdAt: "2026-09-29T05:00:00.000Z", items: [] };

function renderWriter() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}>
      <ToastProvider>
        <PrescriptionWriter appt={appt} />
      </ToastProvider>
    </QueryClientProvider>,
  );
}

describe("rx-warnings helpers", () => {
  it("sorts by severity and gates major warnings on acknowledgement + reason", () => {
    expect(sortWarnings([info, major]).map((w) => w.severity)).toEqual(["major", "info"]);
    expect(overrideBlockReason([info], false, "")).toBeNull();
    expect(overrideBlockReason([major], false, "a long enough reason")).toMatch(/acknowledge/i);
    expect(overrideBlockReason([major], true, "short")).toMatch(/at least 10/);
    expect(overrideBlockReason([major], true, "Benefit outweighs risk, INR monitored")).toBeNull();
    expect(overrideFields([info], true, "x")).toEqual({});
    expect(overrideFields([major], true, "  Monitored closely  ")).toEqual({ acknowledgedWarnings: true, overrideReason: "Monitored closely" });
  });

  it("reads warnings from a 400 and builds de-duplicated check items", () => {
    const err = new ApiError({ status: 400, code: "VALIDATION_ERROR", message: "x", details: { warnings: [major] } });
    expect(warningsFromError(err)).toEqual([major]);
    expect(warningsFromError(new ApiError({ status: 409, code: "CONFLICT", message: "x", details: { warnings: [major] } }))).toBeNull();
    expect(rxCheckItems([{ drugName: " Aspirin ", strength: "75 mg" }, { drugName: "aspirin", strength: "75 MG" }, { drugName: "x" }])).toEqual([{ drugName: "Aspirin", strength: "75 mg" }]);
  });
});

describe("PrescriptionWriter interaction gating", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.list.mockResolvedValue({ items: [] });
    mocks.profile.mockResolvedValue({ name: "Dr. A" });
  });

  it("shows live warnings by severity and requires acknowledgement + reason for a major one", async () => {
    mocks.check.mockResolvedValue({ warnings: [info, major], knowledgePack: { version: "interactions-fixture-0.1", status: "fixture_unapproved" } });
    mocks.create.mockResolvedValue(rx);
    renderWriter();
    fireEvent.change(screen.getByLabelText(/drug name/i), { target: { value: "Aspirin" } });

    expect(await screen.findByText("Bleeding risk", {}, { timeout: 3000 })).toBeInTheDocument();
    expect(mocks.check).toHaveBeenCalledWith({ patientId: "pt-1", items: [{ drugName: "Aspirin" }] }, expect.anything());
    expect(screen.getByText("1 major")).toBeInTheDocument();
    expect(screen.getByText("1 info")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: /create prescription/i }));
    expect(await screen.findByText(/acknowledge the major warnings before/i)).toBeInTheDocument();
    expect(mocks.create).not.toHaveBeenCalled();

    fireEvent.click(screen.getByRole("checkbox", { name: /reviewed the major warnings/i }));
    fireEvent.change(screen.getByLabelText(/override reason/i), { target: { value: "short" } });
    fireEvent.click(screen.getByRole("button", { name: /create prescription/i }));
    expect(await screen.findByText(/at least 10 characters/i)).toBeInTheDocument();
    expect(mocks.create).not.toHaveBeenCalled();

    fireEvent.change(screen.getByLabelText(/override reason/i), { target: { value: "Low-dose aspirin needed; INR monitored" } });
    fireEvent.click(screen.getByRole("button", { name: /create prescription/i }));
    await waitFor(() => expect(mocks.create).toHaveBeenCalledTimes(1));
    expect(mocks.create.mock.calls[0]![0]).toMatchObject({ acknowledgedWarnings: true, overrideReason: "Low-dose aspirin needed; INR monitored" });
  });

  it("handles a 400 with details.warnings: shows them and resubmits with the override", async () => {
    mocks.check.mockResolvedValue({ warnings: [], knowledgePack: { version: "v", status: "approved" } });
    mocks.create
      .mockRejectedValueOnce(new ApiError({ status: 400, code: "VALIDATION_ERROR", message: "Major warnings", details: { warnings: [major] } }))
      .mockResolvedValueOnce(rx);
    renderWriter();
    fireEvent.change(screen.getByLabelText(/drug name/i), { target: { value: "Warfarin" } });
    fireEvent.click(screen.getByRole("button", { name: /create prescription/i }));

    expect(await screen.findByText("Bleeding risk")).toBeInTheDocument();
    expect(screen.getByText(/server found major warnings/i)).toBeInTheDocument();
    expect(mocks.create.mock.calls[0]![0]).not.toHaveProperty("acknowledgedWarnings");

    fireEvent.click(screen.getByRole("checkbox", { name: /reviewed the major warnings/i }));
    fireEvent.change(screen.getByLabelText(/override reason/i), { target: { value: "Specialist advised, monitored" } });
    fireEvent.click(screen.getByRole("button", { name: /create prescription/i }));
    await waitFor(() => expect(mocks.create).toHaveBeenCalledTimes(2));
    expect(mocks.create.mock.calls[1]![0]).toMatchObject({ acknowledgedWarnings: true, overrideReason: "Specialist advised, monitored" });
  });
});
