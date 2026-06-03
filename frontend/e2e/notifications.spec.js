import { test, expect } from '@playwright/test';

// Notification.permission won't be 'granted' in http://localhost without a real user gesture,
// even with Playwright's grantPermissions. We use addInitScript to set it before Vue reads it
// (Vue reads Notification.permission at component init time to set the reactive ref).

test.describe('Notification preferences', () => {
  test.beforeEach(async ({ page }) => {
    // Inject 'granted' permission BEFORE the page loads so Vue's reactive ref reads it
    await page.addInitScript(() => {
      try {
        Object.defineProperty(window.Notification, 'permission', {
          get: () => 'granted',
          configurable: true,
        });
      } catch {
        // If Notification isn't available, define it
        Object.defineProperty(window, 'Notification', {
          value: { permission: 'granted', requestPermission: async () => 'granted' },
          writable: true, configurable: true,
        });
      }
    });
    await page.goto('/profile');
    await page.waitForLoadState('networkidle');
  });

  test('notification permission is detected as granted', async ({ page }) => {
    const perm = await page.evaluate(() => {
      try { return Notification.permission; } catch { return 'unavailable'; }
    });
    expect(perm).toBe('granted');
  });

  test('notification preferences panel is visible when permission is granted', async ({ page }) => {
    await expect(page.getByText('Notifications enabled')).toBeVisible({ timeout: 8000 });
    await expect(page.locator('.notif-pref-list')).toBeVisible({ timeout: 5000 });
  });

  test('shows all 5 notification preference toggles', async ({ page }) => {
    await expect(page.locator('.notif-pref-list')).toBeVisible({ timeout: 8000 });
    await expect(page.locator('.notif-pref-toggle')).toHaveCount(5, { timeout: 5000 });
  });

  test('can toggle a notification preference off and on', async ({ page }) => {
    await expect(page.locator('.notif-pref-list')).toBeVisible({ timeout: 8000 });
    const firstToggle = page.locator('.notif-pref-toggle').first();
    const before = await firstToggle.isChecked();
    await firstToggle.click();
    expect(await firstToggle.isChecked()).toBe(!before);
    await firstToggle.click();
    expect(await firstToggle.isChecked()).toBe(before);
  });

  test('disable button is visible when notifications are enabled', async ({ page }) => {
    await expect(page.locator('.notif-pref-list')).toBeVisible({ timeout: 8000 });
    await expect(page.getByRole('button', { name: /disable/i })).toBeVisible();
  });
});
