"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { container } from "@/di/container";
import type { AgentRow } from "@/services/agents.service";
import { agentsKeys, usersKeys } from "@/utils/query-keys";
import type { TableQueryInput } from "@/utils/query-params";

export type { AgentRow };

export function useAgentsList(input: TableQueryInput) {
  return useQuery({
    queryKey: agentsKeys.list(input),
    queryFn: () => container.agentsService.listAgents(input),
    placeholderData: keepPreviousData,
  });
}

export function useAgentDetail(id: string) {
  return useQuery({
    queryKey: agentsKeys.detail(id),
    queryFn: () => container.agentsService.getAgentDetail(id),
    enabled: !!id,
  });
}

export function useApproveAgent() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => container.agentsService.approveAgent(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: usersKeys.all });
      queryClient.invalidateQueries({ queryKey: usersKeys.detail(id) });
      queryClient.invalidateQueries({ queryKey: agentsKeys.all });
      queryClient.invalidateQueries({ queryKey: agentsKeys.detail(id) });
    },
  });
}

export function useRejectAgent() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => container.agentsService.rejectAgent(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: usersKeys.all });
      queryClient.invalidateQueries({ queryKey: usersKeys.detail(id) });
      queryClient.invalidateQueries({ queryKey: agentsKeys.all });
      queryClient.invalidateQueries({ queryKey: agentsKeys.detail(id) });
    },
  });
}

export function useApproveCertification() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => container.agentsService.approveCertification(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: agentsKeys.all });
    },
  });
}

export function useRejectCertification() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, reason }: { id: string; reason?: string }) =>
      container.agentsService.rejectCertification(id, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: agentsKeys.all });
    },
  });
}
