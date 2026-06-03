import { test, expect } from '@playwright/test';
import { AUTH2_STATE } from './global.setup.js';

// Both tests open two browser contexts: user1 (from storageState in project config)
// and user2 (opened manually with AUTH2_STATE).

// ─────────────────────────────────────────────────────────────
// Validate activity flow
// User1 scheduled Morning Walk yesterday → auto pending_validation
// User2 sees the Validate button and approves it
// ─────────────────────────────────────────────────────────────

test('validate activity: user2 validates user1 past activity', async ({ browser }) => {
  const yesterday = new Date(Date.now() - 86400000);
  const dateStr = `${yesterday.getFullYear()}-${String(yesterday.getMonth()+1).padStart(2,'0')}-${String(yesterday.getDate()).padStart(2,'0')}`;

  // User2 context
  const ctx2  = await browser.newContext({ storageState: AUTH2_STATE });
  const page2 = await ctx2.newPage();

  await page2.goto(`/daily/${dateStr}`);
  await page2.waitForLoadState('networkidle');
  // Wait for family data to load (familyStore must be ready for role check in the button v-if)
  await page2.waitForTimeout(1000);

  // User2 should see a pending_validation chip for Morning Walk with a Validate button
  const validateBtn = page2.locator('button.validate-btn').filter({ hasText: 'Validate' }).first();
  await expect(validateBtn).toBeVisible({ timeout: 15000 });

  // Validate
  await validateBtn.click();

  // After validation the chip should show "✓ Done"
  await expect(page2.locator('.scheduled-chip', { hasText: 'Morning Walk' })
    .locator('text=Done')).toBeVisible({ timeout: 8000 });

  await ctx2.close();
});

test('validate activity: user1 coin balance increases after validation', async ({ browser }) => {
  // After user2 validated in the previous test (or in setup), user1 should have earned coins.
  // We verify by checking the coin display in the nav/profile.
  const ctx1  = await browser.newContext({ storageState: 'e2e/auth.state.json' });
  const page1 = await ctx1.newPage();

  await page1.goto('/profile');
  await page1.waitForLoadState('networkidle');

  // Profile wallet panel shows TOTAL BALANCE — should be > 0 after the validated activity
  const balanceEl = page1.locator('.balance-amount').first();
  await expect(balanceEl).toBeVisible({ timeout: 8000 });
  const balText = await balanceEl.textContent();
  const balance = parseInt(balText?.replace(/[^0-9]/g, '') || '0', 10);
  expect(balance).toBeGreaterThan(0);

  await ctx1.close();
});

// ─────────────────────────────────────────────────────────────
// Bounty end-to-end flow
// User1 has Evening Care scheduled for tomorrow
// User1 offers a bounty → User2 sees and accepts it
// ─────────────────────────────────────────────────────────────

test('bounty flow: user1 offers bounty, user2 takes over', async ({ browser }) => {
  const tomorrow = new Date(Date.now() + 86400000);
  const dateStr = `${tomorrow.getFullYear()}-${String(tomorrow.getMonth()+1).padStart(2,'0')}-${String(tomorrow.getDate()).padStart(2,'0')}`;

  const ctx1  = await browser.newContext({ storageState: 'e2e/auth.state.json' });
  const ctx2  = await browser.newContext({ storageState: AUTH2_STATE });
  const page1 = await ctx1.newPage();
  const page2 = await ctx2.newPage();

  // ── User1: navigate to tomorrow, find Evening Care ──────────
  await page1.goto(`/daily/${dateStr}`);
  await page1.waitForLoadState('networkidle');
  await page1.waitForTimeout(1000); // let familyStore + activities load

  // Evening Care chip should be visible
  const chip = page1.locator('.scheduled-chip', { hasText: 'Evening Care' }).first();
  await expect(chip).toBeVisible({ timeout: 15000 });

  // Click "Delegate (-cc)"
  const delegateBtn = chip.locator('.validate-btn', { hasText: 'Delegate' });
  await expect(delegateBtn).toBeVisible({ timeout: 5000 });
  await delegateBtn.click();

  // Bounty modal appears
  await expect(page1.getByText('Delegate Task')).toBeVisible({ timeout: 5000 });

  // Enter bounty amount
  await page1.locator('input[type="number"]').fill('10');
  await page1.getByRole('button', { name: 'Offer Bounty', exact: true }).click();

  // Modal closes, chip now shows the offering amount
  await expect(page1.locator('.scheduled-chip', { hasText: 'Evening Care' })
    .locator('text=Offering')).toBeVisible({ timeout: 8000 });

  // ── User2: navigate to same day, accept the bounty ──────────
  await page2.goto(`/daily/${dateStr}`);
  await page2.waitForLoadState('networkidle');

  const takeOverBtn = page2.locator('.scheduled-chip', { hasText: 'Evening Care' })
    .locator('.validate-btn', { hasText: 'Take Over' });
  await expect(takeOverBtn).toBeVisible({ timeout: 10000 });
  await takeOverBtn.click();

  // Accept bounty modal — use heading to avoid strict mode violation (heading + button both say "Claim task")
  await expect(page2.getByRole('heading', { name: 'Claim task' })).toBeVisible({ timeout: 5000 });
  await page2.getByRole('button', { name: 'Claim task', exact: true }).click();

  // Evening Care chip should no longer show "Take Over" for user2 (now their task)
  await expect(takeOverBtn).not.toBeVisible({ timeout: 8000 });

  await ctx1.close();
  await ctx2.close();
});
