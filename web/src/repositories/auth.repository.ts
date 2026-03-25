import type { AxiosInstance } from "axios";
import { apiClient } from "@/repositories/api/client";
import { loginResponseSchema } from "@/validators/auth";

export class AuthRepository {
  constructor(private readonly client: AxiosInstance = apiClient) {}

  async login(email: string, password: string) {
    const { data } = await this.client.post("/api/auth/staff/login/", {
      email,
      password,
    });

    return loginResponseSchema.parse(data);
  }
}
