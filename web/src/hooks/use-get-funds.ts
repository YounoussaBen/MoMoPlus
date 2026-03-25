"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { container } from "@/di/container";
import { getFundsKeys } from "@/utils/query-keys";
import type { TableQueryInput } from "@/utils/query-params";

export function useGetFundsList(input: TableQueryInput) {
  return useQuery({
    queryKey: getFundsKeys.list(input),
    queryFn: () => container.getFundsService.listGetFunds(input),
    placeholderData: keepPreviousData,
  });
}

export function useGetFundsDetail(id: string) {
  return useQuery({
    queryKey: getFundsKeys.detail(id),
    queryFn: () => container.getFundsService.getGetFundsDetail(id),
    enabled: !!id,
  });
}
