export function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export function formatDateTime(iso: string): string {
  return new Date(iso).toLocaleString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

export function formatCurrency(value: string | number | null | undefined): string {
  if (value === null || value === undefined || value === "") return "—";

  const amount = typeof value === "string" ? Number.parseFloat(value) : value;
  if (!Number.isFinite(amount)) return "—";

  return `GHS ${amount.toLocaleString("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

const NETWORK_LABEL: Record<string, string> = {
  mtn: "MTN",
  vodafone: "Telecel",
  telecel: "Telecel",
  airteltigo: "AirtelTigo",
};

export function formatNetwork(network: string): string {
  return NETWORK_LABEL[network] ?? network;
}

export const ID_TYPE_LABEL: Record<string, string> = {
  national_id: "Ghana Card",
  passport: "Passport",
  drivers_license: "Driver's License",
};

export function formatIdType(idType: string): string {
  return ID_TYPE_LABEL[idType] ?? idType;
}

const LOAN_STATUS_LABEL: Record<string, string> = {
  pending: "Pending",
  approved: "Approved",
  disbursing: "Disbursing",
  active: "Active",
  repaying: "Repaying",
  completed: "Completed",
  defaulted: "Defaulted",
  rejected: "Rejected",
  failed: "Failed",
  cancelled: "Cancelled",
};

export function formatLoanStatus(status: string): string {
  return LOAN_STATUS_LABEL[status] ?? status;
}

const PAYMENT_TYPE_LABEL: Record<string, string> = {
  disbursement: "Disbursement",
  repayment: "Repayment",
};

export function formatPaymentType(paymentType: string): string {
  return PAYMENT_TYPE_LABEL[paymentType] ?? paymentType;
}

const PAYMENT_STATUS_LABEL: Record<string, string> = {
  pending: "Pending",
  success: "Success",
  failed: "Failed",
};

export function formatPaymentStatus(status: string): string {
  return PAYMENT_STATUS_LABEL[status] ?? status;
}

const TRANSACTION_TYPE_LABEL: Record<string, string> = {
  cash_out: "Cash Out",
  deposit: "Cash In",
};

export function formatTransactionType(type: string): string {
  return TRANSACTION_TYPE_LABEL[type] ?? type;
}

const TRANSACTION_STATUS_LABEL: Record<string, string> = {
  pending: "Pending",
  accepted: "Accepted",
  completed: "Completed",
  rejected: "Rejected",
  cancelled: "Cancelled",
  expired: "Expired",
};

export function formatTransactionStatus(status: string): string {
  return TRANSACTION_STATUS_LABEL[status] ?? status;
}
