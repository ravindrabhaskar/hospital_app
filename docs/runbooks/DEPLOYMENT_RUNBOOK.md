# Deployment Runbook

Companion to `docs/product/13_DEPLOYMENT.md`. Infrastructure is code in `infra/terraform` (AWS `ap-south-1`); pipelines are `.github/workflows/deploy.yml` (API, worker, web) and `mobile-release.yml` (apps). Store submission: `docs/STORE_SUBMISSION.md`.

Resource names follow `carecompanion-<env>` (`<env>` = `staging` | `production`): cluster `carecompanion-<env>`, services `…-api`, `…-worker`, `…-web`, `…-clamav`, task family `…-ops-psql`, ECR repos `…-api` / `…-web`, secrets `carecompanion/<env>/api/<NAME>`.

## 1. Local development

```bash
# API (PGlite, offline AI, mock payments, dev OTP 123456)
cd services/api
npm ci
npm run db:migrate   # optional: the server also applies migrations at startup
npm run seed         # synthetic personas (see API_CONTRACT.md §20)
npm run dev          # http://localhost:4000/api/v1

# Web portal
cd apps/web && npm ci && npm run dev

# Mobile
cd apps/patient_app && flutter pub get && flutter run    # Android emulator uses http://10.0.2.2:4000/api/v1
cd apps/provider_app && flutter pub get && flutter run
```

Production-like local stack (needs Docker): `docker compose up -d --build` then `docker compose --profile seed run --rm seed` (postgres 16, MinIO, ClamAV, Redis, API, web; see the comments in `docker-compose.yml`).

Quality checks per package: `npm run typecheck && npm run lint && npm test && npm run build`; Flutter: `flutter analyze && flutter test`. Load: `node tests/load/smoke.mjs <apiBase>` or `k6 run tests/load/k6-journey.js` (staging/local only).

## 2. How the pieces fit

| Concern | Mechanism |
|---|---|
| Migrations | The API applies Drizzle migrations **at startup** (`buildApp()` → `runMigrations`). Drizzle takes no lock, so `deploy.yml` first runs a one-off task `node dist/db/migrate.js` with the new image; tasks that boot afterwards find nothing to apply. |
| Background jobs | Separate `worker` service (same image, `WORKER_ENABLED=true`, 1 task). API tasks run `WORKER_ENABLED=false`. A PostgreSQL advisory lock (`WORKER_LOCK_KEY`) guarantees a single job leader even during deploy overlap. |
| Images | Terraform owns the task-definition *shape* (CPU, memory, env, secrets, roles). The pipeline owns the *image*: it copies the latest ACTIVE revision, swaps the image, registers it and updates the service. After a `terraform apply` that changes a task definition, run the deploy workflow to roll it out. |
| Web config | `NEXT_PUBLIC_*` values and the CSP header (API origin) are baked in at **build** time, so each environment gets its own web image (`<sha>-<env>-<cfghash>`). Change a GitHub environment variable → redeploy. |
| Secrets | Secrets Manager entries are created **empty** by Terraform; values are put out-of-band. Tasks read them at start, so a value change needs a new deployment (`--force-new-deployment`). |
| Health | ALB/container liveness: `GET /api/v1/health`. `GET /api/v1/ready` also checks DB and safety rules; it is **503 in production until a clinician-approved rule pack is active** (fail-safe), so it is not used as the load balancer check. |

## 3. First deployment of an environment (one-time)

Do staging first, end to end, then repeat for production. Commands assume a shell with AWS CLI v2, Terraform ≥ 1.10, `jq`, `openssl`, and an admin AWS profile (`export AWS_PROFILE=cc-admin AWS_REGION=ap-south-1`).

### 3.0 Prerequisites the founder provides
1. AWS account (ideally AWS Organizations with separate `staging` and `production` accounts), MFA on root, an admin IAM Identity Center user.
2. A domain, and DNS hosting (Route 53 recommended).
3. ACM certificate **in ap-south-1** covering `api.<domain>` and the portal host (e.g. `portal.<domain>`), DNS-validated, status ISSUED.
4. GitHub repository admin access.
5. Vendor credentials for production boot (the API refuses to start in production without them): MSG91 auth key + DLT-approved template IDs, Razorpay key id/secret/webhook secret, Anthropic API key. (For a staging dry run you may use test keys.)

