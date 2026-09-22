import { corsHeaders } from "./cors.ts";

export function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function errorResponse(status: number, message: string): Response {
  return jsonResponse(status, { error: message });
}

// Mirrors the Firestore version's HttpsError-style rejection: thrown by the
// helpers below, caught once in each function's handler and turned into a
// response with the right status code and message intact.
export class HttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export class ValidationError extends HttpError {
  constructor(message: string) {
    super(400, message);
  }
}

export function requiredString(
  data: Record<string, unknown>,
  field: string,
  maxLength: number,
): string {
  const raw = data[field];
  const value = typeof raw === "string" ? raw.trim() : "";
  if (!value || value.length > maxLength) {
    throw new ValidationError(
      `${field} is required and must be at most ${maxLength} characters.`,
    );
  }
  return value;
}

export function optionalString(
  data: Record<string, unknown>,
  field: string,
  maxLength: number,
): string {
  const raw = data[field];
  const value = typeof raw === "string" ? raw.trim() : "";
  if (value.length > maxLength) {
    throw new ValidationError(
      `${field} must be at most ${maxLength} characters.`,
    );
  }
  return value;
}

export function validatedUid(data: Record<string, unknown>): string {
  const uid = requiredString(data, "uid", 128);
  if (!/^[0-9a-fA-F-]{1,128}$/.test(uid)) {
    throw new ValidationError("Invalid user identifier.");
  }
  return uid;
}
