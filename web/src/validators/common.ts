import { z } from "zod";

export const fileUrlSchema = z.object({
  url: z.string(),
  expires_in: z.number().nullable(),
});

export const embeddedUserSchema = z.object({
  id: z.string(),
  supabase_user_id: z.string(),
  username: z.string(),
  email: z.string(),
  first_name: z.string(),
  last_name: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  is_active: z.boolean(),
});

export function paginatedResponseSchema<T extends z.ZodTypeAny>(itemSchema: T) {
  return z.object({
    count: z.number(),
    next: z.string().nullable(),
    previous: z.string().nullable(),
    results: z.array(itemSchema),
  });
}
