"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import type { UpdateStaffProfileInput } from "@/lib/types";
import { container } from "@/di/container";
import { authKeys } from "@/utils/query-keys";

export function useSettingsProfile() {
  return useQuery({
    queryKey: authKeys.profile(),
    queryFn: () => container.authService.getProfile(),
  });
}

export function useUpdateSettingsProfile() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: UpdateStaffProfileInput) => container.authService.updateProfile(input),
    onSuccess: (profile) => {
      queryClient.setQueryData(authKeys.profile(), profile);
    },
  });
}
