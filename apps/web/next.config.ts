import path from "node:path";
import type { NextConfig } from "next";
import { assertValidPublicEnv } from "./src/lib/env";
import { buildSecurityHeaders } from "./src/lib/security-headers";

const production = process.env.NODE_ENV === "production";
// Fails the build (and dev server start) when a NEXT_PUBLIC_* variable is malformed.
const env = assertValidPublicEnv(production);

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  // Self-contained server for the container image: .next/standalone/server.js (see README).
  output: "standalone",
  // Keep the standalone tree flat (server.js at the root) even though this app lives in a monorepo.
  outputFileTracingRoot: path.join(__dirname),
  // Never ship browser source maps in production.
  productionBrowserSourceMaps: false,
  async headers() {
    return [
      {
        source: "/:path*",
        headers: buildSecurityHeaders({ apiOrigin: env.apiOrigin, jitsiDomain: env.jitsiDomain, production }),
      },
    ];
  },
};

export default nextConfig;
