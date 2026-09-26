/**
 * HTTP security headers for every route (applied in next.config.ts `headers()`).
 *
 * Notes on the CSP:
 * - Pages are statically rendered, so a per-request nonce is not available; Next.js needs
 *   `'unsafe-inline'` for its inline bootstrap scripts and next/font styles. Everything else is
 *   restricted to `'self'`, the API origin and (for the optional embedded call) the Jitsi domain.
 * - Fonts are self-hosted by next/font at build time, so no Google Fonts origin is needed.
 * - `blob:` is allowed for images/objects/frames because record files are opened from object URLs.
 */
export interface SecurityHeaderOptions {
  /** e.g. https://api.example.in */
  apiOrigin: string;
  /** e.g. meet.jit.si */
  jitsiDomain: string;
  production: boolean;
}

export interface Header {
  key: string;
  value: string;
}

export function buildCsp({ apiOrigin, jitsiDomain, production }: SecurityHeaderOptions): string {
  const jitsi = `https://${jitsiDomain}`;
  const directives: Record<string, string[]> = {
    "default-src": ["'self'"],
    "script-src": ["'self'", "'unsafe-inline'", ...(production ? [] : ["'unsafe-eval'"])],
    "style-src": ["'self'", "'unsafe-inline'"],
    "img-src": ["'self'", "data:", "blob:", apiOrigin],
    "font-src": ["'self'", "data:"],
    "connect-src": ["'self'", apiOrigin, ...(production ? [] : ["ws:", "wss:"])],
    "media-src": ["'self'", "blob:"],
    "frame-src": ["'self'", "blob:", jitsi],
    "worker-src": ["'self'", "blob:"],
    "object-src": ["'self'", "blob:"],
    "base-uri": ["'self'"],
    "form-action": ["'self'"],
    "frame-ancestors": ["'none'"],
    "manifest-src": ["'self'"],
  };
  const parts = Object.entries(directives).map(([k, v]) => `${k} ${Array.from(new Set(v)).join(" ")}`);
  // Only when the API itself is https, otherwise a local http API would be "upgraded" and break.
  if (production && apiOrigin.startsWith("https://")) parts.push("upgrade-insecure-requests");
  return parts.join("; ");
}

export function buildSecurityHeaders(opts: SecurityHeaderOptions): Header[] {
  const jitsi = `"https://${opts.jitsiDomain}"`;
  const headers: Header[] = [
    { key: "Content-Security-Policy", value: buildCsp(opts) },
    // The portal itself is never framed (frame-ancestors 'none' + legacy header).
    { key: "X-Frame-Options", value: "DENY" },
    { key: "X-Content-Type-Options", value: "nosniff" },
    { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
    {
      key: "Permissions-Policy",
      // Camera/mic/screen share are delegated only to the Jitsi frame for the optional embedded call.
      value: [
        `camera=(${jitsi})`,
        `microphone=(${jitsi})`,
        `display-capture=(${jitsi})`,
        `fullscreen=(self ${jitsi})`,
        "geolocation=()",
        "payment=()",
        "usb=()",
        "serial=()",
        "bluetooth=()",
      ].join(", "),
    },
    { key: "Cross-Origin-Opener-Policy", value: "same-origin" },
    { key: "X-DNS-Prefetch-Control", value: "off" },
  ];
  if (opts.production) {
    headers.push({ key: "Strict-Transport-Security", value: "max-age=31536000; includeSubDomains" });
  }
  return headers;
}