### 3.1 Bootstrap the Terraform state bucket (once per AWS account)
```bash
cd infra/terraform/bootstrap
terraform init
terraform apply -var="state_bucket_name=carecompanion-tfstate-$(aws sts get-caller-identity --query Account --output text)"
```
Then in `infra/terraform/backend.tf` uncomment `backend "s3" {}` and create `infra/terraform/backend/<env>.s3.tfbackend` (git-ignored) as described in that file.

### 3.2 Apply the infrastructure in bootstrap mode
```bash
cd infra/terraform
cp terraform.tfvars.example staging.tfvars      # fill it in; keep bootstrap_mode = true
terraform init -backend-config=backend/staging.s3.tfbackend
terraform plan  -var-file=staging.tfvars -out=tf.plan
terraform apply tf.plan                          # ~20-30 min (RDS, NAT, ElastiCache)
terraform output                                 # note api_url, portal_url, github_deploy_role_arn, rds_endpoint ...
```
`bootstrap_mode = true` creates everything with 0 running tasks because ECR is still empty. For the second environment in the same AWS account set `create_github_oidc_provider = false`.

DNS: if `create_route53_records = false`, create CNAMEs for `api_domain` and each portal domain pointing to `terraform output -raw alb_dns_name`.

Confirm the SNS subscription emails for alarms.

### 3.3 Put the secret values (out-of-band, never in git)
```bash
ENV=staging
put() { aws secretsmanager put-secret-value --secret-id "carecompanion/$ENV/api/$1" --secret-string "$2" >/dev/null && echo "set $1"; }

# App DB role password: hex only, so the URL needs no escaping.
APP_DB_PW=$(openssl rand -hex 24)
RDS=$(terraform output -raw rds_endpoint)
put DATABASE_URL "postgres://cc_app:${APP_DB_PW}@${RDS}:5432/carecompanion?sslmode=verify-full"
unset APP_DB_PW

put JWT_SECRET             "$(openssl rand -base64 48)"
put PAYMENT_WEBHOOK_SECRET "$(openssl rand -hex 32)"
put MFA_ENCRYPTION_KEY     "$(openssl rand -hex 32)"   # 32 bytes as 64 hex chars
put VIDEO_ROOM_SECRET      "$(openssl rand -hex 32)"
put METRICS_TOKEN          "$(openssl rand -hex 24)"
# vendor values: paste from the vendor dashboards (read -s keeps them out of shell history)
read -rs V && put RAZORPAY_KEY_SECRET "$V"
read -rs V && put RAZORPAY_WEBHOOK_SECRET "$V"
read -rs V && put MSG91_AUTH_KEY "$V"
read -rs V && put ANTHROPIC_API_KEY "$V"
terraform output api_secret_names   # every listed secret must now have a value
```
Non-secret settings (Razorpay key id, MSG91 template ids, support contacts, FCM project/client email, AI model) go in `api_extra_environment` in the tfvars. Optional secrets (e.g. `FCM_PRIVATE_KEY`, `JITSI_APP_SECRET`) must be added to `api_secret_names` **and** given a value before the next deploy.

### 3.4 Create the application database role (one-off psql task)
The RDS master user (password managed by RDS in Secrets Manager) is used only for administration. The app connects as `cc_app`, which owns the schema so that migrations can run. The password is read from the `DATABASE_URL` secret inside the task (`APP_DATABASE_URL`), so it never appears in the command or in CloudTrail.

