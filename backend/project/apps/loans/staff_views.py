from django.db.models import Q, QuerySet
from django.utils import timezone
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAdminUser
from rest_framework.request import Request
from rest_framework.response import Response

from .models import Loan, LoanStatus
from .staff_serializers import StaffLoanDetailSerializer, StaffLoanListSerializer


def _get_loan_or_404(loan_id: str) -> Loan | None:
    try:
        return (
            Loan.objects.select_related("borrower", "agent__user", "borrower_wallet", "agent_wallet")
            .prefetch_related("payments")
            .get(id=loan_id)
        )
    except (Loan.DoesNotExist, Exception):
        return None


def _apply_filters(qs: QuerySet, params: dict) -> QuerySet:
    status_filter = params.get("status")
    if status_filter in LoanStatus.values:
        qs = qs.filter(status=status_filter)

    network = params.get("network", "").strip()
    if network:
        qs = qs.filter(network__iexact=network)

    borrower_id = params.get("borrower_id", "").strip()
    if borrower_id:
        qs = qs.filter(borrower_id=borrower_id)

    agent_id = params.get("agent_id", "").strip()
    if agent_id:
        qs = qs.filter(agent_id=agent_id)

    search = params.get("search", "").strip()
    if search:
        qs = qs.filter(
            Q(borrower__phone__icontains=search)
            | Q(borrower__first_name__icontains=search)
            | Q(borrower__last_name__icontains=search)
            | Q(agent__user__phone__icontains=search)
            | Q(agent__user__first_name__icontains=search)
            | Q(agent__user__last_name__icontains=search)
            | Q(borrower_wallet__phone_number__icontains=search)
            | Q(agent_wallet__phone_number__icontains=search)
        )

    is_overdue = params.get("is_overdue")
    if is_overdue is not None:
        overdue_q = Q(status=LoanStatus.ACTIVE, deadline_at__lt=timezone.now())
        value = is_overdue.lower()
        if value == "true":
            qs = qs.filter(overdue_q)
        elif value == "false":
            qs = qs.exclude(overdue_q)

    return qs


def _apply_ordering(qs: QuerySet, ordering: str | None) -> QuerySet:
    allowed = {
        "created_at",
        "-created_at",
        "updated_at",
        "-updated_at",
        "amount",
        "-amount",
        "status",
        "-status",
        "outstanding_balance",
        "-outstanding_balance",
        "total_repayment",
        "-total_repayment",
        "approved_at",
        "-approved_at",
        "disbursed_at",
        "-disbursed_at",
        "deadline_at",
        "-deadline_at",
        "completed_at",
        "-completed_at",
        "defaulted_at",
        "-defaulted_at",
    }
    if ordering in allowed:
        return qs.order_by(ordering)
    return qs.order_by("-created_at")


@extend_schema(
    tags=["Staff — Loans"],
    parameters=[
        OpenApiParameter("status", str, description="Filter by status"),
        OpenApiParameter("network", str, description="Filter by network"),
        OpenApiParameter("borrower_id", str, description="Filter by borrower UUID"),
        OpenApiParameter("agent_id", str, description="Filter by agent profile UUID"),
        OpenApiParameter("search", str, description="Search by borrower/agent phone number, name, or wallet phone"),
        OpenApiParameter("is_overdue", str, description="Filter overdue active loans: true | false"),
        OpenApiParameter(
            "ordering",
            str,
            description=(
                "Sort field. Prefix with - for descending. "
                "Options: created_at, updated_at, amount, status, outstanding_balance, "
                "total_repayment, approved_at, disbursed_at, deadline_at, completed_at, defaulted_at"
            ),
        ),
        OpenApiParameter("page", int, description="Page number"),
    ],
    responses={
        status.HTTP_200_OK: StaffLoanListSerializer(many=True),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
    },
)
@api_view(["GET"])
@permission_classes([IsAdminUser])
def loan_list(request: Request) -> Response:
    """List loans for staff monitoring with filtering, search, sorting, and pagination."""
    qs = Loan.objects.select_related("borrower", "agent__user", "borrower_wallet", "agent_wallet")
    qs = _apply_filters(qs, request.query_params)
    qs = _apply_ordering(qs, request.query_params.get("ordering"))

    paginator = PageNumberPagination()
    page = paginator.paginate_queryset(qs, request)
    serializer = StaffLoanListSerializer(page, many=True)
    return paginator.get_paginated_response(serializer.data)


@extend_schema(
    tags=["Staff — Loans"],
    responses={
        status.HTTP_200_OK: StaffLoanDetailSerializer,
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Loan not found"),
    },
)
@api_view(["GET"])
@permission_classes([IsAdminUser])
def loan_detail(request: Request, loan_id: str) -> Response:
    """Retrieve a single loan with payment history and lifecycle details."""
    loan = _get_loan_or_404(loan_id)
    if loan is None:
        return Response({"detail": "Loan not found."}, status=status.HTTP_404_NOT_FOUND)

    return Response(StaffLoanDetailSerializer(loan).data)
