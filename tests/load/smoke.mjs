#!/usr/bin/env node
// CareCompanion load smoke test WITHOUT k6 (Node 22+).
//
//   node tests/load/smoke.mjs [baseUrl]
//     baseUrl default: $API_BASE_URL or http://localhost:4000/api/v1
//
//   Optional, for higher fidelity (HTTP pipelining, accurate percentiles):
//     npm --prefix tests/load install      # installs autocannon locally
//   Without it, a built-in closed-loop fetch runner is used (same checks).
//
// Env: PHONE (default +919800000001), OTP (if no devOtp), DURATION (s, default 20),
//      CONNECTIONS (default 10), AI_SAMPLES (default 5, 0 = skip AI), PROFILE_JSON=1 (machine output)
//
// Flow: login once -> GET /doctors -> GET /doctors/:id/slots -> POST AI message (sampled) -> GET /reminders/today
// Pass criteria (docs/product/13_DEPLOYMENT.md §4): non-AI p95 < 500 ms and < 1 % errors;
// AI p95 < 10 s. Exit code 1 on failure, so it can gate a pipeline.
// Autocannon reports p97.5 (not p95); since p97.5 >= p95 it is used as a
// conservative stand-in. Same cautions as k6-journey.js: staging/local only,
// raise RATE_LIMIT_MAX on the target, one login per run.

import { createRequire } from 'node:module';
import { performance } from 'node:perf_hooks';

const BASE = (process.argv[2] ?? process.env.API_BASE_URL ?? 'http://localhost:4000/api/v1').replace(/\/$/, '');
const PHONE = process.env.PHONE ?? '+919800000001';
const DURATION = Number(process.env.DURATION ?? 20);
const CONNECTIONS = Number(process.env.CONNECTIONS ?? 10);
const AI_SAMPLES = Number(process.env.AI_SAMPLES ?? 5);
const P95_BUDGET_MS = 500;
const AI_P95_BUDGET_MS = 10_000;
const MAX_ERROR_RATE = 0.01;

async function loadAutocannon() {
  try {
    const require = createRequire(new URL('./package.json', import.meta.url));
    return require('autocannon');
  } catch {
    return null;
  }
}

async function call(method, path, { token, body } = {}) {
  const headers = {};
  if (token) headers.authorization = `Bearer ${token}`;
  if (body !== undefined) headers['content-type'] = 'application/json';
  const t0 = performance.now();
  const res = await fetch(BASE + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await res.text();
  const ms = performance.now() - t0;
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    /* not json */
  }
  return { status: res.status, json, ms };
}

function pct(sorted, p) {
  if (!sorted.length) return NaN;
  const i = Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1);
  return sorted[Math.max(0, i)];
}

function istDate(offsetDays) {
  return new Date(Date.now() + 5.5 * 3600e3 + offsetDays * 86400e3).toISOString().slice(0, 10);
}

/** Built-in closed-loop runner: CONNECTIONS workers hammer one GET for DURATION seconds. */
async function fetchRun(path, token) {
  const lat = [];
  let errors = 0;
  let requests = 0;
  const end = Date.now() + DURATION * 1000;
  const worker = async () => {
    while (Date.now() < end) {
      requests++;
      try {
        const r = await call('GET', path, { token });
        lat.push(r.ms);
        if (r.status >= 400) errors++;
      } catch {
        errors++;
      }
    }
  };
  await Promise.all(Array.from({ length: CONNECTIONS }, worker));
  lat.sort((a, b) => a - b);
  return { engine: 'fetch', requests, errors, rps: requests / DURATION, p50: pct(lat, 50), p95: pct(lat, 95), p99: pct(lat, 99) };
}

async function autocannonRun(autocannon, path, token) {
  const result = await autocannon({
    url: BASE + path,
    connections: CONNECTIONS,
    duration: DURATION,
    headers: { authorization: `Bearer ${token}` },
  });
  const errors = result.errors + result.timeouts + result.non2xx;
  return {
    engine: 'autocannon',
    requests: result.requests.total,
    errors,
    rps: result.requests.average,
    p50: result.latency.p50,
    p95: result.latency.p97_5, // conservative stand-in (p97.5 >= p95)
    p99: result.latency.p99,
  };
}

