import type { AxiosInstance } from "axios";
import { apiClient } from "@/repositories/api/client";
import { kycSubmissionDetailSchema } from "@/validators/kyc";

export class KycRepository {
  constructor(private readonly client: AxiosInstance = apiClient) {}

  async getById(id: string) {
    const { data } = await this.client.get(`/api/staff/kyc/${id}/`);
    return kycSubmissionDetailSchema.parse(data);
  }

  async approve(id: string) {
    await this.client.post(`/api/staff/kyc/${id}/approve/`);
  }

  async reject(id: string, reason?: string) {
    await this.client.post(`/api/staff/kyc/${id}/reject/`, { reason });
  }
}