```bash
CLUSTER=carecompanion-$ENV
NET="awsvpcConfiguration={subnets=[$(terraform output -json private_subnet_ids | jq -r 'join(",")')],securityGroups=[$(terraform output -raw ops_security_group_id)],assignPublicIp=DISABLED}"

psql_task() { # $1 = shell script run inside postgres:16-alpine
  jq -n --arg s "$1" '{containerOverrides:[{name:"psql",command:["sh","-c",$s]}]}' > /tmp/ovr.json
  TASK=$(aws ecs run-task --cluster "$CLUSTER" --launch-type FARGATE --task-definition "$CLUSTER-ops-psql" \
    --network-configuration "$NET" --overrides file:///tmp/ovr.json --query 'tasks[0].taskArn' --output text)
  aws ecs wait tasks-stopped --cluster "$CLUSTER" --tasks "$TASK"
  aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK" --query 'tasks[0].containers[0].exitCode'
  aws logs tail "/ecs/$CLUSTER-ops-psql" --since 10m
}

psql_task '
P=$(printf %s "$APP_DATABASE_URL" | sed -E "s#^[a-z]+://[^:]+:([^@]+)@.*#\1#")
psql -v ON_ERROR_STOP=1 -v pw="$P" <<"SQL"
SELECT format($$CREATE ROLE cc_app LOGIN PASSWORD %L$$, :'"'"'pw'"'"')
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = $$cc_app$$) \gexec
ALTER ROLE cc_app PASSWORD :'"'"'pw'"'"';
GRANT cc_app TO CURRENT_USER;
ALTER DATABASE carecompanion OWNER TO cc_app;
ALTER SCHEMA public OWNER TO cc_app;
SQL'
```
Expected exit code `0`. The heredoc is quoted (`<<"SQL"`) so `sh` does not expand `$$`; the password reaches SQL only as the psql variable `:'pw'`. (Separate `audit_append` / `readonly` roles from `13_DEPLOYMENT.md` are a later hardening step.)

### 3.5 Configure GitHub
Settings → Environments → create `staging` and `production`:
- `production`: **Required reviewers** = tech lead + ops/product lead; deployment branches/tags = tags `v*` only; enable "Prevent self-review".
- `staging`: branches `main` + tags `v*`.
- Environment **variables** (from `terraform output`): `AWS_DEPLOY_ROLE_ARN`, `AWS_REGION=ap-south-1`, `API_BASE_URL` (= `api_url`), `PORTAL_URL` (= `portal_url`), and the web build values `NEXT_PUBLIC_LEGAL_DRAFT` (keep `true` until counsel approves), `NEXT_PUBLIC_SUPPORT_EMAIL`, `NEXT_PUBLIC_SUPPORT_PHONE`, `NEXT_PUBLIC_LEGAL_ENTITY_NAME`, `NEXT_PUBLIC_GRIEVANCE_OFFICER_NAME`, `NEXT_PUBLIC_GRIEVANCE_OFFICER_EMAIL`, `NEXT_PUBLIC_JITSI_DOMAIN`.
- No AWS keys are stored: the workflow uses OIDC and the role only trusts `repo:<owner>/<repo>:environment:<env>`.

### 3.6 Push the first images (migrations run, no seed)
Actions → **Deploy** → Run workflow → environment `staging`, `run_migrations` ✔, `smoke` ✘ (there are no tasks yet). This builds and pushes the images, registers task definitions, and runs `node dist/db/migrate.js` as `cc_app`, which creates the schema. **Never run the seed against staging/production** (`dist/db/seed.js` refuses when `NODE_ENV=production`).

### 3.7 Leave bootstrap mode
Set `bootstrap_mode = false` in `staging.tfvars`, then `terraform apply -var-file=staging.tfvars`. Autoscaling raises the API to 2 tasks and web/worker/clamav to 1. Then run **Deploy** again (smoke ✔) so the services run the newest task definition. Check:
```bash
curl -s https://api.<domain>/api/v1/health     # {"status":"ok",...}
curl -s https://api.<domain>/api/v1/ready      # db ok; safetyRules "unavailable" until an approved pack is active
```
If a task does not start, check `aws ecs describe-services ... --query 'services[0].events[:5]'` and the log group: the API prints every missing production setting at boot.

### 3.8 Create the first super_admin
The API image ships an idempotent admin-bootstrap CLI (`services/api/src/scripts/create-admin.ts`). It creates the user or adds the roles to an existing user, and writes an audit row with actor `system:cli`. Run it once as a one-off task from the **api** task definition, so it gets the same secrets and `DATABASE_URL` as the service:

