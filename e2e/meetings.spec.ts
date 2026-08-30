import { expect, test } from "@playwright/test";
import { registerViaUi, uniqueEmail } from "./support/helpers";

test.describe("Meetings", () => {
  test("a user can create a meeting, see it in the list, and open its details", async ({
    page,
  }) => {
    await registerViaUi(page, uniqueEmail());

    const title = `Sprint planning ${Math.random().toString(36).slice(2, 8)}`;
    const description = "Plan the next two weeks of work.";

    // Create a meeting.
    await page.getByRole("link", { name: "New meeting" }).click();
    await expect(page).toHaveURL("/meetings/new");

    await page.getByLabel("Title").fill(title);
    await page.getByLabel("Starts at").fill("2026-12-01T10:00");
    await page.getByLabel("Description").fill(description);
    await page.getByRole("button", { name: "Create meeting" }).click();

    // Land on the detail page for the new meeting.
    await expect(page).toHaveURL(/\/meetings\/\d+$/);
    await expect(page.getByRole("heading", { name: title })).toBeVisible();
    await expect(page.getByText(description)).toBeVisible();

    // The meeting shows up in the list on the home page.
    await page.goto("/");
    await expect(page.getByText(title)).toBeVisible();

    // And the list entry links back to the detail page.
    await page.getByRole("link", { name: title }).click();
    await expect(page).toHaveURL(/\/meetings\/\d+$/);
    await expect(page.getByRole("heading", { name: title })).toBeVisible();
  });

  test("creating a meeting without a title shows a validation error", async ({ page }) => {
    await registerViaUi(page, uniqueEmail());

    await page.getByRole("link", { name: "New meeting" }).click();
    await page.getByLabel("Starts at").fill("2026-12-01T10:00");
    await page.getByRole("button", { name: "Create meeting" }).click();

    // The required Title field is flagged client-side and the form never submits.
    await expect(page.getByLabel("Title")).toHaveAttribute("aria-invalid", "true");
    await expect(page).toHaveURL("/meetings/new");
  });
});
