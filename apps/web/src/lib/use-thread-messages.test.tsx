import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { act, renderHook } from "@testing-library/react";
import type { ChatMessage } from "@/lib/api/types";
import { THREAD_POLL_MS, mergeMessages, useThreadMessages } from "./use-thread-messages";

function msg(id: string, minute: number, ep = "ep1"): ChatMessage {
  return {
    id,
    careEpisodeId: ep,
    senderUserId: "u2",
    senderName: "Asha",
    senderRole: "patient",
    text: `message ${id}`,
    attachmentRecordId: null,
    createdAt: new Date(Date.UTC(2026, 8, 26, 4, minute)).toISOString(),
  };
}

const flush = () => act(async () => {
  await vi.advanceTimersByTimeAsync(0);
});
const tick = (ms = THREAD_POLL_MS) => act(async () => {
  await vi.advanceTimersByTimeAsync(ms);
});

describe("useThreadMessages", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });
  afterEach(() => {
    vi.useRealTimers();
  });

  it("loads once, then polls every 10 s with after=<last id>", async () => {
    const fetcher = vi
      .fn()
      .mockResolvedValueOnce({ items: [msg("a", 1), msg("b", 2)] })
      .mockResolvedValue({ items: [] });
    const { result } = renderHook(() => useThreadMessages("ep1", { fetcher }));
    expect(result.current.status).toBe("loading");
    await flush();
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(fetcher).toHaveBeenLastCalledWith("ep1", undefined);
    expect(result.current.status).toBe("ready");
    expect(result.current.messages.map((m) => m.id)).toEqual(["a", "b"]);

    await tick(THREAD_POLL_MS - 1);
    expect(fetcher).toHaveBeenCalledTimes(1);
    await tick(1);
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(fetcher).toHaveBeenLastCalledWith("ep1", "b");
  });

  it("appends new messages in order and dedupes by id", async () => {
    const fetcher = vi
      .fn()
      .mockResolvedValueOnce({ items: [msg("a", 1), msg("b", 2)] })
      .mockResolvedValueOnce({ items: [msg("b", 2), msg("d", 4)] })
      .mockResolvedValue({ items: [] });
    const onNewMessages = vi.fn();
    const { result } = renderHook(() => useThreadMessages("ep1", { fetcher, onNewMessages }));
    await flush();
    // A message returned by POST lands between polls.
    act(() => result.current.append(msg("c", 3)));
    expect(result.current.messages.map((m) => m.id)).toEqual(["a", "b", "c"]);
    await tick();
    expect(fetcher).toHaveBeenLastCalledWith("ep1", "c");
    expect(result.current.messages.map((m) => m.id)).toEqual(["a", "b", "c", "d"]);
    expect(onNewMessages).toHaveBeenCalledTimes(2);
    await tick();
    expect(fetcher).toHaveBeenLastCalledWith("ep1", "d");
  });

  it("resets when the episode changes", async () => {
    const fetcher = vi.fn((ep: string) => Promise.resolve({ items: [msg(`${ep}-1`, 1, ep)] }));
    const { result, rerender } = renderHook(({ ep }) => useThreadMessages(ep, { fetcher }), { initialProps: { ep: "ep1" } });
    await flush();
    expect(result.current.messages.map((m) => m.id)).toEqual(["ep1-1"]);
    rerender({ ep: "ep2" });
    expect(result.current.status).toBe("loading");
    expect(result.current.messages).toEqual([]);
    await flush();
    expect(fetcher).toHaveBeenLastCalledWith("ep2", undefined);
    expect(result.current.messages.map((m) => m.id)).toEqual(["ep2-1"]);
  });

  it("stops polling on unmount", async () => {
    const fetcher = vi.fn().mockResolvedValue({ items: [] });
    const { unmount } = renderHook(() => useThreadMessages("ep1", { fetcher }));
    await flush();
    expect(fetcher).toHaveBeenCalledTimes(1);
    unmount();
    await tick(THREAD_POLL_MS * 3);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it("keeps messages when a poll fails after a successful load", async () => {
    const fetcher = vi
      .fn()
      .mockResolvedValueOnce({ items: [msg("a", 1)] })
      .mockRejectedValueOnce(new TypeError("offline"))
      .mockResolvedValue({ items: [msg("b", 2)] });
    const { result } = renderHook(() => useThreadMessages("ep1", { fetcher }));
    await flush();
    await tick();
    expect(result.current.status).toBe("ready");
    expect(result.current.error).toBeInstanceOf(TypeError);
    expect(result.current.messages.map((m) => m.id)).toEqual(["a"]);
    await tick();
    expect(result.current.error).toBeNull();
    expect(result.current.messages.map((m) => m.id)).toEqual(["a", "b"]);
  });

  it("reports an error when the first load fails", async () => {
    const fetcher = vi.fn().mockRejectedValue(new Error("boom"));
    const { result } = renderHook(() => useThreadMessages("ep1", { fetcher }));
    await flush();
    expect(result.current.status).toBe("error");
    expect(result.current.messages).toEqual([]);
  });
});

describe("mergeMessages", () => {
  it("returns the same array when nothing arrives and sorts by time", () => {
    const cur = [msg("a", 1)];
    expect(mergeMessages(cur, [])).toBe(cur);
    expect(mergeMessages([msg("b", 5)], [msg("a", 1), msg("b", 5)]).map((m) => m.id)).toEqual(["a", "b"]);
  });
});
