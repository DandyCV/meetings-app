"use client";

import { Alert, Button, Card, FieldError, Form, Input, Label, TextField } from "@heroui/react";
import NextLink from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { useAuth } from "@/context/AuthContext";
import { ApiError } from "@/lib/api";

export default function RegisterPage() {
  const { register } = useAuth();
  const router = useRouter();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [passwordConfirmation, setPasswordConfirmation] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setIsSubmitting(true);

    try {
      await register(email, password, passwordConfirmation);
      router.push("/");
    } catch (err) {
      if (err instanceof ApiError) {
        setError(err.errors.length > 0 ? err.errors.join(", ") : err.message);
      } else {
        setError("Something went wrong");
      }
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <main className="flex min-h-screen flex-1 items-center justify-center p-4">
      <Card className="w-full max-w-sm">
        <Card.Header>
          <Card.Title>Sign up</Card.Title>
          <Card.Description>Create an account to get started</Card.Description>
        </Card.Header>

        <Form onSubmit={handleSubmit}>
          <Card.Content>
            <div className="flex flex-col gap-4">
              {error && (
                <Alert status="danger">
                  <Alert.Indicator />
                  <Alert.Content>
                    <Alert.Title>{error}</Alert.Title>
                  </Alert.Content>
                </Alert>
              )}

              <TextField
                isRequired
                name="email"
                type="email"
                autoComplete="email"
                value={email}
                onChange={setEmail}
              >
                <Label>Email</Label>
                <Input placeholder="you@example.com" />
                <FieldError />
              </TextField>

              <TextField
                isRequired
                name="password"
                type="password"
                autoComplete="new-password"
                minLength={8}
                value={password}
                onChange={setPassword}
              >
                <Label>Password</Label>
                <Input placeholder="••••••••" />
                <FieldError />
              </TextField>

              <TextField
                isRequired
                name="password-confirmation"
                type="password"
                autoComplete="new-password"
                minLength={8}
                value={passwordConfirmation}
                onChange={setPasswordConfirmation}
              >
                <Label>Confirm password</Label>
                <Input placeholder="••••••••" />
                <FieldError />
              </TextField>
            </div>
          </Card.Content>

          <Card.Footer className="mt-2 flex flex-col gap-3">
            <Button className="w-full" type="submit" isPending={isSubmitting}>
              {isSubmitting ? "Creating account…" : "Sign up"}
            </Button>
            <p className="text-muted-foreground text-center text-sm">
              Already have an account?{" "}
              <NextLink className="link" href="/login">
                Log in
              </NextLink>
            </p>
          </Card.Footer>
        </Form>
      </Card>
    </main>
  );
}