async function main() {
  console.log(`CareCompanion load smoke against ${BASE} (${DURATION}s x ${CONNECTIONS} connections per endpoint)\n`);
  const health = await call('GET', '/health');
  if (health.status !== 200) throw new Error(`/health returned ${health.status}`);

  // login once (OTP is limited per phone)
  const r1 = await call('POST', '/auth/otp/request', { body: { phone: PHONE } });
  const otp = r1.json?.devOtp ?? process.env.OTP;
  if (!otp) throw new Error('No devOtp returned (production mode?). Set OTP=<code> for a test number.');
  const r2 = await call('POST', '/auth/otp/verify', { body: { phone: PHONE, otp, deviceName: 'load-smoke' } });
  if (r2.status !== 200) throw new Error(`login failed: ${r2.status} ${JSON.stringify(r2.json)}`);
  const token = r2.json.accessToken;
  console.log(`login: ${r2.ms.toFixed(0)} ms`);

  const pats = await call('GET', '/patients', { token });
  const patient = pats.json?.items?.find((p) => !p.isSelf) ?? pats.json?.items?.[0];
  if (!patient) throw new Error('no patient for this account');
  const docs = await call('GET', '/doctors?specialty=general_physician', { token });
  const doctor = docs.json?.items?.[0];
  if (!doctor) throw new Error('no doctors returned (is the database seeded?)');

  const autocannon = await loadAutocannon();
  if (!autocannon) console.log('autocannon not installed (npm --prefix tests/load install); using the built-in fetch runner\n');

  const endpoints = [
    ['GET /doctors', '/doctors?specialty=general_physician'],
    ['GET /doctors/:id/slots', `/doctors/${doctor.id}/slots?date=${istDate(1)}`],
    ['GET /reminders/today', `/reminders/today?patientId=${patient.id}`],
  ];

  const rows = [];
  let ok = true;
  for (const [name, path] of endpoints) {
    const r = autocannon ? await autocannonRun(autocannon, path, token) : await fetchRun(path, token);
    const errRate = r.errors / Math.max(1, r.requests);
    const pass = r.p95 < P95_BUDGET_MS && errRate < MAX_ERROR_RATE;
    ok &&= pass;
    rows.push({ endpoint: name, engine: r.engine, requests: r.requests, 'req/s': r.rps.toFixed(1), errors: r.errors, 'p50 ms': r.p50.toFixed(1), 'p95 ms': r.p95.toFixed(1), 'p99 ms': r.p99.toFixed(1), result: pass ? 'PASS' : 'FAIL' });
  }

  // AI: sequential samples (LLM latency dominates; do not hammer a paid API)
  if (AI_SAMPLES > 0) {
    const lat = [];
    let errors = 0;
    for (let i = 0; i < AI_SAMPLES; i++) {
      const c = await call('POST', '/ai/conversations', { token, body: { patientId: patient.id } });
      if (c.status !== 201 || !c.json?.id) {
        errors++;
        continue;
      }
      const m = await call('POST', `/ai/conversations/${c.json.id}/messages`, { token, body: { text: 'I have had a mild headache since yesterday' } });
      if (m.status >= 400) errors++;
      else lat.push(m.ms);
    }
    lat.sort((a, b) => a - b);
    const pass = errors === 0 && (lat.length === 0 || pct(lat, 95) < AI_P95_BUDGET_MS);
    ok &&= pass;
    rows.push({ endpoint: 'POST /ai/.../messages', engine: 'sequential', requests: lat.length, 'req/s': '-', errors, 'p50 ms': pct(lat, 50).toFixed(1), 'p95 ms': pct(lat, 95).toFixed(1), 'p99 ms': pct(lat, 99).toFixed(1), result: pass ? 'PASS' : 'FAIL' });
  }

  if (process.env.PROFILE_JSON === '1') console.log(JSON.stringify(rows, null, 2));
  else console.table(rows);
  console.log(`\nBudgets: non-AI p95 < ${P95_BUDGET_MS} ms, errors < ${MAX_ERROR_RATE * 100}%; AI p95 < ${AI_P95_BUDGET_MS / 1000} s`);
  console.log(ok ? 'RESULT: PASS' : 'RESULT: FAIL (429s? raise RATE_LIMIT_MAX on the target)');
  process.exit(ok ? 0 : 1);
}

main().catch((err) => {
  console.error(`load smoke failed: ${err.message}`);
  process.exit(1);
});
