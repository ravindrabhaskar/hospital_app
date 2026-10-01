"use client";

import { useEffect, useId, useRef, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { Bot, ClipboardPaste, FileAudio, Mic, Square, Trash2, Wand2 } from "lucide-react";
import { api } from "@/lib/api";
import type { ScribeDraft } from "@/lib/api/types";
import { formatDateTime } from "@/lib/format";
import { SOAP_SECTIONS, audioFileName, formatClock, pickAudioMime, scribeBlockReason, type ScribeSource } from "@/lib/scribe";
import { useToast } from "./toast";
import { Button, ChipGroup, Field, Textarea, cx } from "./ui";

type Mode = "record" | "paste";
type RecState = "idle" | "recording" | "recorded" | "unsupported" | "denied";

/**
 * §46 AI scribe. Patient consent gates everything: the recorder, the paste box and the generate button stay
 * disabled until the doctor confirms consent. The SOAP draft is advisory and is only copied into the notes
 * when the doctor presses "Insert into notes"; nothing is saved automatically.
 */
export function ScribePanel({ appointmentId, onInsert }: { appointmentId: string; onInsert: (draft: ScribeDraft) => void }) {
  const toast = useToast();
  const consentId = useId();
  const [consent, setConsent] = useState(false);
  const [mode, setMode] = useState<Mode>("record");
  const [transcript, setTranscript] = useState("");
  const [audio, setAudio] = useState<{ blob: Blob; mime: string; url: string } | null>(null);
  const [draft, setDraft] = useState<ScribeDraft | null>(null);
  const [showError, setShowError] = useState(false);

  const source: ScribeSource = mode === "paste" ? { mode: "transcript", transcript } : { mode: "audio", audio: audio?.blob ?? null };
  const blocked = scribeBlockReason(consent, source);

  const generate = useMutation({
    mutationFn: () =>
      mode === "paste"
        ? api.scribe.fromTranscript(appointmentId, transcript.trim())
        : api.scribe.fromAudio(appointmentId, audio!.blob, audioFileName(audio!.mime)),
    onSuccess: (d) => {
      setDraft(d);
      toast.success("SOAP draft ready", "Review it, then insert it into your notes and edit before saving.");
    },
    onError: (e) => toast.apiError(e, "Could not generate the draft"),
  });

  // Withdrawn consent discards any local recording (it has not been uploaded).
  useEffect(() => {
    if (!consent) setAudio((a) => {
      if (a) URL.revokeObjectURL(a.url);
      return null;
    });
  }, [consent]);

  return (
    <section aria-labelledby="scribe-heading" className="rounded-[20px] border border-line bg-surface shadow-[var(--shadow-card)]">
      <header className="flex flex-wrap items-start justify-between gap-2 border-b border-line px-5 py-3.5">
        <div>
          <h2 id="scribe-heading" className="flex items-center gap-2 text-base font-semibold">
            <Wand2 className="size-4 text-lavender-fg" aria-hidden /> AI scribe
          </h2>
          <p className="text-xs text-ink-muted">Drafts SOAP notes from the consultation. Audio is transcribed and then discarded.</p>
        </div>
      </header>
      <div className="flex flex-col gap-4 p-5">
        <div className={cx("rounded-xl border p-3", consent ? "border-[#ecc9d8] bg-teal-bg/60" : "border-[#f8d9b5] bg-peach-bg/70")}>
          <label htmlFor={consentId} className="flex items-start gap-2.5 text-sm">
            <input
              id={consentId}
              type="checkbox"
              className="mt-0.5 size-4 shrink-0 accent-[#631D3F]"
              checked={consent}
              onChange={(e) => setConsent(e.target.checked)}
            />
            <span>
              <strong>The patient agreed</strong> to this consultation being recorded and transcribed to draft notes. (Required. The
              confirmation is audited.)
            </span>
          </label>
        </div>

        <fieldset disabled={!consent} className="flex flex-col gap-4 disabled:opacity-60" aria-describedby={!consent ? `${consentId}-hint` : undefined}>
          <legend className="sr-only">Scribe input</legend>
          {!consent && (
            <p id={`${consentId}-hint`} className="text-xs text-ink-muted">
              Recording and transcript input unlock after consent is confirmed.
            </p>
          )}
          <ChipGroup<Mode>
            label="Scribe input"
            value={mode}
            onChange={setMode}
            options={[
              { value: "record", label: "Record in browser" },
              { value: "paste", label: "Paste transcript" },
            ]}
          />
          {mode === "record" ? (
            <Recorder
              enabled={consent}
              audio={audio}
              onAudio={(a) =>
                setAudio((prev) => {
                  if (prev) URL.revokeObjectURL(prev.url);
                  return a;
                })
              }
            />
          ) : (
            <Field label="Consultation transcript" hint="Paste the conversation text. Nothing that is not in the transcript should appear in the draft.">
              {(id, d) => (
                <Textarea id={id} aria-describedby={d} rows={6} value={transcript} onChange={(e) => setTranscript(e.target.value)} disabled={!consent} />
              )}
            </Field>
          )}
        </fieldset>

        <div className="flex flex-col gap-1.5">
          <Button
            className="self-start"
            onClick={() => {
              if (blocked) {
                setShowError(true);
                return;
              }
              setShowError(false);
              generate.mutate();
            }}
            loading={generate.isPending}
            aria-disabled={!!blocked || undefined}
            disabled={!consent}
            icon={<Bot className="size-4" aria-hidden />}
          >
            Generate SOAP draft
          </Button>
          {blocked && (showError || !consent) && (
            <p className="text-xs text-danger-dark" role={showError ? "alert" : undefined}>
              {blocked}
            </p>
          )}
        </div>

        {draft && <ScribeDraftView draft={draft} onInsert={() => onInsert(draft)} onDiscard={() => setDraft(null)} />}
      </div>
    </section>
  );
}

export function ScribeDraftView({ draft, onInsert, onDiscard }: { draft: ScribeDraft; onInsert: () => void; onDiscard: () => void }) {
  return (
    <section aria-label="AI SOAP draft" className="rounded-[20px] border-2 border-dashed border-[#c9bdf3] bg-lavender-bg p-4 text-[#2a2150]">
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <p className="flex items-center gap-2 font-semibold text-[#3b2a8c]">
          <Bot className="size-5" aria-hidden /> SOAP draft
        </p>
        <span className="rounded-full bg-white px-2.5 py-0.5 text-xs font-semibold text-lavender-fg">AI-generated · advisory</span>
      </div>
      <dl className="flex flex-col gap-3">
        {SOAP_SECTIONS.map(({ key, label }) => (
          <div key={key}>
            <dt className="text-xs font-semibold uppercase tracking-wide text-[#5c5190]">{label}</dt>
            <dd className="whitespace-pre-line text-sm">{draft.draft[key]?.trim() || <span className="italic text-[#5c5190]">Nothing in the transcript</span>}</dd>
          </div>
        ))}
      </dl>
      <details className="mt-3 text-[13px]">
        <summary className="cursor-pointer font-medium text-[#3b2a8c]">Transcript</summary>
        <p className="mt-1 max-h-48 overflow-y-auto whitespace-pre-line rounded-lg bg-white/70 p-2">{draft.transcript}</p>
      </details>
      <p className="mt-3 text-[11px] text-[#5c5190]">
        {draft.model} · {formatDateTime(draft.generatedAt)} · audio not retained. Verify every statement; you are responsible for the final notes.
      </p>
      <div className="mt-3 flex flex-wrap gap-2">
        <Button size="sm" onClick={onInsert} icon={<ClipboardPaste className="size-4" aria-hidden />}>
          Insert into notes
        </Button>
        <Button size="sm" variant="ghost" onClick={onDiscard}>
          Discard draft
        </Button>
      </div>
    </section>
  );
}

function Recorder({
  enabled,
  audio,
  onAudio,
}: {
  enabled: boolean;
  audio: { blob: Blob; mime: string; url: string } | null;
  onAudio: (a: { blob: Blob; mime: string; url: string } | null) => void;
}) {
  const [state, setState] = useState<RecState>(() =>
    typeof window !== "undefined" && (typeof MediaRecorder === "undefined" || !navigator.mediaDevices?.getUserMedia) ? "unsupported" : "idle",
  );
  const [secs, setSecs] = useState(0);
  const recRef = useRef<MediaRecorder | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const chunks = useRef<Blob[]>([]);
  const timer = useRef<number | null>(null);

  const stopTracks = () => {
    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;
    if (timer.current) window.clearInterval(timer.current);
    timer.current = null;
  };

  useEffect(() => () => {
    if (recRef.current && recRef.current.state !== "inactive") recRef.current.stop();
    stopTracks();
  }, []);

  // Consent withdrawn mid-recording: stop and drop it.
  useEffect(() => {
    if (!enabled && recRef.current && recRef.current.state !== "inactive") {
      recRef.current.onstop = null;
      recRef.current.stop();
      stopTracks();
      setState("idle");
    }
  }, [enabled]);

  const start = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;
      const mime = pickAudioMime((t) => MediaRecorder.isTypeSupported(t));
      const rec = mime ? new MediaRecorder(stream, { mimeType: mime }) : new MediaRecorder(stream);
      chunks.current = [];
      rec.ondataavailable = (e) => {
        if (e.data.size > 0) chunks.current.push(e.data);
      };
      rec.onstop = () => {
        const type = rec.mimeType || mime || "audio/webm";
        const blob = new Blob(chunks.current, { type });
        onAudio({ blob, mime: type, url: URL.createObjectURL(blob) });
        setState("recorded");
        stopTracks();
      };
      recRef.current = rec;
      rec.start(1000);
      setSecs(0);
      timer.current = window.setInterval(() => setSecs((s) => s + 1), 1000);
      setState("recording");
    } catch {
      stopTracks();
      setState("denied");
    }
  };

  const stop = () => recRef.current?.stop();

  if (state === "unsupported")
    return <p className="text-sm text-ink-muted">This browser cannot record audio. Paste a transcript instead.</p>;

  return (
    <div className="flex flex-col gap-3">
      {state === "denied" && (
        <p role="alert" className="text-sm text-danger-dark">
          Microphone access was blocked. Allow the microphone for this site, or paste a transcript instead.
        </p>
      )}
      <div className="flex flex-wrap items-center gap-3">
        {state === "recording" ? (
          <>
            <Button variant="danger" onClick={stop} icon={<Square className="size-4" aria-hidden />}>
              Stop recording
            </Button>
            <span className="inline-flex items-center gap-2 text-sm font-semibold text-danger-dark" role="timer" aria-live="off">
              <span className="size-2.5 animate-pulse rounded-full bg-danger" aria-hidden /> Recording {formatClock(secs)}
            </span>
          </>
        ) : (
          <Button variant="secondary" onClick={() => void start()} disabled={!enabled} icon={<Mic className="size-4" aria-hidden />}>
            {audio ? "Record again" : "Start recording"}
          </Button>
        )}
      </div>
      {audio && state !== "recording" && (
        <div className="flex flex-wrap items-center gap-3 rounded-xl border border-line p-3">
          <FileAudio className="size-5 text-ink-muted" aria-hidden />
          <audio controls src={audio.url} className="h-9 max-w-full" aria-label="Recorded consultation audio" />
          <span className="text-xs text-ink-muted">{(audio.blob.size / (1024 * 1024)).toFixed(1)} MB</span>
          <Button variant="ghost" size="sm" onClick={() => onAudio(null)} icon={<Trash2 className="size-4" aria-hidden />}>
            Delete recording
          </Button>
        </div>
      )}
    </div>
  );
}
