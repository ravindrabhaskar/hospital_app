import { describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen, within } from "@testing-library/react";
import type { CaseloadFlag, CaseloadItem, Priority } from "@/lib/api/types";
import { CaseloadTable } from "./caseload-table";

function item(name: string, flags: CaseloadFlag[], priority: Priority = "routine"): CaseloadItem {
  return {
    patient: { id: name.toLowerCase(), name, dob: null, age: 70, gender: "male", relation: "self", isSelf: true, permissions: [], avatarUrl: null },
    episodes: [
      {
        id: `${name}-ep`,
        patientId: name.toLowerCase(),
        patientName: name,
        title: `${name} knee care`,
        concern: "",
        status: "UNDER_CARE",
        priority,
        ownerUserId: null,
        ownerName: null,
        nextAction: null,
        createdAt: "2026-09-01T00:00:00.000Z",
        updatedAt: "2026-09-01T00:00:00.000Z",
      },
    ],
    openTasks: 2,
    overdueTasks: 1,
    nextFollowUpAt: null,
    lastContactAt: null,
    flags,
  };
}

const items = [item("Asha", ["no_contact_7d"]), item("Bala", ["open_safety_event", "missed_doses"]), item("Chitra", [])];

const rowNames = () =>
  screen.getAllByTestId("caseload-row").map((r) => within(r).getAllByRole("button")[0]!.textContent);

describe("CaseloadTable", () => {
  it("renders flag badges with labels, descriptions and severity order", () => {
    render(<CaseloadTable items={items} onSelect={() => {}} />);
    const bala = screen.getAllByTestId("caseload-row")[0]!;
    const badges = within(bala).getAllByTitle(/./).map((b) => b.firstChild?.textContent);
    expect(badges).toEqual(["Open safety event", "Missed doses"]);
    expect(within(bala).getByText("Open safety event")).toHaveAttribute("title", "An urgent or emergency safety event is still open");
    expect(screen.getByText("No contact 7d")).toBeInTheDocument();
    expect(screen.getByText("None")).toBeInTheDocument();
  });

  it("sorts by risk (desc) by default and reorders when a header is clicked", () => {
    render(<CaseloadTable items={items} onSelect={() => {}} />);
    const riskTh = screen.getByRole("columnheader", { name: /risk/i });
    const patientTh = screen.getByRole("columnheader", { name: /patient/i });
    expect(riskTh).toHaveAttribute("aria-sort", "descending");
    expect(patientTh).toHaveAttribute("aria-sort", "none");
    expect(rowNames()).toEqual(["Bala", "Asha", "Chitra"]);

    fireEvent.click(within(riskTh).getByRole("button"));
    expect(riskTh).toHaveAttribute("aria-sort", "ascending");
    expect(rowNames()).toEqual(["Chitra", "Asha", "Bala"]);

    fireEvent.click(within(patientTh).getByRole("button"));
    expect(patientTh).toHaveAttribute("aria-sort", "ascending");
    expect(riskTh).toHaveAttribute("aria-sort", "none");
    expect(rowNames()).toEqual(["Asha", "Bala", "Chitra"]);

    fireEvent.click(within(patientTh).getByRole("button"));
    expect(patientTh).toHaveAttribute("aria-sort", "descending");
    expect(rowNames()).toEqual(["Chitra", "Bala", "Asha"]);
  });

  it("calls onSelect when a row or patient button is activated", () => {
    const onSelect = vi.fn();
    render(<CaseloadTable items={items} onSelect={onSelect} />);
    fireEvent.click(screen.getByRole("button", { name: "Asha" }));
    expect(onSelect).toHaveBeenCalledTimes(1);
    expect(onSelect.mock.calls[0]![0].patient.name).toBe("Asha");
    fireEvent.click(screen.getByText("Chitra knee care"));
    expect(onSelect).toHaveBeenCalledTimes(2);
  });

  it("shows the empty content when there are no rows", () => {
    render(<CaseloadTable items={[]} onSelect={() => {}} empty={<p>Nothing to show</p>} />);
    expect(screen.getByText("Nothing to show")).toBeInTheDocument();
  });
});
