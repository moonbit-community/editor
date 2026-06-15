import { defineConfig } from '@playwright/test';

const baseURL = process.env.READONLY_EDITOR_BASE_URL || 'http://127.0.0.1:5173';
const serverPort = new URL(baseURL).port || '5173';

export default defineConfig({
  testDir: 'tests/browser',
  timeout: 30_000,
  workers: 1,
  use: {
    baseURL,
    trace: 'on-first-retry'
  },
  webServer: {
    command: `just dev ROOT=docs/fixtures/project PORT=${serverPort}`,
    url: `http://127.0.0.1:${serverPort}`,
    reuseExistingServer: true,
    timeout: 60_000
  }
});
