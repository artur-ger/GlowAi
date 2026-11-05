import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';

const BASE = process.env.GLOW_BASE || 'http://127.0.0.1:8000/app/';
const OUT = path.resolve('docs/e2e-climate-today.png');

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({
  locale: 'ru-RU',
  viewport: { width: 420, height: 900 },
});
const page = await context.newPage();

const climatePosts = [];
page.on('response', async (res) => {
  if (res.url().includes('/api/v1/climate/today') && res.request().method() === 'POST') {
    let body = null;
    try {
      body = await res.json();
    } catch {
      body = null;
    }
    climatePosts.push({ status: res.status(), body });
  }
});

await page.addInitScript(() => {
  localStorage.setItem('flutter.glowai_onboarded_v1', 'true');
  localStorage.setItem('flutter.glowai_locale_v1', '"ru"');
  localStorage.setItem('flutter.glowai_climate_city_v1', '"Москва"');
  localStorage.setItem('flutter.glowai_climate_country_v1', '"Россия"');
  localStorage.setItem('flutter.glowai_climate_cc_v1', '"RU"');
  localStorage.setItem('flutter.glowai_climate_lat_v1', '55.7558');
  localStorage.setItem('flutter.glowai_climate_lon_v1', '37.6173');
});

await page.goto(BASE, { waitUntil: 'networkidle', timeout: 120000 });
// Flutter canvas + climate POST can take a while on cold start
for (let i = 0; i < 30 && climatePosts.length === 0; i += 1) {
  await page.waitForTimeout(1000);
}
await page.waitForTimeout(2000);

fs.mkdirSync(path.dirname(OUT), { recursive: true });
await page.screenshot({ path: OUT, fullPage: true });

const hit = climatePosts.find(
  (c) => c.status === 200 && String(c.body?.provider || '').includes('mixed_ordinal'),
);
const ok =
  hit &&
  Array.isArray(hit.body.hours) &&
  hit.body.hours.length > 0 &&
  Array.isArray(hit.body.clothing) &&
  hit.body.clothing.length > 0 &&
  typeof hit.body.utci_c === 'number' &&
  typeof hit.body.personal_utci_c === 'number' &&
  hit.body.support &&
  typeof hit.body.support.ireq_clo === 'number' &&
  typeof hit.body.explanation === 'string' &&
  hit.body.explanation.length > 0;

console.log(
  JSON.stringify(
    {
      ok: Boolean(ok),
      climateCalls: climatePosts.length,
      status: hit?.status ?? null,
      provider: hit?.body?.provider ?? null,
      hours: hit?.body?.hours?.length ?? 0,
      clothing: hit?.body?.clothing?.length ?? 0,
      utci_c: hit?.body?.utci_c ?? null,
      ireq_clo: hit?.body?.support?.ireq_clo ?? null,
      pet_c: hit?.body?.support?.pet_c ?? null,
      sensation: hit?.body?.sensation_label ?? null,
      feedback_moment: hit?.body?.feedback_window?.moment ?? null,
      screenshot: OUT,
    },
    null,
    2,
  ),
);

await browser.close();
process.exit(ok ? 0 : 1);
