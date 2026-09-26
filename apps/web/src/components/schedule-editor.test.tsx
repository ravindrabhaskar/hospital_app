import { describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import type { AddLeaveResponse, Appointment, Schedule } from "@/lib/api/types";
import { addDays, todayIST } from "@/lib/format";
import { LeavesPanel, ScheduleEditor } from "./schedule-editor";
import { ToastProvider } from "./toast";

const schedule: Schedule = {
  // Deliberately unsorted: Sunday first, then Monday.
  weekly: [
    { weekday: 0, start: "10:00", end: "11:00", slotMins: 15, modes: ["video"] },
    { weekday: 1, start: "09:00", end: "12:00", slotMins: 30, modes: ["video", "audio"] },
  ],
  leaves: [],
  horizonDays: 14,
  timezone: "Asia/Kolkata",
};

function saveButton() {
  return screen.getByRole("button", { name: /save schedule/i });
}

describe("ScheduleEditor", () => {
  it("shows slot counts and the regeneration note", () => {
    render(<ScheduleEditor schedule={schedule} onSave={vi.fn()} />);
    expect(screen.getByText(/regenerates unbooked future slots for the next 14 days/i)).toBeInTheDocument();
    const monday = screen.getByRole("group", { name: "Monday block 1" });
    expect(within(monday).getByText("6 slots")).toBeInTheDocument();
    // Nothing changed yet → Save disabled.
    expect(saveButton()).toBeDisabled();
  });

  it("flags an overlap and disables Save until it is fixed; Save sends sorted blocks", async () => {
    const onSave = vi.fn().mockResolvedValue(undefined);
    render(<ScheduleEditor schedule={schedule} onSave={onSave} />);

    fireEvent.click(screen.getByRole("button", { name: "Add block on Monday" }));
    const start = screen.getByLabelText("Monday block 2 start");
    fireEvent.change(start, { target: { value: "11:00" } });

    const block2 = screen.getByRole("group", { name: "Monday block 2" });
    expect(within(block2).getByText(/overlaps another block on the same day/i)).toBeInTheDocument();
    expect(within(screen.getByRole("group", { name: "Monday block 1" })).getByText(/overlaps/i)).toBeInTheDocument();
    expect(screen.getByRole("alert")).toHaveTextContent(/fix the highlighted blocks/i);
    expect(saveButton()).toBeDisabled();

    // Move it before the first block; touching (07:00–09:00 then 09:00–12:00) is allowed.
    fireEvent.change(start, { target: { value: "07:00" } });
    fireEvent.change(screen.getByLabelText("Monday block 2 end"), { target: { value: "09:00" } });
    expect(screen.queryByText(/overlaps another block/i)).not.toBeInTheDocument();
    expect(saveButton()).toBeEnabled();

    fireEvent.click(saveButton());
    await waitFor(() => expect(onSave).toHaveBeenCalledTimes(1));
    const sent = onSave.mock.calls[0]![0] as Schedule["weekly"];
    expect(sent.map((b) => `${b.weekday}@${b.start}-${b.end}`)).toEqual(["1@07:00-09:00", "1@09:00-12:00", "0@10:00-11:00"]);
  });

  it("does not render edit controls when read-only", () => {
    render(<ScheduleEditor schedule={schedule} onSave={vi.fn()} readOnly />);
    expect(screen.queryByRole("button", { name: /save schedule/i })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /add block/i })).not.toBeInTheDocument();
  });
});

describe("LeavesPanel", () => {
  it("lists conflicting appointments after adding a leave", async () => {
    const date = addDays(todayIST(), 3);
    const appt = {
      id: "a1",
      patientName: "Lakshmi Devi",
      startAt: `${date}T04:30:00.000Z`,
      endAt: `${date}T05:00:00.000Z`,
      mode: "video",
      status: "scheduled",
    } as unknown as Appointment;
    const onAdd = vi.fn().mockResolvedValue({ leave: { id: "l1", date, reason: null }, conflicts: [appt] } satisfies AddLeaveResponse);
    render(
      <ToastProvider>
        <LeavesPanel leaves={[]} onAdd={onAdd} onRemove={vi.fn()} />
      </ToastProvider>,
    );
    fireEvent.change(screen.getByLabelText(/^date/i), { target: { value: date } });
    fireEvent.click(screen.getByRole("button", { name: /add leave/i }));
    const dialog = await screen.findByRole("dialog", { name: /appointments on this day/i });
    expect(within(dialog).getByText("Lakshmi Devi")).toBeInTheDocument();
    expect(within(dialog).getByText(/not/)).toBeInTheDocument();
    expect(onAdd).toHaveBeenCalledWith({ date });
  });

  it("is read-only without callbacks", () => {
    render(
      <ToastProvider>
        <LeavesPanel leaves={[{ id: "l1", date: "2099-01-01", reason: "Conference" }]} readOnlyNote="Managed by the doctor." />
      </ToastProvider>,
    );
    expect(screen.getByText("Conference")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /add leave|remove/i })).not.toBeInTheDocument();
  });
});
