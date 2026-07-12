import { AgentsRepository } from "@/repositories/agents.repository";
import { UsersRepository } from "@/repositories/users.repository";
import type { AgentCertification, AppUser, CertificationStatus, FileUrl } from "@/lib/types";
import type { TableQueryInput } from "@/utils/query-params";
import { buildTableQueryParams } from "@/utils/query-params";

export type AgentRow = AppUser & { cert_status: CertificationStatus | "none" };

export class AgentsService {
  constructor(
    private readonly usersRepository: UsersRepository,
    private readonly agentsRepository: AgentsRepository,
  ) {}

  private buildVisibleCertMap(certs: AgentCertification[], phones: Array<string | null>) {
    const phoneSet = new Set(phones.filter((phone): phone is string => !!phone));

    return Object.fromEntries(
      certs
        .filter((cert) => !!cert.agent_phone && phoneSet.has(cert.agent_phone))
        .map((cert) => [cert.agent_phone!, cert]),
    ) as Record<string, AgentCertification>;
  }

  private buildAgentRows(
    users: AppUser[],
    certMap: Record<string, AgentCertification>,
    certFilter?: string,
  ) {
    let rows: AgentRow[] = users.map((user) => ({
      ...user,
      cert_status: (user.phone ? certMap[user.phone]?.status : "none") as
        | CertificationStatus
        | "none",
    }));

    if (certFilter) {
      rows = rows.filter((row) => row.cert_status === certFilter);
    }

    return rows;
  }

  async listAgents(input: TableQueryInput) {
    const [usersPage, certificationsPage] = await Promise.all([
      this.usersRepository.list(
        buildTableQueryParams(input, {
          staticParams: { agent_related: "true" },
          excludeFilterKeys: ["certified"],
        }),
      ),
      this.agentsRepository.listCertifications({ page_size: 100 }),
    ]);

    const certMap = this.buildVisibleCertMap(
      certificationsPage.results,
      usersPage.results.map((user) => user.phone),
    );
    const rows = this.buildAgentRows(usersPage.results, certMap, input.activeFilters.certified);

    return {
      rows,
      totalItems: input.activeFilters.certified ? rows.length : usersPage.count,
      certMap,
    };
  }

  async getAgentDetail(id: string) {
    const user = await this.usersRepository.getById(id);

    if (user.role !== "agent" && user.agent_status === "none") {
      return {
        user,
        certification: null as AgentCertification | null,
        certPhotoUrls: {} as Record<string, FileUrl>,
      };
    }

    if (!user.phone) {
      return {
        user,
        certification: null as AgentCertification | null,
        certPhotoUrls: {} as Record<string, FileUrl>,
      };
    }

    const certificationPage = await this.agentsRepository.listCertifications({
      search: user.phone,
      page_size: 1,
    });

    if (certificationPage.results.length === 0) {
      return {
        user,
        certification: null as AgentCertification | null,
        certPhotoUrls: {} as Record<string, FileUrl>,
      };
    }

    const certification = certificationPage.results[0];
    const urlEntries = await Promise.all(
      Object.entries({
        agent_id_photo: certification.agent_id_photo,
        business_location_photo: certification.business_location_photo,
      }).map(async ([key, fileId]) => {
        if (!fileId) return null;

        try {
          const fileUrl = await this.agentsRepository.getFileAccessUrl(fileId);
          return [key, fileUrl] as const;
        } catch {
          return null;
        }
      }),
    );

    return {
      user,
      certification,
      certPhotoUrls: Object.fromEntries(
        urlEntries.filter((entry): entry is readonly [string, FileUrl] => !!entry),
      ),
    };
  }

  approveAgent(id: string) {
    return this.usersRepository.approveAgent(id);
  }

  rejectAgent(id: string) {
    return this.usersRepository.rejectAgent(id);
  }

  approveCertification(id: string) {
    return this.agentsRepository.approveCertification(id);
  }

  rejectCertification(id: string, reason?: string) {
    return this.agentsRepository.rejectCertification(id, reason);
  }
}
