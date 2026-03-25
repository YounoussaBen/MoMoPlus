// ─── Auth ────────────────────────────────────────────────────────────────────

export interface StaffUser {
  id: string;
  username: string;
  email: string;
  first_name: string;
  last_name: string;
  is_active: boolean;
  is_staff: boolean;
  is_superuser: boolean;
}

export interface LoginResponse {
  access: string;
  token_type: string;
  expires_in: number;
  user: StaffUser;
}

// ─── Pagination (DRF PageNumberPagination) ───────────────────────────────────

export interface PaginatedResponse<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}

// ─── Users ───────────────────────────────────────────────────────────────────

export type UserRole = "user" | "agent";
export type AgentStatus = "none" | "pending" | "approved" | "rejected";
export type KycStatus = "none" | "pending" | "approved" | "rejected";

export interface AppUser {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  full_name: string;
  role: UserRole;
  agent_status: AgentStatus;
  is_active: boolean;
  is_staff: boolean;
  created_at: string;
  updated_at: string;
}

export interface AppUserDetail extends AppUser {
  supabase_user_id: string;
  username: string;
  is_superuser: boolean;
}

// ─── KYC ─────────────────────────────────────────────────────────────────────

export type IdType = "ghana_card" | "passport" | "drivers_license";

export interface KycSubmission {
  id: string;
  user_email: string;
  user_name: string;
  status: KycStatus;
  id_type: IdType;
  id_front_id: string;
  id_back_id: string;
  selfie_id: string;
  proof_of_address_id: string;
  rejection_reason: string | null;
  created_at: string;
  updated_at: string;
}

// ─── Agents ──────────────────────────────────────────────────────────────────

export type CertificationStatus = "pending" | "approved" | "rejected";

export interface AgentCertification {
  id: string;
  agent_id_number: string;
  network: string;
  agent_id_photo: string;
  business_location_photo: string;
  business_registration_number: string;
  status: CertificationStatus;
  rejection_reason: string | null;
  created_at: string;
  updated_at: string;
  agent_email?: string;
  agent_name?: string;
}

// ─── Loans ───────────────────────────────────────────────────────────────────

export type LoanStatus =
  | "pending_agent_review"
  | "approved_pending_disbursement"
  | "disbursed"
  | "active"
  | "repayment_pending"
  | "completed"
  | "defaulted"
  | "failed"
  | "cancelled";

export interface LoanPayment {
  id: string;
  payment_type: "disbursement" | "repayment";
  amount: string;
  charge_amount: string;
  transfer_amount: string;
  platform_amount: string;
  status: "pending" | "completed" | "failed";
  reference: string;
  payer_phone: string;
  payer_network: string;
  completed_at: string | null;
  created_at: string;
}

export interface Loan {
  id: string;
  borrower_name: string;
  borrower_email: string;
  agent_name: string;
  agent_id: string;
  amount: string;
  interest_rate: string;
  origination_fee: string;
  agent_interest_amount: string;
  platform_interest_amount: string;
  total_repayment: string;
  penalty_amount: string;
  outstanding_balance: string;
  agent_receivable_balance: string;
  status: LoanStatus;
  network: string;
  borrower_wallet_phone: string;
  borrower_wallet_network: string;
  agent_wallet_phone: string;
  rejection_reason: string | null;
  approved_at: string | null;
  disbursed_at: string | null;
  deadline_at: string | null;
  completed_at: string | null;
  defaulted_at: string | null;
  created_at: string;
  payments: LoanPayment[];
}

// ─── Physical Transactions ───────────────────────────────────────────────────

export type TransactionType = "cash_out" | "cash_in";
export type TransactionStatus =
  | "pending_agent_review"
  | "accepted"
  | "completed"
  | "rejected"
  | "cancelled";

export interface PhysicalTransaction {
  id: string;
  transaction_type: TransactionType;
  amount: string;
  network: string;
  status: TransactionStatus;
  verification_code: string;
  meeting_latitude: number | null;
  meeting_longitude: number | null;
  meeting_description: string;
  user_confirmed: boolean;
  agent_confirmed: boolean;
  user_name: string;
  agent_name: string;
  agent_id: string;
  wallet_phone_number: string;
  wallet_network: string;
  cancellation_reason: string | null;
  created_at: string;
  updated_at: string;
  completed_at: string | null;
  expires_at: string;
}
