from django.db.models import Q, QuerySet
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAdminUser
from rest_framework.request import Request
from rest_framework.response import Response

from .models import CertificationApplication, CertificationStatus
from .serializers import CertificationRejectSerializer, StaffCertificationListSerializer
from .services import approve_certification, reject_certification


def _get_application_or_404(application_id: str) -> CertificationApplication | None:
    try:
        return CertificationApplication.objects.select_related(
            "agent_profile__user",
            "agent_id_photo",
            "business_location_photo",
            "reviewed_by",
        ).get(id=application_id)
    except (CertificationApplication.DoesNotExist, Exception):
        return None


def _apply_filters(qs: QuerySet, params: dict) -> QuerySet:
    status_filter = params.get("status")
    if status_filter in CertificationStatus.values:
        qs = qs.filter(status=status_filter)

    search = params.get("search", "").strip()
    if search:
        qs = qs.filter(
            Q(agent_profile__user__phone__icontains=search)
            | Q(agent_profile__user__first_name__icontains=search)
            | Q(agent_profile__user__last_name__icontains=search)
            | Q(agent_id_number__icontains=search)
        )

    return qs


@extend_schema(
    tags=["Staff — Certifications"],
    parameters=[
        OpenApiParameter("status", str, description="Filter by status: pending | approved | rejected"),
        OpenApiParameter("search", str, description="Search by agent phone number, name, or agent ID"),
        OpenApiParameter("page", int, description="Page number"),
    ],
    responses={
        status.HTTP_200_OK: StaffCertificationListSerializer(many=True),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
    },
)
@api_view(["GET"])
@permission_classes([IsAdminUser])
def certification_list(request: Request) -> Response:
    """List certification applications. Supports filtering, searching, and pagination."""
    qs = CertificationApplication.objects.select_related(
        "agent_profile__user",
    ).order_by("-created_at")
    qs = _apply_filters(qs, request.query_params)

    paginator = PageNumberPagination()
    page = paginator.paginate_queryset(qs, request)
    serializer = StaffCertificationListSerializer(page, many=True)
    return paginator.get_paginated_response(serializer.data)


@extend_schema(
    tags=["Staff — Certifications"],
    responses={
        status.HTTP_200_OK: StaffCertificationListSerializer,
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Application not found"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
    },
)
@api_view(["GET"])
@permission_classes([IsAdminUser])
def certification_detail(request: Request, application_id: str) -> Response:
    """Retrieve a single certification application."""
    application = _get_application_or_404(application_id)
    if application is None:
        return Response({"detail": "Application not found."}, status=status.HTTP_404_NOT_FOUND)
    return Response(StaffCertificationListSerializer(application).data)


@extend_schema(
    tags=["Staff — Certifications"],
    request=None,
    responses={
        status.HTTP_200_OK: StaffCertificationListSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Application is not pending"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Application not found"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
    },
)
@api_view(["POST"])
@permission_classes([IsAdminUser])
def certification_approve(request: Request, application_id: str) -> Response:
    """Approve a certification application. Upgrades the agent to certified."""
    application = _get_application_or_404(application_id)
    if application is None:
        return Response({"detail": "Application not found."}, status=status.HTTP_404_NOT_FOUND)

    try:
        application = approve_certification(application=application, reviewer=request.user)
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(StaffCertificationListSerializer(application).data)


@extend_schema(
    tags=["Staff — Certifications"],
    request=CertificationRejectSerializer,
    responses={
        status.HTTP_200_OK: StaffCertificationListSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Application is not pending"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Application not found"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
    },
)
@api_view(["POST"])
@permission_classes([IsAdminUser])
def certification_reject(request: Request, application_id: str) -> Response:
    """Reject a certification application. Optionally accepts a reason."""
    application = _get_application_or_404(application_id)
    if application is None:
        return Response({"detail": "Application not found."}, status=status.HTTP_404_NOT_FOUND)

    serializer = CertificationRejectSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    try:
        application = reject_certification(
            application=application,
            reviewer=request.user,
            reason=serializer.validated_data.get("reason", ""),
        )
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(StaffCertificationListSerializer(application).data)
