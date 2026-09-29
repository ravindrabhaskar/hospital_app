import type { SoapDraft } from "@/lib/api/types";

/** §46: audio uploads are limited to 25 MB. */
export const SCRIBE_MAX_AUDIO_BYTES = 25 * 1024 * 1024;
export const SCRIBE_MIN_TRANSCRIPT = 20;
export const SCRIBE_MAX_TRANSCRIPT = 50_000;

export type ScribeSource = { mode: "transcript"; transcript: string } | { mode: "audio"; audio: Blob | null };

/**
 * Why the scribe cannot be run yet (null = ready). Patient consent to recording always comes first:
 * without it nothing is recorded, uploaded or sent (the server also rejects `consentConfirmed !== true`).
 */
export function scribeBlockReason(consentConfirmed: boolean, source: ScribeSource): string | null {
  if (!consentConfirmed) return "Confirm that the patient agreed to the consultation being recorded and transcribed.";
  if (source.mode === "transcript") {
    const t = source.transcript.trim();
    if (t.length < SCRIBE_MIN_TRANSCRIPT) return `Paste the consultation transcript (at least ${SCRIBE_MIN_TRANSCRIPT} characters).`;
    if (t.length > SCRIBE_MAX_TRANSCRIPT) return `The transcript is too long (at most ${SCRIBE_MAX_TRANSCRIPT.toLocaleString("en-IN")} characters).`;
    return null;
  }
  if (!source.audio || source.audio.size === 0) return "Record the consultation first.";
  if (source.audio.size > SCRIBE_MAX_AUDIO_BYTES) return "The recording is larger than 25 MB. Record a shorter segment or paste a transcript.";
  return null;
}

export const SOAP_SECTIONS: { key: keyof SoapDraft; label: string }[] = [
  { key: "subjective", label: "Subjective" },
  { key: "objective", label: "Objective" },
  { key: "assessment", label: "Assessment" },
  { key: "plan", label: "Plan" },
];

/** Plain-text SOAP block inserted into the consultation notes (empty sections are skipped). The doctor edits it before saving. */
export function soapToNotes(draft: SoapDraft): string {
  return SOAP_SECTIONS.map(({ key, label }) => {
    const text = (draft[key] ?? "").trim();
    return text ? `${label}:\n${text}` : null;
  })
    .filter(Boolean)
    .join("\n\n");
}

/** Appends the SOAP block to existing notes, separated by a blank line. */
export function insertIntoNotes(existing: string, draft: SoapDraft): string {
  const block = soapToNotes(draft);
  if (!block) return existing;
  return existing.trim() ? `${existing.trimEnd()}\n\n${block}` : block;
}

/** First MediaRecorder mime type the browser supports, from those the API accepts (webm/m4a/wav). */
export function pickAudioMime(isTypeSupported: (t: string) => boolean): string {
  const candidates = ["audio/webm;codecs=opus", "audio/webm", "audio/mp4", "audio/wav"];
  return candidates.find((t) => {
    try {
      return isTypeSupported(t);
    } catch {
      return false;
    }
  }) ?? "";
}

export function audioFileName(mime: string): string {
  if (mime.includes("mp4") || mime.includes("m4a")) return "consultation.m4a";
  if (mime.includes("wav")) return "consultation.wav";
  return "consultation.webm";
}

export function formatClock(totalSeconds: number): string {
  const m = Math.floor(totalSeconds / 60);
  const s = Math.floor(totalSeconds % 60);
  return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
}
