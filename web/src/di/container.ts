import { AuthRepository } from "@/repositories/auth.repository";
import { AgentsRepository } from "@/repositories/agents.repository";
import { KycRepository } from "@/repositories/kyc.repository";
import { UsersRepository } from "@/repositories/users.repository";
import { AuthService } from "@/services/auth.service";
import { AgentsService } from "@/services/agents.service";
import { KycService } from "@/services/kyc.service";
import { UsersService } from "@/services/users.service";

const authRepository = new AuthRepository();
const usersRepository = new UsersRepository();
const agentsRepository = new AgentsRepository();
const kycRepository = new KycRepository();

export const container = {
  authService: new AuthService(authRepository),
  usersService: new UsersService(usersRepository),
  agentsService: new AgentsService(usersRepository, agentsRepository),
  kycService: new KycService(usersRepository, kycRepository),
};
