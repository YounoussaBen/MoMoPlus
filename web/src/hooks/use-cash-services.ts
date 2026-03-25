"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { container } from "@/di/container";
import { cashServicesKeys } from "@/utils/query-keys";
import type { TableQueryInput } from "@/utils/query-params";

export function useCashServicesList(input: TableQueryInput) {
  return useQuery({
    queryKey: cashServicesKeys.list(input),
    queryFn: () => container.cashServicesService.listCashServices(input),
    placeholderData: keepPreviousData,
  });
}

export function useCashServiceDetail(id: string) {
  return useQuery({
    queryKey: cashServicesKeys.detail(id),
    queryFn: () => container.cashServicesService.getCashServiceDetail(id),
    enabled: !!id,
  });
}
