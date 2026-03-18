from django.conf import settings
from django.contrib.auth import authenticate
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import AccessToken

from .models import AgentStatus, UserRole
from .serializers import (
    AuthSyncResponseSerializer,
    MessageSerializer,
    StaffLoginResponseSerializer,
    StaffLoginSerializer,
    StaffUserSerializer,
    UserProfileSerializer,
)


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
