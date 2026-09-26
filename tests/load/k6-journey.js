// CareCompanion k6 load test: patient journey
//   login (once, in setup) -> doctors -> slots -> AI message -> reminders
//
// Run (k6 installed: https://grafana.com/docs/k6/latest/set-up/install-k6/):
//   k6 run tests/load/k6-journey.js                                   # smoke: 2 VUs, 1 min, local API
//   k6 run -e PROFILE=load -e BASE_URL=https://api.staging.example.in/api/v1 tests/load/k6-journey.js
//   k6 run -e PROFILE=stress ... tests/load/k6-journey.js
//
// Env:
//   BASE_URL   API base (default http://localhost:4000/api/v1)
//   PHONE      seeded patient phone (default +919800000001, Vaibhav, who manages Ramesh)
//   OTP        OTP to use when the API does not return devOtp (staging review/test number)
//   PROFILE    smoke | load | stress   (default smoke)
//   AI         1 (default) to include the AI step; 0 to skip it
//
// SLO thresholds (docs/product/13_DEPLOYMENT.md §4):
//   * non-AI endpoints p95 < 500 ms           (tag kind=api)
//   * AI message p95 < 10 s, measured apart   (tag kind=ai; LLM latency, not an SLO of our code)
//   * error rate < 1 %, checks > 99 %
//
// CAUTIONS
//   * NEVER run against production. Use staging or the docker-compose stack with
//     synthetic seed data only.
//   * The API rate-limits per IP (RATE_LIMIT_MAX, default 600/min) and WAF limits
//     per IP (3000 / 5 min). A single load generator hits these quickly: raise
//     RATE_LIMIT_MAX on the target and/or allow-list the generator IP in WAF, or
//     you are measuring 429s.
//   * One login per test (OTP is limited to 5 requests per phone per 15 min).
//     Access tokens live ACCESS_TOKEN_TTL_SEC (15 min), so keep runs <= 14 min
//     or raise the TTL on the test environment.
//   * Each iteration creates an AI conversation. Reset staging data afterwards.

import http from 'k6/http';
import { check, fail, group, sleep } from 'k6';

const BASE = __ENV.BASE_URL || 'http://localhost:4000/api/v1';
const PHONE = __ENV.PHONE || '+919800000001';
const PROFILE = __ENV.PROFILE || 'smoke';
const WITH_AI = (__ENV.AI || '1') !== '0';

const profiles = {
  smoke: { executor: 'constant-vus', vus: 2, duration: '1m' },
  load: {
    executor: 'ramping-vus',
    startVUs: 0,
    stages: [
      { duration: '2m', target: 25 },
      { duration: '6m', target: 50 },
      { duration: '2m', target: 0 },
    ],
    gracefulRampDown: '30s',
  },
  stress: {
    executor: 'ramping-vus',
    startVUs: 0,
    stages: [
      { duration: '2m', target: 50 },
      { duration: '4m', target: 150 },
      { duration: '4m', target: 300 },
      { duration: '2m', target: 0 },
    ],
    gracefulRampDown: '30s',
  },
};

export const options = {
  scenarios: { journey: profiles[PROFILE] || profiles.smoke },
  thresholds: {
    'http_req_duration{kind:api}': ['p(95)<500'],
    'http_req_duration{kind:ai}': ['p(95)<10000'],
    'http_req_duration{name:login}': ['p(95)<1000'],
    'http_req_failed{kind:api}': ['rate<0.01'],
    'http_req_failed{kind:ai}': ['rate<0.02'],
    checks: ['rate>0.99'],
  },
  summaryTrendStats: ['avg', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

function json(res) {
  try {
    return res.json();
  } catch {
    return null;
  }
}

function istDate(offsetDays) {
  const d = new Date(Date.now() + 5.5 * 3600e3 + offsetDays * 86400e3);
  return d.toISOString().slice(0, 10);
}

export function setup() {
  const h = { headers: { 'content-type': 'application/json' }, tags: { name: 'login' } };
  const r1 = http.post(`${BASE}/auth/otp/request`, JSON.stringify({ phone: PHONE }), h);
  if (r1.status !== 200 && r1.status !== 201) fail(`otp/request ${r1.status}: ${r1.body}`);
  const otp = (json(r1) || {}).devOtp || __ENV.OTP;
  if (!otp) fail('No devOtp returned (production mode?). Pass -e OTP=<code> for a test number.');
  const r2 = http.post(`${BASE}/auth/otp/verify`, JSON.stringify({ phone: PHONE, otp, deviceName: 'k6' }), h);
  if (r2.status !== 200) fail(`otp/verify ${r2.status}: ${r2.body}`);
  const token = json(r2).accessToken;

  const auth = { headers: { authorization: `Bearer ${token}` } };
  const pats = json(http.get(`${BASE}/patients`, auth));
  const items = (pats && pats.items) || [];
  const patient = items.find((p) => !p.isSelf) || items[0];
  if (!patient) fail('No patient available for this account');
  return { token, patientId: patient.id };
}

export default function (data) {
  const headers = { authorization: `Bearer ${data.token}`, 'content-type': 'application/json' };
  const api = (name) => ({ headers, tags: { kind: 'api', name } });

  let doctorId = null;
  group('doctors', () => {
    const r = http.get(`${BASE}/doctors?specialty=general_physician`, api('GET /doctors'));
    check(r, { 'doctors 200': (x) => x.status === 200 });
    const list = (json(r) || {}).items || [];
    if (list.length) doctorId = list[Math.floor(Math.random() * list.length)].id;
  });

  group('slots', () => {
    if (!doctorId) return;
    const r = http.get(`${BASE}/doctors/${doctorId}/slots?date=${istDate(1)}`, api('GET /doctors/:id/slots'));
    check(r, { 'slots 200': (x) => x.status === 200 });
  });

  if (WITH_AI) {
    group('ai', () => {
      const c = http.post(`${BASE}/ai/conversations`, JSON.stringify({ patientId: data.patientId }), api('POST /ai/conversations'));
      check(c, { 'conversation 201': (x) => x.status === 201 });
      const conv = json(c);
      if (!conv || !conv.id) return;
      const m = http.post(
        `${BASE}/ai/conversations/${conv.id}/messages`,
        JSON.stringify({ text: 'I have had a mild headache since yesterday' }),
        { headers, tags: { kind: 'ai', name: 'POST /ai/conversations/:id/messages' }, timeout: '60s' },
      );
      check(m, { 'ai reply 200': (x) => x.status === 200 || x.status === 201 });
    });
  }

  group('reminders', () => {
    const r = http.get(`${BASE}/reminders/today?patientId=${data.patientId}`, api('GET /reminders/today'));
    check(r, { 'reminders 200': (x) => x.status === 200 });
  });

  sleep(1 + Math.random() * 2); // think time
}
