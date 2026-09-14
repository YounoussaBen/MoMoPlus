import { UsersRepository } from "@/repositories/users.repository";
import type { UpdateUserReviewDataInput } from "@/lib/types";
import type { TableQueryInput } from "@/utils/query-params";
import { buildTableQueryParams } from "@/utils/query-params";

export class UsersService {
  constructor(private readonly usersRepository: UsersRepository) {}

  listUsers(input: TableQueryInput) {
    return this.usersRepository.list(buildTableQueryParams(input));
  }

  getUserDetail(id: string) {
    return this.usersRepository.getById(id);
  }

  updateReviewData(id: string, input: UpdateUserReviewDataInput) {
    return this.usersRepository.updateReviewData(id, input);
  }

  approveAgent(id: string) {
    return this.usersRepository.approveAgent(id);
  }

  rejectAgent(id: string) {
    return this.usersRepository.rejectAgent(id);
  }

  deactivateUser(id: string, reason: string) {
    return this.usersRepository.deactivate(id, reason);
  }

  getUserGuarantors(userId: string) {
    return this.usersRepository.getGuarantors(userId);
  }
}
