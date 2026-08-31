import path from "node:path";
import { expect, test } from "@playwright/test";
import { createMeetingViaUi, registerViaUi, uniqueEmail } from "./support/helpers";

const FIXTURE = path.join(__dirname, "support/fixtures/sample.txt");

test.describe("Meeting attachments", () => {
  test("shows an empty state, then an uploaded file, then removes it", async ({ page }) => {
    await registerViaUi(page, uniqueEmail());
    await createMeetingViaUi(page, {
      title: `Attach test ${Math.random().toString(36).slice(2, 8)}`,
    });

    // Empty state.
    await expect(page.getByText("No files attached yet")).toBeVisible();

    // Upload.
    await page.getByLabel("Upload file").setInputFiles(FIXTURE);

    const row = page.getByRole("listitem").filter({ hasText: "sample.txt" });
    await expect(row).toBeVisible();
    await expect(row.getByText("Pending")).toBeVisible();

    // Delete (through the confirm dialog).
    await row.getByRole("button", { name: "Delete" }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Delete" }).click();

    await expect(page.getByText("sample.txt")).toHaveCount(0);
    await expect(page.getByText("No files attached yet")).toBeVisible();
  });
});
