import {
  GhanaCardsRepository,
  type GhanaCardRecordInput,
  type GhanaCardRecordUpdateInput,
} from "@/repositories/ghana-cards.repository";
import type { TableQueryInput } from "@/utils/query-params";
import { buildTableQueryParams } from "@/utils/query-params";

export class GhanaCardsService {
  constructor(private readonly repository: GhanaCardsRepository) {}

  list(input: TableQueryInput) {
    return this.repository.list(buildTableQueryParams(input));
  }

  create(input: GhanaCardRecordInput) {
    return this.repository.create(input);
  }

  getById(id: string) {
    return this.repository.getById(id);
  }

  update(id: string, input: GhanaCardRecordUpdateInput) {
    return this.repository.update(id, input);
  }

  delete(id: string) {
    return this.repository.delete(id);
  }

  uploadImage(file: File) {
    return this.repository.uploadImage(file);
  }

  deleteImage(id: string) {
    return this.repository.deleteImage(id);
  }

  setActive(id: string, isActive: boolean) {
    return this.repository.setActive(id, isActive);
  }
}
