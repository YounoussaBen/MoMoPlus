"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { container } from "@/di/container";
import { getErrorMessage } from "@/lib/errors";
import { useToast } from "@/components/ui/toast";
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
  const { success, error } = useToast();

  return useMutation({
    mutationFn: (id: string) => container.kycService.approveKyc(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: kycKeys.all });
      queryClient.invalidateQueries({ queryKey: usersKeys.all });
      success("KYC approved");
    },
    onError: (mutationError) => {
      error("Could not approve KYC", getErrorMessage(mutationError, "Please try again."));
    },
  });
}

export function useRejectKyc() {
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  return useMutation({
    mutationFn: ({ id, reason }: { id: string; reason?: string }) =>
      container.kycService.rejectKyc(id, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: kycKeys.all });
      queryClient.invalidateQueries({ queryKey: usersKeys.all });
      success("KYC rejected");
    },
    onError: (mutationError) => {
      error("Could not reject KYC", getErrorMessage(mutationError, "Please try again."));
    },
  });
}
