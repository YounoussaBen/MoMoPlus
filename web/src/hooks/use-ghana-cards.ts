"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { container } from "@/di/container";
import type { GhanaCardRecordInput } from "@/repositories/ghana-cards.repository";
import { ghanaCardsKeys } from "@/utils/query-keys";
import type { TableQueryInput } from "@/utils/query-params";

export function useGhanaCardsList(input: TableQueryInput) {
  return useQuery({
    queryKey: ghanaCardsKeys.list(input),
    queryFn: () => container.ghanaCardsService.list(input),
    placeholderData: keepPreviousData,
  });
}

export interface CreateGhanaCardForm extends GhanaCardRecordInput {
  frontFile: File;
  backFile: File;
}

export function useCreateGhanaCard() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ frontFile, backFile, ...input }: CreateGhanaCardForm) => {
      const [cardFrontId, cardBackId] = await Promise.all([
        container.ghanaCardsService.uploadImage(frontFile),
        container.ghanaCardsService.uploadImage(backFile),
      ]);
      return container.ghanaCardsService.create({
        ...input,
        card_front_id: cardFrontId,
        card_back_id: cardBackId,
      });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ghanaCardsKeys.all });
    },
  });
}

export function useToggleGhanaCard() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      container.ghanaCardsService.setActive(id, isActive),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ghanaCardsKeys.all });
    },
  });
}
