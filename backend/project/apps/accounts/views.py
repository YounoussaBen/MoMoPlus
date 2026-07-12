import json
import re

from django.conf import settings
from django.contrib.auth import authenticate
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import AccessToken

from project.integrations.sms_gateway import SmsDeliveryError, send_login_otp

from .models import AgentStatus, LoanGuarantor, UserRole
from .phone_numbers import InvalidPhoneNumber, normalize_ghana_phone
from .serializers import (
    AuthSyncResponseSerializer,
    GuarantorBulkCreateSerializer,
    GuarantorCreateSerializer,
    GuarantorSerializer,
    GuarantorUpdateSerializer,
    MessageSerializer,
    StaffLoginResponseSerializer,
    StaffLoginSerializer,
    StaffUserSerializer,
    UserProfileSerializer,
)
from .services import add_guarantor, bulk_create_guarantors, delete_guarantor, update_guarantor
from .webhooks import WebhookSignatureError, verify_standard_webhook


@extend_schema(
    tags=["Authentication"],
    auth=[],
    request=None,
    responses={
        status.HTTP_200_OK: OpenApiResponse(description="SMS accepted by provider"),
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Invalid hook payload"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Invalid hook signature"),
        status.HTTP_502_BAD_GATEWAY: OpenApiResponse(description="SMS provider failure"),
    },
)
@api_view(["POST"])
@permission_classes([AllowAny])
def supabase_send_sms_hook(request: Request) -> Response:
    """Deliver a Supabase-generated login code through Arkesel.

    The raw request body is authenticated before JSON parsing. Supabase remains
    the sole owner of OTP creation, expiry, attempt limits and verification.
    """

    raw_body = request.body
    try:
        verify_standard_webhook(
            raw_body=raw_body,
            webhook_id=request.headers.get("webhook-id"),
            webhook_timestamp=request.headers.get("webhook-timestamp"),
            webhook_signature=request.headers.get("webhook-signature"),
            secret=settings.SEND_SMS_HOOK_SECRET,
            tolerance_seconds=settings.SEND_SMS_HOOK_TOLERANCE_SECONDS,
        )
    except WebhookSignatureError:
        return Response(
            {"error": {"http_code": 401, "message": "Invalid webhook signature."}},
            status=status.HTTP_401_UNAUTHORIZED,
        )

    try:
        event = json.loads(raw_body.decode("utf-8"))
        phone = normalize_ghana_phone(event["user"]["phone"])
        otp_code = str(event["sms"]["otp"])
        if re.fullmatch(r"\d{6}", otp_code) is None:
            raise ValueError
    except (UnicodeDecodeError, json.JSONDecodeError, KeyError, TypeError, ValueError, InvalidPhoneNumber):
        return Response(
            {"error": {"http_code": 400, "message": "Invalid SMS hook payload."}},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        send_login_otp(phone=phone, otp_code=otp_code)
    except SmsDeliveryError:
        return Response(
            {"error": {"http_code": 502, "message": "Unable to deliver the verification code."}},
            status=status.HTTP_502_BAD_GATEWAY,
        )

    return Response({}, status=status.HTTP_200_OK)


@extend_schema(
    tags=["Authentication"],
    auth=[],
    request=StaffLoginSerializer,
    responses={
        status.HTTP_200_OK: StaffLoginResponseSerializer,
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Invalid credentials"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
    },
)
@api_view(["POST"])
@permission_classes([AllowAny])
def staff_login(request: Request) -> Response:
    serializer = StaffLoginSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    user = authenticate(
        request=request,
        email=serializer.validated_data["email"],
        password=serializer.validated_data["password"],
    )
    if user is None:
        return Response({"detail": "Invalid credentials."}, status=status.HTTP_401_UNAUTHORIZED)

    if not (user.is_staff or user.is_superuser):
        return Response({"detail": "Staff access is required."}, status=status.HTTP_403_FORBIDDEN)

    token = AccessToken.for_user(user)
    token["staff_session"] = True
    token["auth_source"] = "django_staff"
    token["email"] = user.email

    return Response(
        {
            "access": str(token),
            "token_type": "Bearer",
            "expires_in": int(settings.SIMPLE_JWT["ACCESS_TOKEN_LIFETIME"].total_seconds()),
            "user": StaffUserSerializer(user).data,
        },
        status=status.HTTP_200_OK,
    )


@extend_schema(
    tags=["Authentication"],
    request=None,
    responses={
        status.HTTP_200_OK: AuthSyncResponseSerializer,
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def sync_profile(request: Request) -> Response:
    """Ensure the Supabase identity is mapped into Django and return the current profile."""
    serializer = UserProfileSerializer(request.user)
    return Response(
        {
            "message": "Supabase user is synced with Django.",
            "user": serializer.data,
        },
        status=status.HTTP_200_OK,
    )


@extend_schema(
    methods=["GET"],
    tags=["Authentication"],
    responses={
        status.HTTP_200_OK: UserProfileSerializer,
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@extend_schema(
    methods=["PUT", "PATCH"],
    tags=["Authentication"],
    request=UserProfileSerializer,
    responses={
        status.HTTP_200_OK: UserProfileSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["GET", "PUT", "PATCH"])
@permission_classes([IsAuthenticated])
def profile(request: Request) -> Response:
    """Get or update user profile"""
    if request.method == "GET":
        serializer = UserProfileSerializer(request.user)
        return Response(serializer.data)

    elif request.method in ["PUT", "PATCH"]:
        serializer = UserProfileSerializer(request.user, data=request.data, partial=(request.method == "PATCH"))
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    return Response({"error": "Method not allowed"}, status=status.HTTP_405_METHOD_NOT_ALLOWED)


@extend_schema(
    tags=["Authentication"],
    request=None,
    responses={
        status.HTTP_200_OK: MessageSerializer,
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def logout(request: Request) -> Response:
    """Explain the expected logout flow for bearer-token clients."""
    return Response(
        {"message": "Discard the current bearer token on the client. Mobile clients should also sign out Supabase."}
    )


@extend_schema(
    tags=["Authentication"],
    request=None,
    responses={
        status.HTTP_200_OK: MessageSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Already an agent or application already pending"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def request_agent(request: Request) -> Response:
    """Submit an application to become an agent. Pending admin approval."""
    user = request.user

    if user.role == UserRole.AGENT:
        return Response({"detail": "You are already an agent."}, status=status.HTTP_400_BAD_REQUEST)

    if user.agent_status == AgentStatus.PENDING:
        return Response(
            {"detail": "Your agent application is already pending review."}, status=status.HTTP_400_BAD_REQUEST
        )

    user.agent_status = AgentStatus.PENDING
    user.save(update_fields=["agent_status", "updated_at"])

    return Response({"message": "Agent application submitted. Pending admin approval."}, status=status.HTTP_200_OK)


# ── Loan Guarantors ─────────────────────────────────────────────────────


@extend_schema(
    methods=["GET"],
    tags=["Guarantors"],
    responses={status.HTTP_200_OK: GuarantorSerializer(many=True)},
)
@extend_schema(
    methods=["POST"],
    tags=["Guarantors"],
    request=GuarantorCreateSerializer,
    responses={
        status.HTTP_201_CREATED: GuarantorSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
    },
)
@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def guarantor_list(request: Request) -> Response:
    if request.method == "GET":
        guarantors = request.user.loan_guarantors.order_by("-created_at")
        return Response(GuarantorSerializer(guarantors, many=True).data)

    serializer = GuarantorCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    guarantor = add_guarantor(
        user=request.user,
        name=serializer.validated_data["name"],
        phone_number=serializer.validated_data["phone_number"],
    )
    return Response(GuarantorSerializer(guarantor).data, status=status.HTTP_201_CREATED)


@extend_schema(
    tags=["Guarantors"],
    request=GuarantorBulkCreateSerializer,
    responses={
        status.HTTP_201_CREATED: GuarantorSerializer(many=True),
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def guarantor_bulk_create(request: Request) -> Response:
    serializer = GuarantorBulkCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    try:
        guarantors = bulk_create_guarantors(
            user=request.user,
            guarantors_data=serializer.validated_data["guarantors"],
        )
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
    return Response(GuarantorSerializer(guarantors, many=True).data, status=status.HTTP_201_CREATED)


@extend_schema(
    methods=["PUT"],
    tags=["Guarantors"],
    request=GuarantorUpdateSerializer,
    responses={
        status.HTTP_200_OK: GuarantorSerializer,
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Guarantor not found"),
    },
)
@extend_schema(
    methods=["DELETE"],
    tags=["Guarantors"],
    responses={
        status.HTTP_204_NO_CONTENT: OpenApiResponse(description="Deleted"),
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Cannot delete — minimum 2 required"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Guarantor not found"),
    },
)
@api_view(["PUT", "DELETE"])
@permission_classes([IsAuthenticated])
def guarantor_detail(request: Request, guarantor_id: str) -> Response:
    try:
        guarantor = request.user.loan_guarantors.get(id=guarantor_id)
    except LoanGuarantor.DoesNotExist:
        return Response({"detail": "Guarantor not found."}, status=status.HTTP_404_NOT_FOUND)

    if request.method == "PUT":
        serializer = GuarantorUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        guarantor = update_guarantor(
            guarantor=guarantor,
            name=serializer.validated_data.get("name"),
            phone_number=serializer.validated_data.get("phone_number"),
        )
        return Response(GuarantorSerializer(guarantor).data)

    # DELETE
    try:
        delete_guarantor(guarantor=guarantor, user=request.user)
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
    return Response(status=status.HTTP_204_NO_CONTENT)
