from django.db.models import Q, QuerySet
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAdminUser
from rest_framework.request import Request
from rest_framework.response import Response

from .models import GhanaCardRecord, KycSubmission
from .services import (
    approve_kyc,
    create_ghana_card_record,
    delete_ghana_card_record,
    reject_kyc,
    update_ghana_card_record,
)
from .staff_serializers import (
    GhanaCardRecordCreateSerializer,
    GhanaCardRecordDetailSerializer,
    GhanaCardRecordListSerializer,
    GhanaCardRecordUpdateSerializer,
    KycRejectSerializer,
    StaffKycDetailSerializer,
    StaffKycListSerializer,
)


def _get_submission_or_404(submission_id: str) -> KycSubmission | None:
    try:
        return KycSubmission.objects.select_related("user", "id_front", "id_back", "selfie", "proof_of_address").get(
            id=submission_id
        )
    except (KycSubmission.DoesNotExist, Exception):
        return None


def _apply_filters(qs: QuerySet, params: dict) -> QuerySet:
    status_filter = params.get("status")
    if status_filter in KycSubmission.Status.values:
        qs = qs.filter(status=status_filter)

    search = params.get("search", "").strip()
    if search:
        qs = qs.filter(
            Q(user__phone__icontains=search)
            | Q(user__first_name__icontains=search)
            | Q(user__last_name__icontains=search)
        )

    return qs


@extend_schema(
    tags=["Staff — KYC"],
    parameters=[
        OpenApiParameter("status", str, description="Filter by status: pending | approved | rejected"),
        OpenApiParameter("search", str, description="Search by user phone number or name"),
        OpenApiParameter("page", int, description="Page number"),
    ],
    responses={
        status.HTTP_200_OK: StaffKycListSerializer(many=True),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
    },
)
@api_view(["GET"])
@permission_classes([IsAdminUser])
def submission_list(request: Request) -> Response:
    """List all KYC submissions with optional status filter and search."""
    qs = KycSubmission.objects.select_related("user").order_by("-created_at")
    qs = _apply_filters(qs, request.query_params)

    paginator = PageNumberPagination()
    page = paginator.paginate_queryset(qs, request)
    serializer = StaffKycListSerializer(page, many=True)
    return paginator.get_paginated_response(serializer.data)


@extend_schema(
    tags=["Staff — KYC"],
    responses={
        status.HTTP_200_OK: StaffKycDetailSerializer,
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Submission not found"),
    },
)
@api_view(["GET"])
@permission_classes([IsAdminUser])
def submission_detail(request: Request, submission_id: str) -> Response:
    """Retrieve a single KYC submission with signed document URLs."""
    submission = _get_submission_or_404(submission_id)
    if submission is None:
        return Response({"detail": "Submission not found."}, status=status.HTTP_404_NOT_FOUND)

    serializer = StaffKycDetailSerializer(submission, context={"request": request})
    return Response(serializer.data)


@extend_schema(
    tags=["Staff — KYC"],
    request=None,
    responses={
        status.HTTP_200_OK: StaffKycDetailSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Submission is not pending"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Submission not found"),
    },
)
@api_view(["POST"])
@permission_classes([IsAdminUser])
def approve(request: Request, submission_id: str) -> Response:
    """Approve a pending KYC submission."""
    submission = _get_submission_or_404(submission_id)
    if submission is None:
        return Response({"detail": "Submission not found."}, status=status.HTTP_404_NOT_FOUND)

    try:
        submission = approve_kyc(submission=submission, reviewer=request.user)
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    serializer = StaffKycDetailSerializer(submission, context={"request": request})
    return Response(serializer.data)


@extend_schema(
    tags=["Staff — KYC"],
    request=KycRejectSerializer,
    responses={
        status.HTTP_200_OK: StaffKycDetailSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Submission is not pending or reason missing"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Staff access required"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Submission not found"),
    },
)
@api_view(["POST"])
@permission_classes([IsAdminUser])
def reject(request: Request, submission_id: str) -> Response:
    """Reject a pending KYC submission. A reason is required."""
    submission = _get_submission_or_404(submission_id)
    if submission is None:
        return Response({"detail": "Submission not found."}, status=status.HTTP_404_NOT_FOUND)

    serializer = KycRejectSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    try:
        submission = reject_kyc(
            submission=submission,
            reviewer=request.user,
            reason=serializer.validated_data["reason"],
        )
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    serializer = StaffKycDetailSerializer(submission, context={"request": request})
    return Response(serializer.data)


