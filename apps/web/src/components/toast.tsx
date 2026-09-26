"use client";

import { createContext, useCallback, useContext, useMemo, useRef, useState, type ReactNode } from "react";
import { CheckCircle2, AlertTriangle, Info, X } from "lucide-react";
import { cx, errorMessage } from "./ui";

type ToastKind = "success" | "error" | "info";
interface ToastItem {
  id: number;
  kind: ToastKind;
  title: string;
  description?: string;
}

interface ToastApi {
  success: (title: string, description?: string) => void;
  error: (title: string, description?: string) => void;
  info: (title: string, description?: string) => void;
  /** Shows an error toast with the parsed API message. */
  apiError: (err: unknown, title?: string) => void;
}

const ToastContext = createContext<ToastApi | null>(null);

export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<ToastItem[]>([]);
  const nextId = useRef(1);

  const dismiss = useCallback((id: number) => setItems((xs) => xs.filter((t) => t.id !== id)), []);

  const push = useCallback(
    (kind: ToastKind, title: string, description?: string) => {
      const id = nextId.current++;
      setItems((xs) => [...xs.slice(-3), { id, kind, title, description }]);
      window.setTimeout(() => dismiss(id), kind === "error" ? 8000 : 4500);
    },
    [dismiss],
  );

  const api = useMemo<ToastApi>(
    () => ({
      success: (t, d) => push("success", t, d),
      error: (t, d) => push("error", t, d),
      info: (t, d) => push("info", t, d),
      apiError: (err, t = "Action failed") => push("error", t, errorMessage(err)),
    }),
    [push],
  );

  return (
    <ToastContext.Provider value={api}>
      {children}
      <div className="pointer-events-none fixed bottom-4 right-4 z-[60] flex w-[min(380px,calc(100vw-2rem))] flex-col gap-2">
        <div aria-live="polite" className="contents">
          {items
            .filter((t) => t.kind !== "error")
            .map((t) => (
              <ToastCard key={t.id} t={t} onDismiss={dismiss} />
            ))}
        </div>
        <div aria-live="assertive" className="contents">
          {items
            .filter((t) => t.kind === "error")
            .map((t) => (
              <ToastCard key={t.id} t={t} onDismiss={dismiss} />
            ))}
        </div>
      </div>
    </ToastContext.Provider>
  );
}

function ToastCard({ t, onDismiss }: { t: ToastItem; onDismiss: (id: number) => void }) {
  const Icon = t.kind === "success" ? CheckCircle2 : t.kind === "error" ? AlertTriangle : Info;
  return (
    <div
      role={t.kind === "error" ? "alert" : "status"}
      className={cx(
        "pointer-events-auto flex items-start gap-3 rounded-2xl border bg-white p-3.5 shadow-lg",
        t.kind === "error" ? "border-[#f6c9c9]" : "border-line",
      )}
    >
      <Icon
        className={cx("mt-0.5 size-5 shrink-0", t.kind === "error" ? "text-danger" : t.kind === "success" ? "text-primary-light" : "text-sky-fg")}
        aria-hidden
      />
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold">{t.title}</p>
        {t.description && <p className="text-[13px] text-ink-muted">{t.description}</p>}
      </div>
      <button type="button" onClick={() => onDismiss(t.id)} aria-label="Dismiss notification" className="rounded-full p-1 text-ink-muted hover:bg-mint-50">
        <X className="size-4" aria-hidden />
      </button>
    </div>
  );
}

export function useToast(): ToastApi {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error("useToast must be used inside ToastProvider");
  return ctx;
}
