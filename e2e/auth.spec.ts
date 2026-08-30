import { expect, test } from "@playwright/test";
import { PASSWORD, registerViaUi, uniqueEmail } from "./support/helpers";

test.describe("Authentication", () => {
  test("a visitor can register a new account", async ({ page }) => {
    const email = uniqueEmail();

    await page.goto("/register");
    await page.getByLabel("Email").fill(email);
    await page.getByLabel("Password", { exact: true }).fill(PASSWORD);
    await page.getByLabel("Confirm password").fill(PASSWORD);
    await page.getByRole("button", { name: "Sign up" }).click();

    await expect(page).toHaveURL("/");
    await expect(page.getByRole("heading", { name: email })).toBeVisible();
  });

  test("registration shows an error when the email is already taken", async ({ page }) => {
    const email = uniqueEmail();
    await registerViaUi(page, email);

    // Log out, then try to register with the same email again.
    await page.getByRole("button", { name: "Log out" }).click();
    await expect(page).toHaveURL("/login");

    await page.goto("/register");
    await page.getByLabel("Email").fill(email);
    await page.getByLabel("Password", { exact: true }).fill(PASSWORD);
    await page.getByLabel("Confirm password").fill(PASSWORD);
    await page.getByRole("button", { name: "Sign up" }).click();

    await expect(page.getByText(/email has already been taken/i)).toBeVisible();
    await expect(page).toHaveURL(/\/register$/);
  });

  test("a registered user can log in", async ({ page }) => {
    const email = uniqueEmail();

    // Create the account, then drop the session to start from a clean slate.
    await registerViaUi(page, email);
    await page.getByRole("button", { name: "Log out" }).click();
    await expect(page).toHaveURL("/login");

    await page.goto("/login");
    await page.getByLabel("Email").fill(email);
    await page.getByLabel("Password", { exact: true }).fill(PASSWORD);
    await page.getByRole("button", { name: "Log in" }).click();

    await expect(page).toHaveURL("/");
    await expect(page.getByRole("heading", { name: email })).toBeVisible();
  });

  test("login rejects invalid credentials", async ({ page }) => {
    await page.goto("/login");
    await page.getByLabel("Email").fill(uniqueEmail());
    await page.getByLabel("Password", { exact: true }).fill("wrong-password");
    await page.getByRole("button", { name: "Log in" }).click();

    await expect(page.getByText(/invalid email or password/i)).toBeVisible();
    await expect(page).toHaveURL(/\/login$/);
  });

  test("a logged-in user can log out and is sent back to login", async ({ page }) => {
    const email = uniqueEmail();
    await registerViaUi(page, email);

    await page.getByRole("button", { name: "Log out" }).click();

    await expect(page).toHaveURL("/login");
    await expect(page.getByRole("button", { name: "Log in" })).toBeVisible();

    // The session is really gone: visiting a guarded page bounces to login.
    await page.goto("/");
    await expect(page).toHaveURL("/login");
  });

  test("unauthenticated visitors are redirected from the home page to login", async ({ page }) => {
    await page.goto("/");
    await expect(page).toHaveURL("/login");
  });
});
