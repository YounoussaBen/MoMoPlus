import type { AxiosInstance } from "axios";
import { apiClient } from "@/repositories/api/client";
import type { UpdateStaffProfileInput } from "@/lib/types";
import { loginResponseSchema, staffProfileSchema } from "@/validators/auth";

export class AuthRepository {
  constructor(private readonly client: AxiosInstance = apiClient) {}

  async login(email: string, password: string) {
    const { data } = await this.client.post("/api/auth/staff/login/", {
      email,
      password,
    });

    return loginResponseSchema.parse(data);
  }

  async getProfile() {
    const { data } = await this.client.get("/api/auth/profile/");
    return staffProfileSchema.parse(data);
  }

  async updateProfile(input: UpdateStaffProfileInput) {
    const { data } = await this.client.patch("/api/auth/profile/", input);
    return staffProfileSchema.parse(data);
  }
}
