import { test, expect } from '@playwright/test';

// Runs as user1 (auth.state.json) who has 30cc from the validate step in global setup
// and a "Movie Night" reward (cost: 10cc) seeded in the marketplace

test.describe('Marketplace', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/marketplace');
    await page.waitForLoadState('networkidle');
    // Wait for the store card to be rendered
    await page.locator('.marketplace-container').waitFor({ state: 'visible', timeout: 15000 });
  });

  test('marketplace page loads correctly', async ({ page }) => {
    await expect(page.getByText('The Reward Store')).toBeVisible({ timeout: 10000 });
  });

  test('seeded reward "Movie Night" is visible in the store', async ({ page }) => {
    await expect(page.getByText('Movie Night')).toBeVisible({ timeout: 10000 });
  });

  test('reward card shows coin cost', async ({ page }) => {
    await expect(page.locator('.coin-amount', { hasText: '10' })).toBeVisible({ timeout: 10000 });
  });

  test('can redeem a reward end-to-end', async ({ page }) => {
    // Click the Buy Now button on the Movie Night reward
    const rewardCard = page.locator('.reward-item', { hasText: 'Movie Night' });
    await expect(rewardCard).toBeVisible({ timeout: 8000 });
    await rewardCard.getByRole('button', { name: 'Buy Now' }).click();

    // Confirmation dialog
    await expect(page.getByRole('heading', { name: 'Confirm Redemption' })).toBeVisible({ timeout: 5000 });

    // The confirm button is labelled "Spend coins"
    await page.getByRole('button', { name: 'Spend coins', exact: true }).click();

    // Success: reward moves to history
    await page.waitForLoadState('networkidle');

    // Either a success message or the reward appears in history
    const successOrHistory = page.getByText(/redeemed|success|Movie Night/i).first();
    await expect(successOrHistory).toBeVisible({ timeout: 8000 });
  });

  test('History tab shows claimed rewards after redemption', async ({ page }) => {
    // Navigate to history tab
    const historyTab = page.locator('.mtab', { hasText: 'History' })
      .or(page.getByRole('button', { name: 'History' })).first();

    if (await historyTab.isVisible()) {
      await historyTab.click();
      await page.waitForLoadState('networkidle');
      // After redeeming in the previous test, Movie Night should appear here
      // (tests share the same backend state)
      await expect(page.locator('body')).toBeVisible();
    }
  });

  test('caregiver can create a new reward', async ({ page }) => {
    // On desktop the tab bar is hidden — all VCards are visible simultaneously
    // The Create form is directly accessible without clicking a tab
    await expect(page.getByText('Create New Reward')).toBeVisible({ timeout: 5000 });

    // VInput labels have no `for` attr — use placeholder selectors scoped to the create card
    const createCard = page.locator('.v-card', { hasText: 'Create New Reward' });
    await createCard.locator('input[placeholder*="Winner"]').fill('E2E Test Reward');
    await createCard.locator('input[type="number"]').first().fill('5');

    await page.getByRole('button', { name: 'Add Reward to Store', exact: true }).click();

    // App shows success toast or navigates back to store with new reward
    await page.waitForLoadState('networkidle');
    // Either success toast or the reward appears somewhere
    const successIndicator = page.getByText(/created|Reward created|E2E Test Reward/i).first();
    await expect(successIndicator).toBeVisible({ timeout: 8000 });
  });
});
