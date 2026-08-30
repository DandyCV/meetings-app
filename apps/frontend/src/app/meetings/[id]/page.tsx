"use client";

import { Card, Spinner, Typography } from "@heroui/react";
import NextLink from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useAuth } from "@/context/AuthContext";
import { ApiError } from "@/lib/api";
import { fetchMeeting, formatMeetingDate, type Meeting } from "@/lib/meetings";
import { getToken } from "@/lib/token";

type LoadState =
  { status: "loading" } | { status: "ready"; meeting: Meeting } | { status: "not-found" };

export default function MeetingPage() {
  const { user, isLoading } = useAuth();
  const router = useRouter();
  const params = useParams<{ id: string }>();

  const [state, setState] = useState<LoadState>({ status: "loading" });

  // Guard the route: send anyone without a session to /login.
  useEffect(() => {
    if (!isLoading && !user) {
      router.replace("/login");
    }
  }, [isLoading, user, router]);

  useEffect(() => {
    if (!user) return;

    fetchMeeting(params.id, getToken())
      .then((meeting) => setState({ status: "ready", meeting }))
      .catch((err) => {
        if (err instanceof ApiError && err.status === 404) {
          setState({ status: "not-found" });
        } else {
          throw err;
        }
      });
  }, [user, params.id]);

  if (isLoading || !user || state.status === "loading") {
    return (
      <div className="flex flex-1 items-center justify-center">
        <Spinner />
      </div>
    );
  }

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col gap-6 p-4 py-8 sm:p-8">
      <NextLink className="link text-sm" href="/">
        ← Back to meetings
      </NextLink>

      {state.status === "not-found" ? (
        <Typography color="muted">This meeting could not be found.</Typography>
      ) : (
        <Card>
          <Card.Header>
            <Card.Title>{state.meeting.title}</Card.Title>
            <Card.Description>{formatMeetingDate(state.meeting.starts_at)}</Card.Description>
          </Card.Header>
          {state.meeting.description && (
            <Card.Content>
              <Typography type="body-sm">{state.meeting.description}</Typography>
            </Card.Content>
          )}
        </Card>
      )}
    </main>
  );
}
