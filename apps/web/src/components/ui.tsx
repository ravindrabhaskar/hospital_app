"use client";

import {
  forwardRef,
  useEffect,
  useId,
  useRef,
  type ButtonHTMLAttributes,
  type InputHTMLAttributes,
  type ReactNode,
  type SelectHTMLAttributes,
  type TextareaHTMLAttributes,
} from "react";
import { AlertTriangle, Inbox, Loader2, Lock, RefreshCw, X } from "lucide-react";
import { ApiError } from "@/lib/api/http";

export function cx(...parts: (string | false | null | undefined)[]) {
  return parts.filter(Boolean).join(" ");
}

/* ---------------- Buttons ---------------- */
type ButtonVariant = "primary" | "secondary" | "ghost" | "danger" | "subtle";
type ButtonSize = "sm" | "md";

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  loading?: boolean;
  icon?: ReactNode;
}

const variantCls: Record<ButtonVariant, string> = {
  primary: "bg-primary text-white hover:bg-primary-dark disabled:bg-primary/50",
  secondary: "border border-primary text-primary bg-white hover:bg-mint-50 disabled:opacity-50",
  ghost: "text-ink-muted hover:bg-mint-50 hover:text-ink disabled:opacity-50",
  danger: "bg-danger text-white hover:bg-danger-dark disabled:opacity-50",
  subtle: "bg-mint-100 text-primary-dark hover:bg-mint-50 disabled:opacity-50",
};

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = "primary", size = "md", loading, icon, className, children, disabled, type = "button", ...rest },
  ref,
) {
  return (
    <button
      ref={ref}
      type={type}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      className={cx(
        "inline-flex items-center justify-center gap-2 rounded-[28px] font-semibold transition-colors disabled:cursor-not-allowed",
        size === "sm" ? "h-9 px-3.5 text-[13px]" : "h-11 px-5 text-sm",
        variantCls[variant],
        className,
      )}
      {...rest}
    >
      {loading ? <Loader2 className="size-4 animate-spin" aria-hidden /> : icon}
      {children}
    </button>
  );
});