1. Create the founder's admin account (replace the phone and name):
   ```bash
   jq -n '{containerOverrides:[{name:"api",command:["node","dist/scripts/create-admin.js","--phone","+919XXXXXXXXX","--name","Founder Name","--roles","super_admin"]}]}' > /tmp/admin.json
   TASK=$(aws ecs run-task --cluster "$CLUSTER" --launch-type FARGATE --task-definition "$CLUSTER-api" \
     --network-configuration "$NET" --overrides file:///tmp/admin.json --query 'tasks[0].taskArn' --output text)
   aws ecs wait tasks-stopped --cluster "$CLUSTER" --tasks "$TASK"
   aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK" --query 'tasks[0].containers[0].exitCode'   # expect 0
   ```
   (Locally or against any database: `cd services/api && npm run create-admin -- --phone +919XXXXXXXXX --name "Founder Name"`.)
2. Sign in on the portal with that phone (real SMS OTP). Staff MFA is enforced in production: enrol TOTP at `/mfa` and store the recovery codes offline.
3. From the admin UI, create the other staff (doctors, coordinators, ops) and verify providers. Use the CLI only for break-glass recovery, for example when the last super_admin loses MFA.

### 3.9 Before real users
Activate a clinician-approved safety rule pack (`services/api/README.md` → "Adding a real clinical rule pack"), until `/ready` reports `safetyRules: ok`; review feature flags; run the load smoke against staging (`node tests/load/smoke.mjs https://api.staging.<domain>/api/v1` with a test phone and `OTP`); run the backup/restore drill (§8). Then repeat §3.1 to §3.8 for production (`production.tfvars`, `db_multi_az = true`, `single_nat_gateway = false`).

## 4. Pre-deployment checklist (every production release)

- [ ] CI green on the release commit (api, web, flutter, docker, compose, terraform).
- [ ] `CHANGELOG.md` updated; release notes list user-visible changes and known issues.
- [ ] Migrations reviewed: expand/contract compliant; rollback note present; rehearsed on staging.
- [ ] AI evaluation suite re-run if prompts, policy, model config or rule pack changed (`docs/AI_EVALUATION.md`).
- [ ] Rule pack: prod active pack is `approved` (never a fixture); any pack change has clinical sign-off.
- [ ] Feature flags for the release reviewed (pilot cohort; P1 flags per `14_DECISIONS.md` Q-07).
- [ ] Staging deploy + smoke passed for the same tag.
- [ ] On-call engineer and ops lead aware; change window agreed (avoid peak visit hours 08:00–11:00 IST).

## 5. Routine deploy

1. Tag the release on `main`: `git tag v1.2.3 && git push origin v1.2.3`.
2. **Deploy** runs staging automatically: build → push to ECR (scan on push) → register task definitions → migration task → update api/worker/web → `aws ecs wait services-stable` → verify no circuit-breaker rollback → smoke (`/health`, `/ready` db check, `/config/public`, portal `/login`).
3. The production job waits for approval in the `production` environment. Approve after checking staging.
4. Production runs the same steps. The job summary lists the **previous task definition ARNs** (needed for rollback).
5. Watch for 30 min: CloudWatch alarms (5xx rate, p95 latency, unhealthy hosts, CPU, RDS storage), AI fallback rate, safety events, webhook errors, worker lag.
6. Announce in the ops channel with the version.

Infra changes: `terraform plan` in a PR (paste the plan), apply after review, then run **Deploy** (manual, same environment) to roll out task-definition changes. Secret value change: put the new value, then `aws ecs update-service --cluster carecompanion-<env> --service carecompanion-<env>-api --force-new-deployment` (same for `-worker`).

## 6. Smoke tests (staging and prod)

| Check | How |
|---|---|
| Liveness/readiness | `GET /api/v1/health` = 200; `GET /api/v1/ready` → `checks.db = ok` (prod: `safetyRules: ok` once approved) |
| Auth | OTP login with the designated staff test number (real SMS; there is no `devOtp` in prod) |
| Read paths | `/me`, `/patients`, `/doctors`, `/home-visit/services`, `/config/public` |
| Booking (staging only) | Book → Razorpay test-mode payment → confirm → cancel → refund |
| Upload | Upload a PDF record → stored in S3 (SSE-KMS), scanned by ClamAV; the EICAR test file is rejected with `FILE_REJECTED` (staging) |
| AI | Neutral test message in staging; an `AIInteraction` row with versions |
| Web | Clinician login + MFA, queue loads; ops overview loads; admin shows the rule-pack version; `/account/delete` loads |

