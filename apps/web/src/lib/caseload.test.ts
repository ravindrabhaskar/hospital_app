import { describe, expect, it } from "vitest";
import type { CareEpisode, CaseloadFlag, CaseloadItem, Priority } from "@/lib/api/types";
import { orderedFlags, riskScore, sortCaseload } from "./caseload";

function episode(priority: Priority, id = `e-${priority}`): CareEpisode {
  return {
    id,
    patientId: "p",
    patientName: "P",
    title: "Episode",
    concern: "",
    status: "UNDER_CARE",
    priority,
    ownerUserId: null,
    ownerName: null,
    nextAction: null,
    createdAt: "2026-09-01T00:00:00.000Z",
    updatedAt: "2026-09-01T00:00:00.000Z",
  };
}

function item(
  name: string,
  opts: { flags?: CaseloadFlag[]; priorities?: Priority[]; overdue?: number; lastContactAt?: string | null; nextFollowUpAt?: string | null } = {},
): CaseloadItem {
  return {
    patient: {
      id: name.toLowerCase(),
      name,
      dob: null,
      age: 60,
      gender: "female",
      relation: "self",
      isSelf: true,
      permissions: [],
      avatarUrl: null,
    },
    episodes: (opts.priorities ?? ["routine"]).map((p, i) => episode(p, `${name}-${i}`)),
    openTasks: 0,
    overdueTasks: opts.overdue ?? 0,
    nextFollowUpAt: opts.nextFollowUpAt ?? null,
    lastContactAt: opts.lastContactAt ?? null,
    flags: opts.flags ?? [],
  };
}

const names = (xs: CaseloadItem[]) => xs.map((x) => x.patient.name);

describe("orderedFlags", () => {
  it("orders by severity and removes duplicates", () => {
    expect(orderedFlags(["no_contact_7d", "overdue_tasks", "open_safety_event", "missed_doses", "overdue_tasks"])).toEqual([
      "open_safety_event",
      "missed_doses",
      "overdue_tasks",
      "no_contact_7d",
    ]);
  });
  it("drops unknown flags", () => {
    expect(orderedFlags(["bogus" as CaseloadFlag, "no_contact_7d"])).toEqual(["no_contact_7d"]);
  });
});

describe("riskScore", () => {
  it("adds flag weights, the highest priority and 2 per overdue task", () => {
    expect(riskScore(item("A"))).toBe(0);
    expect(riskScore(item("A", { flags: ["open_safety_event", "no_contact_7d"] }))).toBe(110);
    expect(riskScore(item("A", { priorities: ["routine", "urgent"] }))).toBe(40);
    expect(riskScore(item("A", { priorities: ["urgent", "emergency"], overdue: 3 }))).toBe(206);
  });
  it("counts duplicate flags once", () => {
    expect(riskScore(item("A", { flags: ["missed_doses", "missed_doses"] }))).toBe(30);
  });
});

describe("sortCaseload", () => {
  const a = item("Asha", { flags: ["no_contact_7d"], lastContactAt: "2026-09-10T00:00:00Z", nextFollowUpAt: null });
  const b = item("Bala", { flags: ["open_safety_event"], lastContactAt: null, nextFollowUpAt: "2026-10-02T00:00:00Z" });
  const c = item("Chitra", { priorities: ["urgent"], lastContactAt: "2026-09-20T00:00:00Z", nextFollowUpAt: "2026-09-30T00:00:00Z" });

  it("sorts by risk (desc by default) without mutating the input", () => {
    const input = [a, b, c];
    expect(names(sortCaseload(input, "risk"))).toEqual(["Bala", "Chitra", "Asha"]);
    expect(names(sortCaseload(input, "risk", "asc"))).toEqual(["Asha", "Chitra", "Bala"]);
    expect(names(input)).toEqual(["Asha", "Bala", "Chitra"]);
  });

  it("breaks risk ties by name", () => {
    const x = item("Zoya");
    const y = item("Anil");
    expect(names(sortCaseload([x, y], "risk"))).toEqual(["Anil", "Zoya"]);
  });

  it("sorts by name", () => {
    expect(names(sortCaseload([c, a, b], "name", "asc"))).toEqual(["Asha", "Bala", "Chitra"]);
    expect(names(sortCaseload([c, a, b], "name", "desc"))).toEqual(["Chitra", "Bala", "Asha"]);
  });

  it("sorts by last contact with missing values last in both directions", () => {
    expect(names(sortCaseload([a, b, c], "lastContact", "asc"))).toEqual(["Asha", "Chitra", "Bala"]);
    expect(names(sortCaseload([a, b, c], "lastContact", "desc"))).toEqual(["Chitra", "Asha", "Bala"]);
  });

  it("sorts by next follow-up with missing values last", () => {
    expect(names(sortCaseload([a, b, c], "nextFollowUp", "asc"))).toEqual(["Chitra", "Bala", "Asha"]);
    expect(names(sortCaseload([a, b, c], "nextFollowUp", "desc"))).toEqual(["Bala", "Chitra", "Asha"]);
  });
});
