import { z } from "zod";
import { fileUrlSchema, paginatedResponseSchema } from "@/validators/common";

export const ghanaCardRecordSchema = z.object({
  id: z.string(),
  masked_card_number: z.string(),
  first_names: z.string(),
  surname: z.string(),
  date_of_birth: z.string().nullable(),
  sex: z.string(),
  is_active: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
});

export const ghanaCardRecordDetailSchema = z.object({
  id: z.string(),
  card_number: z.string(),
  first_names: z.string(),
  surname: z.string(),
  date_of_birth: z.string().nullable(),
  sex: z.string(),
  is_active: z.boolean(),
  card_front_url: fileUrlSchema.nullable(),
  card_back_url: fileUrlSchema.nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

export const ghanaCardRecordsPageSchema = paginatedResponseSchema(ghanaCardRecordSchema);