/* ---------------- Card ---------------- */
export function Card({
  title,
  actions,
  children,
  className,
  bodyClassName,
  id,
  as: As = "section",
  subtitle,
}: {
  title?: ReactNode;
  subtitle?: ReactNode;
  actions?: ReactNode;
  children: ReactNode;
  className?: string;
  bodyClassName?: string;
  id?: string;
  as?: "section" | "div" | "article";
}) {
  const headingId = useId();
  return (
    <As
      id={id}
      aria-labelledby={title ? headingId : undefined}
      className={cx("rounded-[20px] border border-line bg-surface shadow-[var(--shadow-card)]", className)}
    >
      {(title || actions) && (
        <header className="flex flex-wrap items-start justify-between gap-2 border-b border-line px-5 py-3.5">
          <div>
            {title && (
              <h2 id={headingId} className="text-base font-semibold text-ink">
                {title}
              </h2>
            )}
            {subtitle && <p className="text-xs text-ink-muted">{subtitle}</p>}
          </div>
          {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
        </header>
      )}
      <div className={cx("p-5", bodyClassName)}>{children}</div>
    </As>
  );
}

/* ---------------- Badges ---------------- */
export type Tone = "neutral" | "green" | "red" | "amber" | "lavender" | "sky" | "dark";
const toneCls: Record<Tone, string> = {
  neutral: "bg-[#eef2f0] text-ink-muted border-line",
  green: "bg-teal-bg text-primary-dark border-[#ecc9d8]",
  red: "bg-rose-bg text-danger-dark border-[#f6c9c9]",
  amber: "bg-peach-bg text-peach-fg border-[#f8d9b5]",
  lavender: "bg-lavender-bg text-lavender-fg border-[#d9d0f7]",
  sky: "bg-sky-bg text-sky-fg border-[#c9dcf8]",
  dark: "bg-ink text-white border-ink",
};

export function Badge({
  tone = "neutral",
  children,
  className,
  icon,
  title,
}: {
  tone?: Tone;
  children: ReactNode;
  className?: string;
  icon?: ReactNode;
  title?: string;
}) {
  return (
    <span
      title={title}
      className={cx(
        "inline-flex items-center gap-1 whitespace-nowrap rounded-full border px-2 py-0.5 text-xs font-medium",
        toneCls[tone],
        className,
      )}
    >
      {icon}
      {children}
    </span>
  );
}

/* ---------------- Form fields ---------------- */
interface FieldWrapProps {
  label: string;
  error?: string;
  hint?: string;
  required?: boolean;
  children: (id: string, describedBy: string | undefined) => ReactNode;
  className?: string;
}

export function Field({ label, error, hint, required, children, className }: FieldWrapProps) {
  const id = useId();
  const descId = `${id}-desc`;
  const describedBy = error || hint ? descId : undefined;
  return (
    <div className={cx("flex flex-col gap-1", className)}>
      <label htmlFor={id} className="text-[13px] font-medium text-ink">
        {label}
        {required && (
          <span className="text-danger" aria-hidden>
            {" "}
            *
          </span>
        )}
      </label>
      {children(id, describedBy)}
      {(error || hint) && (
        <p id={descId} className={cx("text-xs", error ? "text-danger-dark" : "text-ink-muted")} role={error ? "alert" : undefined}>
          {error || hint}
        </p>
      )}
    </div>
  );
}

const inputBase =
  "w-full rounded-xl border border-line bg-white px-3.5 py-2 text-sm text-ink placeholder:text-ink-muted/70 focus:border-primary-light focus:outline-none focus-visible:outline-2 focus-visible:outline-primary-light disabled:bg-mint-50 aria-[invalid=true]:border-danger";

export const Input = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement>>(function Input(
  { className, ...rest },
  ref,
) {
  return <input ref={ref} className={cx(inputBase, "h-10", className)} {...rest} />;
});

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaHTMLAttributes<HTMLTextAreaElement>>(function Textarea(
  { className, rows = 3, ...rest },
  ref,
) {
  return <textarea ref={ref} rows={rows} className={cx(inputBase, className)} {...rest} />;
});

export const Select = forwardRef<HTMLSelectElement, SelectHTMLAttributes<HTMLSelectElement>>(function Select(
  { className, children, ...rest },
  ref,
) {
  return (
    <select ref={ref} className={cx(inputBase, "h-10 pr-8", className)} {...rest}>
      {children}
    </select>
  );
});

/* ---------------- States ---------------- */
export function LoadingState({ label = "Loading…", rows = 3 }: { label?: string; rows?: number }) {
  return (
    <div role="status" aria-live="polite" className="flex flex-col gap-3 py-2">
      <span className="sr-only">{label}</span>
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="h-12 animate-pulse rounded-xl bg-mint-50" aria-hidden />
      ))}
    </div>
  );
}

export function EmptyState({
  title = "Nothing here yet",
  description,
  action,
  icon,
}: {
  title?: string;
  description?: ReactNode;
  action?: ReactNode;
  icon?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center gap-2 py-10 text-center">
      <div className="flex size-12 items-center justify-center rounded-2xl bg-mint-50 text-primary-light" aria-hidden>
        {icon ?? <Inbox className="size-6" />}
      </div>
      <p className="font-semibold text-ink">{title}</p>
      {description && <p className="max-w-md text-sm text-ink-muted">{description}</p>}
      {action}
    </div>
  );
}

export function UnauthorizedState({ message }: { message?: string }) {
  return (
    <div role="alert" className="flex flex-col items-center gap-2 py-10 text-center">
      <div className="flex size-12 items-center justify-center rounded-2xl bg-peach-bg text-peach-fg" aria-hidden>
        <Lock className="size-6" />
      </div>
      <p className="font-semibold text-ink">You don&apos;t have access to this</p>
      <p className="max-w-md text-sm text-ink-muted">
        {message ?? "Your role does not permit this view. Ask a super admin if you believe this is wrong."}
      </p>
    </div>
  );
}

export function ErrorState({ error, onRetry }: { error: unknown; onRetry?: () => void }) {
  if (error instanceof ApiError && error.status === 403) return <UnauthorizedState message={error.message} />;
  const msg = errorMessage(error);
  const cid = error instanceof ApiError ? error.correlationId : null;
  return (
    <div role="alert" className="flex flex-col items-center gap-2 py-10 text-center">
      <div className="flex size-12 items-center justify-center rounded-2xl bg-rose-bg text-danger" aria-hidden>
        <AlertTriangle className="size-6" />
      </div>
      <p className="font-semibold text-ink">Something went wrong</p>
      <p className="max-w-md text-sm text-ink-muted">{msg}</p>
      {cid && <p className="font-mono text-xs text-ink-muted">Reference: {cid}</p>}
      {onRetry && (
        <Button variant="secondary" size="sm" onClick={onRetry} icon={<RefreshCw className="size-4" aria-hidden />}>
          Try again
        </Button>
      )}
    </div>
  );
}

