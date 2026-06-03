import { chromium } from '@playwright/test';

const EMULATOR   = 'http://localhost:9099';
const PROJECT_ID = 'tfg-carecoins';
const BACKEND    = 'http://localhost:3000';
const FRONTEND   = 'http://localhost:5173';

// ── Test user credentials ─────────────────────────────────────
export const TEST_EMAIL    = 'e2e@carecoins.test';
export const TEST_PASSWORD = 'E2ePassword1!';
export const TEST_FAMILY   = 'E2E Test Family';

export const USER2_EMAIL    = 'e2e2@carecoins.test';
export const USER2_PASSWORD = 'E2ePassword2!';

export const ONBOARD_EMAIL    = 'e2e-onboard@carecoins.test';
export const ONBOARD_PASSWORD = 'E2eOnboard1!';

// ── Auth state paths ──────────────────────────────────────────
export const AUTH_STATE      = 'e2e/auth.state.json';
export const AUTH2_STATE     = 'e2e/auth2.state.json';
export const ONBOARD_STATE   = 'e2e/onboarding.state.json';

// ── Emulator helpers ──────────────────────────────────────────

async function clearEmulatorUsers() {
  await fetch(`${EMULATOR}/emulator/v1/projects/${PROJECT_ID}/accounts`, { method: 'DELETE' });
}

async function signUpUser(email, password) {
  const res = await fetch(
    `${EMULATOR}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=test-api-key`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }) }
  );
  return res.json();
}

async function getIdToken(email, password) {
  const res = await fetch(
    `${EMULATOR}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=test-api-key`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }) }
  );
  const data = await res.json();
  if (!data.idToken) throw new Error(`Emulator sign-in failed for ${email}: ${JSON.stringify(data)}`);
  return data.idToken;
}

// ── Backend API helpers ───────────────────────────────────────

async function apiPost(path, body, idToken) {
  const res = await fetch(`${BACKEND}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${idToken}` },
    body: JSON.stringify(body),
  });
  return res.json();
}

async function bootstrapUser(idToken) {
  await fetch(`${BACKEND}/api/me`, { headers: { Authorization: `Bearer ${idToken}` } });
}

// ── Browser auth-state saver ──────────────────────────────────

async function saveAuthState(browser, email, password, statePath) {
  const context = await browser.newContext();
  const page    = await context.newPage();
  await page.goto(`${FRONTEND}/login`);
  await page.waitForLoadState('networkidle');
  await page.fill('input[type="email"]',    email);
  await page.fill('input[type="password"]', password);
  await page.getByRole('button', { name: /sign in/i }).first().click();
  // Onboarding user lands on /onboarding, others on /dashboard
  await page.waitForURL(url => url.href.includes('/dashboard') || url.href.includes('/onboarding'), { timeout: 20000 });
  await context.storageState({ path: statePath });
  await context.close();
}

// ── Main seed ─────────────────────────────────────────────────

async function seedAll(token1, token2) {
  // Bootstrap both users in backend DB
  await bootstrapUser(token1);
  await bootstrapUser(token2);

  // ── Family ────────────────────────────────────────────────
  const { family } = await apiPost('/api/families', {
    name: TEST_FAMILY, alias: 'Tester', caretakers: [],
    objectsOfCare: [{ name: 'Test Baby', type: 'child', careTime: 'full_time' }],
  }, token1);
  if (!family?.id) throw new Error('Family creation failed');

  // ── Invite & add user2 to family ─────────────────────────
  await apiPost(`/api/families/${family.id}/invitations`, { email: USER2_EMAIL }, token1);
  await apiPost('/api/families/join-request', { familyId: family.id, alias: 'Tester2' }, token2);

  // ── Activity templates ────────────────────────────────────
  const { activity: walk }    = await apiPost('/api/activities', { familyId: family.id, title: 'Morning Walk',  category: 'care',      durationMinutes: 30, coinValue: 30 }, token1);
  const { activity: kitchen } = await apiPost('/api/activities', { familyId: family.id, title: 'Tidy Kitchen',  category: 'household', durationMinutes: 20, coinValue: 20 }, token1);
  const { activity: evening } = await apiPost('/api/activities', { familyId: family.id, title: 'Evening Care',  category: 'care',      durationMinutes: 45, coinValue: 45 }, token1);

  // Approve all templates
  await apiPost(`/api/activities/${walk.id}/approve`,    {}, token1);
  await apiPost(`/api/activities/${kitchen.id}/approve`, {}, token1);
  await apiPost(`/api/activities/${evening.id}/approve`, {}, token1);

  // ── Past instance 1 (3 days ago) → validate immediately → user1 earns 30cc
  const threeDaysAgo = new Date(Date.now() - 3 * 86400000).toISOString();
  const { activity: oldWalk } = await apiPost(`/api/activities/${walk.id}/schedule`, { startsAt: threeDaysAgo }, token1);
  if (!oldWalk?.id) throw new Error('Old walk scheduling failed');
  await apiPost(`/api/activities/${oldWalk.id}/validate`, {}, token2);

  // ── Past instance 2 (yesterday) → leave as pending_validation for the UI validate test
  const yesterday = new Date(Date.now() - 86400000).toISOString();
  const { activity: pastWalk } = await apiPost(`/api/activities/${walk.id}/schedule`, { startsAt: yesterday }, token1);
  if (!pastWalk?.id) throw new Error('Past walk scheduling failed');
  // Do NOT validate — the UI test does this

  // ── Future instance for bounty test ──────────────────────
  const tomorrow = new Date(Date.now() + 86400000).toISOString();
  await apiPost(`/api/activities/${evening.id}/schedule`, { startsAt: tomorrow }, token1);

  // ── Marketplace reward (cost 10cc, user1 has 30cc) ───────
  await apiPost('/api/marketplace/rewards', {
    familyId: family.id, title: 'Movie Night',
    description: 'Pick the movie for family night', cost: 10,
  }, token1);

  return family;
}

// ── Global setup entry point ──────────────────────────────────

export default async function globalSetup() {
  console.log('\n[E2E setup] Clearing emulator…');
  await clearEmulatorUsers();

  console.log('[E2E setup] Creating users…');
  await signUpUser(TEST_EMAIL,    TEST_PASSWORD);
  await signUpUser(USER2_EMAIL,   USER2_PASSWORD);
  await signUpUser(ONBOARD_EMAIL, ONBOARD_PASSWORD);

  const token1      = await getIdToken(TEST_EMAIL,    TEST_PASSWORD);
  const token2      = await getIdToken(USER2_EMAIL,   USER2_PASSWORD);
  const tokenOnboard = await getIdToken(ONBOARD_EMAIL, ONBOARD_PASSWORD);

  // Bootstrap onboarding user with NO family
  await bootstrapUser(tokenOnboard);

  console.log('[E2E setup] Seeding family, activities, rewards…');
  await seedAll(token1, token2);

  console.log('[E2E setup] Saving browser auth states…');
  const browser = await chromium.launch();
  await saveAuthState(browser, TEST_EMAIL,    TEST_PASSWORD,    AUTH_STATE);
  await saveAuthState(browser, USER2_EMAIL,   USER2_PASSWORD,   AUTH2_STATE);
  await saveAuthState(browser, ONBOARD_EMAIL, ONBOARD_PASSWORD, ONBOARD_STATE);
  await browser.close();

  console.log('[E2E setup] All done — 3 auth states saved.\n');
}
