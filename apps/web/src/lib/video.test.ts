import { describe, expect, it } from "vitest";
import { canEmbed, formatCountdown, isRemoteMode, isSafeJoinUrl, videoJoinWindow } from "./video";

const appt = { startAt: "2026-09-26T05:00:00.000Z", endAt: "2026-09-26T05:30:00.000Z" };
const at = (iso: string) => new Date(iso);

describe("videoJoinWindow", () => {
  it("is 'before' until 10 minutes before the start, with a countdown", () => {
    const w = videoJoinWindow(appt, at("2026-09-26T04:45:00.000Z"));
    expect(w.phase).toBe("before");
    expect(w.opensAt.toISOString()).toBe("2026-09-26T04:50:00.000Z");
    expect(w.msUntilOpen).toBe(5 * 60_000);
  });
  it("opens exactly 10 minutes before and stays open until 60 minutes after the end", () => {
    expect(videoJoinWindow(appt, at("2026-09-26T04:50:00.000Z")).phase).toBe("open");
    expect(videoJoinWindow(appt, at("2026-09-26T06:30:00.000Z")).phase).toBe("open");
    const closed = videoJoinWindow(appt, at("2026-09-26T06:30:01.000Z"));
    expect(closed.phase).toBe("closed");
    expect(closed.msUntilOpen).toBe(0);
  });
  it("prefers the server's opensAt from a 409", () => {
    const w = videoJoinWindow(appt, at("2026-09-26T04:52:00.000Z"), "2026-09-26T04:55:00.000Z");
    expect(w.phase).toBe("before");
    expect(w.msUntilOpen).toBe(3 * 60_000);
    expect(videoJoinWindow(appt, at("2026-09-26T04:52:00.000Z"), "garbage").phase).toBe("open");
  });
});

describe("video helpers", () => {
  it("only video/audio are remote", () => {
    expect(isRemoteMode("video")).toBe(true);
    expect(isRemoteMode("audio")).toBe(true);
    expect(isRemoteMode("in_clinic")).toBe(false);
    expect(isRemoteMode("chat")).toBe(false);
  });
  it("formats countdowns", () => {
    expect(formatCountdown(4 * 60_000 + 7_000)).toBe("4:07");
    expect(formatCountdown(65 * 60_000)).toBe("1h 05m");
    expect(formatCountdown(50 * 3_600_000)).toBe("2d 2h");
    expect(formatCountdown(-5)).toBe("0:00");
  });
  it("embeds only https URLs on the configured Jitsi host", () => {
    expect(canEmbed("https://meet.jit.si/cc-abc123", "meet.jit.si")).toBe(true);
    expect(canEmbed("http://meet.jit.si/cc-abc123", "meet.jit.si")).toBe(false);
    expect(canEmbed("https://evil.example/cc", "meet.jit.si")).toBe(false);
    expect(canEmbed("not a url", "meet.jit.si")).toBe(false);
  });
  it("rejects non-http join URLs", () => {
    expect(isSafeJoinUrl("https://meet.jit.si/x")).toBe(true);
    expect(isSafeJoinUrl("javascript:alert(1)")).toBe(false);
  });
});
