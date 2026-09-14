"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { container } from "@/di/container";
import { getErrorMessage } from "@/lib/errors";
import { useToast } from "@/components/ui/toast";
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
  const { success, error } = useToast();

  return useMutation({
    mutationFn: (id: string) => container.agentsService.approveAgent(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: usersKeys.all });
      queryClient.invalidateQueries({ queryKey: usersKeys.detail(id) });
      queryClient.invalidateQueries({ queryKey: agentsKeys.all });
      queryClient.invalidateQueries({ queryKey: agentsKeys.detail(id) });
      success("Agent approved");
    },
    onError: (mutationError) => {
      error("Could not approve agent", getErrorMessage(mutationError, "Please try again."));
    },
  });
}

export function useRejectAgent() {
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  return useMutation({
    mutationFn: (id: string) => container.agentsService.rejectAgent(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: usersKeys.all });
      queryClient.invalidateQueries({ queryKey: usersKeys.detail(id) });
      queryClient.invalidateQueries({ queryKey: agentsKeys.all });
      queryClient.invalidateQueries({ queryKey: agentsKeys.detail(id) });
      success("Agent application rejected");
    },
    onError: (mutationError) => {
      error("Could not reject agent", getErrorMessage(mutationError, "Please try again."));
    },
  });
}

export function useApproveCertification() {
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  return useMutation({
    mutationFn: (id: string) => container.agentsService.approveCertification(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: agentsKeys.all });
      success("Certification approved");
    },
    onError: (mutationError) => {
      error("Could not approve certification", getErrorMessage(mutationError, "Please try again."));
    },
  });
}

export function useRejectCertification() {
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  return useMutation({
    mutationFn: ({ id, reason }: { id: string; reason?: string }) =>
      container.agentsService.rejectCertification(id, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: agentsKeys.all });
      success("Certification rejected");
    },
    onError: (mutationError) => {
      error("Could not reject certification", getErrorMessage(mutationError, "Please try again."));
    },
  });
}
