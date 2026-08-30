export type Meeting = {
  id: number;
  title: string;
  description: string | null;
  starts_at: string;
};

export function formatMeetingDate(isoDate: string): string {
  return new Date(isoDate).toLocaleString(undefined, {
    dateStyle: "medium",
    timeStyle: "short",
  });
}
