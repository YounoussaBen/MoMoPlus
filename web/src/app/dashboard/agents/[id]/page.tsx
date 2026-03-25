"use client";

import { use, useState, useCallback } from "react";
import { UserCog, CreditCard, CheckCircle, XCircle } from "lucide-react";
import { apiFetch } from "@/lib/api";
import { formatDate } from "@/lib/format";
import type { AgentCertification, PaginatedResponse, FileUrl, AppUserDetail } from "@/lib/types";
import { Badge } from "@/components/ui/badge";
import { ConfirmModal } from "@/components/modals/confirm-modal";
import { RejectModal } from "@/components/modals/reject-modal";
import { ContentViewerModal, useContentViewer } from "@/components/modals/content-viewer-modal";
import {
  useUserDetail,
  DetailHeader,
  DetailLoading,
  DetailNotFound,
  ProfileSection,
  Section,
  InfoRow,
  DocCard,
  STATUS_VARIANT,
} from "@/components/dashboard/user-detail-shared";

export default function AgentDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const viewer = useContentViewer();

  const [certification, setCertification] = useState<AgentCertification | null>(null);
  const [certPhotoUrls, setCertPhotoUrls] = useState<Record<string, FileUrl>>({});
  const [agentModal, setAgentModal] = useState<"approve" | "reject" | null>(null);
  const [certModal, setCertModal] = useState<"approve" | "reject" | null>(null);
  const [actionLoading, setActionLoading] = useState(false);

  const fetchExtra = useCallback(async (userRes: AppUserDetail) => {
    if (userRes.role !== "agent" && userRes.agent_status === "none") return;
    try {
      const certRes = await apiFetch<PaginatedResponse<AgentCertification>>(
        `/api/staff/agents/certifications/?search=${encodeURIComponent(userRes.email)}&page_size=1`,
      );
      if (certRes.results.length > 0) {
        setCertification(certRes.results[0]);
        const cert = certRes.results[0];
        const urls: Record<string, FileUrl> = {};
        for (const [key, fileId] of Object.entries({
          agent_id_photo: cert.agent_id_photo,
          business_location_photo: cert.business_location_photo,
        })) {
          if (fileId) {
            try {
              const urlRes = await apiFetch<FileUrl>(`/api/files/${fileId}/access-url/`, {
                method: "POST",
              });
              urls[key] = urlRes;
            } catch {
              /* file not available */
            }
          }
        }
        setCertPhotoUrls(urls);
      }
    } catch {
      /* no certification */
    }
  }, []);

  const { user, loading, refetch } = useUserDetail(id, fetchExtra);

  if (loading) return <DetailLoading />;
  if (!user) return <DetailNotFound backHref="/dashboard/agents" />;

  const handleAgentAction = async () => {
    if (!agentModal) return;
    setActionLoading(true);
    try {
      const endpoint =
        agentModal === "approve"
          ? `/api/staff/users/${user.id}/approve-agent/`
          : `/api/staff/users/${user.id}/reject-agent/`;
      await apiFetch(endpoint, { method: "POST" });
      setAgentModal(null);
      refetch();
    } catch {
      /* keep modal open */
    } finally {
      setActionLoading(false);
    }
  };

  const handleCertAction = async (reason?: string) => {
    if (!certModal || !certification) return;
    setActionLoading(true);
    try {
      const endpoint =
        certModal === "approve"
          ? `/api/staff/agents/certifications/${certification.id}/approve/`
          : `/api/staff/agents/certifications/${certification.id}/reject/`;
      await apiFetch(endpoint, {
        method: "POST",
        body: certModal === "reject" ? JSON.stringify({ reason }) : undefined,
      });
      setCertModal(null);
      refetch();
    } catch {
      /* keep modal open */
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <DetailHeader user={user} backHref="/dashboard/agents" />
      <ProfileSection user={user} />

      {/* Agent Application */}
      {user.agent_status === "pending" && (
        <Section
          icon={UserCog}
          title="Agent Application"
          action={
            <div className="flex items-center gap-2">
              <button
                onClick={() => setAgentModal("approve")}
                className="flex items-center gap-1.5 rounded-lg bg-green-600 px-3 py-1.5 text-sm font-medium text-white transition-colors hover:bg-green-700"
              >
                <CheckCircle size={14} />
                Approve
              </button>
              <button
                onClick={() => setAgentModal("reject")}
                className="flex items-center gap-1.5 rounded-lg bg-red-600 px-3 py-1.5 text-sm font-medium text-white transition-colors hover:bg-red-700"
              >
                <XCircle size={14} />
                Reject
              </button>
            </div>
          }
        >
          <p className="text-muted-foreground text-sm">
            This user has a pending agent application awaiting review.
          </p>
        </Section>
      )}

      {/* Certification */}
      {certification && (
        <Section
          icon={CreditCard}
          title="Agent Certification"
          badge={
            <Badge variant={STATUS_VARIANT[certification.status] ?? "muted"}>
              {certification.status}
            </Badge>
          }
          action={
            certification.status === "pending" ? (
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setCertModal("approve")}
                  className="flex items-center gap-1.5 rounded-lg bg-green-600 px-3 py-1.5 text-sm font-medium text-white transition-colors hover:bg-green-700"
                >
                  <CheckCircle size={14} />
                  Approve
                </button>
                <button
                  onClick={() => setCertModal("reject")}
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
              <InfoRow label="Agent ID Number">{certification.agent_id_number}</InfoRow>
              <InfoRow label="Network">{certification.network.toUpperCase()}</InfoRow>
              <InfoRow label="Applied">{formatDate(certification.created_at)}</InfoRow>
              {certification.business_registration_number && (
                <InfoRow label="Business Reg. No.">
                  {certification.business_registration_number}
                </InfoRow>
              )}
              {certification.reviewed_at && (
                <InfoRow label="Reviewed">{formatDate(certification.reviewed_at)}</InfoRow>
              )}
              {certification.rejection_reason && (
                <InfoRow label="Rejection Reason">
                  <span className="text-red-500">{certification.rejection_reason}</span>
                </InfoRow>
              )}
            </div>

            <div>
              <p className="text-foreground mb-3 text-sm font-medium">Documents</p>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                <DocCard
                  label="Agent ID Photo"
                  fileUrl={certPhotoUrls.agent_id_photo ?? null}
                  onView={(url, title) => viewer.open(url, title, "IMAGE")}
                />
                <DocCard
                  label="Business Location"
                  fileUrl={certPhotoUrls.business_location_photo ?? null}
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

      {agentModal === "approve" && (
        <ConfirmModal
          title="Approve Agent Application"
          description={`Approve ${user.first_name} ${user.last_name} as an agent?`}
          confirmLabel="Approve"
          confirmClassName="bg-green-600 text-white hover:bg-green-700"
          isLoading={actionLoading}
          onConfirm={handleAgentAction}
          onCancel={() => setAgentModal(null)}
        />
      )}
      {agentModal === "reject" && (
        <ConfirmModal
          title="Reject Agent Application"
          description={`Reject the agent application from ${user.first_name} ${user.last_name}?`}
          confirmLabel="Reject"
          isLoading={actionLoading}
          onConfirm={handleAgentAction}
          onCancel={() => setAgentModal(null)}
        />
      )}
      {certModal === "approve" && (
        <ConfirmModal
          title="Approve Certification"
          description="This will upgrade the agent to certified status."
          confirmLabel="Approve"
          confirmClassName="bg-green-600 text-white hover:bg-green-700"
          isLoading={actionLoading}
          onConfirm={() => handleCertAction()}
          onCancel={() => setCertModal(null)}
        />
      )}
      {certModal === "reject" && (
        <RejectModal
          title="Reject Certification"
          description="Provide a reason for rejecting this certification application."
          isLoading={actionLoading}
          onConfirm={(reason) => handleCertAction(reason)}
          onCancel={() => setCertModal(null)}
        />
      )}
    </div>
  );
}
