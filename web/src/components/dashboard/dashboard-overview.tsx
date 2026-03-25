"use client";

import { useMemo, useState } from "react";
import {
  Activity,
  ArrowDownLeft,
  ArrowUpRight,
  BadgeAlert,
  BriefcaseBusiness,
  Clock3,
  CreditCard,
  FileClock,
  Landmark,
  RefreshCcw,
  ShieldCheck,
  TrendingUp,
  Users,
} from "lucide-react";

import { useDashboardOverview } from "@/hooks/use-dashboard";
import { formatCurrency, formatDateTime } from "@/lib/format";
import type {
  DashboardActivityPoint,
  DashboardBreakdownPoint,
  DashboardMoneyFlowPoint,
  StaffDashboardOverview,
} from "@/lib/types";
import { cn } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { Skeleton } from "@/components/ui/skeleton";

const RANGE_OPTIONS = [7, 14, 30, 90] as const;

const ACTIVITY_SERIES = [
  { key: "users", label: "Users", color: "var(--color-primary)" },
  { key: "agents", label: "Agents", color: "var(--color-info)" },
  { key: "kyc_submissions", label: "KYC", color: "var(--color-warning)" },
  { key: "get_funds_cases", label: "Get Funds", color: "var(--color-success)" },
  { key: "cash_services", label: "Cash Services", color: "var(--color-destructive)" },
] as const;

const MONEY_SERIES = [
  { key: "loan_disbursements", label: "Disbursements", color: "var(--color-primary)" },
  { key: "loan_repayments", label: "Repayments", color: "var(--color-info)" },
  { key: "cash_in", label: "Cash In", color: "var(--color-success)" },
  { key: "cash_out", label: "Cash Out", color: "var(--color-warning)" },
] as const;

function formatShortDate(value: string) {
  return new Date(value).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
  });
}

function formatCompactNumber(value: number) {
  return new Intl.NumberFormat("en-US", {
    notation: "compact",
    maximumFractionDigits: 1,
  }).format(value);
}

function buildLinePath(points: { x: number; y: number }[]) {
  return points
    .map((point, index) => `${index === 0 ? "M" : "L"} ${point.x.toFixed(2)} ${point.y.toFixed(2)}`)
    .join(" ");
}

function DashboardMetricCard({
  title,
  value,
  caption,
  icon: Icon,
  badge,
}: {
  title: string;
  value: string;
  caption: string;
  icon: React.ComponentType<{ className?: string }>;
  badge?: React.ReactNode;
}) {
  return (
    <Card className="border-border/60 border">
      <CardHeader className="flex flex-row items-start justify-between gap-4 pb-4">
        <div className="space-y-1">
          <p className="text-muted-foreground text-xs font-medium tracking-[0.16em] uppercase">
            {title}
          </p>
          <CardTitle className="text-3xl font-semibold">{value}</CardTitle>
        </div>
        <div className="bg-secondary text-secondary-foreground rounded-2xl p-3">
          <Icon className="size-5" />
        </div>
      </CardHeader>
      <CardContent className="flex items-center justify-between pt-0">
        <p className="text-muted-foreground text-sm">{caption}</p>
        {badge}
      </CardContent>
    </Card>
  );
}

function DashboardSectionHeader({
  title,
  description,
  trailing,
}: {
  title: string;
  description: string;
  trailing?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <h1 className="text-foreground text-3xl font-semibold tracking-tight">{title}</h1>
        <p className="text-muted-foreground mt-1 text-sm">{description}</p>
      </div>
      {trailing}
    </div>
  );
}

function DashboardRangePicker({
  value,
  onChange,
}: {
  value: number;
  onChange: (next: number) => void;
}) {
  return (
    <div className="bg-card border-border/60 inline-flex items-center gap-1 rounded-2xl border p-1">
      {RANGE_OPTIONS.map((option) => (
        <Button
          key={option}
          variant={option === value ? "secondary" : "ghost"}
          size="sm"
          className={cn(
            "rounded-xl px-3",
            option === value ? "text-foreground" : "text-muted-foreground",
          )}
          onClick={() => onChange(option)}
        >
          {option}d
        </Button>
      ))}
    </div>
  );
}

