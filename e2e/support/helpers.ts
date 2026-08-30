import { expect, type Page } from "@playwright/test";

export const PASSWORD = "password123";

/** A fresh, unique email so each test owns its own account. */
export function uniqueEmail(): string {
  const rand = Math.random().toString(36).slice(2, 10);
  return `e2e-${Date.now()}-${rand}@example.com`;
}

/** Register a brand-new account through the UI and land on the home page. */
export async function registerViaUi(page: Page, email: string): Promise<void> {
  await page.goto("/register");

  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password", { exact: true }).fill(PASSWORD);
  await page.getByLabel("Confirm password").fill(PASSWORD);
  await page.getByRole("button", { name: "Sign up" }).click();

  await expect(page).toHaveURL("/");
  await expect(page.getByRole("heading", { name: email })).toBeVisible();
}
