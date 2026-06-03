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
    // Authenticated tests — load saved session
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'], storageState: 'e2e/auth.state.json' },
      testIgnore: ['**/landing.spec.js', '**/dashboard.spec.js'],
    },
    // Public tests — no auth state
    {
      name: 'chromium-public',
      use: { ...devices['Desktop Chrome'] },
      testMatch: ['**/landing.spec.js', '**/dashboard.spec.js'],
    },
  ],

  webServer: [
    // 1. Firebase Auth Emulator
    {
      command: `firebase emulators:start --only auth --project tfg-carecoins`,
      url: 'http://localhost:9099',
      reuseExistingServer: true,
      timeout: 30000,
      cwd: path.join(__dirname, '..'),
    },
    // 2. Backend (with emulator env var)
    {
      command: 'npm run dev:test',
      url: 'http://localhost:3000/health',
      reuseExistingServer: true,
      timeout: 30000,
      cwd: path.join(__dirname, '../backend'),
    },
    // 3. Frontend (with emulator env var)
    {
      command: 'npm run dev:test',
      url: 'http://localhost:5173',
      reuseExistingServer: true,
      timeout: 30000,
    },
  ],
});
