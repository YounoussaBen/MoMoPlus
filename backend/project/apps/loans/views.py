from datetime import date

from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response

from project.apps.accounts.models import UserRole

from .models import Loan
from .serializers import (
    AcceptLoanSerializer,
    AgentEarningsSerializer,
    CancelLoanSerializer,
    LoanSerializer,
    RejectLoanSerializer,
    RepayLoanSerializer,
    RequestLoanSerializer,
)
from .services import (
    accept_loan,
    cancel_loan,
    get_agent_earnings,
    get_agent_loans,
    get_borrower_loans,
    get_loan_detail,
    initiate_disbursement,
    initiate_repayment,
    reject_loan,
    request_loan,
)


def _get_loan_or_404(pk: str) -> Loan | None:
    try:
        return (
            Loan.objects.select_related("borrower", "agent__user", "borrower_wallet", "agent_wallet")
            .prefetch_related("payments")
            .get(pk=pk)
        )
    except Loan.DoesNotExist:
        return None


@extend_schema(
    tags=["Loans"],
    request=RequestLoanSerializer,
    responses={
        status.HTTP_201_CREATED: LoanSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def loan_request(request: Request) -> Response:
    """User requests an emergency loan from an agent."""
    serializer = RequestLoanSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    d = serializer.validated_data

    try:
        loan = request_loan(
            borrower=request.user,
            agent_profile_id=str(d["agent_id"]),
            amount=d["amount"],
            wallet_id=str(d["wallet_id"]),
            network=d["network"],
        )
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    loan = get_loan_detail(loan_id=str(loan.pk), user=request.user)
    return Response(LoanSerializer(loan).data, status=status.HTTP_201_CREATED)


@extend_schema(
    tags=["Loans"],
    responses={status.HTTP_200_OK: LoanSerializer(many=True)},
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def loan_list(request: Request) -> Response:
    """List loans for the authenticated user (borrower or agent)."""
    status_filter = request.query_params.get("status")

    if request.user.role == UserRole.AGENT:
        loans = get_agent_loans(user=request.user, status=status_filter)
    else:
        loans = get_borrower_loans(user=request.user, status=status_filter)

    return Response(LoanSerializer(loans, many=True).data)


@extend_schema(
    tags=["Loans"],
    parameters=[
        OpenApiParameter(
            name="period",
            type=str,
            location=OpenApiParameter.QUERY,
            required=False,
            description="Filter recent earnings to: today | week | month | custom",
        ),
        OpenApiParameter(
            name="start_date",
            type=str,
            location=OpenApiParameter.QUERY,
            required=False,
            description="Required when period=custom. Format: YYYY-MM-DD.",
        ),
        OpenApiParameter(
            name="end_date",
            type=str,
            location=OpenApiParameter.QUERY,
            required=False,
            description="Required when period=custom. Format: YYYY-MM-DD.",
        ),
    ],
    responses={
        status.HTTP_200_OK: AgentEarningsSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Invalid period or date filter"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Not an agent"),
    },
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def agent_earnings(request: Request) -> Response:
    """Aggregated earnings for the authenticated agent."""
    if request.user.role != UserRole.AGENT:
        return Response({"detail": "Only agents can view earnings."}, status=status.HTTP_403_FORBIDDEN)

    period = request.query_params.get("period") or None
    start_date_raw = request.query_params.get("start_date") or None
    end_date_raw = request.query_params.get("end_date") or None

    if period not in {None, "today", "week", "month", "custom"}:
        return Response(
            {"detail": "Invalid period. Use today, week, month, or custom."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        start_date = date.fromisoformat(start_date_raw) if start_date_raw else None
        end_date = date.fromisoformat(end_date_raw) if end_date_raw else None
    except ValueError:
        return Response(
            {"detail": "Invalid date format. Use YYYY-MM-DD for start_date and end_date."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if period == "custom":
        if start_date is None or end_date is None:
            return Response(
                {"detail": "Custom period requires start_date and end_date."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if start_date > end_date:
            return Response(
                {"detail": "start_date cannot be after end_date."},
                status=status.HTTP_400_BAD_REQUEST,
            )
    elif start_date is not None or end_date is not None:
        return Response(
            {"detail": "start_date and end_date can only be used with period=custom."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    data = get_agent_earnings(
        user=request.user,
        period=period,
        start_date=start_date,
        end_date=end_date,
    )
    return Response(AgentEarningsSerializer(data).data)


@extend_schema(
    tags=["Loans"],
    responses={
        status.HTTP_200_OK: LoanSerializer,
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Loan not found"),
    },
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def loan_detail(request: Request, pk: str) -> Response:
    """Get details of a specific loan."""
    try:
        loan = get_loan_detail(loan_id=pk, user=request.user)
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_404_NOT_FOUND)

    return Response(LoanSerializer(loan).data)


@extend_schema(
    tags=["Loans"],
    request=AcceptLoanSerializer,
    responses={
        status.HTTP_200_OK: LoanSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Loan not found"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def loan_accept(request: Request, pk: str) -> Response:
    """Agent accepts a loan request."""
    loan = _get_loan_or_404(pk)
    if loan is None:
        return Response({"detail": "Loan not found."}, status=status.HTTP_404_NOT_FOUND)

    serializer = AcceptLoanSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    try:
        loan = accept_loan(
            loan=loan,
            agent_user=request.user,
            agent_wallet_id=str(serializer.validated_data["agent_wallet_id"]),
        )
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(LoanSerializer(loan).data)


@extend_schema(
    tags=["Loans"],
    request=RejectLoanSerializer,
    responses={
        status.HTTP_200_OK: LoanSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Loan not found"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def loan_reject(request: Request, pk: str) -> Response:
    """Agent rejects a loan request."""
    loan = _get_loan_or_404(pk)
    if loan is None:
        return Response({"detail": "Loan not found."}, status=status.HTTP_404_NOT_FOUND)

    serializer = RejectLoanSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    try:
        loan = reject_loan(
            loan=loan,
            agent_user=request.user,
            reason=serializer.validated_data.get("reason", ""),
        )
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(LoanSerializer(loan).data)


@extend_schema(
    tags=["Loans"],
    request=None,
    responses={
        status.HTTP_200_OK: LoanSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Loan not found"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def loan_disburse(request: Request, pk: str) -> Response:
    """Initiate disbursement for an approved loan (charges the agent's MoMo)."""
    loan = _get_loan_or_404(pk)
    if loan is None:
        return Response({"detail": "Loan not found."}, status=status.HTTP_404_NOT_FOUND)

    if loan.agent.user_id != request.user.pk:
        return Response({"detail": "Only the agent can initiate disbursement."}, status=status.HTTP_400_BAD_REQUEST)

    try:
        initiate_disbursement(loan=loan)
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    loan.refresh_from_db()
    return Response(LoanSerializer(loan).data)


@extend_schema(
    tags=["Loans"],
    request=RepayLoanSerializer,
    responses={
        status.HTTP_200_OK: LoanSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Loan not found"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def loan_repay(request: Request, pk: str) -> Response:
    """Initiate repayment for an active loan (charges the borrower's MoMo)."""
    loan = _get_loan_or_404(pk)
    if loan is None:
        return Response({"detail": "Loan not found."}, status=status.HTTP_404_NOT_FOUND)

    if loan.borrower_id != request.user.pk:
        return Response({"detail": "Only the borrower can initiate repayment."}, status=status.HTTP_400_BAD_REQUEST)

    serializer = RepayLoanSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    amount = serializer.validated_data.get("amount")

    try:
        initiate_repayment(loan=loan, amount=amount)
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    loan.refresh_from_db()
    return Response(LoanSerializer(loan).data)


@extend_schema(
    tags=["Loans"],
    request=CancelLoanSerializer,
    responses={
        status.HTTP_200_OK: LoanSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Loan not found"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def loan_cancel(request: Request, pk: str) -> Response:
    """Cancel a pending or approved loan."""
    loan = _get_loan_or_404(pk)
    if loan is None:
        return Response({"detail": "Loan not found."}, status=status.HTTP_404_NOT_FOUND)

    serializer = CancelLoanSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    try:
        loan = cancel_loan(
            loan=loan,
            user=request.user,
            reason=serializer.validated_data.get("reason", ""),
        )
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(LoanSerializer(loan).data)