function DashboardLineChart({
  data,
  series,
}: {
  data: DashboardActivityPoint[];
  series: typeof ACTIVITY_SERIES;
}) {
  const dimensions = {
    width: 820,
    height: 280,
    paddingX: 22,
    paddingTop: 18,
    paddingBottom: 34,
  };

  const maxValue = Math.max(1, ...data.flatMap((point) => series.map((item) => point[item.key])));
  const usableHeight = dimensions.height - dimensions.paddingTop - dimensions.paddingBottom;
  const usableWidth = dimensions.width - dimensions.paddingX * 2;

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-3">
        {series.map((item) => (
          <div key={item.key} className="flex items-center gap-2 text-xs">
            <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: item.color }} />
            <span className="text-muted-foreground">{item.label}</span>
          </div>
        ))}
      </div>

      <svg
        viewBox={`0 0 ${dimensions.width} ${dimensions.height}`}
        className="h-72 w-full overflow-visible"
      >
        {[0, 0.25, 0.5, 0.75, 1].map((tick) => {
          const y = dimensions.paddingTop + usableHeight * tick;
          return (
            <g key={tick}>
              <line
                x1={dimensions.paddingX}
                x2={dimensions.width - dimensions.paddingX}
                y1={y}
                y2={y}
                stroke="color-mix(in srgb, var(--color-border) 72%, transparent)"
                strokeWidth="1"
                strokeDasharray={tick === 1 ? undefined : "4 6"}
              />
              <text
                x={dimensions.paddingX}
                y={y - 6}
                fill="var(--color-muted-foreground)"
                fontSize="11"
              >
                {Math.round(maxValue * (1 - tick))}
              </text>
            </g>
          );
        })}

        {series.map((item) => {
          const points = data.map((point, index) => {
            const x =
              dimensions.paddingX +
              (data.length === 1 ? usableWidth / 2 : (usableWidth * index) / (data.length - 1));
            const y =
              dimensions.paddingTop + usableHeight - (usableHeight * point[item.key]) / maxValue;
            return { x, y };
          });

          return (
            <g key={item.key}>
              <path
                d={buildLinePath(points)}
                fill="none"
                stroke={item.color}
                strokeWidth="3"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
              {points.map((point, index) => (
                <circle
                  key={`${item.key}-${index}`}
                  cx={point.x}
                  cy={point.y}
                  r="3.25"
                  fill={item.color}
                  stroke="var(--color-card)"
                  strokeWidth="2"
                />
              ))}
            </g>
          );
        })}

        {data.map((point, index) => {
          const x =
            dimensions.paddingX +
            (data.length === 1 ? usableWidth / 2 : (usableWidth * index) / (data.length - 1));
          return (
            <text
              key={point.date}
              x={x}
              y={dimensions.height - 8}
              textAnchor="middle"
              fill="var(--color-muted-foreground)"
              fontSize="11"
            >
              {index % Math.max(1, Math.ceil(data.length / 6)) === 0 || index === data.length - 1
                ? formatShortDate(point.date)
                : ""}
            </text>
          );
        })}
      </svg>
    </div>
  );
}

