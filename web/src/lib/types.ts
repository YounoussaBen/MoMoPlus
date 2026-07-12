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
export type IdType = "national_id" | "passport" | "drivers_license";

export interface UserKycSummary {
  id: string;
  status: KycStatus;
  id_type: IdType;
  rejection_reason: string;
  reviewed_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface StaffProfile {
  id: string;
  supabase_user_id: string | null;
  username: string;
  email: string;
  first_name: string;
  last_name: string;
  full_name: string;
  role: UserRole;
  agent_status: AgentStatus;
  kyc_status: KycStatus;
  created_at: string;
  updated_at: string;
}

export interface UpdateStaffProfileInput {
  first_name: string;
  last_name: string;
}

export interface AppUser {
  id: string;
  email: string | null;
  phone: string | null;
  first_name: string;
  last_name: string;
  full_name: string;
  role: UserRole;
  agent_status: AgentStatus;
  kyc_status: KycStatus;
  kyc_submission: UserKycSummary | null;
  is_active: boolean;
  deactivation_reason: string;
  deactivated_at: string | null;
  is_staff: boolean;
  created_at: string;
  updated_at: string;
}

export interface AppUserDetail extends AppUser {
  supabase_user_id: string;
  username: string;
  is_superuser: boolean;
}

// ─── Loan Guarantors ────────────────────────────────────────────────────────

export interface LoanGuarantor {
  id: string;
  name: string;
  phone_number: string;
  created_at: string;
  updated_at: string;
}

// ─── Shared (nested user in KYC / file URLs) ────────────────────────────────

export interface EmbeddedUser {
  id: string;
  supabase_user_id: string;
  username: string;
  email: string | null;
  phone: string | null;
  first_name: string;
  last_name: string;
  created_at: string;
  updated_at: string;
  is_active: boolean;
}

export interface FileUrl {
  url: string;
  expires_in: number | null;
}

// ─── KYC ─────────────────────────────────────────────────────────────────────

export interface KycSubmission {
  id: string;
  user: EmbeddedUser;
  status: KycStatus;
  id_type: IdType;
  created_at: string;
  updated_at: string;
}

export interface KycSubmissionDetail extends KycSubmission {
  id_front_url: FileUrl | null;
  id_back_url: FileUrl | null;
  selfie_url: FileUrl | null;
  proof_of_address_url: FileUrl | null;
  rejection_reason: string;
  reviewed_at: string | null;
}

// ─── Agents ──────────────────────────────────────────────────────────────────

export type CertificationStatus = "pending" | "approved" | "rejected";

export interface AgentCertification {
  id: string;
  agent_phone: string | null;
  agent_name: string;
  agent_id_number: string;
  network: string;
  agent_id_photo: string;
  business_location_photo: string;
  business_registration_number: string;
  status: CertificationStatus;
  rejection_reason: string;
  reviewed_at: string | null;
  created_at: string;
}

// ─── Loans ───────────────────────────────────────────────────────────────────

export type StaffLoanStatus =
  | "pending"
  | "approved"
  | "disbursing"
  | "active"
  | "repaying"
  | "completed"
  | "defaulted"
  | "rejected"
  | "failed"
  | "cancelled";

export type StaffLoanPaymentType = "disbursement" | "repayment";
export type StaffLoanPaymentStatus = "pending" | "success" | "failed";

export interface StaffLoanPayment {
  id: string;
  payment_type: StaffLoanPaymentType;
  amount: string;
  charge_amount: string;
  transfer_amount: string;
  platform_amount: string;
  status: StaffLoanPaymentStatus;
  reference: string;
  paystack_reference: string;
  payer_phone: string;
  payer_network: string;
  recipient_code: string;
  completed_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface StaffLoanListItem {
  id: string;
  borrower_id: string;
  borrower_name: string;
  borrower_phone: string | null;
  agent_user_id: string;
  agent_name: string;
  agent_id: string;
  agent_phone: string | null;
  amount: string;
  total_repayment: string;
  penalty_amount: string;
  outstanding_balance: string;
  agent_receivable_balance: string;
  status: StaffLoanStatus;
  network: string;
  borrower_wallet_phone: string;
  borrower_wallet_network: string;
  agent_wallet_phone: string;
  agent_wallet_network: string;
  approved_at: string | null;
  disbursed_at: string | null;
  deadline_at: string | null;
  completed_at: string | null;
  defaulted_at: string | null;
  is_overdue: boolean;
  created_at: string;
  updated_at: string;
}

export interface StaffLoanDetail extends StaffLoanListItem {
  interest_rate: string;
  origination_fee: string;
  agent_interest_amount: string;
  platform_interest_amount: string;
  rejection_reason: string;
  last_penalty_at: string | null;
  payments: StaffLoanPayment[];
}

// ─── Physical Transactions ───────────────────────────────────────────────────

export type StaffTransactionType = "cash_out" | "deposit";
export type StaffTransactionStatus =
  | "pending"
  | "accepted"
  | "completed"
  | "rejected"
  | "cancelled"
  | "expired";

export interface StaffPhysicalTransaction {
  id: string;
  user_id: string;
  user_phone: string | null;
  user_name: string;
  agent_user_id: string;
  agent_id: string;
  agent_phone: string | null;
  agent_name: string;
  transaction_type: StaffTransactionType;
  amount: string;
  network: string;
  status: StaffTransactionStatus;
  verification_code: string;
  meeting_latitude: string | null;
  meeting_longitude: string | null;
  meeting_description: string;
  has_meeting: boolean;
  user_confirmed: boolean;
  agent_confirmed: boolean;
  wallet_phone_number: string;
  wallet_network: string;
  cancellation_reason: string;
  created_at: string;
  updated_at: string;
  completed_at: string | null;
  expires_at: string;
}

// ─── Dashboard ────────────────────────────────────────────────────────────────

export interface DashboardSummary {
  total_users: number;
  approved_agents: number;
  pending_kyc_reviews: number;
  pending_agent_reviews: number;
  open_get_funds_cases: number;
  overdue_get_funds_cases: number;
  open_cash_services: number;
  scheduled_cash_meetings: number;
}

export interface DashboardPeriod {
  new_users: number;
  new_agents: number;
  new_kyc_submissions: number;
  new_get_funds_cases: number;
  new_cash_services: number;
  loan_disbursement_volume: string;
  loan_repayment_volume: string;
  cash_in_volume: string;
  cash_out_volume: string;
}

export interface DashboardActivityPoint {
  date: string;
  users: number;
  agents: number;
  kyc_submissions: number;
  get_funds_cases: number;
  cash_services: number;
}

export interface DashboardMoneyFlowPoint {
  date: string;
  loan_disbursements: string;
  loan_repayments: string;
  cash_in: string;
  cash_out: string;
}

export interface DashboardBreakdownPoint {
  key: string;
  label: string;
  value: number;
}

export interface DashboardCharts {
  activity: DashboardActivityPoint[];
  money_flow: DashboardMoneyFlowPoint[];
  kyc_status_breakdown: DashboardBreakdownPoint[];
  loan_status_breakdown: DashboardBreakdownPoint[];
  cash_service_status_breakdown: DashboardBreakdownPoint[];
  network_breakdown: DashboardBreakdownPoint[];
}

export interface StaffDashboardOverview {
  generated_at: string;
  range_days: number;
  summary: DashboardSummary;
  period: DashboardPeriod;
  charts: DashboardCharts;
}
