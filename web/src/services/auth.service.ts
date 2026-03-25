import { isAxiosError } from "axios";
import type { UpdateStaffProfileInput } from "@/lib/types";
import { AuthRepository } from "@/repositories/auth.repository";

function extractApiErrorMessage(error: unknown, fallback: string) {
  if (!isAxiosError(error)) return fallback;

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

  return fallback;
}

export class AuthService {
  constructor(private readonly authRepository: AuthRepository) {}

  async login(email: string, password: string) {
    try {
      return await this.authRepository.login(email, password);
    } catch (error) {
      throw new Error(extractApiErrorMessage(error, "Invalid credentials."));
    }
  }

  async getProfile() {
    try {
      return await this.authRepository.getProfile();
    } catch (error) {
      throw new Error(extractApiErrorMessage(error, "Unable to load your profile."));
    }
  }

  async updateProfile(input: UpdateStaffProfileInput) {
    try {
      return await this.authRepository.updateProfile(input);
    } catch (error) {
      throw new Error(extractApiErrorMessage(error, "Unable to update your profile."));
    }
  }
}
