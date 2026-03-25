import type { AxiosInstance } from "axios";
import { apiClient } from "@/repositories/api/client";
import type { ApiQueryParamValue } from "@/utils/query-params";
import { staffLoanDetailSchema, staffLoansPageSchema } from "@/validators/get-funds";

export class GetFundsRepository {
  constructor(private readonly client: AxiosInstance = apiClient) {}

  async list(params: Record<string, ApiQueryParamValue>) {
    const { data } = await this.client.get("/api/staff/loans/", { params });
    return staffLoansPageSchema.parse(data);
  }

  async getById(id: string) {
    const { data } = await this.client.get(`/api/staff/loans/${id}/`);
    return staffLoanDetailSchema.parse(data);
  }
}
