import { beforeEach, describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { ScribeDraft } from "@/lib/api/types";
import { insertIntoNotes, scribeBlockReason, soapToNotes } from "@/lib/scribe";
import { ToastProvider } from "./toast";
import { ScribePanel } from "./scribe-panel";

const mocks = vi.hoisted(() => ({ fromTranscript: vi.fn(), fromAudio: vi.fn() }));
vi.mock("@/lib/api", () => ({ api: { scribe: { fromTranscript: mocks.fromTranscript, fromAudio: mocks.fromAudio } } }));

const draft: ScribeDraft = {
  id: "s1",
  appointmentId: "appt-1",
  transcript: "Patient reports fever for two days.",
  draft: { subjective: "Fever for 2 days", objective: "", assessment: "Likely viral illness", plan: "Fluids, paracetamol, review in 3 days" },
  model: "mock-scribe",
  advisory: true,
  generatedAt: "2026-09-29T05:00:00.000Z",
  audioRetained: false,
};

function renderPanel(onInsert = vi.fn()) {
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  render(
    <QueryClientProvider client={qc}>
      <ToastProvider>
        <ScribePanel appointmentId="appt-1" onInsert={onInsert} />
      </ToastProvider>
    </QueryClientProvider>,
  );
  return onInsert;
}

describe("scribe consent gating", () => {
  beforeEach(() => vi.clearAllMocks());

  it("pure rule: consent first, then a usable transcript or recording", () => {
    expect(scribeBlockReason(false, { mode: "transcript", transcript: "x".repeat(100) })).toMatch(/patient agreed/i);
    expect(scribeBlockReason(true, { mode: "transcript", transcript: "too short" })).toMatch(/at least 20/);
    expect(scribeBlockReason(true, { mode: "transcript", transcript: "Patient reports fever for two days now." })).toBeNull();
    expect(scribeBlockReason(true, { mode: "audio", audio: null })).toMatch(/record/i);
    expect(scribeBlockReason(true, { mode: "audio", audio: new Blob(["abc"], { type: "audio/webm" }) })).toBeNull();
  });

  it("keeps recording, transcript and generate disabled until consent is ticked", () => {
    renderPanel();
    expect(screen.getByRole("button", { name: /generate soap draft/i })).toBeDisabled();
    fireEvent.click(screen.getByRole("radio", { name: /paste transcript/i }));
    expect(screen.getByLabelText(/consultation transcript/i)).toBeDisabled();
    fireEvent.click(screen.getByRole("checkbox", { name: /patient agreed/i }));
    expect(screen.getByLabelText(/consultation transcript/i)).toBeEnabled();
    expect(screen.getByRole("button", { name: /generate soap draft/i })).toBeEnabled();
  });

  it("does not call the API with a too-short transcript, then sends it with consent", async () => {
    mocks.fromTranscript.mockResolvedValue(draft);
    const onInsert = renderPanel();
    fireEvent.click(screen.getByRole("checkbox", { name: /patient agreed/i }));
    fireEvent.click(screen.getByRole("radio", { name: /paste transcript/i }));
    fireEvent.change(screen.getByLabelText(/consultation transcript/i), { target: { value: "short" } });
    fireEvent.click(screen.getByRole("button", { name: /generate soap draft/i }));
    expect(await screen.findByRole("alert")).toHaveTextContent(/at least 20/);
    expect(mocks.fromTranscript).not.toHaveBeenCalled();

    fireEvent.change(screen.getByLabelText(/consultation transcript/i), { target: { value: "  Patient reports fever for two days.  " } });
    fireEvent.click(screen.getByRole("button", { name: /generate soap draft/i }));
    await waitFor(() => expect(mocks.fromTranscript).toHaveBeenCalledWith("appt-1", "Patient reports fever for two days."));

    // Draft rendering: lavender advisory panel with the four SOAP sections.
    const panel = await screen.findByRole("region", { name: /ai soap draft/i });
    expect(within(panel).getByText("AI-generated · advisory")).toBeInTheDocument();
    expect(within(panel).getByText("Likely viral illness")).toBeInTheDocument();
    expect(within(panel).getByText("Nothing in the transcript")).toBeInTheDocument();
    expect(onInsert).not.toHaveBeenCalled();
    fireEvent.click(within(panel).getByRole("button", { name: /insert into notes/i }));
    expect(onInsert).toHaveBeenCalledWith(draft);
  });
});

describe("SOAP → notes", () => {
  it("formats labelled sections, skips empty ones and appends to existing notes", () => {
    expect(soapToNotes(draft.draft)).toBe("Subjective:\nFever for 2 days\n\nAssessment:\nLikely viral illness\n\nPlan:\nFluids, paracetamol, review in 3 days");
    expect(insertIntoNotes("BP 130/80", draft.draft).startsWith("BP 130/80\n\nSubjective:")).toBe(true);
    expect(insertIntoNotes("", { subjective: "", objective: "", assessment: "", plan: "" })).toBe("");
  });
});
