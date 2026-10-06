/**
 * Chart colour tokens. They reference the theme CSS variables in globals.css so charts (Recharts SVG and
 * inline SVG sparklines) follow whatever palette the app defines instead of hard-coded hexes.
 */
export const CHART = {
  series: "var(--color-primary)",
  grid: "var(--color-line)",
  ink: "var(--color-ink)",
  inkMuted: "var(--color-ink-muted)",
  surface: "var(--color-surface)",
  warning: "var(--color-peach-fg)",
  danger: "var(--color-danger)",
} as const;
