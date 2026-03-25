import { DashboardRepository } from "@/repositories/dashboard.repository";

export class DashboardService {
  constructor(private readonly dashboardRepository: DashboardRepository) {}

  getOverview(days: number) {
    return this.dashboardRepository.getOverview(days);
  }
}
