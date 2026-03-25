import { z } from "zod";

export const staffUserSchema = z.object({
  id: z.string(),
  username: z.string(),
  email: z.string(),
  first_name: z.string(),
  last_name: z.string(),
  is_active: z.boolean(),
  is_staff: z.boolean(),
  is_superuser: z.boolean(),
});

export const loginResponseSchema = z.object({
  access: z.string(),
  token_type: z.string(),
  expires_in: z.number(),
  user: staffUserSchema,
});

export const staffProfileSchema = z.object({
  id: z.string(),
  supabase_user_id: z.string().nullable(),
  username: z.string(),
  email: z.string().email(),
  first_name: z.string(),
  last_name: z.string(),
  full_name: z.string(),
  role: z.enum(["user", "agent"]),
  agent_status: z.enum(["none", "pending", "approved", "rejected"]),
  kyc_status: z.enum(["none", "pending", "approved", "rejected"]),
  created_at: z.string(),
  updated_at: z.string(),
});
