"use client";

import { use, useState } from "react";
import { FileCheck, CheckCircle, XCircle } from "lucide-react";
import { useApproveKyc, useKycDetail, useRejectKyc } from "@/hooks/use-kyc";
import { formatDate, formatIdType } from "@/lib/format";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ConfirmModal } from "@/components/modals/confirm-modal";
import { RejectModal } from "@/components/modals/reject-modal";
import { ContentViewerModal, useContentViewer } from "@/components/modals/content-viewer-modal";
import {
  DetailHeader,
  KycDetailSkeleton,
  DetailNotFound,
  ProfileSection,
  Section,
  InfoRow,
  DocCard,
  STATUS_VARIANT,
} from "@/components/dashboard/user-detail-shared";

export default function KycDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const viewer = useContentViewer();

  const [kycModal, setKycModal] = useState<"approve" | "reject" | null>(null);
  const approveKycMutation = useApproveKyc();
  const rejectKycMutation = useRejectKyc();
  const actionLoading = approveKycMutation.isPending || rejectKycMutation.isPending;
  const kycDetailQuery = useKycDetail(id);
  const user = kycDetailQuery.data?.user ?? null;
  const kyc = kycDetailQuery.data?.kyc ?? null;

  if (kycDetailQuery.isLoading) return <KycDetailSkeleton />;
  if (!user) return <DetailNotFound backHref="/dashboard/kyc" />;

  const handleKycAction = async (reason?: string) => {
    if (!kycModal || !kyc) return;

    try {
      if (kycModal === "approve") {
        await approveKycMutation.mutateAsync(kyc.id);
      } else {
        await rejectKycMutation.mutateAsync({
          id: kyc.id,
          reason,
        });
      }
      setKycModal(null);
    } catch {
      /* keep modal open */
    }
  };

  return (
    <div className="space-y-6">
      <DetailHeader user={user} backHref="/dashboard/kyc" />
      <ProfileSection user={user} />

      {/* KYC Section */}
      {kyc && (
        <Section
          icon={FileCheck}
          title="KYC Submission"
          badge={<Badge variant={STATUS_VARIANT[kyc.status] ?? "muted"}>{kyc.status}</Badge>}
          action={
            kyc.status === "pending" ? (
              <div className="flex items-center gap-2">
                <Button onClick={() => setKycModal("approve")} size="sm">
                  <CheckCircle size={14} />
                  Approve
                </Button>
                <Button onClick={() => setKycModal("reject")} variant="destructive" size="sm">
                  <XCircle size={14} />
                  Reject
                </Button>
              </div>
            ) : undefined
          }
        >
          <div className="space-y-5">
            <div className="grid gap-4 sm:grid-cols-3">
              <InfoRow label="ID Type">{formatIdType(kyc.id_type)}</InfoRow>
              <InfoRow label="Submitted">{formatDate(kyc.created_at)}</InfoRow>
              {kyc.reviewed_at ? (
                <InfoRow label="Reviewed">{formatDate(kyc.reviewed_at)}</InfoRow>
              ) : (
                <div />
              )}
              {kyc.rejection_reason && (
                <InfoRow label="Rejection Reason">
                  <span className="text-destructive">{kyc.rejection_reason}</span>
                </InfoRow>
              )}
            </div>

            <div>
              <p className="text-foreground mb-3 text-sm font-medium">Documents</p>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                <DocCard
                  label="ID Front"
                  fileUrl={kyc.id_front_url}
                  onView={(url, title) => viewer.open(url, title, "IMAGE")}
                />
                <DocCard
                  label="ID Back"
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
        </Section>
      )}

      <ContentViewerModal
        url={viewer.url}
        title={viewer.title}
        type={viewer.type}
        isOpen={viewer.isOpen}
        onClose={viewer.close}
      />

      {kycModal === "approve" && (
        <ConfirmModal
          title="Approve KYC Submission"
          description="This will mark the user's identity as verified."
          confirmLabel="Approve"
          confirmVariant="default"
          isLoading={actionLoading}
          onConfirm={() => handleKycAction()}
          onCancel={() => setKycModal(null)}
        />
      )}
      {kycModal === "reject" && (
        <RejectModal
          title="Reject KYC Submission"
          description="Provide a reason for rejecting this KYC submission."
          isLoading={actionLoading}
          onConfirm={(reason) => handleKycAction(reason)}
          onCancel={() => setKycModal(null)}
        />
      )}
    </div>
  );
}
