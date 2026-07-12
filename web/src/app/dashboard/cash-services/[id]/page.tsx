"use client";

import { use } from "react";
import { ArrowLeftRight, MapPinned, ShieldCheck, UserRound } from "lucide-react";
import { useCashServiceDetail } from "@/hooks/use-cash-services";
import {
  formatCurrency,
  formatDateTime,
  formatNetwork,
  formatPhone,
  formatTransactionStatus,
  formatTransactionType,
} from "@/lib/format";
import { Badge } from "@/components/ui/badge";
import { DetailHeaderSkeleton, SectionSkeleton } from "@/components/dashboard/skeletons";
import {
  DetailMetricCard,
  DetailPageNotFound,
  EmptyInlineState,
  EntityDetailHeader,
} from "@/components/dashboard/entity-detail";
import { InfoRow, Section } from "@/components/dashboard/user-detail-shared";

const STATUS_VARIANT: Record<string, "muted" | "warning" | "info" | "success" | "destructive"> = {
  pending: "warning",
  accepted: "info",
  completed: "success",
  rejected: "destructive",
  cancelled: "muted",
  expired: "destructive",
};

function formatOptionalDate(value: string | null) {
  return value ? formatDateTime(value) : "—";
}

export default function CashServiceDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const detailQuery = useCashServiceDetail(id);
  const item = detailQuery.data ?? null;

  if (detailQuery.isLoading) {
    return (
      <div className="space-y-6">
        <DetailHeaderSkeleton />
        <SectionSkeleton rows={4} />
        <SectionSkeleton rows={4} />
        <SectionSkeleton rows={4} />
      </div>
    );
  }

  if (!item) {
    return (
      <DetailPageNotFound
        title="Cash service case not found"
        description="The record may have been removed or is unavailable."
        backHref="/dashboard/cash-services"
      />
    );
  }

  return (
    <div className="space-y-6">
      <EntityDetailHeader
        title="Cash Service Case"
        subtitle={`${item.user_name} with ${item.agent_name}`}
        backHref="/dashboard/cash-services"
        badges={
          <>
            <Badge variant={STATUS_VARIANT[item.status] ?? "muted"}>
              {formatTransactionStatus(item.status)}
            </Badge>
            <Badge variant="info">{formatTransactionType(item.transaction_type)}</Badge>
          </>
        }
      />

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <DetailMetricCard label="Amount" value={formatCurrency(item.amount)} />
        <DetailMetricCard
          label="Meeting"
          value={item.has_meeting ? "Scheduled" : "Not set"}
          caption={item.meeting_description || undefined}
        />
        <DetailMetricCard label="Customer Confirmed" value={item.user_confirmed ? "Yes" : "No"} />
        <DetailMetricCard label="Agent Confirmed" value={item.agent_confirmed ? "Yes" : "No"} />
      </div>

      <Section icon={UserRound} title="Participants">
        <div className="grid gap-4 sm:grid-cols-2">
          <InfoRow label="Customer">{item.user_name}</InfoRow>
          <InfoRow label="Customer Phone">{formatPhone(item.user_phone)}</InfoRow>
          <InfoRow label="Agent">{item.agent_name}</InfoRow>
          <InfoRow label="Agent Phone">{formatPhone(item.agent_phone)}</InfoRow>
          <InfoRow label="Wallet Phone">{item.wallet_phone_number}</InfoRow>
          <InfoRow label="Wallet Network">{formatNetwork(item.wallet_network)}</InfoRow>
        </div>
      </Section>

      <Section icon={ArrowLeftRight} title="Transaction Details">
        <div className="grid gap-4 sm:grid-cols-2">
          <InfoRow label="Type">{formatTransactionType(item.transaction_type)}</InfoRow>
          <InfoRow label="Status">{formatTransactionStatus(item.status)}</InfoRow>
          <InfoRow label="Network">{formatNetwork(item.network)}</InfoRow>
          <InfoRow label="Verification Code">{item.verification_code}</InfoRow>
          <InfoRow label="Created">{formatDateTime(item.created_at)}</InfoRow>
          <InfoRow label="Expires">{formatDateTime(item.expires_at)}</InfoRow>
          <InfoRow label="Completed">{formatOptionalDate(item.completed_at)}</InfoRow>
          {item.cancellation_reason ? (
            <InfoRow label="Cancellation Reason">
              <span className="text-destructive">{item.cancellation_reason}</span>
            </InfoRow>
          ) : null}
        </div>
      </Section>

      <Section icon={MapPinned} title="Meeting Details">
        {item.has_meeting ? (
          <div className="grid gap-4 sm:grid-cols-2">
            <InfoRow label="Description">{item.meeting_description || "—"}</InfoRow>
            <InfoRow label="Latitude">{item.meeting_latitude ?? "—"}</InfoRow>
            <InfoRow label="Longitude">{item.meeting_longitude ?? "—"}</InfoRow>
          </div>
        ) : (
          <EmptyInlineState
            title="Meeting not set yet"
            description="Meeting coordinates and notes will appear here after the transaction is accepted."
          />
        )}
      </Section>

      <Section icon={ShieldCheck} title="Confirmation State">
        <div className="grid gap-4 sm:grid-cols-2">
          <InfoRow label="Customer Confirmed">
            <Badge variant={item.user_confirmed ? "success" : "muted"}>
              {item.user_confirmed ? "Confirmed" : "Pending"}
            </Badge>
          </InfoRow>
          <InfoRow label="Agent Confirmed">
            <Badge variant={item.agent_confirmed ? "success" : "muted"}>
              {item.agent_confirmed ? "Confirmed" : "Pending"}
            </Badge>
          </InfoRow>
        </div>
      </Section>
    </div>
  );
}
