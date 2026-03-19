from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response

from .models import KycSubmission
from .serializers import KycStatusSerializer, KycSubmitSerializer
from .services import submit_kyc


@extend_schema(
    tags=["KYC"],
    request=KycSubmitSerializer,
    responses={
        status.HTTP_200_OK: KycStatusSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error or already pending/approved"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def submit(request: Request) -> Response:
    """Submit KYC using pre-uploaded file asset IDs. Re-submission replaces a rejected submission."""
    serializer = KycSubmitSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    d = serializer.validated_data

    try:
        submission = submit_kyc(
            user=request.user,
            id_type=d["id_type"],
            id_front_id=str(d["id_front_id"]),
            id_back_id=str(d["id_back_id"]),
            selfie_id=str(d["selfie_id"]),
            proof_of_address_id=str(d["proof_of_address_id"]),
        )
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    request.user.kyc_draft = {}
    request.user.save(update_fields=["kyc_draft", "updated_at"])
    return Response(KycStatusSerializer(submission).data, status=status.HTTP_200_OK)


@extend_schema(
    tags=["KYC"],
    responses={
        status.HTTP_200_OK: KycStatusSerializer,
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="No KYC submission found"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def kyc_status(request: Request) -> Response:
    """Return the current user's KYC submission status."""
    try:
        submission = KycSubmission.objects.get(user=request.user)
    except KycSubmission.DoesNotExist:
        return Response({"detail": "No KYC submission found."}, status=status.HTTP_404_NOT_FOUND)

    return Response(KycStatusSerializer(submission).data)


@extend_schema(
    tags=["KYC"],
    responses={
        status.HTTP_200_OK: OpenApiResponse(description="Current KYC draft"),
    },
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def kyc_draft(request: Request) -> Response:
    """Return the authenticated user's in-progress KYC wizard draft."""
    return Response(request.user.kyc_draft or {})


@extend_schema(
    tags=["KYC"],
    request=None,
    responses={
        status.HTTP_200_OK: OpenApiResponse(description="Draft saved"),
    },
)
@api_view(["PUT"])
@permission_classes([IsAuthenticated])
def kyc_draft_save(request: Request) -> Response:
    """Persist the in-progress KYC wizard draft for the authenticated user."""
    data = request.data
    if not isinstance(data, dict):
        return Response({"detail": "Expected a JSON object."}, status=status.HTTP_400_BAD_REQUEST)
    request.user.kyc_draft = data
    request.user.save(update_fields=["kyc_draft", "updated_at"])
    return Response(request.user.kyc_draft)
