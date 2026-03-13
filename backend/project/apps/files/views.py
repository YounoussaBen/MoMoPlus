from __future__ import annotations

from django.db.models import Q
from django.http import Http404
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import generics, permissions, status
from rest_framework.exceptions import PermissionDenied
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import FileAsset
from .serializers import (
    FileAssetAccessUrlSerializer,
    FileAssetSerializer,
    FileAssetUpdateSerializer,
    FileAssetUploadSerializer,
)
from .services import FileAssetAccessError, build_access_url, create_file_asset, delete_file_asset


class FileAssetListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def get_queryset(self):
        if self.request.user.is_staff or self.request.user.is_superuser:
            queryset = FileAsset.objects.active()
        else:
            queryset = FileAsset.objects.owned_by(self.request.user)

        queryset = queryset.select_related("owner", "uploaded_by")

        kind = self.request.query_params.get("kind")
        visibility = self.request.query_params.get("visibility")
        status_filter = self.request.query_params.get("status")
        owner = self.request.query_params.get("owner")
        uploaded_by = self.request.query_params.get("uploaded_by")
        query = self.request.query_params.get("q")

        if kind:
            queryset = queryset.filter(kind=kind)

        if visibility:
            queryset = queryset.filter(visibility=visibility)

        if status_filter:
            queryset = queryset.filter(status=status_filter)

        if owner:
            queryset = queryset.filter(owner_id=owner)

        if uploaded_by:
            queryset = queryset.filter(uploaded_by_id=uploaded_by)

        if query:
            queryset = queryset.filter(
                Q(original_name__icontains=query)
                | Q(content_type__icontains=query)
                | Q(storage_path__icontains=query)
                | Q(sha256__icontains=query)
            )

        return queryset

    def get_serializer_class(self):
        if self.request.method == "POST":
            return FileAssetUploadSerializer
        return FileAssetSerializer

    @extend_schema(
        tags=["Files"],
        parameters=[
            OpenApiParameter(name="kind", type=str, location=OpenApiParameter.QUERY, required=False),
            OpenApiParameter(name="visibility", type=str, location=OpenApiParameter.QUERY, required=False),
            OpenApiParameter(name="status", type=str, location=OpenApiParameter.QUERY, required=False),
            OpenApiParameter(name="owner", type=str, location=OpenApiParameter.QUERY, required=False),
            OpenApiParameter(name="uploaded_by", type=str, location=OpenApiParameter.QUERY, required=False),
            OpenApiParameter(
                name="q",
                type=str,
                location=OpenApiParameter.QUERY,
                required=False,
                description="Search original_name, content_type, storage_path, and sha256.",
            ),
        ],
        responses={status.HTTP_200_OK: FileAssetSerializer(many=True)},
    )
    def get(self, request: Request, *args, **kwargs) -> Response:
        return super().get(request, *args, **kwargs)

    @extend_schema(
        tags=["Files"],
        request=FileAssetUploadSerializer,
        responses={
            status.HTTP_201_CREATED: FileAssetSerializer,
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
        },
    )
    def post(self, request: Request, *args, **kwargs) -> Response:
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        asset = create_file_asset(
            owner=request.user,
            uploaded_by=request.user,
            uploaded_file=serializer.validated_data["file"],
            kind=serializer.validated_data["kind"],
            visibility=serializer.validated_data.get("visibility"),
            metadata=serializer.validated_data.get("metadata"),
        )
        response_serializer = FileAssetSerializer(asset, context=self.get_serializer_context())
        headers = self.get_success_headers(response_serializer.data)
        return Response(response_serializer.data, status=status.HTTP_201_CREATED, headers=headers)


class FileAssetDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self, file_id):
        try:
            return FileAsset.objects.active().select_related("owner", "uploaded_by").get(pk=file_id)
        except FileAsset.DoesNotExist as exc:
            raise Http404 from exc

    def _check_view_permission(self, request: Request, asset: FileAsset) -> None:
        if not asset.can_view(request.user):
            raise PermissionDenied("You do not have permission to access this file.")

    def _check_manage_permission(self, request: Request, asset: FileAsset) -> None:
        if not asset.can_manage(request.user):
            raise PermissionDenied("You do not have permission to manage this file.")

    @extend_schema(
        tags=["Files"],
        responses={
            status.HTTP_200_OK: FileAssetSerializer,
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Permission denied"),
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="File not found"),
        },
    )
    def get(self, request: Request, file_id, *args, **kwargs) -> Response:
        asset = self.get_object(file_id)
        self._check_view_permission(request, asset)
        serializer = FileAssetSerializer(asset, context={"request": request})
        return Response(serializer.data)

    @extend_schema(
        tags=["Files"],
        request=FileAssetUpdateSerializer,
        responses={
            status.HTTP_200_OK: FileAssetSerializer,
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Permission denied"),
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="File not found"),
        },
    )
    def patch(self, request: Request, file_id, *args, **kwargs) -> Response:
        asset = self.get_object(file_id)
        self._check_manage_permission(request, asset)
        serializer = FileAssetUpdateSerializer(asset, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(FileAssetSerializer(asset, context={"request": request}).data)

    @extend_schema(
        tags=["Files"],
        responses={
            status.HTTP_204_NO_CONTENT: OpenApiResponse(description="File deleted"),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Permission denied"),
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="File not found"),
        },
    )
    def delete(self, request: Request, file_id, *args, **kwargs) -> Response:
        asset = self.get_object(file_id)
        self._check_manage_permission(request, asset)
        delete_file_asset(asset=asset, actor=request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)


class FileAssetAccessUrlView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = FileAssetAccessUrlSerializer

    def get_object(self, file_id):
        try:
            return FileAsset.objects.active().select_related("owner").get(pk=file_id)
        except FileAsset.DoesNotExist as exc:
            raise Http404 from exc

    @extend_schema(
        tags=["Files"],
        request=None,
        parameters=[
            OpenApiParameter(
                name="file_id",
                type=str,
                location=OpenApiParameter.PATH,
                description="File asset UUID.",
            )
        ],
        responses={
            status.HTTP_200_OK: FileAssetAccessUrlSerializer,
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Permission denied"),
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="File not found"),
        },
    )
    def post(self, request: Request, file_id, *args, **kwargs) -> Response:
        asset = self.get_object(file_id)
        if not asset.can_view(request.user):
            raise PermissionDenied("You do not have permission to access this file.")

        try:
            payload = build_access_url(asset=asset, request=request)
        except FileAssetAccessError as exc:
            raise PermissionDenied(str(exc)) from exc

        return Response(payload, status=status.HTTP_200_OK)
