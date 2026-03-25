"use client";

import { useQuery } from "@tanstack/react-query";

import { container } from "@/di/container";
import { dashboardKeys } from "@/utils/query-keys";

export function useDashboardOverview(days: number) {
  return useQuery({
    queryKey: dashboardKeys.overview(days),
    queryFn: () => container.dashboardService.getOverview(days),
  });
}
