import { defineConfig, devices } from "@playwright/test";

const FRONTEND_URL = "http://localhost:3000";
const BACKEND_HEALTH_URL = "http://localhost:3001/up";

/**
 * E2E config for the full stack: it boots the Rails API (test env) and the
 * Next.js frontend, then drives them through a real browser.
 */
export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: "list",
  use: {
    baseURL: FRONTEND_URL,
    trace: "on-first-retry",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: [
    {
      command: "npm run e2e:backend",
      url: BACKEND_HEALTH_URL,
      reuseExistingServer: !process.env.CI,
      timeout: 120_000,
    },
    {
      command: "npm run dev:frontend",
      url: FRONTEND_URL,
      reuseExistingServer: !process.env.CI,
      timeout: 120_000,
    },
  ],
});
