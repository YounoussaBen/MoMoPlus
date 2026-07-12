"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { container } from "@/di/container";
import { agentsKeys, usersKeys } from "@/utils/query-keys";
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

export function useApproveAgentApplication() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => container.usersService.approveAgent(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: usersKeys.all });
      queryClient.invalidateQueries({ queryKey: usersKeys.detail(id) });
      queryClient.invalidateQueries({ queryKey: agentsKeys.all });
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

  return useMutation({
    mutationFn: (id: string) => container.usersService.rejectAgent(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: usersKeys.all });
      queryClient.invalidateQueries({ queryKey: usersKeys.detail(id) });
      queryClient.invalidateQueries({ queryKey: agentsKeys.all });
    },
  });
}

export function useDeactivateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) =>
      container.usersService.deactivateUser(id, reason),
    onSuccess: (_, { id }) => {
      queryClient.invalidateQueries({ queryKey: usersKeys.all });
      queryClient.invalidateQueries({ queryKey: usersKeys.detail(id) });
      queryClient.invalidateQueries({ queryKey: agentsKeys.all });
    },
  });
}
