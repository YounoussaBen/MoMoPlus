import { z } from "zod";
import { paginatedResponseSchema } from "@/validators/common";

export const appUserSchema = z.object({
  id: z.string(),
  email: z.string().nullable(),
  phone: z.string().nullable(),
  first_name: z.string(),
  last_name: z.string(),
  full_name: z.string(),
  role: z.enum(["user", "agent"]),
  agent_status: z.enum(["none", "pending", "approved", "rejected"]),
  is_active: z.boolean(),
  is_staff: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
});

export const appUserDetailSchema = appUserSchema.extend({
  supabase_user_id: z.string(),
  username: z.string(),
  is_superuser: z.boolean(),
});

export const appUsersPageSchema = paginatedResponseSchema(appUserSchema);

export const loanGuarantorSchema = z.object({
  id: z.string(),
  name: z.string(),
  phone_number: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
});

export const loanGuarantorsArraySchema = z.array(loanGuarantorSchema);
