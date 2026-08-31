import { API_URL, apiFetch } from "@/lib/api";

export type Meeting = {
  id: number;
  title: string;
  description: string | null;
  starts_at: string;
  attachments_count: number;
};

export type ProcessingStatus = "pending" | "processed" | "failed";

export type MeetingAttachment = {
  id: number;
  meeting_id: number;
  filename: string;
  byte_size: number;
  content_type: string;
  processing_status: ProcessingStatus;
  processed_at: string | null;
  created_at: string;
  download_url: string;
};

/** Mirrors the backend limit (MeetingAttachment::MAX_FILE_SIZE). */
export const MAX_ATTACHMENT_BYTES = 25 * 1024 * 1024;

/** Mirrors the backend allowlist (MeetingAttachment::ALLOWED_CONTENT_TYPES). */
export const ALLOWED_ATTACHMENT_TYPES = [
  "application/pdf",
  "text/plain",
  "image/png",
  "image/jpeg",
  "image/gif",
  "image/webp",
  "audio/mpeg",
  "audio/wav",
  "audio/mp4",
  "video/mp4",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.ms-powerpoint",
  "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  "application/vnd.ms-excel",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
];

export type NewMeeting = {
  title: string;
  description: string;
  starts_at: string;
};

export function formatMeetingDate(isoDate: string): string {
  return new Date(isoDate).toLocaleString(undefined, {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

export function fetchMeetings(token: string | null): Promise<Meeting[]> {
  return apiFetch<Meeting[]>("/meetings", { token });
}

export function fetchMeeting(id: string | number, token: string | null): Promise<Meeting> {
  return apiFetch<Meeting>(`/meetings/${id}`, { token });
}

export function createMeeting(meeting: NewMeeting, token: string | null): Promise<Meeting> {
  return apiFetch<Meeting>("/meetings", { method: "POST", body: { meeting }, token });
}

export function fetchAttachments(
  meetingId: number | string,
  token: string | null,
): Promise<MeetingAttachment[]> {
  return apiFetch<MeetingAttachment[]>(`/meetings/${meetingId}/attachments`, { token });
}

export function uploadAttachment(
  meetingId: number | string,
  file: File,
  token: string | null,
): Promise<MeetingAttachment> {
  const form = new FormData();
  form.append("attachment[file]", file);
  return apiFetch<MeetingAttachment>(`/meetings/${meetingId}/attachments`, {
    method: "POST",
    body: form,
    token,
  });
}

export function deleteAttachment(
  meetingId: number | string,
  id: number,
  token: string | null,
): Promise<void> {
  return apiFetch<null>(`/meetings/${meetingId}/attachments/${id}`, {
    method: "DELETE",
    token,
  }).then(() => undefined);
}

/** Fetch the blob with the auth header and hand it to the browser as a download. */
export async function downloadAttachment(
  attachment: MeetingAttachment,
  token: string | null,
): Promise<void> {
  const response = await fetch(`${new URL(API_URL).origin}${attachment.download_url}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (!response.ok) {
    throw new Error(`Download failed (${response.status})`);
  }
  const blob = await response.blob();
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = attachment.filename;
  document.body.appendChild(link);
  link.click();
  setTimeout(() => {
    link.remove();
    URL.revokeObjectURL(url);
  }, 0);
}

export function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  const units = ["KB", "MB", "GB"];
  let size = bytes / 1024;
  let unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }
  return `${size.toFixed(1)} ${units[unitIndex]}`;
}
