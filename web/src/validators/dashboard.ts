import { z } from "zod";

const dashboardSummarySchema = z.object({
  total_users: z.number(),
  approved_agents: z.number(),
  pending_kyc_reviews: z.number(),
  pending_agent_reviews: z.number(),
  open_get_funds_cases: z.number(),
  overdue_get_funds_cases: z.number(),
  open_cash_services: z.number(),
  scheduled_cash_meetings: z.number(),
});

const dashboardPeriodSchema = z.object({
  new_users: z.number(),
  new_agents: z.number(),
  new_kyc_submissions: z.number(),
  new_get_funds_cases: z.number(),
  new_cash_services: z.number(),
  loan_disbursement_volume: z.string(),
  loan_repayment_volume: z.string(),
  cash_in_volume: z.string(),
  cash_out_volume: z.string(),
});

const dashboardActivityPointSchema = z.object({
  date: z.string(),
  users: z.number(),
  agents: z.number(),
  kyc_submissions: z.number(),
  get_funds_cases: z.number(),
  cash_services: z.number(),
});

const dashboardMoneyFlowPointSchema = z.object({
  date: z.string(),
  loan_disbursements: z.string(),
  loan_repayments: z.string(),
  cash_in: z.string(),
  cash_out: z.string(),
});

const dashboardBreakdownPointSchema = z.object({
  key: z.string(),
  label: z.string(),
  value: z.number(),
});

export const dashboardOverviewSchema = z.object({
  generated_at: z.string(),
  range_days: z.number(),
  summary: dashboardSummarySchema,
  period: dashboardPeriodSchema,
  charts: z.object({
    activity: z.array(dashboardActivityPointSchema),
    money_flow: z.array(dashboardMoneyFlowPointSchema),
    kyc_status_breakdown: z.array(dashboardBreakdownPointSchema),
    loan_status_breakdown: z.array(dashboardBreakdownPointSchema),
    cash_service_status_breakdown: z.array(dashboardBreakdownPointSchema),
    network_breakdown: z.array(dashboardBreakdownPointSchema),
  }),
});
