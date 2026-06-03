import { test, expect } from '@playwright/test';

// Runs with ONBOARD_STATE (user logged in but no family)
// Router guard redirects to /onboarding when hasFamilies === false

test.describe('Onboarding flow', () => {
  test('authenticated user with no family lands on /onboarding', async ({ page }) => {
    await page.goto('/dashboard');
    await page.waitForURL(url => url.href.includes('/onboarding'), { timeout: 10000 });
    expect(page.url()).toContain('/onboarding');
  });

  test('onboarding page shows create and join options', async ({ page }) => {
    await page.goto('/onboarding');
    await page.waitForLoadState('networkidle');
    await expect(page.getByText('Welcome to CareCoins')).toBeVisible();
    await expect(page.getByText('Create a New Family')).toBeVisible();
    await expect(page.getByText('Join via Invite Link')).toBeVisible();
  });

  test('can create a new family and lands on dashboard', async ({ page }) => {
    await page.goto('/onboarding');
    await page.waitForLoadState('networkidle');

    // Click into the Create flow
    await page.getByRole('button', { name: 'Create Family' }).click();
    await expect(page.getByText('Setup Your New Family')).toBeVisible({ timeout: 5000 });

    // VInput doesn't associate <label> with <input> via `for`, so use placeholder
    await page.locator('input[placeholder="e.g. The Smiths"]').fill('E2E Onboarding Family');

    // Submit — button is "Complete Setup" at bottom of the create form
    await page.getByRole('button', { name: 'Complete Setup', exact: true }).click();

    // Wait for the success toast or any navigation away from /onboarding
    // fetchUserData is async after family creation — router might loop back once
    await page.waitForURL(
      url => url.href.includes('/dashboard') || url.href.includes('/onboarding'),
      { timeout: 15000 }
    );

    // If we landed back on /onboarding (router re-triggered before store updated), navigate again
    if (page.url().includes('/onboarding')) {
      await page.waitForTimeout(2000); // give fetchUserData time to settle
      await page.goto('/dashboard');
    }

    await page.waitForURL('**/dashboard', { timeout: 15000 });
    await expect(page.getByText('Family Hub')).toBeVisible({ timeout: 10000 });
  });
});
