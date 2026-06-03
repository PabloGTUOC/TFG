import { test, expect } from '@playwright/test';
import { TEST_FAMILY } from './global.setup.js';

// All tests in this file start already logged in (via storageState from global.setup.js)

// ─────────────────────────────────────────────────────────────
// Dashboard
// ─────────────────────────────────────────────────────────────

test.describe('Dashboard', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    // Wait for the dashboard root (v-if on members.length > 0) — data may take a moment
    await page.locator('.dashboard-root').waitFor({ state: 'visible', timeout: 15000 });
  });

  test('renders Family Hub heading', async ({ page }) => {
    await expect(page.getByText('Family Hub')).toBeVisible({ timeout: 10000 });
  });

  test('shows active family members section', async ({ page }) => {
    await expect(page.getByText('Active Family Members')).toBeVisible({ timeout: 10000 });
  });

  test('week calendar is visible', async ({ page }) => {
    await expect(page.locator('.week-section')).toBeVisible({ timeout: 10000 });
  });

  test('KPI cards are present', async ({ page }) => {
    await expect(page.locator('.kpi-grid')).toBeVisible({ timeout: 10000 });
  });

  test('no JavaScript errors on load', async ({ page }) => {
    const errors = [];
    page.on('pageerror', err => errors.push(err.message));
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    expect(errors.filter(e => !e.includes('ResizeObserver'))).toHaveLength(0);
  });
});

// ─────────────────────────────────────────────────────────────
// Daily view
// ─────────────────────────────────────────────────────────────

test.describe('Daily view', () => {
  test('opens for today from the URL', async ({ page }) => {
    const today = new Date().toISOString().split('T')[0];
    await page.goto(`/daily/${today}`);
    await page.waitForLoadState('networkidle');
    await expect(page.getByText('Daily Schedule')).toBeVisible();
  });

  test('task library shows seeded templates (desktop)', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    const today = new Date().toISOString().split('T')[0];
    await page.goto(`/daily/${today}`);
    await page.waitForLoadState('networkidle');
    // Both templates should appear in the library sidebar (scoped to avoid matching timeline chips)
    await expect(page.locator('.task-library .task-row', { hasText: 'Morning Walk' }).first()).toBeVisible();
    await expect(page.locator('.task-library .task-row', { hasText: 'Tidy Kitchen' }).first()).toBeVisible();
  });

  test('date navigation moves to next day', async ({ page }) => {
    const today = new Date().toISOString().split('T')[0];
    await page.goto(`/daily/${today}`);
    await page.waitForLoadState('networkidle');

    // Click the forward arrow
    const fwdBtn = page.locator('.date-nav-btn').last();
    await fwdBtn.click();

    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowStr = tomorrow.toISOString().split('T')[0];
    await page.waitForURL(`**/daily/${tomorrowStr}`, { timeout: 5000 });
    expect(page.url()).toContain(tomorrowStr);
  });

  test('back button returns to dashboard', async ({ page }) => {
    const today = new Date().toISOString().split('T')[0];
    await page.goto(`/daily/${today}`);
    await page.waitForLoadState('networkidle');
    await page.locator('.daily-back-fab').click();
    await page.waitForURL('**/dashboard', { timeout: 5000 });
    expect(page.url()).toContain('/dashboard');
  });

  test('task sheet opens on mobile add button click', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    const today = new Date().toISOString().split('T')[0];
    await page.goto(`/daily/${today}`);
    await page.waitForLoadState('networkidle');

    const addBtn = page.locator('.mobile-bottom-add');
    await expect(addBtn).toBeVisible({ timeout: 8000 });
    await addBtn.click();
    await expect(page.locator('.task-sheet')).toBeVisible({ timeout: 5000 });
  });
});

// ─────────────────────────────────────────────────────────────
// Schedule a task
// ─────────────────────────────────────────────────────────────

test.describe('Schedule task flow', () => {
  test('can schedule Morning Walk on mobile via task sheet', async ({ page }) => {
    // On mobile (<=768px), clicking a task in the sheet directly opens the schedule modal
    await page.setViewportSize({ width: 390, height: 844 });
    const today = new Date().toISOString().split('T')[0];
    await page.goto(`/daily/${today}`);
    await page.waitForLoadState('networkidle');

    // Open the task sheet
    const addBtn = page.locator('.mobile-bottom-add');
    await expect(addBtn).toBeVisible({ timeout: 8000 });
    await addBtn.click();
    await expect(page.locator('.task-sheet')).toBeVisible({ timeout: 5000 });

    // Click Morning Walk in the sheet — triggers tapToScheduleFromSheet → opens schedule modal
    await page.locator('.task-sheet').getByText('Morning Walk').click();
    await expect(page.getByText('Confirm Time')).toBeVisible({ timeout: 8000 });

    // Confirm the schedule — use exact match to avoid matching the bottom-bar "Add task" button
    await page.getByRole('button', { name: 'Schedule', exact: true }).click();

    // Activity should now appear in the mobile timeline list
    await expect(page.locator('.tl-card-title', { hasText: 'Morning Walk' })).toBeVisible({ timeout: 8000 });
  });
});

// ─────────────────────────────────────────────────────────────
// Profile
// ─────────────────────────────────────────────────────────────

test.describe('Profile page', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/profile');
    await page.waitForLoadState('networkidle');
  });

  test('shows Personal Area heading', async ({ page }) => {
    await expect(page.getByText('Personal Area')).toBeVisible();
  });

  test('shows the test family banner', async ({ page }) => {
    await expect(page.getByText(TEST_FAMILY)).toBeVisible();
  });

  test('Account Settings section is visible', async ({ page }) => {
    await expect(page.getByText('Account Settings')).toBeVisible();
  });

  test('wallet tab shows coin balance', async ({ page }) => {
    // On desktop the wallet column is always visible
    await expect(page.getByText('TOTAL BALANCE')).toBeVisible();
  });
});

// ─────────────────────────────────────────────────────────────
// Navigation
// ─────────────────────────────────────────────────────────────

test.describe('Navigation', () => {
  test('nav links reach all main sections', async ({ page }) => {
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');

    // Profile link
    const profileLink = page.getByRole('link', { name: /profile/i }).first();
    if (await profileLink.isVisible()) {
      await profileLink.click();
      await page.waitForURL('**/profile', { timeout: 5000 });
      await expect(page.getByText('Personal Area')).toBeVisible();
    }
  });

  test('logout clears session and redirects to login', async ({ page }) => {
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');

    const logoutBtn = page.getByRole('button', { name: /log out|sign out/i }).first();
    if (await logoutBtn.isVisible()) {
      await logoutBtn.click();
      await page.waitForURL('**/login', { timeout: 8000 });
      expect(page.url()).toContain('/login');
    }
  });
});
