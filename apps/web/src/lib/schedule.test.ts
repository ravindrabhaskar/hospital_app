import { describe, expect, it } from "vitest";
import type { WeeklyBlock } from "@/lib/api/types";
import { newBlock, slotCount, sortBlocks, toMinutes, validateWeekly } from "./schedule";

const b = (over: Partial<WeeklyBlock> = {}): WeeklyBlock => ({
  weekday: 1,
  start: "09:00",
  end: "12:00",
  slotMins: 30,
  modes: ["video"],
  ...over,
});

describe("validateWeekly", () => {
  it("accepts a valid template", () => {
    expect(validateWeekly([b(), b({ weekday: 2 })])).toEqual({});
  });

  it("flags overlapping blocks on the same day on both blocks", () => {
    const errors = validateWeekly([b({ start: "09:00", end: "12:00" }), b({ start: "11:00", end: "13:00" })]);
    expect(Object.keys(errors).sort()).toEqual(["0", "1"]);
    expect(errors[0]).toMatch(/overlaps/i);
    expect(errors[1]).toMatch(/overlaps/i);
  });

  it("flags a block fully contained in another", () => {
    const errors = validateWeekly([b({ start: "09:00", end: "17:00" }), b({ start: "10:00", end: "11:00" })]);
    expect(errors[0]).toBeDefined();
    expect(errors[1]).toBeDefined();
  });

  it("allows touching blocks", () => {
    expect(validateWeekly([b({ start: "10:00", end: "12:00" }), b({ start: "12:00", end: "13:00" })])).toEqual({});
  });

  it("allows the same times on different weekdays", () => {
    expect(validateWeekly([b({ weekday: 1 }), b({ weekday: 3 }), b({ weekday: 0 })])).toEqual({});
  });

  it("rejects end ≤ start", () => {
    expect(validateWeekly([b({ start: "12:00", end: "12:00" })])[0]).toMatch(/after the start/i);
    expect(validateWeekly([b({ start: "13:00", end: "12:00" })])[0]).toMatch(/after the start/i);
  });

  it("rejects a block shorter than one slot", () => {
    expect(validateWeekly([b({ start: "09:00", end: "09:20", slotMins: 30 })])[0]).toMatch(/shorter than one 30-minute slot/i);
  });

  it("requires at least one mode", () => {
    expect(validateWeekly([b({ modes: [] })])[0]).toMatch(/at least one/i);
  });

  it("rejects malformed times", () => {
    expect(validateWeekly([b({ start: "" })])[0]).toMatch(/HH:MM/);
    expect(toMinutes("24:00")).toBeNull();
  });

  it("only flags the overlapping pair, not unrelated blocks", () => {
    const errors = validateWeekly([b({ start: "08:00", end: "09:00" }), b({ start: "10:00", end: "12:00" }), b({ start: "11:30", end: "12:30" })]);
    expect(errors[0]).toBeUndefined();
    expect(errors[1]).toBeDefined();
    expect(errors[2]).toBeDefined();
  });
});

describe("slotCount", () => {
  it("counts whole slots", () => {
    expect(slotCount({ start: "09:00", end: "12:00", slotMins: 30 })).toBe(6);
    expect(slotCount({ start: "09:00", end: "09:50", slotMins: 20 })).toBe(2);
    expect(slotCount({ start: "09:00", end: "10:00", slotMins: 45 })).toBe(1);
  });

  it("is 0 for invalid ranges", () => {
    expect(slotCount({ start: "12:00", end: "09:00", slotMins: 15 })).toBe(0);
    expect(slotCount({ start: "bad", end: "09:00", slotMins: 15 })).toBe(0);
  });
});

describe("sortBlocks", () => {
  it("orders Monday→Sunday, then by start, without mutating the input", () => {
    const input = [
      b({ weekday: 0, start: "09:00", end: "10:00" }),
      b({ weekday: 3, start: "14:00", end: "15:00" }),
      b({ weekday: 1, start: "16:00", end: "17:00" }),
      b({ weekday: 3, start: "08:00", end: "09:00" }),
      b({ weekday: 1, start: "07:00", end: "08:00" }),
    ];
    const copy = [...input];
    const sorted = sortBlocks(input);
    expect(sorted.map((x) => `${x.weekday}@${x.start}`)).toEqual(["1@07:00", "1@16:00", "3@08:00", "3@14:00", "0@09:00"]);
    expect(input).toEqual(copy);
  });
});

describe("newBlock", () => {
  it("starts at 09:00 on an empty day and after the last block otherwise", () => {
    expect(newBlock(2, [])).toMatchObject({ weekday: 2, start: "09:00", end: "13:00" });
    const next = newBlock(1, [b({ weekday: 1, start: "09:00", end: "12:00" })]);
    expect(next.start).toBe("13:00");
    expect(validateWeekly([b({ weekday: 1, start: "09:00", end: "12:00" }), next])).toEqual({});
  });
});
