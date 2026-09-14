"use client";

import { use, useState } from "react";
import { Ban, CheckCircle, FileCheck, Pencil, Phone, Users, XCircle } from "lucide-react";
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
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Modal } from "@/components/ui/modal";
import { useApproveKyc, useKycSubmissionDetail, useRejectKyc } from "@/hooks/use-kyc";
import { useDeactivateUser, useUpdateUserReviewData, useUserGuarantors } from "@/hooks/use-users";
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
  const [isEditOpen, setIsEditOpen] = useState(false);
  const kycQuery = useKycSubmissionDetail(user?.kyc_submission?.id ?? "");
  const approveKycMutation = useApproveKyc();
  const rejectKycMutation = useRejectKyc();
  const deactivateUserMutation = useDeactivateUser();
  const updateReviewDataMutation = useUpdateUserReviewData();
  const actionLoading =
    approveKycMutation.isPending ||
    rejectKycMutation.isPending ||
    deactivateUserMutation.isPending ||
    updateReviewDataMutation.isPending;

  if (loading || (user?.kyc_submission && kycQuery.isLoading)) return <UserDetailSkeleton />;
  if (!user) return <DetailNotFound backHref="/dashboard/users" />;

  const kyc = kycQuery.data ?? null;
  const canEditReviewData =
    !user.is_staff &&
    !user.is_superuser &&
    user.kyc_status !== "approved" &&
    kyc?.status !== "approved";

  const handleReviewDataSave = async (formData: FormData) => {
    const firstName = String(formData.get("first_name") ?? "").trim();
    const lastName = String(formData.get("last_name") ?? "").trim();

    if (!firstName || !lastName) return;

    try {
      await updateReviewDataMutation.mutateAsync({
        id: user.id,
        input: {
          first_name: firstName,
          last_name: lastName,
        },
      });
      setIsEditOpen(false);
    } catch {
      // The mutation displays the API error as a toast and keeps the form open.
    }
  };

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
      <ProfileSection
        user={user}
        action={
          canEditReviewData ? (
            <Button variant="outline" size="sm" onClick={() => setIsEditOpen(true)}>
              <Pencil size={14} />
              Edit details
            </Button>
          ) : undefined
        }
      />

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

      {isEditOpen && (
        <Modal
          open
          onClose={() => setIsEditOpen(false)}
          title="Edit user details"
          description="Correct the user's name before completing the identity review."
          closeDisabled={updateReviewDataMutation.isPending}
          className="max-w-lg"
        >
          <form
            key={`${user.id}:${user.updated_at}:${kyc?.updated_at ?? "no-kyc"}`}
            className="flex min-h-0 flex-col"
            onSubmit={(event) => {
              event.preventDefault();
              void handleReviewDataSave(new FormData(event.currentTarget));
            }}
          >
            <div className="space-y-5 overflow-y-auto px-5 py-6 sm:px-7">
              <div className="grid gap-4 sm:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="review-first-name">First name</Label>
                  <Input
                    id="review-first-name"
                    name="first_name"
                    defaultValue={user.first_name}
                    autoComplete="given-name"
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="review-last-name">Last name</Label>
                  <Input
                    id="review-last-name"
                    name="last_name"
                    defaultValue={user.last_name}
                    autoComplete="family-name"
                    required
                  />
                </div>
              </div>
            </div>

            <div className="border-border/70 flex flex-col-reverse gap-3 border-t px-5 py-4 sm:flex-row sm:justify-end sm:px-7">
              <Button
                type="button"
                variant="outline"
                onClick={() => setIsEditOpen(false)}
                disabled={updateReviewDataMutation.isPending}
              >
                Cancel
              </Button>
              <Button type="submit" disabled={updateReviewDataMutation.isPending}>
                {updateReviewDataMutation.isPending ? "Saving..." : "Save changes"}
              </Button>
            </div>
          </form>
        </Modal>
      )}

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
