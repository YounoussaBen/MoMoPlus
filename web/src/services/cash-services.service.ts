import { CashServicesRepository } from "@/repositories/cash-services.repository";
import type { TableQueryInput } from "@/utils/query-params";
import { buildTableQueryParams } from "@/utils/query-params";

export class CashServicesService {
  constructor(private readonly cashServicesRepository: CashServicesRepository) {}

  listCashServices(input: TableQueryInput) {
    return this.cashServicesRepository.list(buildTableQueryParams(input));
  }

  getCashServiceDetail(id: string) {
    return this.cashServicesRepository.getById(id);
  }
}
