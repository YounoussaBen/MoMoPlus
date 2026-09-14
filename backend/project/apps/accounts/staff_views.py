from django.db import transaction
from django.db.models import Q, QuerySet
from django.utils import timezone
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAdminUser
from rest_framework.request import Request
from rest_framework.response import Response

from project.apps.kyc.models import KycSubmission

from .models import AgentStatus, KycStatus, User, UserRole
from .serializers import GuarantorSerializer
from .staff_serializers import (
    AccountDeactivateSerializer,
    AgentRejectSerializer,
    StaffUserDetailSerializer,
    StaffUserListSerializer,
    StaffUserReviewUpdateSerializer,
)


def _get_user_or_404(user_id: str) -> User | None:
    try:
        return User.objects.get(id=user_id)
    except (User.DoesNotExist, Exception):
        return None


def _apply_filters(qs: QuerySet, params: dict) -> QuerySet:
    if params.get("agent_related", "").lower() == "true":
        qs = qs.filter(Q(role=UserRole.AGENT) | ~Q(agent_status=AgentStatus.NONE))
    else:
        role = params.get("role")
        if role in UserRole.values:
            qs = qs.filter(role=role)

    agent_status = params.get("agent_status")
    if agent_status in AgentStatus.values:
        qs = qs.filter(agent_status=agent_status)

    kyc_status = params.get("kyc_status")
    if kyc_status in KycStatus.values:
        qs = qs.filter(kyc_status=kyc_status)

    id_type = params.get("id_type")
    if id_type in KycSubmission.IdType.values:
        qs = qs.filter(kyc_submission__id_type=id_type)

    is_active = params.get("is_active")
    if is_active is not None:
        qs = qs.filter(is_active=(is_active.lower() == "true"))

    search = params.get("search", "").strip()
    if search:
        qs = qs.filter(Q(phone__icontains=search) | Q(first_name__icontains=search) | Q(last_name__icontains=search))

    return qs


def _apply_ordering(qs: QuerySet, ordering: str | None) -> QuerySet:
    allowed = {
        "created_at",
        "-created_at",
        "phone",
        "-phone",
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
            "agent_related",
            str,
            description="If true, return users who are agents or have a pending/rejected application",
        ),
        OpenApiParameter(
            "agent_status", str, description="Filter by agent_status: none | pending | approved | rejected"
        ),
        OpenApiParameter("kyc_status", str, description="Filter by KYC status: none | pending | approved | rejected"),
        OpenApiParameter("id_type", str, description="Filter by KYC ID type: national_id (Ghana Card)"),
        OpenApiParameter("is_active", str, description="Filter by active status: true | false"),
        OpenApiParameter("search", str, description="Search by phone number, first name, or last name"),
        OpenApiParameter(
            "ordering",
            str,
            description="Sort field. Prefix with - for descending. Options: created_at, phone, first_name, last_name, role, agent_status",
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
    qs = User.objects.exclude(is_superuser=True).select_related("kyc_submission")
    qs = _apply_filters(qs, request.query_params)
    qs = _apply_ordering(qs, request.query_params.get("ordering"))

    from rest_framework.pagination import PageNumberPagination

    paginator = PageNumberPagination()
    page = paginator.paginate_queryset(qs, request)
    serializer = StaffUserListSerializer(page, many=True)
    return paginator.get_paginated_response(serializer.data)


@extend_schema(
    methods=["GET"],
    tags=["Staff — Users"],
    responses={
        status.HTTP_200_OK: StaffUserDetailSerializer,
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="User not found"),
    },
)
@extend_schema(
    methods=["PATCH"],
    tags=["Staff — Users"],
    request=StaffUserReviewUpdateSerializer,
    responses={
        status.HTTP_200_OK: StaffUserDetailSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(
            description="Validation error or the user's KYC has already been approved"
        ),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="User not found"),
    },
)
@api_view(["GET", "PATCH"])
@permission_classes([IsAdminUser])
def user_detail(request: Request, user_id: str) -> Response:
    """Retrieve or correct a user's review data."""
    user = _get_user_or_404(user_id)
    if user is None:
        return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)

    if request.method == "PATCH":
        serializer = StaffUserReviewUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        with transaction.atomic():
            user = User.objects.select_for_update().get(pk=user.pk)
            submission = KycSubmission.objects.select_for_update().filter(user_id=user.pk).first()

            if user.is_staff or user.is_superuser:
                return Response(
                    {"detail": "Staff accounts cannot be edited here."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if user.kyc_status == KycStatus.APPROVED or (
                submission and submission.status == KycSubmission.Status.APPROVED
            ):
                return Response(
                    {"detail": "Approved KYC data cannot be edited."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            validated = serializer.validated_data
            update_fields: list[str] = []
            for field in ("first_name", "last_name"):
                if field in validated:
                    setattr(user, field, validated[field])
                    update_fields.append(field)

            if update_fields:
                update_fields.append("updated_at")
                user.save(update_fields=update_fields)

    return Response(StaffUserDetailSerializer(user).data)


@extend_schema(
    tags=["Staff — Users"],
    request=AccountDeactivateSerializer,
    responses={
        status.HTTP_200_OK: StaffUserDetailSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(
            description="Account is not KYC-approved, is already inactive, or is a staff account"
        ),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="User not found"),
    },
)
@api_view(["POST"])
@permission_classes([IsAdminUser])
def deactivate_user(request: Request, user_id: str) -> Response:
    """Deactivate a KYC-approved account and retain the staff-provided reason."""
    user = _get_user_or_404(user_id)
    if user is None:
        return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)
    if user.is_staff:
        return Response({"detail": "Staff accounts cannot be deactivated here."}, status=status.HTTP_400_BAD_REQUEST)
    if user.kyc_status != KycStatus.APPROVED:
        return Response(
            {"detail": "Only KYC-approved accounts can be deactivated."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if not user.is_active:
        return Response({"detail": "Account is already inactive."}, status=status.HTTP_400_BAD_REQUEST)

    serializer = AccountDeactivateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    user.is_active = False
    user.deactivation_reason = serializer.validated_data["reason"]
    user.deactivated_at = timezone.now()
    user.save(update_fields=["is_active", "deactivation_reason", "deactivated_at", "updated_at"])
    return Response(StaffUserDetailSerializer(user).data, status=status.HTTP_200_OK)


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

    AgentProfile.objects.get_or_create(user=user, defaults={"agent_type": AgentType.SELF_ENROLLED})

    return Response(StaffUserDetailSerializer(user).data, status=status.HTTP_200_OK)


@extend_schema(
    tags=["Staff — Users"],
    responses={
        status.HTTP_200_OK: GuarantorSerializer(many=True),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="User not found"),
    },
)
@api_view(["GET"])
@permission_classes([IsAdminUser])
def user_guarantors(request: Request, user_id: str) -> Response:
    """List loan guarantors for a specific user."""
    user = _get_user_or_404(user_id)
    if user is None:
        return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)
    guarantors = user.loan_guarantors.order_by("-created_at")
    return Response(GuarantorSerializer(guarantors, many=True).data)


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
