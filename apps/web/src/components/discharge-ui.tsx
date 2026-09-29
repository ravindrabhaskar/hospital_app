"use client";

import type { DischargeStatus } from "@/lib/api/types";
import { programProgress } from "@/lib/discharge";
import type { Tone } from "./ui";

export const DISCHARGE_TONE: Record<DischargeStatus, Tone> = { active: "green", completed: "neutral", readmitted: "red", withdrawn: "neutral" };

export function DayProgress({ day }: { day: number }) {
  const shown = Math.min(Math.max(day, 0), 30);
  return (
    <div>
      <p className="text-[13px] font-semibold tabular-nums">Day {shown}/30</p>
      <div role="progressbar" aria-label="Program progress" aria-valuemin={0} aria-valuemax={30} aria-valuenow={shown} className="mt-1 h-2 w-full rounded-full bg-mint-100">
        <div className="h-2 rounded-full bg-primary-light" style={{ width: `${programProgress(day)}%` }} />
      </div>
    </div>
  );
}
