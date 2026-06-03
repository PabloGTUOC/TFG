// Shared auth helper for E2E tests.
// Real Google sign-in requires manual interaction so E2E tests that need auth
// should be run against a seeded test account or use the invite-link join flow.
// This file provides page helpers used across test files.

export async function waitForDashboard(page) {
  await page.waitForURL('**/dashboard', { timeout: 15000 });
}

export async function navigateToLogin(page) {
  await page.goto('/login');
  await page.waitForLoadState('networkidle');
}
