from django.db.models import Q, QuerySet
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAdminUser
from rest_framework.request import Request
from rest_framework.response import Response

from .models import PhysicalTransaction, TransactionStatus, TransactionType
from .staff_serializers import StaffPhysicalTransactionSerializer


def _get_transaction_or_404(transaction_id: str) -> PhysicalTransaction | None:
    try:
        return PhysicalTransaction.objects.select_related("user", "agent__user", "wallet").get(id=transaction_id)
    except (PhysicalTransaction.DoesNotExist, Exception):
        return None


def _apply_filters(qs: QuerySet, params: dict) -> QuerySet:
    status_filter = params.get("status")
    if status_filter in TransactionStatus.values:
        qs = qs.filter(status=status_filter)

    transaction_type = params.get("transaction_type")
    if transaction_type in TransactionType.values:
        qs = qs.filter(transaction_type=transaction_type)

    network = params.get("network", "").strip()
    if network:
        qs = qs.filter(network__iexact=network)

    user_id = params.get("user_id", "").strip()
    if user_id:
        qs = qs.filter(user_id=user_id)

    agent_id = params.get("agent_id", "").strip()
    if agent_id:
        qs = qs.filter(agent_id=agent_id)

    search = params.get("search", "").strip()
    if search:
        qs = qs.filter(
            Q(user__email__icontains=search)
            | Q(user__first_name__icontains=search)
            | Q(user__last_name__icontains=search)
            | Q(agent__user__email__icontains=search)
            | Q(agent__user__first_name__icontains=search)
            | Q(agent__user__last_name__icontains=search)
            | Q(wallet__phone_number__icontains=search)
            | Q(meeting_description__icontains=search)
        )

    has_meeting = params.get("has_meeting")
    if has_meeting is not None:
        meeting_q = Q(meeting_latitude__isnull=False, meeting_longitude__isnull=False)
        value = has_meeting.lower()
        if value == "true":
            qs = qs.filter(meeting_q)
        elif value == "false":
            qs = qs.exclude(meeting_q)

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
        "transaction_type",
        "-transaction_type",
        "completed_at",
        "-completed_at",
        "expires_at",
        "-expires_at",
    }
    if ordering in allowed:
        return qs.order_by(ordering)
    return qs.order_by("-created_at")


@extend_schema(
    tags=["Staff — Cash Services"],
    parameters=[
        OpenApiParameter("status", str, description="Filter by status"),
        OpenApiParameter("transaction_type", str, description="Filter by transaction type: cash_out | deposit"),
        OpenApiParameter("network", str, description="Filter by network"),
        OpenApiParameter("user_id", str, description="Filter by user UUID"),
        OpenApiParameter("agent_id", str, description="Filter by agent profile UUID"),
        OpenApiParameter("search", str, description="Search by user/agent email, name, wallet phone, or meeting note"),
        OpenApiParameter("has_meeting", str, description="Filter transactions with meeting coordinates: true | false"),
        OpenApiParameter(
            "ordering",
            str,
            description=(
                "Sort field. Prefix with - for descending. "
                "Options: created_at, updated_at, amount, status, transaction_type, completed_at, expires_at"
            ),
        ),
        OpenApiParameter("page", int, description="Page number"),
    ],
    responses={
        status.HTTP_200_OK: StaffPhysicalTransactionSerializer(many=True),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
    },
)
@api_view(["GET"])
@permission_classes([IsAdminUser])
def transaction_list(request: Request) -> Response:
    """List physical cash-service transactions for staff monitoring."""
    qs = PhysicalTransaction.objects.select_related("user", "agent__user", "wallet")
    qs = _apply_filters(qs, request.query_params)
    qs = _apply_ordering(qs, request.query_params.get("ordering"))

    paginator = PageNumberPagination()
    page = paginator.paginate_queryset(qs, request)
    serializer = StaffPhysicalTransactionSerializer(page, many=True)
    return paginator.get_paginated_response(serializer.data)


@extend_schema(
    tags=["Staff — Cash Services"],
    responses={
        status.HTTP_200_OK: StaffPhysicalTransactionSerializer,
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Transaction not found"),
    },
)
@api_view(["GET"])
@permission_classes([IsAdminUser])
def transaction_detail(request: Request, transaction_id: str) -> Response:
    """Retrieve a single physical cash-service transaction."""
    transaction = _get_transaction_or_404(transaction_id)
    if transaction is None:
        return Response({"detail": "Transaction not found."}, status=status.HTTP_404_NOT_FOUND)

    return Response(StaffPhysicalTransactionSerializer(transaction).data)
