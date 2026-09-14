"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import type { UpdateStaffProfileInput } from "@/lib/types";
import { container } from "@/di/container";
import { getErrorMessage } from "@/lib/errors";
import { useToast } from "@/components/ui/toast";
import { authKeys } from "@/utils/query-keys";

export function useSettingsProfile() {
  return useQuery({
    queryKey: authKeys.profile(),
    queryFn: () => container.authService.getProfile(),
  });
}

export function useUpdateSettingsProfile() {
  const queryClient = useQueryClient();
  const { success, error } = useToast();

  return useMutation({
    mutationFn: (input: UpdateStaffProfileInput) => container.authService.updateProfile(input),
    onSuccess: (profile) => {
      queryClient.setQueryData(authKeys.profile(), profile);
      success("Profile updated", "Your staff details have been saved.");
    },
    onError: (mutationError) => {
      error("Could not update profile", getErrorMessage(mutationError, "Please try again."));
    },
  });
}
