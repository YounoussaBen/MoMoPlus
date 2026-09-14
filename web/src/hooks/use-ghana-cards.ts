"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { container } from "@/di/container";
import type { GhanaCardRecordInput } from "@/repositories/ghana-cards.repository";
import { getErrorMessage } from "@/lib/errors";
import { useToast } from "@/components/ui/toast";
import { ghanaCardsKeys } from "@/utils/query-keys";
import type { TableQueryInput } from "@/utils/query-params";

export function useGhanaCardsList(input: TableQueryInput) {
  return useQuery({
    queryKey: ghanaCardsKeys.list(input),
    queryFn: () => container.ghanaCardsService.list(input),
    placeholderData: keepPreviousData,
  });
}

export function useCreateGhanaCard() {
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  return useMutation({
    mutationFn: (input: GhanaCardRecordInput) => container.ghanaCardsService.create(input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ghanaCardsKeys.all });
      success("Card added", "The Ghana Card is now available for automatic verification.");
    },
    onError: (mutationError) => {
      error(
        "Could not add card",
        getErrorMessage(mutationError, "Please review the card details and try again."),
      );
    },
  });
}

export function useUploadGhanaCardImage() {
  return useMutation({
    mutationFn: (file: File) => container.ghanaCardsService.uploadImage(file),
  });
}

export function useDeleteGhanaCardImage() {
  return useMutation({
    mutationFn: (id: string) => container.ghanaCardsService.deleteImage(id),
  });
}

export function useToggleGhanaCard() {
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  return useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      container.ghanaCardsService.setActive(id, isActive),
    onSuccess: (_, { isActive }) => {
      queryClient.invalidateQueries({ queryKey: ghanaCardsKeys.all });
      success(isActive ? "Card activated" : "Card deactivated");
    },
    onError: (mutationError) => {
      error("Could not update card", getErrorMessage(mutationError, "Please try again."));
    },
  });
}
