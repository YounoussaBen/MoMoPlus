import { KycRepository } from "@/repositories/kyc.repository";

export class KycService {
  constructor(private readonly kycRepository: KycRepository) {}

  getSubmissionDetail(id: string) {
    return this.kycRepository.getById(id);
  }

  approveKyc(id: string) {
    return this.kycRepository.approve(id);
  }

  rejectKyc(id: string, reason?: string) {
    return this.kycRepository.reject(id, reason);
  }
}
