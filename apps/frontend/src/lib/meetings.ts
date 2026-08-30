import { apiFetch } from "@/lib/api";

export type Meeting = {
  id: number;
  title: string;
  description: string | null;
  starts_at: string;
};

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
