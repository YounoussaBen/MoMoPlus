import type { AxiosInstance } from "axios";
import { apiClient } from "@/repositories/api/client";
import type { ApiQueryParamValue } from "@/utils/query-params";
import {
  staffPhysicalTransactionSchema,
  staffPhysicalTransactionsPageSchema,
} from "@/validators/cash-services";

export class CashServicesRepository {
  constructor(private readonly client: AxiosInstance = apiClient) {}

  async list(params: Record<string, ApiQueryParamValue>) {
    const { data } = await this.client.get("/api/staff/transactions/physical/", { params });
    return staffPhysicalTransactionsPageSchema.parse(data);
  }

  async getById(id: string) {
    const { data } = await this.client.get(`/api/staff/transactions/physical/${id}/`);
    return staffPhysicalTransactionSchema.parse(data);
  }
}
