from django.db.models import Q, QuerySet
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAdminUser
from rest_framework.request import Request
from rest_framework.response import Response

from .models import AgentStatus, User, UserRole
from .staff_serializers import AgentRejectSerializer, StaffUserDetailSerializer, StaffUserListSerializer


def _get_user_or_404(user_id: str) -> User | None:
    try:
        return User.objects.get(id=user_id)
    except (User.DoesNotExist, Exception):
        return None


def _apply_filters(qs: QuerySet, params: dict) -> QuerySet:
    role = params.get("role")
    if role in UserRole.values:
        qs = qs.filter(role=role)

    agent_status = params.get("agent_status")
    if agent_status in AgentStatus.values:
        qs = qs.filter(agent_status=agent_status)

    is_active = params.get("is_active")
    if is_active is not None:
        qs = qs.filter(is_active=(is_active.lower() == "true"))

    search = params.get("search", "").strip()
    if search:
        qs = qs.filter(Q(email__icontains=search) | Q(first_name__icontains=search) | Q(last_name__icontains=search))

    return qs


def _apply_ordering(qs: QuerySet, ordering: str | None) -> QuerySet:
    allowed = {
        "created_at",
        "-created_at",
        "email",
        "-email",
        "first_name",
        "-first_name",
        "last_name",
        "-last_name",
        "role",
        "-role",
        "agent_status",
        "-agent_status",
    }
    if ordering in allowed:
        return qs.order_by(ordering)
    return qs.order_by("-created_at")


@extend_schema(
    tags=["Staff — Users"],
    parameters=[
        OpenApiParameter("role", str, description="Filter by role: user | agent"),
        OpenApiParameter(
            "agent_status", str, description="Filter by agent_status: none | pending | approved | rejected"
        ),
        OpenApiParameter("is_active", str, description="Filter by active status: true | false"),
        OpenApiParameter("search", str, description="Search by email, first name, or last name"),
        OpenApiParameter(
            "ordering",
            str,
            description="Sort field. Prefix with - for descending. Options: created_at, email, first_name, last_name, role, agent_status",
        ),
        OpenApiParameter("page", int, description="Page number"),
    ],
    responses={
        status.HTTP_200_OK: StaffUserListSerializer(many=True),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
    },
)
@api_view(["GET"])
@permission_classes([IsAdminUser])
def user_list(request: Request) -> Response:
    """List all users. Supports filtering, searching, sorting and pagination."""
    qs = User.objects.exclude(is_superuser=True)
    qs = _apply_filters(qs, request.query_params)
    qs = _apply_ordering(qs, request.query_params.get("ordering"))

    from rest_framework.pagination import PageNumberPagination

    paginator = PageNumberPagination()
    page = paginator.paginate_queryset(qs, request)
    serializer = StaffUserListSerializer(page, many=True)
    return paginator.get_paginated_response(serializer.data)


@extend_schema(
    tags=["Staff — Users"],
    responses={
        status.HTTP_200_OK: StaffUserDetailSerializer,
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="User not found"),
    },
)
@api_view(["GET"])
@permission_classes([IsAdminUser])
def user_detail(request: Request, user_id: str) -> Response:
    """Retrieve a single user's full profile."""
    user = _get_user_or_404(user_id)
    if user is None:
        return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)
    return Response(StaffUserDetailSerializer(user).data)


@extend_schema(
    tags=["Staff — Users"],
    request=None,
    responses={
        status.HTTP_200_OK: StaffUserDetailSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(
            description="User is already an agent or not a pending applicant"
        ),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="User not found"),
    },
)
@api_view(["POST"])
@permission_classes([IsAdminUser])
def approve_agent(request: Request, user_id: str) -> Response:
    """Approve a pending agent application. Sets role=agent and agent_status=approved."""
    user = _get_user_or_404(user_id)
    if user is None:
        return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)

    if user.role == UserRole.AGENT:
        return Response({"detail": "User is already an agent."}, status=status.HTTP_400_BAD_REQUEST)

    if user.agent_status != AgentStatus.PENDING:
        return Response(
            {"detail": "Only pending applications can be approved."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user.role = UserRole.AGENT
    user.agent_status = AgentStatus.APPROVED
    user.save(update_fields=["role", "agent_status", "updated_at"])

    from project.apps.agents.models import AgentProfile, AgentType

    AgentProfile.objects.get_or_create(user=user, defaults={"agent_type": AgentType.CERTIFIED})

    return Response(StaffUserDetailSerializer(user).data, status=status.HTTP_200_OK)


@extend_schema(
    tags=["Staff — Users"],
    request=AgentRejectSerializer,
    responses={
        status.HTTP_200_OK: StaffUserDetailSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Application is not in a rejectable state"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="User not found"),
    },
)
@api_view(["POST"])
@permission_classes([IsAdminUser])
def reject_agent(request: Request, user_id: str) -> Response:
    """Reject a pending agent application. Optionally accepts a reason (ignored for now, reserved for notifications)."""
    user = _get_user_or_404(user_id)
    if user is None:
        return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)

    if user.agent_status != AgentStatus.PENDING:
        return Response(
            {"detail": "Only pending applications can be rejected."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user.agent_status = AgentStatus.REJECTED
    user.save(update_fields=["agent_status", "updated_at"])

    return Response(StaffUserDetailSerializer(user).data, status=status.HTTP_200_OK)
