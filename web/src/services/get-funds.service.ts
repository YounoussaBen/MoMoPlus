import { GetFundsRepository } from "@/repositories/get-funds.repository";
import type { TableQueryInput } from "@/utils/query-params";
import { buildTableQueryParams } from "@/utils/query-params";

export class GetFundsService {
  constructor(private readonly getFundsRepository: GetFundsRepository) {}

  listGetFunds(input: TableQueryInput) {
    return this.getFundsRepository.list(buildTableQueryParams(input));
  }

  getGetFundsDetail(id: string) {
    return this.getFundsRepository.getById(id);
  }
}