export function errorMessage(error: unknown): string {
  if (error instanceof ApiError) return error.message;
  if (error instanceof TypeError) return "Could not reach the server. Check your connection or that the API is running.";
  if (error instanceof Error) return error.message;
  return "Unexpected error.";
}

/** Renders loading / error / empty / content for a query. */
export function QueryView<T>({
  query,
  empty,
  isEmpty,
  children,
  loadingRows,
}: {
  query: { isPending: boolean; isError: boolean; error: unknown; data: T | undefined; refetch: () => unknown };
  empty?: ReactNode;
  isEmpty?: (data: T) => boolean;
  children: (data: T) => ReactNode;
  loadingRows?: number;
}) {
  if (query.isPending) return <LoadingState rows={loadingRows} />;
  if (query.isError) return <ErrorState error={query.error} onRetry={() => query.refetch()} />;
  const data = query.data as T;
  if (isEmpty?.(data)) return <>{empty ?? <EmptyState />}</>;
  return <>{children(data)}</>;
}

/* ---------------- Page header ---------------- */
export function PageHeader({
  title,
  description,
  actions,
}: {
  title: string;
  description?: ReactNode;
  actions?: ReactNode;
}) {
  return (
    <div className="mb-5 flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 className="text-[22px] font-bold leading-7 text-ink">{title}</h1>
        {description && <p className="mt-0.5 text-sm text-ink-muted">{description}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </div>
  );
}

/* ---------------- Chips / tabs ---------------- */
export function ChipGroup<V extends string>({
  label,
  options,
  value,
  onChange,
}: {
  label: string;
  options: { value: V; label: string; count?: number }[];
  value: V;
  onChange: (v: V) => void;
}) {
  return (
    <div role="radiogroup" aria-label={label} className="flex flex-wrap gap-2">
      {options.map((o) => {
        const active = o.value === value;
        return (
          <button
            key={o.value}
            type="button"
            role="radio"
            aria-checked={active}
            onClick={() => onChange(o.value)}
            className={cx(
              "h-9 rounded-full border px-3.5 text-[13px] font-medium transition-colors",
              active ? "border-primary bg-primary text-white" : "border-line bg-white text-ink hover:bg-mint-50",
            )}
          >
            {o.label}
            {o.count !== undefined && (
              <span className={cx("ml-1.5 rounded-full px-1.5 text-xs", active ? "bg-white/20" : "bg-mint-100")}>{o.count}</span>
            )}
          </button>
        );
      })}
    </div>
  );
}

/* ---------------- Dialog ---------------- */
export function Dialog({
  open,
  onClose,
  title,
  description,
  children,
  footer,
  size = "md",
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: ReactNode;
  children: ReactNode;
  footer?: ReactNode;
  size?: "md" | "lg";
}) {
  const ref = useRef<HTMLDivElement>(null);
  const titleId = useId();
  const restoreRef = useRef<Element | null>(null);

  useEffect(() => {
    if (!open) return;
    restoreRef.current = document.activeElement;
    const node = ref.current;
    const focusables = () =>
      Array.from(
        node?.querySelectorAll<HTMLElement>(
          'a[href],button:not([disabled]),textarea:not([disabled]),input:not([disabled]),select:not([disabled]),[tabindex]:not([tabindex="-1"])',
        ) ?? [],
      );
    const first = focusables().find((el) => el.dataset.autofocus !== undefined) ?? focusables()[1] ?? focusables()[0];
    first?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.stopPropagation();
        onClose();
      } else if (e.key === "Tab") {
        const els = focusables();
        if (els.length === 0) return;
        const firstEl = els[0]!;
        const lastEl = els[els.length - 1]!;
        if (e.shiftKey && document.activeElement === firstEl) {
          e.preventDefault();
          lastEl.focus();
        } else if (!e.shiftKey && document.activeElement === lastEl) {
          e.preventDefault();
          firstEl.focus();
        }
      }
    };
    document.addEventListener("keydown", onKey);
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = prevOverflow;
      (restoreRef.current as HTMLElement | null)?.focus?.();
    };
  }, [open, onClose]);

  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-ink/40" aria-hidden onClick={onClose} />
      <div
        ref={ref}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        className={cx(
          "relative flex max-h-[90vh] w-full flex-col rounded-[20px] bg-white shadow-xl",
          size === "lg" ? "max-w-3xl" : "max-w-lg",
        )}
      >
        <div className="flex items-start justify-between gap-3 border-b border-line px-5 py-4">
          <div>
            <h2 id={titleId} className="text-lg font-semibold">
              {title}
            </h2>
            {description && <div className="mt-0.5 text-sm text-ink-muted">{description}</div>}
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close dialog"
            className="rounded-full p-1.5 text-ink-muted hover:bg-mint-50"
          >
            <X className="size-5" aria-hidden />
          </button>
        </div>
        <div className="overflow-y-auto px-5 py-4">{children}</div>
        {footer && <div className="flex flex-wrap justify-end gap-2 border-t border-line px-5 py-3">{footer}</div>}
      </div>
    </div>
  );
}

