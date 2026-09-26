# syntax=docker/dockerfile:1.7
#
# CareCompanion web portal image (apps/web, Next.js 15 standalone output)
# ---------------------------------------------------------------------------
# Build (context = apps/web):
#   docker build \
#     --build-arg NEXT_PUBLIC_API_BASE_URL=https://api.example.in/api/v1 \
#     -t carecompanion-web:local apps/web
#
# IMPORTANT: NEXT_PUBLIC_* variables are inlined into the browser bundle by
# `next build`, and the CSP security headers (which allow only the API origin)
# are computed in next.config.ts at build time. NEXT_PUBLIC_API_BASE_URL,
# NEXT_PUBLIC_LEGAL_DRAFT, NEXT_PUBLIC_JITSI_DOMAIN, ... are therefore BAKED IN
# AT BUILD TIME; setting them at `docker run` time has no effect. Build one
# image per environment (the deploy workflow tags them <sha>-staging /
# <sha>-production). HOSTNAME=0.0.0.0 below is required, otherwise the
# standalone server binds to localhost only and health checks fail.
#
# Requires `output: "standalone"` in next.config.ts (produces .next/standalone).
# Runs `node server.js` as the unprivileged `node` user on port 3000.
# ---------------------------------------------------------------------------

ARG NODE_IMAGE=node:24-alpine

# ---- 1. dependencies ------------------------------------------------------------
FROM ${NODE_IMAGE} AS deps
WORKDIR /app
RUN apk add --no-cache libc6-compat
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --no-audit --no-fund

# ---- 2. build ------------------------------------------------------------------
FROM ${NODE_IMAGE} AS build
WORKDIR /app
# Every NEXT_PUBLIC_* value (validated by src/lib/env.ts; a bad value fails the
# build) and the Content-Security-Policy headers built from the API origin in
# next.config.ts are fixed at build time. Blank = the app's default.
ARG NEXT_PUBLIC_API_BASE_URL=http://localhost:4000/api/v1
ARG NEXT_PUBLIC_LEGAL_DRAFT=true
ARG NEXT_PUBLIC_JITSI_DOMAIN=meet.jit.si
ARG NEXT_PUBLIC_SUPPORT_EMAIL=
ARG NEXT_PUBLIC_SUPPORT_PHONE=
ARG NEXT_PUBLIC_LEGAL_ENTITY_NAME=
ARG NEXT_PUBLIC_GRIEVANCE_OFFICER_NAME=
ARG NEXT_PUBLIC_GRIEVANCE_OFFICER_EMAIL=
ENV NEXT_PUBLIC_API_BASE_URL=${NEXT_PUBLIC_API_BASE_URL} \
    NEXT_PUBLIC_LEGAL_DRAFT=${NEXT_PUBLIC_LEGAL_DRAFT} \
    NEXT_PUBLIC_JITSI_DOMAIN=${NEXT_PUBLIC_JITSI_DOMAIN} \
    NEXT_PUBLIC_SUPPORT_EMAIL=${NEXT_PUBLIC_SUPPORT_EMAIL} \
    NEXT_PUBLIC_SUPPORT_PHONE=${NEXT_PUBLIC_SUPPORT_PHONE} \
    NEXT_PUBLIC_LEGAL_ENTITY_NAME=${NEXT_PUBLIC_LEGAL_ENTITY_NAME} \
    NEXT_PUBLIC_GRIEVANCE_OFFICER_NAME=${NEXT_PUBLIC_GRIEVANCE_OFFICER_NAME} \
    NEXT_PUBLIC_GRIEVANCE_OFFICER_EMAIL=${NEXT_PUBLIC_GRIEVANCE_OFFICER_EMAIL} \
    NEXT_TELEMETRY_DISABLED=1 \
    NODE_ENV=production
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# `public/` is optional in this app; make sure the COPY below never fails.
RUN mkdir -p public && npm run build \
 && test -f .next/standalone/server.js || (echo 'ERROR: .next/standalone/server.js missing - set output: "standalone" in next.config.ts' && exit 1)

# ---- 3. runtime -----------------------------------------------------------------
FROM ${NODE_IMAGE} AS runtime
WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0
RUN apk add --no-cache tini

COPY --chown=node:node --from=build /app/.next/standalone ./
COPY --chown=node:node --from=build /app/.next/static ./.next/static
COPY --chown=node:node --from=build /app/public ./public

USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/login').then(r=>process.exit(r.status<500?0:1)).catch(()=>process.exit(1))"

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]
