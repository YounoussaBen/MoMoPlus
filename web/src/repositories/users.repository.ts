import type { AxiosInstance } from "axios";
import { apiClient } from "@/repositories/api/client";
import type { ApiQueryParamValue } from "@/utils/query-params";
import {
  appUserDetailSchema,
  appUsersPageSchema,
  loanGuarantorsArraySchema,
} from "@/validators/users";

export class UsersRepository {
  constructor(private readonly client: AxiosInstance = apiClient) {}

  async list(params: Record<string, ApiQueryParamValue>) {
    const { data } = await this.client.get("/api/staff/users/", { params });
    return appUsersPageSchema.parse(data);
  }

  async getById(id: string) {
    const { data } = await this.client.get(`/api/staff/users/${id}/`);
    return appUserDetailSchema.parse(data);
  }

  async approveAgent(id: string) {
    await this.client.post(`/api/staff/users/${id}/approve-agent/`);
  }

  async rejectAgent(id: string) {
    await this.client.post(`/api/staff/users/${id}/reject-agent/`);
  }

  async deactivate(id: string, reason: string) {
    await this.client.post(`/api/staff/users/${id}/deactivate/`, { reason });
  }

  async getGuarantors(userId: string) {
    const { data } = await this.client.get(`/api/staff/users/${userId}/guarantors/`);
    return loanGuarantorsArraySchema.parse(data);
  }
}
