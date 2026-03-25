from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response

from project.apps.accounts.models import UserRole

from .models import PhysicalTransaction
from .serializers import (
    AcceptTransactionSerializer,
    CancelTransactionSerializer,
    CreatePhysicalTransactionSerializer,
    PhysicalTransactionSerializer,
    RejectTransactionSerializer,
)
from .services import (
    accept_transaction,
    cancel_transaction,
    confirm_transaction,
    create_physical_transaction,
    get_agent_transactions,
    get_transaction_detail,
    get_user_transactions,
    reject_transaction,
)


def _get_txn_or_404(pk: str) -> PhysicalTransaction | None:
    try:
        return PhysicalTransaction.objects.select_related("user", "agent__user", "wallet").get(pk=pk)
    except PhysicalTransaction.DoesNotExist:
        return None


@extend_schema(
    tags=["Cash Services"],
    request=CreatePhysicalTransactionSerializer,
    responses={
        status.HTTP_201_CREATED: PhysicalTransactionSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def create_transaction(request: Request) -> Response:
    """Create a physical transaction request."""
    serializer = CreatePhysicalTransactionSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    d = serializer.validated_data

    try:
        txn = create_physical_transaction(
            user=request.user,
            agent_profile_id=str(d["agent_id"]),
            transaction_type=d["transaction_type"],
            amount=d["amount"],
            network=d["network"],
            wallet_id=str(d["wallet_id"]),
        )
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(
        PhysicalTransactionSerializer(txn).data,
        status=status.HTTP_201_CREATED,
    )


@extend_schema(
    tags=["Cash Services"],
    responses={status.HTTP_200_OK: PhysicalTransactionSerializer(many=True)},
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def list_transactions(request: Request) -> Response:
    """List physical transactions for the authenticated user or agent."""
    status_filter = request.query_params.get("status")

    if request.user.role == UserRole.AGENT:
        txns = get_agent_transactions(user=request.user, status=status_filter)
    else:
        txns = get_user_transactions(user=request.user, status=status_filter)

    return Response(PhysicalTransactionSerializer(txns, many=True).data)


@extend_schema(
    tags=["Cash Services"],
    responses={
        status.HTTP_200_OK: PhysicalTransactionSerializer,
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Transaction not found"),
    },
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def transaction_detail(request: Request, pk: str) -> Response:
    """Get details of a specific physical transaction."""
    try:
        txn = get_transaction_detail(transaction_id=pk, user=request.user)
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_404_NOT_FOUND)

    return Response(PhysicalTransactionSerializer(txn).data)


@extend_schema(
    tags=["Cash Services"],
    request=AcceptTransactionSerializer,
    responses={
        status.HTTP_200_OK: PhysicalTransactionSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Transaction not found"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def accept_transaction_view(request: Request, pk: str) -> Response:
    """Agent accepts a physical transaction and sets the meeting point."""
    txn = _get_txn_or_404(pk)
    if txn is None:
        return Response({"detail": "Transaction not found."}, status=status.HTTP_404_NOT_FOUND)

    serializer = AcceptTransactionSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    d = serializer.validated_data

    try:
        txn = accept_transaction(
            txn=txn,
            user=request.user,
            meeting_latitude=d["meeting_latitude"],
            meeting_longitude=d["meeting_longitude"],
            meeting_description=d.get("meeting_description", ""),
        )
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(PhysicalTransactionSerializer(txn).data)


@extend_schema(
    tags=["Cash Services"],
    request=RejectTransactionSerializer,
    responses={
        status.HTTP_200_OK: PhysicalTransactionSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Transaction not found"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def reject_transaction_view(request: Request, pk: str) -> Response:
    """Agent rejects a physical transaction."""
    txn = _get_txn_or_404(pk)
    if txn is None:
        return Response({"detail": "Transaction not found."}, status=status.HTTP_404_NOT_FOUND)

    serializer = RejectTransactionSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    try:
        txn = reject_transaction(
            txn=txn,
            user=request.user,
            reason=serializer.validated_data.get("reason", ""),
        )
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(PhysicalTransactionSerializer(txn).data)


@extend_schema(
    tags=["Cash Services"],
    request=None,
    responses={
        status.HTTP_200_OK: PhysicalTransactionSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Transaction not found"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def confirm_transaction_view(request: Request, pk: str) -> Response:
    """Confirm the verification code for a physical transaction."""
    txn = _get_txn_or_404(pk)
    if txn is None:
        return Response({"detail": "Transaction not found."}, status=status.HTTP_404_NOT_FOUND)

    try:
        txn = confirm_transaction(txn=txn, user=request.user)
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(PhysicalTransactionSerializer(txn).data)


@extend_schema(
    tags=["Cash Services"],
    request=CancelTransactionSerializer,
    responses={
        status.HTTP_200_OK: PhysicalTransactionSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Transaction not found"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def cancel_transaction_view(request: Request, pk: str) -> Response:
    """Cancel a physical transaction."""
    txn = _get_txn_or_404(pk)
    if txn is None:
        return Response({"detail": "Transaction not found."}, status=status.HTTP_404_NOT_FOUND)

    serializer = CancelTransactionSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    try:
        txn = cancel_transaction(
            txn=txn,
            user=request.user,
            reason=serializer.validated_data.get("reason", ""),
        )
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(PhysicalTransactionSerializer(txn).data)
