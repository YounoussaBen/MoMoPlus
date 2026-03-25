"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/context/auth-context";
import { DashboardShellSkeleton } from "@/components/dashboard/skeletons";

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const { user, hydrated } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (hydrated && !user) {
      router.replace("/login");
    }
  }, [user, hydrated, router]);

  if (!hydrated || !user) {
    return <DashboardShellSkeleton />;
  }

  return <>{children}</>;
}
