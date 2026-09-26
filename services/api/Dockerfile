# syntax=docker/dockerfile:1.7
#
# CareCompanion API image (services/api)
# ---------------------------------------------------------------------------
# Build (context = services/api):
#   docker build -t carecompanion-api:local services/api
#
# Runtime behaviour
#   * Entrypoint: `node dist/server.js` as the unprivileged `node` user (uid 1000).
#   * DATABASE MIGRATIONS ARE APPLIED AT STARTUP: buildApp() in src/app.ts calls
#     runMigrations() (drizzle migrator, files in /app/drizzle) before listening.
#     No separate entrypoint is needed. Because drizzle takes no advisory lock,
#     the deploy pipeline ALSO runs a one-off task first:
#         node dist/db/migrate.js
#     so that several API tasks booting at the same time find nothing to apply.
#   * One-off commands available in this image (no dev dependencies needed):
#         node dist/db/migrate.js          apply migrations and exit
#         node dist/db/seed.js [--reset]   synthetic demo seed (refused when NODE_ENV=production)
#   * Health: GET /api/v1/health (liveness). /api/v1/ready also checks the DB.
#   * Amazon RDS CA bundle is installed and trusted via NODE_EXTRA_CA_CERTS, so a
#     DATABASE_URL with `?sslmode=verify-full` works against RDS.
# ---------------------------------------------------------------------------

ARG NODE_IMAGE=node:24-alpine

# ---- 1. all dependencies (for the TypeScript build) -------------------------
FROM ${NODE_IMAGE} AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --no-audit --no-fund

# ---- 2. compile ---------------------------------------------------------------
FROM deps AS build
COPY tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN npm run build

# ---- 3. production dependencies only ------------------------------------------
FROM ${NODE_IMAGE} AS prod-deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev --no-audit --no-fund \
 && npm cache clean --force

# ---- 4. runtime -----------------------------------------------------------------
FROM ${NODE_IMAGE} AS runtime
ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=4000 \
    NODE_EXTRA_CA_CERTS=/etc/ssl/certs/rds-global-bundle.pem \
    NODE_OPTIONS=--enable-source-maps
WORKDIR /app

# tini = correct signal forwarding (graceful SIGTERM shutdown on ECS/compose)
RUN apk add --no-cache tini
ADD --chmod=644 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /etc/ssl/certs/rds-global-bundle.pem

COPY --chown=node:node package.json ./
COPY --chown=node:node --from=prod-deps /app/node_modules ./node_modules
COPY --chown=node:node --from=build /app/dist ./dist
COPY --chown=node:node drizzle ./drizzle

# Writable dirs only matter for STORAGE_DRIVER=local or PGlite (dev); prod uses S3 + RDS.
RUN mkdir -p /app/.data && chown node:node /app/.data

USER node
EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||4000)+'/api/v1/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "dist/server.js"]