## 7. Rollback

| Situation | Action |
|---|---|
| App regression, schema unchanged or expand-only | Redeploy the previous task definitions (ARNs in the deploy job summary, or `aws ecs list-task-definitions --family-prefix carecompanion-<env>-api --sort DESC`): `aws ecs update-service --cluster carecompanion-<env> --service carecompanion-<env>-api --task-definition <prev-arn>`; repeat for `-worker` and `-web`; `aws ecs wait services-stable ...`. About 5 min. Alternatively re-run **Deploy** for the previous tag (images are immutable and reused). |
| Deployment fails health checks | Nothing to do: the ECS deployment circuit breaker rolls back automatically and the workflow fails at "Verify the new revisions". |
| Migration task fails | The workflow stops **before** updating services; the old version keeps running. Fix forward. |
| Bad migration (contract step) | Contract steps ship one release after the code stops using the old structure. Restore with the prepared reverse migration from the rollback note, via a one-off task. **Never** hand-edit the prod schema. |
| Data corruption | Stop writes (scale API and worker to 0 via `aws ecs update-service --desired-count 0` after setting the autoscaling min to 0, plus status page), PITR restore to a new instance at T-1 min (`aws rds restore-db-instance-to-point-in-time`), verify, update the `DATABASE_URL` secret to the new endpoint, force a new deployment, reconcile payments with the gateway. SEV-1. |
| Bad infra change | `terraform apply` the previous commit's configuration. RDS has deletion protection and a final snapshot; the records bucket is versioned. |
| Mobile release defect | Halt the staged rollout in Play Console / App Store phased release; hotfix; raise `MIN_APP_VERSION_*` if the API changes. |
| AI/safety defect | Flip `kill_switch_ai` first (seconds), then roll back. |

## 8. Secrets rotation

| Secret | Procedure |
|---|---|
| RDS master password | Managed by RDS in Secrets Manager (auto-rotation). Only the ops psql task uses it. |
| App DB password (`cc_app`) | Generate a new hex password → `ALTER ROLE cc_app PASSWORD ...` via the psql task (same pattern as §3.4, after updating the secret) → force new deployments of api and worker. Brief connection errors are possible; do it in a quiet window. |
| `JWT_SECRET` | Update the secret → force new deployment. All sessions must re-login (no dual-key support yet). |
| `PAYMENT_WEBHOOK_SECRET` / `RAZORPAY_WEBHOOK_SECRET` | Generate in the gateway → update the secret → deploy → switch in the gateway. |
| `ANTHROPIC_API_KEY`, `MSG91_AUTH_KEY` | Create the new key → update the secret → force new deployment → revoke the old key. |
| `MFA_ENCRYPTION_KEY` | Do **not** rotate without a re-encryption migration (it encrypts stored TOTP secrets). |

Record every rotation (date, actor, reason).

## 9. Backup and restore drill (quarterly; before the pilot)

1. Restore the latest automated snapshot and a PITR target (T-15 min) to `cc-drill-<date>` in the database subnets (backups are kept 14 days).
2. Run migration status and row-count sanity checks; verify the audit hash chain; spot-check S3 retrieval for 10 records.
3. Measure the achieved RTO/RPO against the targets (RTO ≤ 4h, RPO ≤ 15 min).
4. Delete the drill resources; file the report (date, durations, issues) as evidence for the Reliability launch gate.

## 10. Mobile release

1. Bump `version`/build number in `pubspec.yaml`; update store release notes (en/hi/te).
2. Push a tag `mobile-v1.2.3` (or run **Mobile release** manually): signed AABs are built with `--dart-define=API_BASE_URL=$MOBILE_API_BASE_URL`, verified not debug-signed, uploaded as artifacts, and (if `PLAY_SERVICE_ACCOUNT_JSON` is set) sent to the Play **internal** track. iOS is disabled until `IOS_RELEASE_ENABLED=true`.
3. Internal QA checklist (login, Ask AI, booking, visit tracking, records, offline sync for the provider app), then promote internal → closed (pilot cohort) in Play Console / TestFlight.
4. Public launch: staged rollout 10% → 50% → 100% with crash-free sessions ≥ 99.5%. See `docs/STORE_SUBMISSION.md`.
