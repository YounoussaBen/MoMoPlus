import axios, { type AxiosInstance } from "axios";
import { apiClient } from "@/repositories/api/client";
import type { ApiQueryParamValue } from "@/utils/query-params";
import { ghanaCardRecordDetailSchema, ghanaCardRecordsPageSchema } from "@/validators/ghana-cards";

export interface GhanaCardRecordInput {
  card_number: string;
  first_names: string;
  surname: string;
  date_of_birth: string | null;
  sex: string;
  card_front_id: string;
  card_back_id: string;
}

interface FileUploadResponse {
  file: { id: string };
  upload: { signed_url: string | null };
}

export class GhanaCardsRepository {
  constructor(private readonly client: AxiosInstance = apiClient) {}

  async list(params: Record<string, ApiQueryParamValue>) {
    const { data } = await this.client.get("/api/staff/kyc/ghana-cards/", { params });
    return ghanaCardRecordsPageSchema.parse(data);
  }

  async create(input: GhanaCardRecordInput) {
    const { data } = await this.client.post("/api/staff/kyc/ghana-cards/", input);
    return ghanaCardRecordDetailSchema.parse(data);
  }

  async uploadImage(file: File) {
    const { data } = await this.client.post<FileUploadResponse>("/api/files/", {
      original_name: file.name,
      content_type: file.type || "application/octet-stream",
      size: file.size,
      kind: "ghana_card",
      visibility: "private",
    });

    if (!data.upload.signed_url) {
      throw new Error("The storage service did not return an upload URL.");
    }

    await axios.put(data.upload.signed_url, file, {
      headers: { "Content-Type": file.type || "application/octet-stream" },
    });
    await this.client.post(`/api/files/${data.file.id}/complete/`);
    return data.file.id;
  }

  async setActive(id: string, isActive: boolean) {
    const { data } = await this.client.patch(`/api/staff/kyc/ghana-cards/${id}/`, {
      is_active: isActive,
    });
    return ghanaCardRecordDetailSchema.parse(data);
  }
}
