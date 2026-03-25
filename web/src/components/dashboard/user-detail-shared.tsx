"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { ArrowLeft, Mail, Calendar, Users, Loader2, ImageIcon } from "lucide-react";
import { apiFetch } from "@/lib/api";
import { formatDate } from "@/lib/format";
import type { AppUserDetail } from "@/lib/types";
import type { FileUrl } from "@/lib/types";
import { Badge } from "@/components/ui/badge";

export const STATUS_VARIANT: Record<string, "muted" | "warning" | "success" | "destructive"> = {
  none: "muted",
  pending: "warning",
  approved: "success",
  rejected: "destructive",
};

export function InfoRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-1 sm:flex-row sm:items-center sm:gap-4">
      <span className="text-muted-foreground w-40 shrink-0 text-sm">{label}</span>
      <span className="text-foreground text-sm">{children}</span>
    </div>
  );
}

export function Section({
  icon: Icon,
  title,
  children,
  action,
  badge,
}: {
  icon: React.ElementType;
  title: string;
  children: React.ReactNode;
  action?: React.ReactNode;
  badge?: React.ReactNode;
}) {
  return (
    <div className="border-border/50 bg-card rounded-xl border">
      <div className="border-border/50 flex items-center justify-between border-b px-6 py-4">
        <div className="flex items-center gap-3">
          <Icon size={18} className="text-muted-foreground" />
          <h2 className="text-foreground text-base font-semibold">{title}</h2>
          {badge}
        </div>
        {action}
      </div>
      <div className="px-6 py-5">{children}</div>
    </div>
  );
}

export function DocCard({
  label,
  fileUrl,
  onView,
}: {
  label: string;
  fileUrl: FileUrl | null;
  onView: (url: string, title: string) => void;
}) {
  if (!fileUrl) {
    return (
      <div className="border-border bg-muted/30 flex h-32 flex-col items-center justify-center rounded-xl border border-dashed text-center">
        <ImageIcon size={24} className="text-muted-foreground mb-2" />
        <p className="text-muted-foreground text-xs">{label}</p>
        <p className="text-muted-foreground text-xs">Not uploaded</p>
      </div>
    );
  }

  return (
    <button
      onClick={() => onView(fileUrl.url, label)}
      className="group border-border bg-muted/30 hover:border-primary/50 hover:bg-muted/60 relative flex h-32 flex-col items-center justify-center overflow-hidden rounded-xl border transition-colors"
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={fileUrl.url}
        alt={label}
        className="absolute inset-0 h-full w-full object-cover opacity-80 transition-opacity group-hover:opacity-100"
        onError={(e) => {
          (e.target as HTMLImageElement).style.display = "none";
        }}
      />
      <div className="relative z-10 rounded-lg bg-black/50 px-3 py-2 text-white">
        <p className="text-xs font-medium">{label}</p>
      </div>
    </button>
  );
}

export function useUserDetail(id: string, fetchExtra?: (user: AppUserDetail) => Promise<void>) {
  const [user, setUser] = useState<AppUserDetail | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchAll = useCallback(async () => {
    setLoading(true);
    try {
      const userRes = await apiFetch<AppUserDetail>(`/api/staff/users/${id}/`);
      setUser(userRes);
      if (fetchExtra) await fetchExtra(userRes);
    } catch {
      /* user fetch failed */
    } finally {
      setLoading(false);
    }
  }, [id, fetchExtra]);

  useEffect(() => {
    fetchAll();
  }, [fetchAll]);

  return { user, loading, refetch: fetchAll };
}

export function ProfileSection({ user }: { user: AppUserDetail }) {
  return (
    <Section icon={Users} title="Profile Information">
      <div className="grid gap-4 sm:grid-cols-2">
        <InfoRow label="Full Name">
          {user.first_name} {user.last_name}
        </InfoRow>
        <InfoRow label="Email">
          <span className="flex items-center gap-1.5">
            <Mail size={14} className="text-muted-foreground" />
            {user.email}
          </span>
        </InfoRow>
        <InfoRow label="Role">
          <Badge variant={user.role === "agent" ? "info" : "muted"}>{user.role}</Badge>
        </InfoRow>
        <InfoRow label="Joined">
          <span className="flex items-center gap-1.5">
            <Calendar size={14} className="text-muted-foreground" />
            {formatDate(user.created_at)}
          </span>
        </InfoRow>
      </div>
    </Section>
  );
}

export function DetailHeader({ user, backHref }: { user: AppUserDetail; backHref: string }) {
  const router = useRouter();
  return (
    <div className="flex items-center gap-4">
      <button
        onClick={() => router.push(backHref as never)}
        className="text-muted-foreground hover:bg-muted rounded-lg p-2 transition-colors"
      >
        <ArrowLeft size={20} />
      </button>
      <div className="flex-1">
        <h1 className="text-foreground text-2xl font-bold">
          {user.first_name} {user.last_name}
        </h1>
        <p className="text-muted-foreground text-sm">{user.email}</p>
      </div>
      <div className="flex items-center gap-2">
        <Badge variant={user.role === "agent" ? "info" : "muted"}>{user.role}</Badge>
        <Badge variant={user.is_active ? "success" : "destructive"}>
          {user.is_active ? "Active" : "Inactive"}
        </Badge>
      </div>
    </div>
  );
}

export function DetailLoading() {
  return (
    <div className="flex h-64 items-center justify-center">
      <Loader2 className="text-primary h-8 w-8 animate-spin" />
    </div>
  );
}

export function DetailNotFound({ backHref }: { backHref: string }) {
  const router = useRouter();
  return (
    <div className="flex h-64 flex-col items-center justify-center gap-4">
      <p className="text-muted-foreground">User not found</p>
      <button
        onClick={() => router.push(backHref as never)}
        className="text-primary text-sm hover:underline"
      >
        Go back
      </button>
    </div>
  );
}
