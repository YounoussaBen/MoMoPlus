"use client";

import { use, useState, useCallback } from "react";
import { FileCheck, CheckCircle, XCircle } from "lucide-react";
import { apiFetch } from "@/lib/api";
import { formatDate, formatIdType } from "@/lib/format";
import type { KycSubmissionDetail, PaginatedResponse, AppUserDetail } from "@/lib/types";
import { Badge } from "@/components/ui/badge";
import { ConfirmModal } from "@/components/modals/confirm-modal";
import { RejectModal } from "@/components/modals/reject-modal";
import { ContentViewerModal, useContentViewer } from "@/components/modals/content-viewer-modal";
import {
  useUserDetail,
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

  const [kyc, setKyc] = useState<KycSubmissionDetail | null>(null);
  const [kycModal, setKycModal] = useState<"approve" | "reject" | null>(null);
  const [actionLoading, setActionLoading] = useState(false);

  const fetchExtra = useCallback(async (userRes: AppUserDetail) => {
    try {
      const kycRes = await apiFetch<PaginatedResponse<KycSubmissionDetail>>(
        `/api/staff/kyc/?search=${encodeURIComponent(userRes.email)}&page_size=1`,
      );
      if (kycRes.results.length > 0) {
        const kycDetail = await apiFetch<KycSubmissionDetail>(
          `/api/staff/kyc/${kycRes.results[0].id}/`,
        );
        setKyc(kycDetail);
      }
    } catch {
      /* no KYC */
    }
  }, []);

  const { user, loading, refetch } = useUserDetail(id, fetchExtra);

  if (loading) return <KycDetailSkeleton />;
  if (!user) return <DetailNotFound backHref="/dashboard/kyc" />;

  const handleKycAction = async (reason?: string) => {
    if (!kycModal || !kyc) return;
    setActionLoading(true);
    try {
      const endpoint =
        kycModal === "approve"
          ? `/api/staff/kyc/${kyc.id}/approve/`
          : `/api/staff/kyc/${kyc.id}/reject/`;
      await apiFetch(endpoint, {
        method: "POST",
        body: kycModal === "reject" ? JSON.stringify({ reason }) : undefined,
      });
      setKycModal(null);
      refetch();
    } catch {
      /* keep modal open */
    } finally {
      setActionLoading(false);
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
                <button
                  onClick={() => setKycModal("approve")}
                  className="flex items-center gap-1.5 rounded-lg bg-green-600 px-3 py-1.5 text-sm font-medium text-white transition-colors hover:bg-green-700"
                >
                  <CheckCircle size={14} />
                  Approve
                </button>
                <button
                  onClick={() => setKycModal("reject")}
                  className="flex items-center gap-1.5 rounded-lg bg-red-600 px-3 py-1.5 text-sm font-medium text-white transition-colors hover:bg-red-700"
                >
                  <XCircle size={14} />
                  Reject
                </button>
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
                  <span className="text-red-500">{kyc.rejection_reason}</span>
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
          confirmClassName="bg-green-600 text-white hover:bg-green-700"
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
