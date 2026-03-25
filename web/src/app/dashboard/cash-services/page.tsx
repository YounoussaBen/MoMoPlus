import { ArrowLeftRight } from "lucide-react";
import { ComingSoonPage } from "@/components/dashboard/coming-soon";

export default function CashServicesPage() {
  return (
    <ComingSoonPage
      title="Cash Services"
      description="Monitor physical cash-in and cash-out transactions, meeting sessions, and incident reports."
      icon={ArrowLeftRight}
    />
  );
}
