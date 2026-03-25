"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/context/auth-context";

export default function RootPage() {
  const { user, hydrated } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (hydrated) {
      router.replace(user ? "/dashboard" : "/login");
    }
  }, [user, hydrated, router]);

  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="border-primary h-8 w-8 animate-spin rounded-full border-4 border-t-transparent" />
    </div>
  );
}
