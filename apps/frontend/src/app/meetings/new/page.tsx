"use client";

import {
  Alert,
  Button,
  Card,
  FieldError,
  Form,
  Input,
  Label,
  TextArea,
  TextField,
} from "@heroui/react";
import NextLink from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useAuth } from "@/context/AuthContext";
import { ApiError } from "@/lib/api";
import { createMeeting } from "@/lib/meetings";
import { getToken } from "@/lib/token";

export default function NewMeetingPage() {
  const { user, isLoading } = useAuth();
  const router = useRouter();

  const [title, setTitle] = useState("");
  const [startsAt, setStartsAt] = useState("");
  const [description, setDescription] = useState("");
  const [errors, setErrors] = useState<string[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Guard the route: send anyone without a session to /login.
  useEffect(() => {
    if (!isLoading && !user) {
      router.replace("/login");
    }
  }, [isLoading, user, router]);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setErrors([]);
    setIsSubmitting(true);

    try {
      const meeting = await createMeeting({ title, description, starts_at: startsAt }, getToken());
      router.push(`/meetings/${meeting.id}`);
    } catch (err) {
      if (err instanceof ApiError) {
        setErrors(err.errors.length > 0 ? err.errors : [err.message]);
      } else {
        setErrors(["Something went wrong"]);
      }
      setIsSubmitting(false);
    }
  }

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col gap-6 p-4 py-8 sm:p-8">
      <NextLink className="link text-sm" href="/">
        ← Back to meetings
      </NextLink>

      <Card>
        <Card.Header>
          <Card.Title>New meeting</Card.Title>
          <Card.Description>Schedule a meeting and share the details.</Card.Description>
        </Card.Header>

        <Form onSubmit={handleSubmit}>
          <Card.Content>
            <div className="flex flex-col gap-4">
              {errors.length > 0 && (
                <Alert status="danger">
                  <Alert.Indicator />
                  <Alert.Content>
                    <Alert.Title>Could not create the meeting</Alert.Title>
                    <Alert.Description>
                      <ul className="list-inside list-disc">
                        {errors.map((message) => (
                          <li key={message}>{message}</li>
                        ))}
                      </ul>
                    </Alert.Description>
                  </Alert.Content>
                </Alert>
              )}

              <TextField isRequired name="title" value={title} onChange={setTitle}>
                <Label>Title</Label>
                <Input placeholder="Sprint planning" />
                <FieldError />
              </TextField>

              <TextField
                isRequired
                name="starts_at"
                type="datetime-local"
                value={startsAt}
                onChange={setStartsAt}
              >
                <Label>Starts at</Label>
                <Input />
                <FieldError />
              </TextField>

              <TextField name="description" value={description} onChange={setDescription}>
                <Label>Description</Label>
                <TextArea placeholder="Agenda, links, anything useful…" />
                <FieldError />
              </TextField>
            </div>
          </Card.Content>

          <Card.Footer className="mt-2">
            <Button type="submit" isPending={isSubmitting}>
              {isSubmitting ? "Creating…" : "Create meeting"}
            </Button>
          </Card.Footer>
        </Form>
      </Card>
    </main>
  );
}
