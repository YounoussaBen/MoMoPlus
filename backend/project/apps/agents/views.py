from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response

from project.apps.accounts.models import UserRole
from project.integrations.google_maps import GoogleMapsConfigurationError, GoogleMapsRequestError

from .models import AgentProfile
from .serializers import (
    AgentProfileSerializer,
    ApplyCertificationSerializer,
    CertificationApplicationSerializer,
    NearbyAgentSerializer,
    NearbyQuerySerializer,
    RoutePreviewRequestSerializer,
    RoutePreviewSerializer,
    UpdateAgentProfileSerializer,
)
from .services import (
    apply_for_certification,
    get_agent_profile,
    get_certification_status,
    get_nearby_agents,
    get_route_preview,
    toggle_availability,
    update_agent_profile,
)


def _require_agent(request: Request) -> Response | None:
    """Return a 403 Response if the user is not an approved agent, else None."""
    if request.user.role != UserRole.AGENT:
        return Response({"detail": "Only agents can access this endpoint."}, status=status.HTTP_403_FORBIDDEN)
    return None


@extend_schema(
    tags=["Agents"],
    parameters=[NearbyQuerySerializer],
    responses={
        status.HTTP_200_OK: NearbyAgentSerializer(many=True),
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Invalid query parameters"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def nearby_agents(request: Request) -> Response:
    """Find available agents near a given location."""
    qs = NearbyQuerySerializer(data=request.query_params)
    qs.is_valid(raise_exception=True)
    d = qs.validated_data

    agents = get_nearby_agents(
        lat=d["lat"],
        lon=d["lon"],
        radius_km=d.get("radius", 10.0),
        min_amount=d.get("min_amount"),
        max_amount=d.get("max_amount"),
        sort_by=d.get("sort_by", "distance"),
    )

    return Response(NearbyAgentSerializer(agents, many=True, context={"request": request}).data)


@extend_schema(
    tags=["Agents"],
    responses={
        status.HTTP_200_OK: NearbyAgentSerializer,
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Agent not found"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def agent_detail(request: Request, pk: str) -> Response:
    """Get public details for a specific agent."""
    try:
        profile = AgentProfile.objects.select_related("user__kyc_submission__selfie").get(pk=pk)
    except AgentProfile.DoesNotExist:
        return Response({"detail": "Agent not found."}, status=status.HTTP_404_NOT_FOUND)

    profile.distance_km = 0.0  # type: ignore[attr-defined]
    return Response(NearbyAgentSerializer(profile, context={"request": request}).data)


@extend_schema(
    tags=["Agents"],
    request=RoutePreviewRequestSerializer,
    responses={
        status.HTTP_200_OK: RoutePreviewSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
        status.HTTP_502_BAD_GATEWAY: OpenApiResponse(description="Route provider failure"),
        status.HTTP_503_SERVICE_UNAVAILABLE: OpenApiResponse(description="Route provider not configured"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def route_preview(request: Request) -> Response:
    """Return a driving route preview from the user to an agent."""
    serializer = RoutePreviewRequestSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    try:
        route = get_route_preview(**serializer.validated_data)
    except GoogleMapsConfigurationError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
    except GoogleMapsRequestError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

    return Response(RoutePreviewSerializer(route).data)


@extend_schema(
    tags=["Agents"],
    responses={
        status.HTTP_200_OK: AgentProfileSerializer,
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Not an agent"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def my_profile(request: Request) -> Response:
    """Get the authenticated agent's own profile."""
    forbidden = _require_agent(request)
    if forbidden:
        return forbidden

    profile = get_agent_profile(user=request.user)
    return Response(AgentProfileSerializer(profile).data)


@extend_schema(
    tags=["Agents"],
    request=UpdateAgentProfileSerializer,
    responses={
        status.HTTP_200_OK: AgentProfileSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Not an agent"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["PUT"])
@permission_classes([IsAuthenticated])
def update_profile(request: Request) -> Response:
    """Update the authenticated agent's profile."""
    forbidden = _require_agent(request)
    if forbidden:
        return forbidden

    serializer = UpdateAgentProfileSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    try:
        profile = update_agent_profile(user=request.user, **serializer.validated_data)
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(AgentProfileSerializer(profile).data)


@extend_schema(
    tags=["Agents"],
    request=None,
    responses={
        status.HTTP_200_OK: AgentProfileSerializer,
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Not an agent"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def toggle_availability_view(request: Request) -> Response:
    """Toggle the authenticated agent's availability."""
    forbidden = _require_agent(request)
    if forbidden:
        return forbidden

    try:
        profile = toggle_availability(user=request.user)
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(AgentProfileSerializer(profile).data)


# ---------------------------------------------------------------------------
# Certification
# ---------------------------------------------------------------------------


@extend_schema(
    tags=["Agents — Certification"],
    responses={
        status.HTTP_200_OK: CertificationApplicationSerializer,
        status.HTTP_204_NO_CONTENT: OpenApiResponse(description="No application found"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Not an agent"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def certification_status(request: Request) -> Response:
    """Get the agent's most recent certification application."""
    forbidden = _require_agent(request)
    if forbidden:
        return forbidden

    application = get_certification_status(user=request.user)
    if application is None:
        return Response(status=status.HTTP_204_NO_CONTENT)

    return Response(CertificationApplicationSerializer(application).data)


@extend_schema(
    tags=["Agents — Certification"],
    request=ApplyCertificationSerializer,
    responses={
        status.HTTP_201_CREATED: CertificationApplicationSerializer,
        status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error"),
        status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Not an agent"),
        status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def certification_apply(request: Request) -> Response:
    """Submit a certification application."""
    forbidden = _require_agent(request)
    if forbidden:
        return forbidden

    serializer = ApplyCertificationSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    d = serializer.validated_data

    try:
        application = apply_for_certification(
            user=request.user,
            agent_id_number=d["agent_id_number"],
            network=d.get("network", "mtn"),
            agent_id_photo_id=str(d["agent_id_photo_id"]),
            business_location_photo_id=str(d["business_location_photo_id"]),
            business_registration_number=d.get("business_registration_number", ""),
        )
    except ValueError as exc:
        return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    return Response(
        CertificationApplicationSerializer(application).data,
        status=status.HTTP_201_CREATED,
    )
