import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';

const BASE = process.env.GLOW_BASE || 'http://127.0.0.1:8000/app/';
const API = process.env.GLOW_API || 'http://127.0.0.1:8000';
const OUT = path.resolve('docs/e2e-auth-climate.png');

async function api(pathname, { method = 'GET', body, token } = {}) {
  const res = await fetch(`${API}${pathname}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`${method} ${pathname} -> ${res.status} ${JSON.stringify(data)}`);
  return data;
}

const email = `climate.e2e.${Date.now()}@example.com`;
const password = 'testpass1';
const reg = await api('/api/v1/auth/register', {
  method: 'POST',
  body: { email, password, display_name: 'E2E', accept_terms: true },
});
const verified = await api('/api/v1/auth/verify-email', {
  method: 'POST',
  body: { email, code: reg.dev_verify_code },
});
const token = verified.access_token;
const uid = verified.user.id;

// Fresh account: onboarded=false
const before = await api('/api/v1/climate/profile', { token });
if (before.onboarded !== false) throw new Error('expected onboarded=false for new user');

await api('/api/v1/climate/profile', {
  method: 'PUT',
  token,
  body: {
    onboarded: true,
    city_name: 'Moscow',
    city_country: 'Russia',
    city_country_code: 'RU',
    lat: 55.7558,
    lon: 37.6173,
    cold_bias: 0.7,
    heat_bias: 0,
    activity: 'moderate',
    age_band: '30_50',
    sex: 'female',
    feedback_offset: -0.5,
    feedback_count: 2,
    habits: ['sport'],
    allergies: ['pollen'],
    skin_note: '',
    leave_hour: 8,
    return_hour: 19,
    client_key: `u${uid}`,
  },
});

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 420, height: 900 } });
const climatePosts = [];
page.on('response', async (res) => {
  if (res.url().includes('/api/v1/climate/today') && res.request().method() === 'POST') {
    try {
      climatePosts.push({ status: res.status(), body: await res.json() });
    } catch {
      climatePosts.push({ status: res.status(), body: null });
    }
  }
});

await page.addInitScript(
  ({ token, uid }) => {
    // shared_preferences web encodes string values as JSON strings
    localStorage.setItem('flutter.glowai_jwt_v1', JSON.stringify(token));
    localStorage.setItem('flutter.glowai_email_v1', JSON.stringify('e2e@example.com'));
    localStorage.setItem('flutter.glowai_name_v1', JSON.stringify('E2E'));
    localStorage.setItem('flutter.glowai_user_id_v1', String(uid));
    localStorage.setItem('flutter.glowai_locale_v1', JSON.stringify('ru'));
  },
  { token, uid },
);

await page.goto(BASE, { waitUntil: 'networkidle', timeout: 120000 });
for (let i = 0; i < 40 && climatePosts.length === 0; i += 1) {
  await page.waitForTimeout(1000);
}
await page.waitForTimeout(2000);
fs.mkdirSync(path.dirname(OUT), { recursive: true });
await page.screenshot({ path: OUT, fullPage: true });

const hit = climatePosts.find((c) => c.status === 200 && c.body?.provider);
const ok = Boolean(hit && hit.body.support?.ireq_clo != null);

console.log(
  JSON.stringify(
    {
      ok,
      email,
      uid,
      newUserOnboardedFalse: before.onboarded === false,
      climateCalls: climatePosts.length,
      provider: hit?.body?.provider ?? null,
      personal: hit?.body?.personal_utci_c ?? null,
      screenshot: OUT,
    },
    null,
    2,
  ),
);

await browser.close();
process.exit(ok ? 0 : 1);
