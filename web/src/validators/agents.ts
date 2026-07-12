import { z } from "zod";
import { paginatedResponseSchema } from "@/validators/common";

export const agentCertificationSchema = z.object({
  id: z.string(),
  agent_phone: z.string().nullable(),
  agent_name: z.string(),
  agent_id_number: z.string(),
  network: z.string(),
  agent_id_photo: z.string(),
  business_location_photo: z.string(),
  business_registration_number: z.string(),
  status: z.enum(["pending", "approved", "rejected"]),
  rejection_reason: z.string(),
  reviewed_at: z.string().nullable(),
  created_at: z.string(),
});

export const agentCertificationsPageSchema = paginatedResponseSchema(agentCertificationSchema);
