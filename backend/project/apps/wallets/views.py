from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response

from .models import Wallet
from .serializers import AddWalletSerializer, VerifyOtpSerializer, WalletSerializer
from .services import add_wallet, delete_wallet, resend_otp, set_default_wallet, verify_otp


@extend_schema(
    tags=["Wallets"],
    responses={
        status.HTTP_200_OK: WalletSerializer(many=True),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def wallet_list(request: Request) -> Response:
    """List the authenticated user's wallets."""
    wallets = Wallet.objects.filter(user=request.user).order_by("-is_default", "-created_at")
    return Response(WalletSerializer(wallets, many=True).data)


@extend_schema(
    tags=["Wallets"],
    request=AddWalletSerializer,
    responses={
        status.HTTP_201_CREATED: WalletSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error or duplicate"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def wallet_create(request: Request) -> Response:
    """Add a new wallet. An OTP will be sent for verification."""
    serializer = AddWalletSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    d = serializer.validated_data

    try:
        wallet = add_wallet(
            user=request.user,
            phone_number=d["phone_number"],
            network=d["network"],
        )
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(WalletSerializer(wallet).data, status=status.HTTP_201_CREATED)


def _get_user_wallet(request: Request, pk: str) -> Wallet | None:
    """Helper to fetch a wallet owned by the authenticated user."""
    try:
        return Wallet.objects.get(pk=pk, user=request.user)
    except Wallet.DoesNotExist:
        return None


@extend_schema(
    tags=["Wallets"],
    request=VerifyOtpSerializer,
    responses={
        status.HTTP_200_OK: WalletSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Invalid or expired OTP"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Wallet not found"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def wallet_verify(request: Request, pk: str) -> Response:
    """Verify wallet ownership with an OTP code."""
    wallet = _get_user_wallet(request, pk)
    if wallet is None:
        return Response({"detail": "Wallet not found."}, status=status.HTTP_404_NOT_FOUND)

    serializer = VerifyOtpSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    try:
        wallet = verify_otp(wallet=wallet, code=serializer.validated_data["code"])
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(WalletSerializer(wallet).data)


@extend_schema(
    tags=["Wallets"],
    request=None,
    responses={
        status.HTTP_200_OK: OpenApiResponse(description="OTP resent"),
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Wallet already verified"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Wallet not found"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def wallet_resend_otp(request: Request, pk: str) -> Response:
    """Resend OTP for an unverified wallet."""
    wallet = _get_user_wallet(request, pk)
    if wallet is None:
        return Response({"detail": "Wallet not found."}, status=status.HTTP_404_NOT_FOUND)

    try:
        resend_otp(wallet=wallet)
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response({"detail": "OTP sent."})


@extend_schema(
    tags=["Wallets"],
    request=None,
    responses={
        status.HTTP_200_OK: WalletSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Wallet not verified"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Wallet not found"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def wallet_set_default(request: Request, pk: str) -> Response:
    """Set a verified wallet as default."""
    wallet = _get_user_wallet(request, pk)
    if wallet is None:
        return Response({"detail": "Wallet not found."}, status=status.HTTP_404_NOT_FOUND)

    try:
        wallet = set_default_wallet(user=request.user, wallet=wallet)
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(WalletSerializer(wallet).data)


@extend_schema(
    tags=["Wallets"],
    request=None,
    responses={
        status.HTTP_204_NO_CONTENT: OpenApiResponse(description="Wallet deleted"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Wallet not found"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def wallet_delete(request: Request, pk: str) -> Response:
    """Delete a wallet."""
    wallet = _get_user_wallet(request, pk)
    if wallet is None:
        return Response({"detail": "Wallet not found."}, status=status.HTTP_404_NOT_FOUND)

    try:
        delete_wallet(user=request.user, wallet=wallet)
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(status=status.HTTP_204_NO_CONTENT)
