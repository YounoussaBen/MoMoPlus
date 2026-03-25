import { z } from "zod";
import { paginatedResponseSchema } from "@/validators/common";

export const staffTransactionTypeSchema = z.enum(["cash_out", "deposit"]);
export const staffTransactionStatusSchema = z.enum([
  "pending",
  "accepted",
  "completed",
  "rejected",
  "cancelled",
  "expired",
]);

export const staffPhysicalTransactionSchema = z.object({
  id: z.string(),
  user_id: z.string(),
  user_email: z.string(),
  user_name: z.string(),
  agent_user_id: z.string(),
  agent_id: z.string(),
  agent_email: z.string(),
  agent_name: z.string(),
  transaction_type: staffTransactionTypeSchema,
  amount: z.string(),
  network: z.string(),
  status: staffTransactionStatusSchema,
  verification_code: z.string(),
  meeting_latitude: z.string().nullable(),
  meeting_longitude: z.string().nullable(),
  meeting_description: z.string(),
  has_meeting: z.boolean(),
  user_confirmed: z.boolean(),
  agent_confirmed: z.boolean(),
  wallet_phone_number: z.string(),
  wallet_network: z.string(),
  cancellation_reason: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  completed_at: z.string().nullable(),
  expires_at: z.string(),
});

export const staffPhysicalTransactionsPageSchema = paginatedResponseSchema(
  staffPhysicalTransactionSchema,
);
