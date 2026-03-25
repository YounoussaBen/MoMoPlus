"use client";

import { use, useState } from "react";
import { UserCog, CreditCard, CheckCircle, XCircle } from "lucide-react";
import {
  useAgentDetail,
  useApproveAgent,
  useApproveCertification,
  useRejectAgent,
  useRejectCertification,
} from "@/hooks/use-agents";
import { formatDate } from "@/lib/format";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ConfirmModal } from "@/components/modals/confirm-modal";
import { RejectModal } from "@/components/modals/reject-modal";
import { ContentViewerModal, useContentViewer } from "@/components/modals/content-viewer-modal";
import {
  DetailHeader,
  AgentDetailSkeleton,
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

  const [agentModal, setAgentModal] = useState<"approve" | "reject" | null>(null);
  const [certModal, setCertModal] = useState<"approve" | "reject" | null>(null);
  const approveAgentMutation = useApproveAgent();
  const rejectAgentMutation = useRejectAgent();
  const approveCertificationMutation = useApproveCertification();
  const rejectCertificationMutation = useRejectCertification();
  const actionLoading =
    approveAgentMutation.isPending ||
    rejectAgentMutation.isPending ||
    approveCertificationMutation.isPending ||
    rejectCertificationMutation.isPending;
  const agentDetailQuery = useAgentDetail(id);
  const user = agentDetailQuery.data?.user ?? null;
  const certification = agentDetailQuery.data?.certification ?? null;
  const certPhotoUrls = agentDetailQuery.data?.certPhotoUrls ?? {};

  if (agentDetailQuery.isLoading) return <AgentDetailSkeleton />;
  if (!user) return <DetailNotFound backHref="/dashboard/agents" />;

  const handleAgentAction = async () => {
    if (!agentModal) return;

    try {
      if (agentModal === "approve") {
        await approveAgentMutation.mutateAsync(user.id);
      } else {
        await rejectAgentMutation.mutateAsync(user.id);
      }
      setAgentModal(null);
    } catch {
      /* keep modal open */
    }
  };

  const handleCertAction = async (reason?: string) => {
    if (!certModal || !certification) return;

    try {
      if (certModal === "approve") {
        await approveCertificationMutation.mutateAsync(certification.id);
      } else {
        await rejectCertificationMutation.mutateAsync({
          id: certification.id,
          reason,
        });
      }
      setCertModal(null);
    } catch {
      /* keep modal open */
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
              <Button onClick={() => setAgentModal("approve")} size="sm">
                <CheckCircle size={14} />
                Approve
              </Button>
              <Button onClick={() => setAgentModal("reject")} variant="destructive" size="sm">
                <XCircle size={14} />
                Reject
              </Button>
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
                <Button onClick={() => setCertModal("approve")} size="sm">
                  <CheckCircle size={14} />
                  Approve
                </Button>
                <Button onClick={() => setCertModal("reject")} variant="destructive" size="sm">
                  <XCircle size={14} />
                  Reject
                </Button>
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
                  <span className="text-destructive">{certification.rejection_reason}</span>
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
          confirmVariant="default"
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
          confirmVariant="default"
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
