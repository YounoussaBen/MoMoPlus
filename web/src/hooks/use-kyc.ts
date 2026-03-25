"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { container } from "@/di/container";
import { kycKeys } from "@/utils/query-keys";
import type { TableQueryInput } from "@/utils/query-params";

export function useKycList(input: TableQueryInput) {
  return useQuery({
    queryKey: kycKeys.list(input),
    queryFn: () => container.kycService.listKyc(input),
    placeholderData: keepPreviousData,
  });
}

export function useKycDetail(id: string) {
  return useQuery({
    queryKey: kycKeys.detail(id),
    queryFn: () => container.kycService.getKycDetail(id),
    enabled: !!id,
  });
}

export function useApproveKyc() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => container.kycService.approveKyc(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: kycKeys.all });
    },
  });
}

export function useRejectKyc() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, reason }: { id: string; reason?: string }) =>
      container.kycService.rejectKyc(id, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: kycKeys.all });
    },
  });
}
