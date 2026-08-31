"use client";

import { Alert, AlertDialog, Button, Chip, Spinner, Typography } from "@heroui/react";
import { useEffect, useState } from "react";
import { ApiError } from "@/lib/api";
import {
  ALLOWED_ATTACHMENT_TYPES,
  MAX_ATTACHMENT_BYTES,
  deleteAttachment,
  downloadAttachment,
  fetchAttachments,
  formatFileSize,
  formatMeetingDate,
  uploadAttachment,
  type MeetingAttachment,
  type ProcessingStatus,
} from "@/lib/meetings";
import { getToken } from "@/lib/token";

const STATUS_LABEL: Record<ProcessingStatus, string> = {
  pending: "Pending",
  processed: "Processed",
  failed: "Failed",
};

const STATUS_COLOR: Record<ProcessingStatus, "warning" | "success" | "danger"> = {
  pending: "warning",
  processed: "success",
  failed: "danger",
};

export function MeetingAttachments({ meetingId }: { meetingId: number }) {
  const [attachments, setAttachments] = useState<MeetingAttachment[] | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [pendingDelete, setPendingDelete] = useState<MeetingAttachment | null>(null);

  useEffect(() => {
    fetchAttachments(meetingId, getToken())
      .then(setAttachments)
      .catch(() => setAttachments([]));
  }, [meetingId]);

  async function reload() {
    setAttachments(await fetchAttachments(meetingId, getToken()));
  }

  async function handleFile(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;

    setError(null);
    setNotice(null);

    if (file.size === 0) {
      setError("That file is empty.");
      return;
    }
    if (file.size > MAX_ATTACHMENT_BYTES) {
      setError("That file is larger than the 25 MB limit.");
      return;
    }
    if (file.type && !ALLOWED_ATTACHMENT_TYPES.includes(file.type)) {
      setError(`Files of type ${file.type} are not supported.`);
      return;
    }

    setIsUploading(true);
    try {
      await uploadAttachment(meetingId, file, getToken());
      await reload();
      setNotice("File uploaded.");
    } catch (err) {
      setError(
        err instanceof ApiError
          ? (err.errors[0] ?? err.message)
          : "Upload failed. Please try again.",
      );
    } finally {
      setIsUploading(false);
    }
  }

  async function confirmDelete() {
    if (!pendingDelete) return;
    const target = pendingDelete;
    setPendingDelete(null);
    setError(null);
    setNotice(null);
    try {
      await deleteAttachment(meetingId, target.id, getToken());
      await reload();
      setNotice("File removed.");
    } catch {
      setError("Could not remove that file. Please try again.");
    }
  }

  return (
    <section className="flex flex-col gap-4" aria-labelledby="attachments-heading">
      <Typography id="attachments-heading" type="h4">
        Files
      </Typography>

      <div className="flex flex-col gap-1">
        <label className="text-sm font-medium" htmlFor="attachment-input">
          Upload file
        </label>
        <input
          id="attachment-input"
          type="file"
          aria-label="Upload file"
          disabled={isUploading}
          onChange={handleFile}
          className="text-sm"
        />
        {isUploading && (
          <span className="flex items-center gap-2 text-sm">
            <Spinner size="sm" /> Uploading…
          </span>
        )}
      </div>

      {error && (
        <Alert status="danger">
          <Alert.Indicator />
          <Alert.Content>
            <Alert.Title>Upload problem</Alert.Title>
            <Alert.Description>{error}</Alert.Description>
          </Alert.Content>
        </Alert>
      )}
      {notice && (
        <Alert status="success">
          <Alert.Indicator />
          <Alert.Content>
            <Alert.Description>{notice}</Alert.Description>
          </Alert.Content>
        </Alert>
      )}

      {attachments === null && (
        <div className="flex items-center gap-2">
          <Spinner size="sm" />
          <Typography color="muted">Loading files…</Typography>
        </div>
      )}

      {attachments !== null && attachments.length === 0 && (
        <Typography color="muted">No files attached yet.</Typography>
      )}

      {attachments !== null && attachments.length > 0 && (
        <ul className="divide-y divide-border rounded-lg border">
          {attachments.map((attachment) => (
            <li
              key={attachment.id}
              className="flex flex-wrap items-center justify-between gap-3 p-3"
            >
              <div className="min-w-0">
                <p className="truncate font-medium">{attachment.filename}</p>
                <p className="text-xs text-muted">
                  {formatFileSize(attachment.byte_size)} · {attachment.content_type} ·{" "}
                  {formatMeetingDate(attachment.created_at)}
                </p>
              </div>
              <div className="flex shrink-0 items-center gap-2">
                <Chip
                  color={STATUS_COLOR[attachment.processing_status]}
                  size="sm"
                  variant="primary"
                >
                  {STATUS_LABEL[attachment.processing_status]}
                </Chip>
                <Button
                  size="sm"
                  variant="secondary"
                  onPress={() => {
                    void downloadAttachment(attachment, getToken()).catch(() =>
                      setError("Could not download that file. Please try again."),
                    );
                  }}
                >
                  Download
                </Button>
                <Button size="sm" variant="danger" onPress={() => setPendingDelete(attachment)}>
                  Delete
                </Button>
              </div>
            </li>
          ))}
        </ul>
      )}

      <AlertDialog.Backdrop
        isOpen={pendingDelete !== null}
        onOpenChange={(open) => {
          if (!open) setPendingDelete(null);
        }}
      >
        <AlertDialog.Container>
          <AlertDialog.Dialog role="dialog" className="sm:max-w-[400px]">
            <AlertDialog.Header>
              <AlertDialog.Icon status="danger" />
              <AlertDialog.Heading>Delete this file?</AlertDialog.Heading>
            </AlertDialog.Header>
            <AlertDialog.Body>
              <Typography color="muted" type="body-sm">
                {pendingDelete
                  ? `"${pendingDelete.filename}" will be permanently removed from this meeting.`
                  : ""}
              </Typography>
            </AlertDialog.Body>
            <AlertDialog.Footer>
              <Button slot="close" variant="tertiary">
                Cancel
              </Button>
              <Button variant="danger" onPress={confirmDelete}>
                Delete
              </Button>
            </AlertDialog.Footer>
          </AlertDialog.Dialog>
        </AlertDialog.Container>
      </AlertDialog.Backdrop>
    </section>
  );
}
