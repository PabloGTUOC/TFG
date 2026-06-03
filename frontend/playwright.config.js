import { defineConfig, devices } from '@playwright/test';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  testDir: './e2e',
  globalSetup: './e2e/global.setup.js',
  fullyParallel: false,
  retries: 0,
  timeout: 30000,

  use: {
    baseURL: 'http://localhost:5173',
    headless: true,
    viewport: { width: 1280, height: 720 },
    trace: 'on-first-retry',
  },

  projects: [
    // ── Authenticated as user1 ───────────────────────────────
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'], storageState: 'e2e/auth.state.json' },
      testIgnore: [
        '**/landing.spec.js', '**/dashboard.spec.js',
        '**/onboarding.spec.js', '**/two-users.spec.js',
      ],
    },

    // ── Public (no auth) ─────────────────────────────────────
    {
      name: 'chromium-public',
      use: { ...devices['Desktop Chrome'] },
      testMatch: ['**/landing.spec.js', '**/dashboard.spec.js'],
    },

    // ── Two-user tests (user1 + user2 contexts inside each test)
    {
      name: 'chromium-multi',
      use: { ...devices['Desktop Chrome'], storageState: 'e2e/auth.state.json' },
      testMatch: ['**/two-users.spec.js'],
    },

    // ── Onboarding user (no family) ──────────────────────────
    {
      name: 'chromium-onboard',
      use: { ...devices['Desktop Chrome'], storageState: 'e2e/onboarding.state.json' },
      testMatch: ['**/onboarding.spec.js'],
    },

    // ── WebKit (Safari engine) — happy paths + public ────────
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'], storageState: 'e2e/auth.state.json' },
      testMatch: ['**/happy-paths.spec.js'],
    },
    {
      name: 'webkit-public',
      use: { ...devices['Desktop Safari'] },
      testMatch: ['**/landing.spec.js'],
    },
  ],

  webServer: [
    {
      command: `firebase emulators:start --only auth --project tfg-carecoins`,
      url: 'http://localhost:9099',
      reuseExistingServer: true,
      timeout: 30000,
      cwd: path.join(__dirname, '..'),
    },
    {
      command: 'npm run dev:test',
      url: 'http://localhost:3000/health',
      reuseExistingServer: true,
      timeout: 30000,
      cwd: path.join(__dirname, '../backend'),
    },
    {
      command: 'npm run dev:test',
      url: 'http://localhost:5173',
      reuseExistingServer: true,
      timeout: 30000,
    },
  ],
});
