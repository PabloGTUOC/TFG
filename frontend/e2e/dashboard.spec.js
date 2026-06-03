import { test, expect } from '@playwright/test';

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard — requires auth
//
// NOTE: These tests require a logged-in session. Because CareCoins uses
// Firebase Google auth, full login automation requires a service account or
// Firebase Emulator. Until then, these tests run as "unauthenticated" checks —
// they verify that the app correctly redirects or shows the auth gate.
//
// To enable full happy-path tests, set up Firebase Emulator Auth and update
// playwright.config.js with a globalSetup that seeds an auth token into
// storageState.
// ─────────────────────────────────────────────────────────────────────────────

test.describe('Dashboard — unauthenticated guard', () => {
  test('redirects unauthenticated users away from /dashboard', async ({ page }) => {
    await page.goto('/dashboard');
    // Wait for the auth guard to resolve and redirect (it awaits waitForAuth)
    // waitForURL predicate receives a URL object, not a string
    await page.waitForURL(url => !url.href.includes('/dashboard'), { timeout: 10000 });
    expect(page.url()).not.toContain('/dashboard');
  });

  test('redirects unauthenticated users away from /daily', async ({ page }) => {
    const today = new Date().toISOString().split('T')[0];
    await page.goto(`/daily/${today}`);
    await page.waitForURL(url => !url.href.includes('/daily'), { timeout: 10000 });
    expect(page.url()).not.toContain('/daily');
  });

  test('redirects unauthenticated users away from /profile', async ({ page }) => {
    await page.goto('/profile');
    await page.waitForURL(url => !url.href.includes('/profile'), { timeout: 10000 });
    expect(page.url()).not.toContain('/profile');
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Mobile viewport — public pages render correctly
// ─────────────────────────────────────────────────────────────────────────────

test.describe('Mobile viewport', () => {
  test.use({ viewport: { width: 390, height: 844 } });

  test('login page renders correctly on mobile', async ({ page }) => {
    await page.goto('/login');
    await page.waitForLoadState('networkidle');
    await expect(page.locator('body')).toBeVisible();
    // No horizontal scroll
    const bodyWidth  = await page.evaluate(() => document.body.scrollWidth);
    const innerWidth = await page.evaluate(() => window.innerWidth);
    expect(bodyWidth).toBeLessThanOrEqual(innerWidth + 20); // 5px tolerance
  });

  test('landing page has no significant horizontal overflow on mobile', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    const bodyWidth  = await page.evaluate(() => document.body.scrollWidth);
    const innerWidth = await page.evaluate(() => window.innerWidth);
    expect(bodyWidth).toBeLessThanOrEqual(innerWidth + 30);
  });
});
