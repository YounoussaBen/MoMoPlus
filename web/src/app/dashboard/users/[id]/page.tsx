"use client";

import { use, useState } from "react";
import { Ban, CheckCircle, FileCheck, Phone, Users, XCircle } from "lucide-react";
import {
  DetailHeader,
  DetailNotFound,
  DocCard,
  InfoRow,
  ProfileSection,
  Section,
  STATUS_VARIANT,
  UserDetailSkeleton,
  useUserDetail,
} from "@/components/dashboard/user-detail-shared";
import { ContentViewerModal, useContentViewer } from "@/components/modals/content-viewer-modal";
import { ConfirmModal } from "@/components/modals/confirm-modal";
import { RejectModal } from "@/components/modals/reject-modal";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { useApproveKyc, useKycSubmissionDetail, useRejectKyc } from "@/hooks/use-kyc";
import { useDeactivateUser, useUserGuarantors } from "@/hooks/use-users";
import { formatDate, formatPhone } from "@/lib/format";
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
        {guarantors.map((guarantor: LoanGuarantor) => (
          <div
            key={guarantor.id}
            className="border-border/50 flex items-center gap-4 rounded-lg border p-3"
          >
            <div className="bg-primary/10 flex h-9 w-9 shrink-0 items-center justify-center rounded-full">
              <Users size={16} className="text-primary" />
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-foreground text-sm font-medium">{guarantor.name}</p>
              <p className="text-muted-foreground flex items-center gap-1 text-xs">
                <Phone size={11} />
                {guarantor.phone_number}
              </p>
            </div>
          </div>
        ))}
      </div>
    </Section>
  );
}

type UserAction = "approve-kyc" | "reject-kyc" | "deactivate" | null;

export default function UserDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const { user, loading } = useUserDetail(id);
  const viewer = useContentViewer();
  const [action, setAction] = useState<UserAction>(null);
  const kycQuery = useKycSubmissionDetail(user?.kyc_submission?.id ?? "");
  const approveKycMutation = useApproveKyc();
  const rejectKycMutation = useRejectKyc();
  const deactivateUserMutation = useDeactivateUser();
  const actionLoading =
    approveKycMutation.isPending || rejectKycMutation.isPending || deactivateUserMutation.isPending;

  if (loading || (user?.kyc_submission && kycQuery.isLoading)) return <UserDetailSkeleton />;
  if (!user) return <DetailNotFound backHref="/dashboard/users" />;

  const kyc = kycQuery.data ?? null;

  const handleAction = async (reason?: string) => {
    if (!action) return;
    try {
      if (action === "approve-kyc" && kyc) {
        await approveKycMutation.mutateAsync(kyc.id);
      } else if (action === "reject-kyc" && kyc) {
        await rejectKycMutation.mutateAsync({ id: kyc.id, reason });
      } else if (action === "deactivate") {
        await deactivateUserMutation.mutateAsync({ id: user.id, reason: reason ?? "" });
      }
      setAction(null);
    } catch {
      // Keep the modal open so the API error remains visible.
    }
  };

  const kycAction =
    kyc?.status === "pending" ? (
      <div className="flex items-center gap-2">
        <Button onClick={() => setAction("approve-kyc")} size="sm">
          <CheckCircle size={14} />
          Approve
        </Button>
        <Button onClick={() => setAction("reject-kyc")} variant="destructive" size="sm">
          <XCircle size={14} />
          Reject
        </Button>
      </div>
    ) : user.kyc_status === "approved" && user.is_active ? (
      <Button onClick={() => setAction("deactivate")} variant="destructive" size="sm">
        <Ban size={14} />
        Deactivate account
      </Button>
    ) : undefined;

  return (
    <div className="space-y-6">
      <DetailHeader user={user} backHref="/dashboard/users" />
      <ProfileSection user={user} />

      <Section
        icon={FileCheck}
        title="KYC Review"
        badge={
          <Badge variant={STATUS_VARIANT[user.kyc_status] ?? "muted"}>{user.kyc_status}</Badge>
        }
        action={kycAction}
      >
        {kyc ? (
          <div className="space-y-5">
            <div className="grid gap-4 sm:grid-cols-3">
              <InfoRow label="Identity">Ghana Card</InfoRow>
              <InfoRow label="Ghana Card number">{kyc.ghana_card_number || "—"}</InfoRow>
              <InfoRow label="Verification method">{kyc.verification_method}</InfoRow>
              <InfoRow label="Submitted">{formatDate(kyc.created_at)}</InfoRow>
              <InfoRow label="Reviewed">
                {kyc.reviewed_at ? formatDate(kyc.reviewed_at) : "—"}
              </InfoRow>
              {kyc.rejection_reason && (
                <InfoRow label="Review Reason">
                  <span className="text-destructive">{kyc.rejection_reason}</span>
                </InfoRow>
              )}
            </div>

            <div>
              <p className="text-foreground mb-3 text-sm font-medium">Verification documents</p>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                <DocCard
                  label="Ghana Card front"
                  fileUrl={kyc.id_front_url}
                  onView={(url, title) => viewer.open(url, title, "IMAGE")}
                />
                <DocCard
                  label="Ghana Card back"
                  fileUrl={kyc.id_back_url}
                  onView={(url, title) => viewer.open(url, title, "IMAGE")}
                />
                <DocCard
                  label="Selfie"
                  fileUrl={kyc.selfie_url}
                  onView={(url, title) => viewer.open(url, title, "IMAGE")}
                />
                <DocCard
                  label="Proof of Address"
                  fileUrl={kyc.proof_of_address_url}
                  onView={(url, title) => viewer.open(url, title, "IMAGE")}
                />
              </div>
            </div>
          </div>
        ) : (
          <p className="text-muted-foreground py-4 text-center text-sm">
            This user has not submitted identity verification documents.
          </p>
        )}
      </Section>

      {user.deactivation_reason && (
        <Section
          icon={Ban}
          title="Account Deactivation"
          badge={<Badge variant="destructive">Inactive</Badge>}
        >
          <div className="grid gap-4 sm:grid-cols-2">
            <InfoRow label="Reason">{user.deactivation_reason}</InfoRow>
            <InfoRow label="Deactivated">
              {user.deactivated_at ? formatDate(user.deactivated_at) : "—"}
            </InfoRow>
          </div>
        </Section>
      )}

      <GuarantorsSection userId={id} />

      <ContentViewerModal
        url={viewer.url}
        title={viewer.title}
        type={viewer.type}
        isOpen={viewer.isOpen}
        onClose={viewer.close}
      />

      {action === "approve-kyc" && (
        <ConfirmModal
          title="Approve KYC Submission"
          description={`Approve ${user.full_name || formatPhone(user.phone)}'s identity verification?`}
          confirmLabel="Approve"
          isLoading={actionLoading}
          onConfirm={() => handleAction()}
          onCancel={() => setAction(null)}
        />
      )}
      {action === "reject-kyc" && (
        <RejectModal
          title="Reject KYC Submission"
          description="Provide a reason for rejecting this identity verification."
          isLoading={actionLoading}
          onConfirm={handleAction}
          onCancel={() => setAction(null)}
        />
      )}
      {action === "deactivate" && (
        <RejectModal
          title="Deactivate Account"
          description={`Explain why ${user.full_name || formatPhone(user.phone)}'s account should be deactivated. They will no longer be able to sign in.`}
          reasonPlaceholder="Reason for deactivation (required)"
          confirmLabel="Deactivate"
          isLoading={actionLoading}
          onConfirm={handleAction}
          onCancel={() => setAction(null)}
        />
      )}
    </div>
  );
}
