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
    // "Pending" holds only because the backend runs with queue_adapter = :test
    // (ProcessMeetingAttachmentJob is enqueued, not run). A reused dev-env backend
    // would run the job and flip this to "Processed".
    await expect(row.getByText("Pending")).toBeVisible();

    // Download (fetched with auth, handed to the browser as a blob download).
    const [download] = await Promise.all([
      page.waitForEvent("download"),
      row.getByRole("button", { name: "Download" }).click(),
    ]);
    expect(download.suggestedFilename()).toBe("sample.txt");

    // Delete (through the confirm dialog).
    await row.getByRole("button", { name: "Delete" }).click();
    await page.getByRole("alertdialog").getByRole("button", { name: "Delete" }).click();

    await expect(page.getByText("sample.txt")).toHaveCount(0);
    await expect(page.getByText("No files attached yet")).toBeVisible();
  });
});