function DashboardMoneyFlowChart({
  data,
  series,
}: {
  data: DashboardMoneyFlowPoint[];
  series: typeof MONEY_SERIES;
}) {
  const chartRows = data.slice(-7);
  const maxValue = Math.max(
    1,
    ...chartRows.flatMap((row) => series.map((item) => Number.parseFloat(row[item.key]) || 0)),
  );

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-3">
        {series.map((item) => (
          <div key={item.key} className="flex items-center gap-2 text-xs">
            <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: item.color }} />
            <span className="text-muted-foreground">{item.label}</span>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-7 gap-3">
        {chartRows.map((row) => (
          <div key={row.date} className="flex min-w-0 flex-col items-center gap-3">
            <div className="bg-muted/40 flex h-52 w-full items-end gap-1 rounded-2xl px-2 py-3">
              {series.map((item) => {
                const value = Number.parseFloat(row[item.key]) || 0;
                const height = `${Math.max((value / maxValue) * 100, value > 0 ? 6 : 0)}%`;
                return (
                  <div key={item.key} className="flex h-full flex-1 items-end">
                    <div
                      className="w-full rounded-full"
                      style={{
                        height,
                        backgroundColor: item.color,
                      }}
                    />
                  </div>
                );
              })}
            </div>
            <div className="space-y-1 text-center">
              <p className="text-foreground text-xs font-medium">{formatShortDate(row.date)}</p>
              <p className="text-muted-foreground text-[11px]">
                {formatCurrency(
                  series.reduce((sum, item) => sum + (Number.parseFloat(row[item.key]) || 0), 0),
                )}
              </p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function BreakdownCard({
  title,
  description,
  items,
}: {
  title: string;
  description: string;
  items: DashboardBreakdownPoint[];
}) {
  const total = items.reduce((sum, item) => sum + item.value, 0);

  return (
    <Card className="border-border/60 border">
      <CardHeader className="pb-4">
        <CardTitle className="text-lg">{title}</CardTitle>
        <p className="text-muted-foreground text-sm">{description}</p>
      </CardHeader>
      <CardContent className="space-y-4 pt-0">
        {items.map((item) => {
          const share = total === 0 ? 0 : (item.value / total) * 100;
          return (
            <div key={item.key} className="space-y-2">
              <div className="flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <p className="text-foreground truncate text-sm font-medium">{item.label}</p>
                  <p className="text-muted-foreground text-xs">
                    {share.toFixed(0)}% of tracked items
                  </p>
                </div>
                <p className="text-foreground text-sm font-semibold">{item.value}</p>
              </div>
              <div className="bg-muted h-2 rounded-full">
                <div
                  className="bg-primary h-2 rounded-full"
                  style={{ width: `${Math.max(share, item.value > 0 ? 6 : 0)}%` }}
                />
              </div>
            </div>
          );
        })}
      </CardContent>
    </Card>
  );
}

function NetworkDistributionCard({ items }: { items: DashboardBreakdownPoint[] }) {
  const total = items.reduce((sum, item) => sum + item.value, 0);

  return (
    <Card className="border-border/60 border">
      <CardHeader className="pb-4">
        <CardTitle className="text-lg">Network Mix</CardTitle>
        <p className="text-muted-foreground text-sm">
          Case distribution across telco rails for the selected window.
        </p>
      </CardHeader>
      <CardContent className="space-y-4 pt-0">
        {items.map((item) => {
          const percentage = total === 0 ? 0 : (item.value / total) * 100;
          return (
            <div key={item.key} className="space-y-2">
              <div className="flex items-center justify-between gap-3">
                <p className="text-sm font-medium">{item.label}</p>
                <div className="text-right text-sm">
                  <p className="font-semibold">{item.value}</p>
                  <p className="text-muted-foreground text-xs">{percentage.toFixed(0)}%</p>
                </div>
              </div>
              <div className="bg-muted h-2.5 rounded-full">
                <div
                  className="bg-primary h-2.5 rounded-full"
                  style={{ width: `${Math.max(percentage, item.value > 0 ? 8 : 0)}%` }}
                />
              </div>
            </div>
          );
        })}
      </CardContent>
    </Card>
  );
}

function DashboardOverviewSkeleton() {
  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div className="space-y-2">
          <Skeleton className="h-8 w-60" />
          <Skeleton className="h-4 w-96 max-w-full" />
        </div>
        <Skeleton className="h-10 w-52 rounded-2xl" />
      </div>

      <Skeleton className="h-28 rounded-[28px]" />

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {Array.from({ length: 8 }).map((_, index) => (
          <Skeleton key={index} className="h-40 rounded-[28px]" />
        ))}
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.6fr,1fr]">
        <Skeleton className="h-[420px] rounded-[28px]" />
        <div className="space-y-6">
          {Array.from({ length: 3 }).map((_, index) => (
            <Skeleton key={index} className="h-[220px] rounded-[28px]" />
          ))}
        </div>
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.6fr,1fr]">
        <Skeleton className="h-[420px] rounded-[28px]" />
        <Skeleton className="h-[420px] rounded-[28px]" />
      </div>
    </div>
  );
}

function OverviewContent({ overview }: { overview: StaffDashboardOverview }) {
  const refreshedAt = useMemo(() => formatDateTime(overview.generated_at), [overview.generated_at]);

  return (
    <div className="space-y-6">
      <Card className="border-border/60 border">
        <CardContent className="grid gap-4 p-6 lg:grid-cols-4">
          <div className="space-y-2">
            <p className="text-muted-foreground text-xs font-medium tracking-[0.16em] uppercase">
              Loan Disbursement Volume
            </p>
            <p className="text-foreground text-2xl font-semibold">
              {formatCurrency(overview.period.loan_disbursement_volume)}
            </p>
            <p className="text-muted-foreground text-sm">
              Funds released in the last {overview.range_days} days.
            </p>
          </div>
          <div className="space-y-2">
            <p className="text-muted-foreground text-xs font-medium tracking-[0.16em] uppercase">
              Loan Repayment Volume
            </p>
            <p className="text-foreground text-2xl font-semibold">
              {formatCurrency(overview.period.loan_repayment_volume)}
            </p>
            <p className="text-muted-foreground text-sm">
              Repayments successfully collected in the selected window.
            </p>
          </div>
          <div className="space-y-2">
            <p className="text-muted-foreground text-xs font-medium tracking-[0.16em] uppercase">
              Cash In Volume
            </p>
            <p className="text-foreground text-2xl font-semibold">
              {formatCurrency(overview.period.cash_in_volume)}
            </p>
            <p className="text-muted-foreground text-sm">
              Completed physical deposits across all active networks.
            </p>
          </div>
          <div className="space-y-2">
            <p className="text-muted-foreground text-xs font-medium tracking-[0.16em] uppercase">
              Cash Out Volume
            </p>
            <p className="text-foreground text-2xl font-semibold">
              {formatCurrency(overview.period.cash_out_volume)}
            </p>
            <p className="text-muted-foreground text-sm">
              Completed physical withdrawals settled in the same period.
            </p>
          </div>
        </CardContent>
      </Card>

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <DashboardMetricCard
          title="Total Users"
          value={formatCompactNumber(overview.summary.total_users)}
          caption={`${overview.period.new_users} added in the last ${overview.range_days} days`}
          icon={Users}
          badge={<Badge variant="secondary">Live</Badge>}
        />
        <DashboardMetricCard
          title="Approved Agents"
          value={formatCompactNumber(overview.summary.approved_agents)}
          caption={`${overview.period.new_agents} new profiles in range`}
          icon={ShieldCheck}
          badge={<Badge variant="success">Verified</Badge>}
        />
        <DashboardMetricCard
          title="Pending KYC"
          value={formatCompactNumber(overview.summary.pending_kyc_reviews)}
          caption={`${overview.period.new_kyc_submissions} submissions entered the queue`}
          icon={FileClock}
          badge={<Badge variant="warning">Review</Badge>}
        />
        <DashboardMetricCard
          title="Agent Reviews"
          value={formatCompactNumber(overview.summary.pending_agent_reviews)}
          caption="Certification applications waiting for staff action"
          icon={BadgeAlert}
          badge={<Badge variant="info">Queue</Badge>}
        />
        <DashboardMetricCard
          title="Open Get Funds"
          value={formatCompactNumber(overview.summary.open_get_funds_cases)}
          caption={`${overview.period.new_get_funds_cases} new cases in the selected window`}
          icon={Landmark}
          badge={<Badge variant="secondary">Active</Badge>}
        />
        <DashboardMetricCard
          title="Overdue Cases"
          value={formatCompactNumber(overview.summary.overdue_get_funds_cases)}
          caption="Cases past deadline and needing intervention"
          icon={Clock3}
          badge={<Badge variant="destructive">Attention</Badge>}
        />
        <DashboardMetricCard
          title="Open Cash Services"
          value={formatCompactNumber(overview.summary.open_cash_services)}
          caption={`${overview.period.new_cash_services} cash cases were created recently`}
          icon={CreditCard}
          badge={<Badge variant="secondary">In Flight</Badge>}
        />
        <DashboardMetricCard
          title="Meetings Scheduled"
          value={formatCompactNumber(overview.summary.scheduled_cash_meetings)}
          caption="Accepted cash-service cases with meeting coordinates"
          icon={BriefcaseBusiness}
          badge={<Badge variant="success">Ready</Badge>}
        />
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.6fr,1fr]">
        <Card className="border-border/60 border">
          <CardHeader className="flex flex-row items-center justify-between gap-4 pb-4">
            <div>
              <CardTitle className="text-lg">Operational Activity</CardTitle>
              <p className="text-muted-foreground mt-1 text-sm">
                Daily onboarding and operations across users, KYC, get funds, and cash services.
              </p>
            </div>
            <Badge variant="secondary">
              <Activity className="size-3.5" />
              Last {overview.range_days} days
            </Badge>
          </CardHeader>
          <CardContent className="pt-0">
            <DashboardLineChart data={overview.charts.activity} series={ACTIVITY_SERIES} />
          </CardContent>
        </Card>

        <div className="space-y-6">
          <BreakdownCard
            title="KYC Pipeline"
            description="Current review distribution across the KYC queue."
            items={overview.charts.kyc_status_breakdown}
          />
          <BreakdownCard
            title="Get Funds Portfolio"
            description="Current status spread across the monitored credit pipeline."
            items={overview.charts.loan_status_breakdown}
          />
          <BreakdownCard
            title="Cash Services Queue"
            description="Live status mix for physical cash service operations."
            items={overview.charts.cash_service_status_breakdown}
          />
        </div>
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.6fr,1fr]">
        <Card className="border-border/60 border">
          <CardHeader className="flex flex-row items-center justify-between gap-4 pb-4">
            <div>
              <CardTitle className="text-lg">Money Movement</CardTitle>
              <p className="text-muted-foreground mt-1 text-sm">
                Disbursements, repayments, cash-ins, and cash-outs over the latest week.
              </p>
            </div>
            <Badge variant="secondary">
              <TrendingUp className="size-3.5" />
              Weekly focus
            </Badge>
          </CardHeader>
          <CardContent className="pt-0">
            <DashboardMoneyFlowChart data={overview.charts.money_flow} series={MONEY_SERIES} />
          </CardContent>
        </Card>

        <NetworkDistributionCard items={overview.charts.network_breakdown} />
      </div>

      <div className="text-muted-foreground flex items-center gap-2 text-xs">
        <RefreshCcw className="size-3.5" />
        <span>Data refreshed at {refreshedAt}</span>
      </div>
    </div>
  );
}

