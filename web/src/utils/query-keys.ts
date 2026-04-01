import type { TableQueryInput } from "@/utils/query-params";

export const authKeys = {
  all: ["auth"] as const,
  profile: () => ["auth", "profile"] as const,
};

export const dashboardKeys = {
  all: ["dashboard"] as const,
  overview: (days: number) => ["dashboard", "overview", days] as const,
};

export const usersKeys = {
  all: ["users"] as const,
  lists: () => ["users", "list"] as const,
  list: (input: TableQueryInput) => ["users", "list", input] as const,
  detail: (id: string) => ["users", "detail", id] as const,
  guarantors: (id: string) => ["users", "guarantors", id] as const,
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

export const getFundsKeys = {
  all: ["get-funds"] as const,
  lists: () => ["get-funds", "list"] as const,
  list: (input: TableQueryInput) => ["get-funds", "list", input] as const,
  detail: (id: string) => ["get-funds", "detail", id] as const,
};

export const cashServicesKeys = {
  all: ["cash-services"] as const,
  lists: () => ["cash-services", "list"] as const,
  list: (input: TableQueryInput) => ["cash-services", "list", input] as const,
  detail: (id: string) => ["cash-services", "detail", id] as const,
};
