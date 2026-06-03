import { chromium } from '@playwright/test';

const EMULATOR   = 'http://localhost:9099';
const PROJECT_ID = 'tfg-carecoins';
const BACKEND    = 'http://localhost:3000';
const FRONTEND   = 'http://localhost:5173';

export const TEST_EMAIL    = 'e2e@carecoins.test';
export const TEST_PASSWORD = 'E2ePassword1!';
export const TEST_FAMILY   = 'E2E Test Family';
export const AUTH_STATE    = 'e2e/auth.state.json';

// ── Emulator helpers ──────────────────────────────────────────

async function clearEmulatorUsers() {
  await fetch(
    `${EMULATOR}/emulator/v1/projects/${PROJECT_ID}/accounts`,
    { method: 'DELETE' }
  );
}

async function signUpTestUser() {
  const res = await fetch(
    `${EMULATOR}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=test-api-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: TEST_EMAIL, password: TEST_PASSWORD, returnSecureToken: true }),
    }
  );
  return res.json();
}

async function getIdToken() {
  const res = await fetch(
    `${EMULATOR}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=test-api-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: TEST_EMAIL, password: TEST_PASSWORD, returnSecureToken: true }),
    }
  );
  const data = await res.json();
  if (!data.idToken) throw new Error(`Emulator sign-in failed: ${JSON.stringify(data)}`);
  return data.idToken;
}

// ── Backend seed helpers ──────────────────────────────────────

async function apiPost(path, body, idToken) {
  const res = await fetch(`${BACKEND}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${idToken}` },
    body: JSON.stringify(body),
  });
  return res.json();
}

async function apiGet(path, idToken) {
  const res = await fetch(`${BACKEND}${path}`, {
    headers: { Authorization: `Bearer ${idToken}` },
  });
  return res.json();
}

async function seedTestData(idToken) {
  // Bootstrap user in backend DB
  await fetch(`${BACKEND}/api/me`, { headers: { Authorization: `Bearer ${idToken}` } });

  // Create a test family
  const { family } = await apiPost('/api/families', {
    name: TEST_FAMILY,
    alias: 'Tester',
    caretakers: [],
    objectsOfCare: [{ name: 'Test Baby', type: 'child', careTime: 'full_time' }],
  }, idToken);

  if (!family?.id) throw new Error('Family creation failed');

  // Create two activity templates (one care, one household) — status starts as 'pending'
  const { activity: walk }   = await apiPost('/api/activities', { familyId: family.id, title: 'Morning Walk', category: 'care',      durationMinutes: 30, coinValue: 30 }, idToken);
  const { activity: kitchen } = await apiPost('/api/activities', { familyId: family.id, title: 'Tidy Kitchen', category: 'household', durationMinutes: 20, coinValue: 20 }, idToken);

  // Approve both templates (caregiver required — our test user IS a caregiver)
  await apiPost(`/api/activities/${walk.id}/approve`,    {}, idToken);
  await apiPost(`/api/activities/${kitchen.id}/approve`, {}, idToken);

  return family;
}

// ── Global setup entry point ──────────────────────────────────

export default async function globalSetup() {
  console.log('\n[E2E setup] Clearing emulator users…');
  await clearEmulatorUsers();

  console.log('[E2E setup] Creating test user…');
  await signUpTestUser();
  const idToken = await getIdToken();

  console.log('[E2E setup] Seeding backend data…');
  await seedTestData(idToken);

  console.log('[E2E setup] Logging in via browser to save auth state…');
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page    = await context.newPage();

  await page.goto(`${FRONTEND}/login`);
  await page.waitForLoadState('networkidle');

  await page.fill('input[type="email"]',    TEST_EMAIL);
  await page.fill('input[type="password"]', TEST_PASSWORD);
  await page.getByRole('button', { name: /sign in/i }).first().click();

  await page.waitForURL('**/dashboard', { timeout: 20000 });

  await context.storageState({ path: AUTH_STATE });
  await browser.close();

  console.log('[E2E setup] Auth state saved. Ready.\n');
}
