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
