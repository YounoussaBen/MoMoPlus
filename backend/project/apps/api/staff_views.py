from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, time, timedelta
from decimal import Decimal

from django.db.models import Count, Sum
from django.db.models.functions import Coalesce, TruncDate
from django.utils import timezone
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAdminUser
from rest_framework.request import Request
from rest_framework.response import Response

from project.apps.accounts.models import AgentStatus, User, UserRole
from project.apps.agents.models import AgentProfile, CertificationApplication, CertificationStatus
from project.apps.kyc.models import KycSubmission
from project.apps.loans.models import Loan, LoanPayment, LoanStatus, PaymentStatus, PaymentType
from project.apps.transactions.models import PhysicalTransaction, TransactionStatus, TransactionType
from project.apps.wallets.models import Wallet

from .staff_serializers import StaffDashboardOverviewSerializer

ZERO_AMOUNT = Decimal("0.00")
ALLOWED_RANGE_DAYS = {7, 14, 30, 90}
OPEN_LOAN_STATUSES = [
    LoanStatus.APPROVED,
    LoanStatus.DISBURSING,
    LoanStatus.ACTIVE,
    LoanStatus.REPAYING,
]
OPEN_CASH_SERVICE_STATUSES = [
    TransactionStatus.PENDING,
    TransactionStatus.ACCEPTED,
]


def _parse_range_days(raw_value: str | None) -> int:
    if raw_value is None:
        return 30

    try:
        parsed = int(raw_value)
    except (TypeError, ValueError):
        return 30

    return parsed if parsed in ALLOWED_RANGE_DAYS else 30


def _make_day_start(value: date) -> datetime:
    return timezone.make_aware(datetime.combine(value, time.min), timezone.get_current_timezone())


def _build_date_sequence(start_date: date, end_date: date) -> list[date]:
    return [start_date + timedelta(days=index) for index in range((end_date - start_date).days + 1)]


def _count_by_day(queryset, *, date_field: str = "created_at") -> dict[date, int]:
    rows = queryset.annotate(day=TruncDate(date_field)).values("day").annotate(value=Count("id")).order_by("day")
    return {row["day"]: row["value"] for row in rows if row["day"] is not None}


def _amount_by_day(queryset, *, date_field: str = "created_at") -> dict[date, Decimal]:
    rows = (
        queryset.annotate(day=TruncDate(date_field))
        .values("day")
        .annotate(value=Coalesce(Sum("amount"), ZERO_AMOUNT))
        .order_by("day")
    )
    return {row["day"]: row["value"] for row in rows if row["day"] is not None}


def _build_breakdown(choices, rows: dict[str, int]) -> list[dict[str, int | str]]:
    return [
        {
            "key": value,
            "label": label,
            "value": rows.get(value, 0),
        }
        for value, label in choices
    ]


def _sum_amount(queryset) -> Decimal:
    return queryset.aggregate(total=Coalesce(Sum("amount"), ZERO_AMOUNT))["total"]


