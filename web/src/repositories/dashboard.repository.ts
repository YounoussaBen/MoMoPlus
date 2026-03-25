import type { AxiosInstance } from "axios";

import { apiClient } from "@/repositories/api/client";
import { dashboardOverviewSchema } from "@/validators/dashboard";

export class DashboardRepository {
  constructor(private readonly client: AxiosInstance = apiClient) {}

  async getOverview(days: number) {
    const { data } = await this.client.get("/api/staff/dashboard/", {
      params: { days },
    });
    return dashboardOverviewSchema.parse(data);
  }
}
