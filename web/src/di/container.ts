import { AuthRepository } from "@/repositories/auth.repository";
import { AgentsRepository } from "@/repositories/agents.repository";
import { CashServicesRepository } from "@/repositories/cash-services.repository";
import { DashboardRepository } from "@/repositories/dashboard.repository";
import { GetFundsRepository } from "@/repositories/get-funds.repository";
import { GhanaCardsRepository } from "@/repositories/ghana-cards.repository";
import { KycRepository } from "@/repositories/kyc.repository";
import { UsersRepository } from "@/repositories/users.repository";
import { AuthService } from "@/services/auth.service";
import { AgentsService } from "@/services/agents.service";
import { CashServicesService } from "@/services/cash-services.service";
import { DashboardService } from "@/services/dashboard.service";
import { GetFundsService } from "@/services/get-funds.service";
import { GhanaCardsService } from "@/services/ghana-cards.service";
import { KycService } from "@/services/kyc.service";
import { UsersService } from "@/services/users.service";

const authRepository = new AuthRepository();
const usersRepository = new UsersRepository();
const agentsRepository = new AgentsRepository();
const kycRepository = new KycRepository();
const dashboardRepository = new DashboardRepository();
const getFundsRepository = new GetFundsRepository();
const ghanaCardsRepository = new GhanaCardsRepository();
const cashServicesRepository = new CashServicesRepository();

export const container = {
  authService: new AuthService(authRepository),
  usersService: new UsersService(usersRepository),
  agentsService: new AgentsService(usersRepository, agentsRepository),
  kycService: new KycService(kycRepository),
  dashboardService: new DashboardService(dashboardRepository),
  getFundsService: new GetFundsService(getFundsRepository),
  ghanaCardsService: new GhanaCardsService(ghanaCardsRepository),
  cashServicesService: new CashServicesService(cashServicesRepository),
};
