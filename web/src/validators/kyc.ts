import { z } from "zod";
import { embeddedUserSchema, fileUrlSchema } from "@/validators/common";

export const kycSubmissionSchema = z.object({
  id: z.string(),
  user: embeddedUserSchema,
  status: z.enum(["none", "pending", "approved", "rejected"]),
  id_type: z.enum(["national_id", "passport", "drivers_license"]),
  created_at: z.string(),
  updated_at: z.string(),
});

export const kycSubmissionDetailSchema = kycSubmissionSchema.extend({
  id_front_url: fileUrlSchema.nullable(),
  id_back_url: fileUrlSchema.nullable(),
  selfie_url: fileUrlSchema.nullable(),
  proof_of_address_url: fileUrlSchema.nullable(),
  rejection_reason: z.string(),
  reviewed_at: z.string().nullable(),
});
