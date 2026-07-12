"use client";

import { use } from "react";
import { Clock3, ReceiptText, UserRound } from "lucide-react";
import { useGetFundsDetail } from "@/hooks/use-get-funds";
import {
  formatCurrency,
  formatDateTime,
  formatLoanStatus,
  formatNetwork,
  formatPaymentStatus,
  formatPaymentType,
  formatPhone,
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
  approved: "info",
  disbursing: "info",
  active: "success",
  repaying: "warning",
  completed: "success",
  defaulted: "destructive",
  rejected: "destructive",
  cancelled: "muted",
  failed: "destructive",
};

const PAYMENT_STATUS_VARIANT: Record<string, "warning" | "success" | "destructive"> = {
  pending: "warning",
  success: "success",
  failed: "destructive",
};

function formatOptionalDate(value: string | null) {
  return value ? formatDateTime(value) : "—";
}

export default function GetFundsDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const detailQuery = useGetFundsDetail(id);
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
        title="Get funds case not found"
        description="The record may have been removed or is unavailable."
        backHref="/dashboard/get-funds"
      />
    );
  }

  return (
    <div className="space-y-6">
      <EntityDetailHeader
        title="Get Funds Case"
        subtitle={`${item.borrower_name} with ${item.agent_name}`}
        backHref="/dashboard/get-funds"
        badges={
          <>
            <Badge variant={STATUS_VARIANT[item.status] ?? "muted"}>
              {formatLoanStatus(item.status)}
            </Badge>
            {item.is_overdue ? <Badge variant="destructive">Overdue</Badge> : null}
          </>
        }
      />

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <DetailMetricCard label="Requested" value={formatCurrency(item.amount)} />
        <DetailMetricCard label="Total Repayment" value={formatCurrency(item.total_repayment)} />
        <DetailMetricCard label="Outstanding" value={formatCurrency(item.outstanding_balance)} />
        <DetailMetricCard
          label="Penalty"
          value={formatCurrency(item.penalty_amount)}
          caption={
            item.last_penalty_at
              ? `Last applied ${formatDateTime(item.last_penalty_at)}`
              : undefined
          }
        />
      </div>

      <Section icon={UserRound} title="Participants">
        <div className="grid gap-4 sm:grid-cols-2">
          <InfoRow label="Customer">{item.borrower_name}</InfoRow>
          <InfoRow label="Customer Phone">{formatPhone(item.borrower_phone)}</InfoRow>
          <InfoRow label="Customer Wallet">{item.borrower_wallet_phone}</InfoRow>
          <InfoRow label="Customer Network">{formatNetwork(item.borrower_wallet_network)}</InfoRow>
          <InfoRow label="Agent">{item.agent_name}</InfoRow>
          <InfoRow label="Agent Phone">{formatPhone(item.agent_phone)}</InfoRow>
          <InfoRow label="Agent Wallet">{item.agent_wallet_phone || "—"}</InfoRow>
          <InfoRow label="Agent Network">
            {item.agent_wallet_network ? formatNetwork(item.agent_wallet_network) : "—"}
          </InfoRow>
        </div>
      </Section>

      <Section icon={Clock3} title="Lifecycle">
        <div className="grid gap-4 sm:grid-cols-2">
          <InfoRow label="Status">{formatLoanStatus(item.status)}</InfoRow>
          <InfoRow label="Network">{formatNetwork(item.network)}</InfoRow>
          <InfoRow label="Created">{formatDateTime(item.created_at)}</InfoRow>
          <InfoRow label="Approved">{formatOptionalDate(item.approved_at)}</InfoRow>
          <InfoRow label="Disbursed">{formatOptionalDate(item.disbursed_at)}</InfoRow>
          <InfoRow label="Deadline">{formatOptionalDate(item.deadline_at)}</InfoRow>
          <InfoRow label="Completed">{formatOptionalDate(item.completed_at)}</InfoRow>
          <InfoRow label="Defaulted">{formatOptionalDate(item.defaulted_at)}</InfoRow>
          {item.rejection_reason ? (
            <InfoRow label="Rejection Reason">
              <span className="text-destructive">{item.rejection_reason}</span>
            </InfoRow>
          ) : null}
        </div>
      </Section>

      <Section icon={ReceiptText} title="Payment History">
        {item.payments.length === 0 ? (
          <EmptyInlineState
            title="No payments recorded yet"
            description="Disbursement and repayment events will appear here when they happen."
          />
        ) : (
          <div className="space-y-3">
            {item.payments.map((payment) => (
              <div key={payment.id} className="border-border/50 bg-muted/20 rounded-xl border p-4">
                <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                  <div className="space-y-2">
                    <div className="flex flex-wrap items-center gap-2">
                      <Badge variant="info">{formatPaymentType(payment.payment_type)}</Badge>
                      <Badge variant={PAYMENT_STATUS_VARIANT[payment.status] ?? "warning"}>
                        {formatPaymentStatus(payment.status)}
                      </Badge>
                    </div>
                    <p className="text-foreground text-sm font-medium">
                      {formatCurrency(payment.amount)}
                    </p>
                    <p className="text-muted-foreground text-xs">
                      Charge {formatCurrency(payment.charge_amount)} • Transfer{" "}
                      {formatCurrency(payment.transfer_amount)} • Platform{" "}
                      {formatCurrency(payment.platform_amount)}
                    </p>
                  </div>
                  <div className="text-muted-foreground text-xs sm:text-right">
                    <p>{formatDateTime(payment.created_at)}</p>
                    <p>Ref: {payment.reference}</p>
                    <p>Payer: {payment.payer_phone}</p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </Section>
    </div>
  );
}
