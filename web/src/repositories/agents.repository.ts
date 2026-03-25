import type { AxiosInstance } from "axios";
import { apiClient } from "@/repositories/api/client";
import type { ApiQueryParamValue } from "@/utils/query-params";
import { agentCertificationsPageSchema } from "@/validators/agents";
import { fileUrlSchema } from "@/validators/common";

export class AgentsRepository {
  constructor(private readonly client: AxiosInstance = apiClient) {}

  async listCertifications(params: Record<string, ApiQueryParamValue>) {
    const { data } = await this.client.get("/api/staff/agents/certifications/", { params });
    return agentCertificationsPageSchema.parse(data);
  }

  async approveCertification(id: string) {
    await this.client.post(`/api/staff/agents/certifications/${id}/approve/`);
  }

  async rejectCertification(id: string, reason?: string) {
    await this.client.post(`/api/staff/agents/certifications/${id}/reject/`, { reason });
  }

  async getFileAccessUrl(fileId: string) {
    const { data } = await this.client.post(`/api/files/${fileId}/access-url/`);
    return fileUrlSchema.parse(data);
  }
}
