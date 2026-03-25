import type { TableQueryInput } from "@/utils/query-params";

export const usersKeys = {
  all: ["users"] as const,
  lists: () => ["users", "list"] as const,
  list: (input: TableQueryInput) => ["users", "list", input] as const,
  detail: (id: string) => ["users", "detail", id] as const,
};

export const agentsKeys = {
  all: ["agents"] as const,
  lists: () => ["agents", "list"] as const,
  list: (input: TableQueryInput) => ["agents", "list", input] as const,
  certifications: () => ["agents", "certifications"] as const,
  detail: (id: string) => ["agents", "detail", id] as const,
};

export const kycKeys = {
  all: ["kyc"] as const,
  lists: () => ["kyc", "list"] as const,
  list: (input: TableQueryInput) => ["kyc", "list", input] as const,
  detail: (id: string) => ["kyc", "detail", id] as const,
};
