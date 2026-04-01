"use client";

import { use } from "react";
import { Users, Phone } from "lucide-react";
import {
  useUserDetail,
  DetailHeader,
  UserDetailSkeleton,
  DetailNotFound,
  ProfileSection,
  Section,
} from "@/components/dashboard/user-detail-shared";
import { useUserGuarantors } from "@/hooks/use-users";
import { Badge } from "@/components/ui/badge";
import type { LoanGuarantor } from "@/lib/types";

function GuarantorsSection({ userId }: { userId: string }) {
  const { data: guarantors, isLoading } = useUserGuarantors(userId);

  if (isLoading) {
    return (
      <Section icon={Users} title="Loan Guarantors">
        <div className="flex items-center justify-center py-8">
          <div className="border-primary h-5 w-5 animate-spin rounded-full border-2 border-t-transparent" />
        </div>
      </Section>
    );
  }

  if (!guarantors?.length) {
    return (
      <Section icon={Users} title="Loan Guarantors" badge={<Badge variant="muted">0</Badge>}>
        <p className="text-muted-foreground py-4 text-center text-sm">No guarantors added yet.</p>
      </Section>
    );
  }

  return (
    <Section
      icon={Users}
      title="Loan Guarantors"
      badge={<Badge variant="muted">{guarantors.length}</Badge>}
    >
      <div className="space-y-3">
        {guarantors.map((g: LoanGuarantor) => (
          <div
            key={g.id}
            className="border-border/50 flex items-center gap-4 rounded-lg border p-3"
          >
            <div className="bg-primary/10 flex h-9 w-9 shrink-0 items-center justify-center rounded-full">
              <Users size={16} className="text-primary" />
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-foreground text-sm font-medium">{g.name}</p>
              <p className="text-muted-foreground flex items-center gap-1 text-xs">
                <Phone size={11} />
                {g.phone_number}
              </p>
            </div>
          </div>
        ))}
      </div>
    </Section>
  );
}

export default function UserDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const { user, loading } = useUserDetail(id);

  if (loading) return <UserDetailSkeleton />;
  if (!user) return <DetailNotFound backHref="/dashboard/users" />;

  return (
    <div className="space-y-6">
      <DetailHeader user={user} backHref="/dashboard/users" />
      <ProfileSection user={user} />
      <GuarantorsSection userId={id} />
    </div>
  );
}