export function DashboardOverviewPage() {
  const [selectedDays, setSelectedDays] = useState<number>(30);
  const overviewQuery = useDashboardOverview(selectedDays);

  if (overviewQuery.isLoading) {
    return <DashboardOverviewSkeleton />;
  }

  if (!overviewQuery.data) {
    return (
      <EmptyState
        icon={<TrendingUp className="size-8" />}
        title="Dashboard data is unavailable"
        description="The overview endpoint could not be loaded. Try refreshing or check the staff API."
        action={
          <Button variant="outline" onClick={() => overviewQuery.refetch()}>
            Retry
          </Button>
        }
      />
    );
  }

  return (
    <div className="space-y-6">
      <DashboardSectionHeader
        title="Dashboard"
        description="Platform-level activity, queue health, and money movement in one view."
        trailing={<DashboardRangePicker value={selectedDays} onChange={setSelectedDays} />}
      />

      <div className="flex flex-wrap items-center gap-3">
        <Badge variant="secondary">
          <ArrowUpRight className="size-3.5" />
          {overviewQuery.data.period.new_users} new users
        </Badge>
        <Badge variant="info">
          <ShieldCheck className="size-3.5" />
          {overviewQuery.data.period.new_agents} new agents
        </Badge>
        <Badge variant="warning">
          <FileClock className="size-3.5" />
          {overviewQuery.data.summary.pending_kyc_reviews} pending KYC
        </Badge>
        <Badge variant="destructive">
          <ArrowDownLeft className="size-3.5" />
          {overviewQuery.data.summary.overdue_get_funds_cases} overdue get-funds cases
        </Badge>
      </div>

      <OverviewContent overview={overviewQuery.data} />
    </div>
  );
}
