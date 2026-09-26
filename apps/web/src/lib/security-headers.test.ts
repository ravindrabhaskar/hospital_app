import { describe, expect, it } from "vitest";
import { buildCsp, buildSecurityHeaders } from "./security-headers";
import { parsePublicEnv } from "./env";
import nextConfig from "../../next.config";

const opts = { apiOrigin: "https://api.carecompanion.in", jitsiDomain: "meet.jit.si", production: true };
const byKey = (h: { key: string; value: string }[]) => Object.fromEntries(h.map((x) => [x.key, x.value]));

function directives(csp: string) {
  return Object.fromEntries(
    csp.split(";").map((d) => {
      const [name, ...values] = d.trim().split(/\s+/);
      return [name!, values];
    }),
  );
}

describe("security headers", () => {
  it("production CSP allows only self, the API origin and the Jitsi frame", () => {
    const d = directives(buildCsp(opts));
    expect(d["default-src"]).toEqual(["'self'"]);
    expect(d["connect-src"]).toEqual(["'self'", "https://api.carecompanion.in"]);
    expect(d["frame-src"]).toEqual(["'self'", "blob:", "https://meet.jit.si"]);
    expect(d["frame-ancestors"]).toEqual(["'none'"]);
    expect(d["script-src"]).not.toContain("'unsafe-eval'");
    expect(d["upgrade-insecure-requests"]).toEqual([]);
    expect(d["base-uri"]).toEqual(["'self'"]);
  });

  it("dev CSP allows eval and websockets for HMR but no HSTS", () => {
    const h = byKey(buildSecurityHeaders({ ...opts, production: false }));
    const d = directives(h["Content-Security-Policy"]!);
    expect(d["script-src"]).toContain("'unsafe-eval'");
    expect(d["connect-src"]).toContain("ws:");
    expect(h["Strict-Transport-Security"]).toBeUndefined();
  });

  it("does not upgrade requests when the API is plain http (local production build)", () => {
    expect(buildCsp({ ...opts, apiOrigin: "http://localhost:4000" })).not.toContain("upgrade-insecure-requests");
  });

  it("sets HSTS, frame, referrer, nosniff and permissions headers in production", () => {
    const h = byKey(buildSecurityHeaders(opts));
    expect(h["Strict-Transport-Security"]).toMatch(/max-age=31536000/);
    expect(h["X-Frame-Options"]).toBe("DENY");
    expect(h["X-Content-Type-Options"]).toBe("nosniff");
    expect(h["Referrer-Policy"]).toBe("strict-origin-when-cross-origin");
    expect(h["Permissions-Policy"]).toContain('camera=("https://meet.jit.si")');
    expect(h["Permissions-Policy"]).toContain("geolocation=()");
  });

  it("next.config applies the headers to every route and builds a standalone server without source maps", async () => {
    expect(nextConfig.output).toBe("standalone");
    expect(nextConfig.productionBrowserSourceMaps).toBe(false);
    expect(nextConfig.poweredByHeader).toBe(false);
    const routes = await nextConfig.headers!();
    expect(routes[0]!.source).toBe("/:path*");
    const keys = routes[0]!.headers.map((x) => x.key);
    expect(keys).toEqual(expect.arrayContaining(["Content-Security-Policy", "X-Frame-Options", "Referrer-Policy", "Permissions-Policy"]));
  });
});

describe("public env validation", () => {
  it("applies defaults", () => {
    const { env, errors } = parsePublicEnv({}, { production: false });
    expect(errors).toEqual([]);
    expect(env.apiBaseUrl).toBe("http://localhost:4000/api/v1");
    expect(env.apiOrigin).toBe("http://localhost:4000");
    expect(env.legalDraft).toBe(true);
    expect(env.jitsiDomain).toBe("meet.jit.si");
  });
  it("parses values and strips the trailing slash", () => {
    const { env, errors } = parsePublicEnv(
      { NEXT_PUBLIC_API_BASE_URL: "https://api.cc.in/api/v1/", NEXT_PUBLIC_LEGAL_DRAFT: "false", NEXT_PUBLIC_JITSI_DOMAIN: "meet.cc.in" },
      { production: true },
    );
    expect(errors).toEqual([]);
    expect(env.apiBaseUrl).toBe("https://api.cc.in/api/v1");
    expect(env.apiOrigin).toBe("https://api.cc.in");
    expect(env.legalDraft).toBe(false);
  });
  it("reports malformed values and plain-http APIs in production", () => {
    expect(parsePublicEnv({ NEXT_PUBLIC_API_BASE_URL: "not-a-url" }, { production: false }).errors[0]).toMatch(/NEXT_PUBLIC_API_BASE_URL/);
    expect(parsePublicEnv({ NEXT_PUBLIC_LEGAL_DRAFT: "maybe" }, { production: false }).errors[0]).toMatch(/NEXT_PUBLIC_LEGAL_DRAFT/);
    expect(parsePublicEnv({ NEXT_PUBLIC_JITSI_DOMAIN: "https://x/y" }, { production: false }).errors).toHaveLength(1);
    expect(parsePublicEnv({ NEXT_PUBLIC_API_BASE_URL: "http://api.cc.in/api/v1" }, { production: true }).errors[0]).toMatch(/https/);
    expect(parsePublicEnv({ NEXT_PUBLIC_API_BASE_URL: "http://localhost:4000/api/v1" }, { production: true }).errors).toEqual([]);
  });
});