/* ---------------- Table ---------------- */
export function Table({ caption, children, className }: { caption: string; children: ReactNode; className?: string }) {
  return (
    <div className={cx("-mx-5 overflow-x-auto", className)}>
      <table className="w-full min-w-[640px] border-collapse text-left text-sm">
        <caption className="sr-only">{caption}</caption>
        {children}
      </table>
    </div>
  );
}
export function Th({ children, className }: { children?: ReactNode; className?: string }) {
  return (
    <th scope="col" className={cx("border-b border-line bg-mint-50/60 px-5 py-2.5 text-xs font-semibold uppercase tracking-wide text-ink-muted", className)}>
      {children}
    </th>
  );
}
export function Td({ children, className, colSpan }: { children?: ReactNode; className?: string; colSpan?: number }) {
  return (
    <td colSpan={colSpan} className={cx("border-b border-line px-5 py-3 align-top", className)}>
      {children}
    </td>
  );
}

/* ---------------- Stat tile ---------------- */
export function StatTile({
  label,
  value,
  hint,
  tone = "neutral",
  icon,
  href,
}: {
  label: string;
  value: ReactNode;
  hint?: ReactNode;
  tone?: "neutral" | "alert" | "warn";
  icon?: ReactNode;
  href?: string;
}) {
  const inner = (
    <>
      <div className="flex items-center gap-2 text-[13px] font-medium text-ink-muted">
        {icon && (
          <span
            aria-hidden
            className={cx(
              "flex size-8 items-center justify-center rounded-xl",
              tone === "alert" ? "bg-rose-bg text-danger" : tone === "warn" ? "bg-peach-bg text-peach-fg" : "bg-teal-bg text-teal-fg",
            )}
          >
            {icon}
          </span>
        )}
        {label}
      </div>
      <div className="mt-2 text-[28px] font-semibold leading-8 tabular-nums text-ink">{value}</div>
      {hint && <div className="mt-1 text-xs text-ink-muted">{hint}</div>}
    </>
  );
  const cls = cx(
    "block rounded-[16px] border bg-white p-4 shadow-[var(--shadow-card)]",
    tone === "alert" ? "border-[#f6c9c9]" : tone === "warn" ? "border-[#f8d9b5]" : "border-line",
    href && "hover:border-primary-light",
  );
  if (href)
    return (
      <a href={href} className={cls}>
        {inner}
      </a>
    );
  return <div className={cls}>{inner}</div>;
}

export function Spinner({ label = "Loading" }: { label?: string }) {
  return (
    <span role="status" className="inline-flex items-center gap-2 text-ink-muted">
      <Loader2 className="size-4 animate-spin" aria-hidden />
      <span className="sr-only">{label}</span>
    </span>
  );
}

export function Toggle({
  checked,
  onChange,
  label,
  disabled,
  danger,
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  label: string;
  disabled?: boolean;
  danger?: boolean;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className={cx(
        "relative inline-flex h-7 w-12 shrink-0 items-center rounded-full transition-colors disabled:opacity-50",
        checked ? (danger ? "bg-danger" : "bg-primary") : "bg-[#c9d6d0]",
      )}
    >
      <span
        aria-hidden
        className={cx("inline-block size-5 rounded-full bg-white shadow transition-transform", checked ? "translate-x-6" : "translate-x-1")}
      />
    </button>
  );
}
