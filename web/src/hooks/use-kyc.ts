"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { container } from "@/di/container";
import { kycKeys, usersKeys } from "@/utils/query-keys";

export function useKycSubmissionDetail(id: string) {
  return useQuery({
    queryKey: kycKeys.submission(id),
    queryFn: () => container.kycService.getSubmissionDetail(id),
    enabled: !!id,
  });
}

export function useApproveKyc() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => container.kycService.approveKyc(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: kycKeys.all });
      queryClient.invalidateQueries({ queryKey: usersKeys.all });
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
      queryClient.invalidateQueries({ queryKey: usersKeys.all });
    },
  });
}
