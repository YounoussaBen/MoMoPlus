import { z } from "zod";
import { paginatedResponseSchema } from "@/validators/common";

export const staffLoanStatusSchema = z.enum([
  "pending",
  "approved",
  "disbursing",
  "active",
  "repaying",
  "completed",
  "defaulted",
  "rejected",
  "failed",
  "cancelled",
]);

export const staffLoanPaymentSchema = z.object({
  id: z.string(),
  payment_type: z.enum(["disbursement", "repayment"]),
  amount: z.string(),
  charge_amount: z.string(),
  transfer_amount: z.string(),
  platform_amount: z.string(),
  status: z.enum(["pending", "success", "failed"]),
  reference: z.string(),
  paystack_reference: z.string(),
  payer_phone: z.string(),
  payer_network: z.string(),
  recipient_code: z.string(),
  completed_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

export const staffLoanListItemSchema = z.object({
  id: z.string(),
  borrower_id: z.string(),
  borrower_name: z.string(),
  borrower_email: z.string(),
  agent_user_id: z.string(),
  agent_id: z.string(),
  agent_name: z.string(),
  agent_email: z.string(),
  amount: z.string(),
  total_repayment: z.string(),
  outstanding_balance: z.string(),
  agent_receivable_balance: z.string(),
  penalty_amount: z.string(),
  status: staffLoanStatusSchema,
  network: z.string(),
  borrower_wallet_phone: z.string(),
  borrower_wallet_network: z.string(),
  agent_wallet_phone: z.string(),
  agent_wallet_network: z.string(),
  approved_at: z.string().nullable(),
  disbursed_at: z.string().nullable(),
  deadline_at: z.string().nullable(),
  completed_at: z.string().nullable(),
  defaulted_at: z.string().nullable(),
  is_overdue: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
});

export const staffLoanDetailSchema = staffLoanListItemSchema.extend({
  interest_rate: z.string(),
  origination_fee: z.string(),
  agent_interest_amount: z.string(),
  platform_interest_amount: z.string(),
  rejection_reason: z.string(),
  last_penalty_at: z.string().nullable(),
  payments: z.array(staffLoanPaymentSchema),
});

export const staffLoansPageSchema = paginatedResponseSchema(staffLoanListItemSchema);
