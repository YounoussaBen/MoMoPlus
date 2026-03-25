import { Wallet } from "lucide-react";
import { ComingSoonPage } from "@/components/dashboard/coming-soon";

export default function GetFundsPage() {
  return (
    <ComingSoonPage
      title="Get Funds"
      description="Monitor active loans, track disbursements and repayments, and manage overdue cases."
      icon={Wallet}
    />
  );
}