def _get_ghana_card_or_404(record_id: str) -> GhanaCardRecord | None:
    try:
        return GhanaCardRecord.objects.select_related("card_front", "card_back", "created_by").get(id=record_id)
    except (GhanaCardRecord.DoesNotExist, Exception):
        return None


@extend_schema(
    methods=["GET"],
    tags=["Staff — Ghana Cards"],
    parameters=[
        OpenApiParameter("search", str, description="Search by Ghana Card number or cardholder name"),
        OpenApiParameter("is_active", str, description="Filter by active status: true | false"),
        OpenApiParameter("page", int, description="Page number"),
    ],
    responses={status.HTTP_200_OK: GhanaCardRecordListSerializer(many=True)},
)
@extend_schema(
    methods=["POST"],
    tags=["Staff — Ghana Cards"],
    request=GhanaCardRecordCreateSerializer,
    responses={
        status.HTTP_201_CREATED: GhanaCardRecordDetailSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error or duplicate card"),
    },
)
@api_view(["GET", "POST"])
@permission_classes([IsAdminUser])
def ghana_card_list_create(request: Request) -> Response:
    """List registered Ghana Cards or add a new card to the verification registry."""
    if request.method == "GET":
        qs = GhanaCardRecord.objects.all().order_by("-created_at")
        active_filter = request.query_params.get("is_active")
        if active_filter in {"true", "false"}:
            qs = qs.filter(is_active=active_filter == "true")

        search = request.query_params.get("search", "").strip()
        if search:
            qs = qs.filter(
                Q(card_number__icontains=search) | Q(first_names__icontains=search) | Q(surname__icontains=search)
            )

        paginator = PageNumberPagination()
        page = paginator.paginate_queryset(qs, request)
        serializer = GhanaCardRecordListSerializer(page, many=True)
        return paginator.get_paginated_response(serializer.data)

    serializer = GhanaCardRecordCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    try:
        record = create_ghana_card_record(
            actor=request.user,
            card_number=serializer.validated_data["card_number"],
            first_names=serializer.validated_data["first_names"],
            surname=serializer.validated_data["surname"],
            date_of_birth=serializer.validated_data.get("date_of_birth"),
            sex=serializer.validated_data.get("sex", ""),
            card_front_id=str(serializer.validated_data["card_front_id"]),
            card_back_id=str(serializer.validated_data["card_back_id"]),
        )
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(
        GhanaCardRecordDetailSerializer(record, context={"request": request}).data,
        status=status.HTTP_201_CREATED,
    )


@extend_schema(
    methods=["GET"],
    tags=["Staff — Ghana Cards"],
    responses={
        status.HTTP_200_OK: GhanaCardRecordDetailSerializer,
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Ghana Card not found"),
    },
)
@extend_schema(
    methods=["PATCH"],
    tags=["Staff — Ghana Cards"],
    request=GhanaCardRecordUpdateSerializer,
    responses={
        status.HTTP_200_OK: GhanaCardRecordDetailSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Ghana Card not found"),
    },
)
@extend_schema(
    methods=["DELETE"],
    tags=["Staff — Ghana Cards"],
    responses={
        status.HTTP_204_NO_CONTENT: OpenApiResponse(description="Ghana Card deleted"),
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Ghana Card not found"),
    },
)
@api_view(["GET", "PATCH", "DELETE"])
@permission_classes([IsAdminUser])
def ghana_card_detail(request: Request, record_id: str) -> Response:
    record = _get_ghana_card_or_404(record_id)
    if record is None:
        return Response({"detail": "Ghana Card not found."}, status=status.HTTP_404_NOT_FOUND)

    if request.method == "DELETE":
        delete_ghana_card_record(record=record, actor=request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)

    if request.method == "PATCH":
        serializer = GhanaCardRecordUpdateSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        try:
            record = update_ghana_card_record(
                record=record,
                actor=request.user,
                changes=serializer.validated_data,
            )
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(GhanaCardRecordDetailSerializer(record, context={"request": request}).data)
