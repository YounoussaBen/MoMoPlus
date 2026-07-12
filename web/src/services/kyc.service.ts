import { KycRepository } from "@/repositories/kyc.repository";
import { UsersRepository } from "@/repositories/users.repository";
import type { KycSubmissionDetail } from "@/lib/types";
import type { TableQueryInput } from "@/utils/query-params";
import { buildTableQueryParams } from "@/utils/query-params";

export class KycService {
  constructor(
    private readonly usersRepository: UsersRepository,
    private readonly kycRepository: KycRepository,
  ) {}

  listKyc(input: TableQueryInput) {
    return this.kycRepository.list(buildTableQueryParams(input));
  }

  async getKycDetail(id: string) {
    const user = await this.usersRepository.getById(id);
    if (!user.phone) {
      return {
        user,
        kyc: null as KycSubmissionDetail | null,
      };
    }
    const submissions = await this.kycRepository.list({
      search: user.phone,
      page_size: 1,
      page: 1,
    });

    if (submissions.results.length === 0) {
      return {
        user,
        kyc: null as KycSubmissionDetail | null,
      };
    }

    const kyc = await this.kycRepository.getById(submissions.results[0].id);
    return { user, kyc };
  }

  approveKyc(id: string) {
    return this.kycRepository.approve(id);
  }

  rejectKyc(id: string, reason?: string) {
    return this.kycRepository.reject(id, reason);
  }
}