@extend_schema(
    tags=["Staff — Dashboard"],
    parameters=[
        OpenApiParameter(
            "days",
            int,
            description="Chart window in days. Supported values: 7, 14, 30, 90. Defaults to 30.",
        ),
    ],
    responses={
        status.HTTP_200_OK: StaffDashboardOverviewSerializer,
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
    },
)
@api_view(["GET"])
@permission_classes([IsAdminUser])
def dashboard_overview(request: Request) -> Response:
    """Return aggregated dashboard metrics and chart-ready series for the staff web dashboard."""

    range_days = _parse_range_days(request.query_params.get("days"))
    today = timezone.localdate()
    range_start_date = today - timedelta(days=range_days - 1)
    range_start = _make_day_start(range_start_date)
    now = timezone.now()

    users_queryset = User.objects.exclude(is_superuser=True)
    agents_queryset = AgentProfile.objects.select_related("user")
    certifications_queryset = CertificationApplication.objects.select_related("agent_profile__user")
    kyc_queryset = KycSubmission.objects.select_related("user")
    loans_queryset = Loan.objects.select_related("borrower", "agent__user")
    transactions_queryset = PhysicalTransaction.objects.select_related("user", "agent__user")
    successful_payments_queryset = LoanPayment.objects.filter(status=PaymentStatus.SUCCESS).annotate(
        effective_at=Coalesce("completed_at", "created_at")
    )
    completed_transactions_queryset = PhysicalTransaction.objects.filter(status=TransactionStatus.COMPLETED).annotate(
        effective_at=Coalesce("completed_at", "created_at")
    )

    current_period_filters = {"created_at__gte": range_start}

    summary = {
        "total_users": users_queryset.count(),
        "approved_agents": agents_queryset.filter(
            user__role=UserRole.AGENT,
            user__agent_status=AgentStatus.APPROVED,
            user__is_active=True,
        ).count(),
        "pending_kyc_reviews": kyc_queryset.filter(status=KycSubmission.Status.PENDING).count(),
        "pending_agent_reviews": certifications_queryset.filter(status=CertificationStatus.PENDING).count(),
        "open_get_funds_cases": loans_queryset.filter(status__in=OPEN_LOAN_STATUSES).count(),
        "overdue_get_funds_cases": loans_queryset.filter(
            status=LoanStatus.ACTIVE,
            deadline_at__lt=now,
        ).count(),
        "open_cash_services": transactions_queryset.filter(status__in=OPEN_CASH_SERVICE_STATUSES).count(),
        "scheduled_cash_meetings": transactions_queryset.filter(
            status=TransactionStatus.ACCEPTED,
            meeting_latitude__isnull=False,
            meeting_longitude__isnull=False,
        ).count(),
    }

    period = {
        "new_users": users_queryset.filter(**current_period_filters).count(),
        "new_agents": agents_queryset.filter(created_at__gte=range_start).count(),
        "new_kyc_submissions": kyc_queryset.filter(**current_period_filters).count(),
        "new_get_funds_cases": loans_queryset.filter(**current_period_filters).count(),
        "new_cash_services": transactions_queryset.filter(**current_period_filters).count(),
        "loan_disbursement_volume": _sum_amount(
            successful_payments_queryset.filter(
                effective_at__gte=range_start,
                payment_type=PaymentType.DISBURSEMENT,
            )
        ),
        "loan_repayment_volume": _sum_amount(
            successful_payments_queryset.filter(
                effective_at__gte=range_start,
                payment_type=PaymentType.REPAYMENT,
            )
        ),
        "cash_in_volume": _sum_amount(
            completed_transactions_queryset.filter(
                effective_at__gte=range_start,
                transaction_type=TransactionType.DEPOSIT,
            )
        ),
        "cash_out_volume": _sum_amount(
            completed_transactions_queryset.filter(
                effective_at__gte=range_start,
                transaction_type=TransactionType.CASH_OUT,
            )
        ),
    }

    activity_days = _build_date_sequence(range_start_date, today)
    user_series = _count_by_day(users_queryset.filter(created_at__gte=range_start))
    agent_series = _count_by_day(agents_queryset.filter(created_at__gte=range_start))
    kyc_series = _count_by_day(kyc_queryset.filter(created_at__gte=range_start))
    loan_series = _count_by_day(loans_queryset.filter(created_at__gte=range_start))
    cash_series = _count_by_day(transactions_queryset.filter(created_at__gte=range_start))

    activity = [
        {
            "date": day,
            "users": user_series.get(day, 0),
            "agents": agent_series.get(day, 0),
            "kyc_submissions": kyc_series.get(day, 0),
            "get_funds_cases": loan_series.get(day, 0),
            "cash_services": cash_series.get(day, 0),
        }
        for day in activity_days
    ]

    loan_disbursement_series = _amount_by_day(
        successful_payments_queryset.filter(
            effective_at__gte=range_start,
            payment_type=PaymentType.DISBURSEMENT,
        ),
        date_field="effective_at",
    )
    loan_repayment_series = _amount_by_day(
        successful_payments_queryset.filter(
            effective_at__gte=range_start,
            payment_type=PaymentType.REPAYMENT,
        ),
        date_field="effective_at",
    )
    cash_in_series = _amount_by_day(
        completed_transactions_queryset.filter(
            effective_at__gte=range_start,
            transaction_type=TransactionType.DEPOSIT,
        ),
        date_field="effective_at",
    )
    cash_out_series = _amount_by_day(
        completed_transactions_queryset.filter(
            effective_at__gte=range_start,
            transaction_type=TransactionType.CASH_OUT,
        ),
        date_field="effective_at",
    )

    money_flow = [
        {
            "date": day,
            "loan_disbursements": loan_disbursement_series.get(day, ZERO_AMOUNT),
            "loan_repayments": loan_repayment_series.get(day, ZERO_AMOUNT),
            "cash_in": cash_in_series.get(day, ZERO_AMOUNT),
            "cash_out": cash_out_series.get(day, ZERO_AMOUNT),
        }
        for day in activity_days
    ]

    kyc_status_counts = {
        row["status"]: row["value"] for row in kyc_queryset.values("status").annotate(value=Count("id"))
    }
    loan_status_counts = {
        row["status"]: row["value"] for row in loans_queryset.values("status").annotate(value=Count("id"))
    }
    cash_status_counts = {
        row["status"]: row["value"] for row in transactions_queryset.values("status").annotate(value=Count("id"))
    }

    network_counts = defaultdict(int)
    for row in loans_queryset.filter(created_at__gte=range_start).values("network").annotate(value=Count("id")):
        network_counts[row["network"]] += row["value"]
    for row in transactions_queryset.filter(created_at__gte=range_start).values("network").annotate(value=Count("id")):
        network_counts[row["network"]] += row["value"]

    charts = {
        "activity": activity,
        "money_flow": money_flow,
        "kyc_status_breakdown": _build_breakdown(KycSubmission.Status.choices, kyc_status_counts),
        "loan_status_breakdown": _build_breakdown(LoanStatus.choices, loan_status_counts),
        "cash_service_status_breakdown": _build_breakdown(TransactionStatus.choices, cash_status_counts),
        "network_breakdown": _build_breakdown(Wallet.Network.choices, dict(network_counts)),
    }

    payload = {
        "generated_at": now,
        "range_days": range_days,
        "summary": summary,
        "period": period,
        "charts": charts,
    }
    return Response(StaffDashboardOverviewSerializer(payload).data)
