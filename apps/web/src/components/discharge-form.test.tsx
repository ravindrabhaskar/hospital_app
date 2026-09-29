import { beforeEach, describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ToastProvider } from "./toast";
import { DischargeForm } from "./discharge-form";

const mocks = vi.hoisted(() => ({ create: vi.fn(), templates: vi.fn() }));
vi.mock("@/lib/api", () => ({ api: { discharges: { create: mocks.create }, programs: { templates: mocks.templates } } }));

function renderForm(onCreated = vi.fn()) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
  render(
    <QueryClientProvider client={qc}>
      <ToastProvider>
        <DischargeForm onCreated={onCreated} />
      </ToastProvider>
    </QueryClientProvider>,
  );
  return onCreated;
}

describe("DischargeForm", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.templates.mockResolvedValue({ items: [{ code: "heart_failure", name: "Heart failure", status: "fixture_unapproved" }] });
  });

  it("blocks moving on until the step is valid, then posts multipart with the PDF", async () => {
    mocks.create.mockResolvedValue({ id: "dc-1", patientName: "Lakshmi Devi" });
    const onCreated = renderForm();

    fireEvent.click(screen.getByRole("button", { name: /next/i }));
    expect(await screen.findByText("Patient name is required")).toBeInTheDocument();
    expect(screen.getByText(/Step 1 of 4/)).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText(/patient name/i), { target: { value: "Lakshmi Devi" } });
    fireEvent.change(screen.getByLabelText(/patient phone/i), { target: { value: "9876543210" } });
    fireEvent.change(screen.getByLabelText(/date of birth/i), { target: { value: "1958-04-12" } });
    fireEvent.change(screen.getByLabelText(/gender/i), { target: { value: "female" } });
    fireEvent.click(screen.getByRole("button", { name: /next/i }));
    expect(await screen.findByText(/Step 2 of 4/)).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText(/treating doctor/i), { target: { value: "Dr. Suresh" } });
    fireEvent.change(screen.getByLabelText(/diagnosis summary/i), { target: { value: "Pneumonia, treated and stable." } });
    fireEvent.click(screen.getByRole("button", { name: /next/i }));
    expect(await screen.findByText(/Step 3 of 4/)).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText(/care program/i), { target: { value: "heart_failure" } });
    fireEvent.click(screen.getByRole("button", { name: /next/i }));
    expect(await screen.findByText(/Step 4 of 4/)).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: /register discharge/i }));
    expect(await screen.findByText(/attach the discharge summary pdf/i)).toBeInTheDocument();
    expect(mocks.create).not.toHaveBeenCalled();

    const pdf = new File(["%PDF-1.4"], "summary.pdf", { type: "application/pdf" });
    fireEvent.change(screen.getByLabelText(/discharge summary \(pdf/i), { target: { files: [pdf] } });
    fireEvent.click(screen.getByRole("button", { name: /register discharge/i }));

    await waitFor(() => expect(mocks.create).toHaveBeenCalledTimes(1));
    const fd = mocks.create.mock.calls[0]![0] as FormData;
    expect(fd).toBeInstanceOf(FormData);
    expect(JSON.parse(fd.get("patient") as string)).toMatchObject({ name: "Lakshmi Devi", phone: "+919876543210", gender: "female" });
    expect(fd.get("programTemplateCode")).toBe("heart_failure");
    expect(JSON.parse(fd.get("followUp") as string).followUpDays).toEqual([7, 14, 30]);
    expect((fd.get("file") as File).name).toBe("summary.pdf");
    await waitFor(() => expect(onCreated).toHaveBeenCalledWith({ id: "dc-1", patientName: "Lakshmi Devi" }));
  });
});
