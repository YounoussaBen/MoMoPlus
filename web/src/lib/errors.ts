import { isAxiosError } from "axios";

export function getErrorMessage(error: unknown, fallback = "Something went wrong.") {
  if (isAxiosError(error)) {
    const detail = error.response?.data?.detail;
    if (typeof detail === "string") return detail;

    const payload = error.response?.data;
    if (payload && typeof payload === "object") {
      for (const value of Object.values(payload as Record<string, unknown>)) {
        if (typeof value === "string") return value;
        if (Array.isArray(value)) {
          const firstMessage = value.find((entry): entry is string => typeof entry === "string");
          if (firstMessage) return firstMessage;
        }
      }
    }
  }

  return error instanceof Error ? error.message : fallback;
}
