"use client";

import { use } from "react";
import {
  useUserDetail,
  DetailHeader,
  UserDetailSkeleton,
  DetailNotFound,
  ProfileSection,
} from "@/components/dashboard/user-detail-shared";

export default function UserDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const { user, loading } = useUserDetail(id);

  if (loading) return <UserDetailSkeleton />;
  if (!user) return <DetailNotFound backHref="/dashboard/users" />;

  return (
    <div className="space-y-6">
      <DetailHeader user={user} backHref="/dashboard/users" />
      <ProfileSection user={user} />
    </div>
  );
}
