"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { container } from "@/di/container";
import { getErrorMessage } from "@/lib/errors";
import { useToast } from "@/components/ui/toast";
import { agentsKeys, kycKeys, usersKeys } from "@/utils/query-keys";
import type { UpdateUserReviewDataInput } from "@/lib/types";
import type { TableQueryInput } from "@/utils/query-params";

export function useUsersList(input: TableQueryInput) {
  return useQuery({
    queryKey: usersKeys.list(input),
    queryFn: () => container.usersService.listUsers(input),
    placeholderData: keepPreviousData,
  });
}

export function useUserDetail(id: string) {
  return useQuery({
    queryKey: usersKeys.detail(id),
    queryFn: () => container.usersService.getUserDetail(id),
    enabled: !!id,
  });
}

export function useUpdateUserReviewData() {
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: UpdateUserReviewDataInput }) =>
      container.usersService.updateReviewData(id, input),
    onSuccess: (updatedUser, { id }) => {
      queryClient.setQueryData(usersKeys.detail(id), updatedUser);
      queryClient.invalidateQueries({ queryKey: usersKeys.all });
      queryClient.invalidateQueries({ queryKey: kycKeys.all });
      success("User details updated", "The corrected information is ready for review.");
    },
    onError: (mutationError) => {
      error("Could not update user details", getErrorMessage(mutationError, "Please try again."));
    },
  });
}

export function useApproveAgentApplication() {
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  return useMutation({
    mutationFn: (id: string) => container.usersService.approveAgent(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: usersKeys.all });
      queryClient.invalidateQueries({ queryKey: usersKeys.detail(id) });
      queryClient.invalidateQueries({ queryKey: agentsKeys.all });
      success("Agent approved", "The user now has agent permissions.");
    },
    onError: (mutationError) => {
      error("Could not approve agent", getErrorMessage(mutationError, "Please try again."));
    },
  });
}

export function useUserGuarantors(userId: string) {
  return useQuery({
    queryKey: usersKeys.guarantors(userId),
    queryFn: () => container.usersService.getUserGuarantors(userId),
    enabled: !!userId,
  });
}

export function useRejectAgentApplication() {
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  return useMutation({
    mutationFn: (id: string) => container.usersService.rejectAgent(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: usersKeys.all });
      queryClient.invalidateQueries({ queryKey: usersKeys.detail(id) });
      queryClient.invalidateQueries({ queryKey: agentsKeys.all });
      success("Agent application rejected");
    },
    onError: (mutationError) => {
      error("Could not reject agent", getErrorMessage(mutationError, "Please try again."));
    },
  });
}

export function useDeactivateUser() {
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  return useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) =>
      container.usersService.deactivateUser(id, reason),
    onSuccess: (_, { id }) => {
      queryClient.invalidateQueries({ queryKey: usersKeys.all });
      queryClient.invalidateQueries({ queryKey: usersKeys.detail(id) });
      queryClient.invalidateQueries({ queryKey: agentsKeys.all });
      success("Account deactivated");
    },
    onError: (mutationError) => {
      error("Could not deactivate account", getErrorMessage(mutationError, "Please try again."));
    },
  });
}
