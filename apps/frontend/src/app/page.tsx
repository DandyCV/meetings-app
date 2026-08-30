"use client";

import { Button, Card, Spinner, Typography } from "@heroui/react";
import NextLink from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useAuth } from "@/context/AuthContext";
import { fetchMeetings, formatMeetingDate, type Meeting } from "@/lib/meetings";
import { getToken } from "@/lib/token";

const DETAILED_COUNT = 3;

export default function Home() {
  const { user, isLoading, logout } = useAuth();
  const router = useRouter();

  const [meetings, setMeetings] = useState<Meeting[] | null>(null);

  // Guard the route: send anyone without a session to /login.
  useEffect(() => {
    if (!isLoading && !user) {
      router.replace("/login");
    }
  }, [isLoading, user, router]);

  useEffect(() => {
    if (!user) return;

    fetchMeetings(getToken()).then(setMeetings);
  }, [user]);

  if (isLoading || !user) {
    return (
      <div className="flex flex-1 items-center justify-center">
        <Spinner />
      </div>
    );
  }

  const detailedMeetings = meetings?.slice(0, DETAILED_COUNT) ?? [];
  const remainingMeetings = meetings?.slice(DETAILED_COUNT) ?? [];

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col gap-8 p-4 py-8 sm:p-8">
      <header className="flex items-center justify-between gap-4">
        <Typography className="min-w-0 truncate" title={user.email} type="h4">
          {user.email}
        </Typography>
        <div className="flex shrink-0 items-center gap-3">
          <Button render={(props) => <NextLink {...props} href="/meetings/new" />}>
            New meeting
          </Button>
          <Button
            variant="secondary"
            onPress={() => {
              logout();
              router.push("/login");
            }}
          >
            Log out
          </Button>
        </div>
      </header>

      <section className="flex flex-col gap-4">
        <Typography type="h3">Latest meetings</Typography>

        {meetings === null && (
          <div className="flex items-center gap-2">
            <Spinner size="sm" />
            <Typography color="muted">Loading meetings…</Typography>
          </div>
        )}

        {meetings !== null && meetings.length === 0 && (
          <div className="flex flex-col items-start gap-3">
            <Typography color="muted">You don&apos;t have any meetings yet.</Typography>
            <Button
              variant="secondary"
              render={(props) => <NextLink {...props} href="/meetings/new" />}
            >
              Create your first meeting
            </Button>
          </div>
        )}

        {detailedMeetings.length > 0 && (
          <div className="flex flex-col gap-4">
            {detailedMeetings.map((meeting) => (
              <Card
                key={meeting.id}
                className="hover:border-default-400 relative transition-colors"
              >
                <Card.Header>
                  <Card.Title>
                    <NextLink
                      className="link after:absolute after:inset-0"
                      href={`/meetings/${meeting.id}`}
                    >
                      {meeting.title}
                    </NextLink>
                  </Card.Title>
                  <Card.Description>{formatMeetingDate(meeting.starts_at)}</Card.Description>
                </Card.Header>
                {meeting.description && (
                  <Card.Content>
                    <Typography type="body-sm">{meeting.description}</Typography>
                  </Card.Content>
                )}
              </Card>
            ))}
          </div>
        )}
      </section>

      {remainingMeetings.length > 0 && (
        <section className="flex flex-col gap-4">
          <Typography type="h3">All meetings</Typography>
          <Card className="divide-border divide-y p-0">
            {remainingMeetings.map((meeting) => (
              <NextLink
                key={meeting.id}
                href={`/meetings/${meeting.id}`}
                className="hover:bg-default-100 flex min-h-11 items-center justify-between gap-4 px-4 py-3 transition-colors first:rounded-t-[inherit] last:rounded-b-[inherit]"
              >
                <span className="font-medium">{meeting.title}</span>
                <Typography color="muted" type="body-sm">
                  {formatMeetingDate(meeting.starts_at)}
                </Typography>
              </NextLink>
            ))}
          </Card>
        </section>
      )}
    </main>
  );
}
