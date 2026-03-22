from __future__ import annotations

import math
from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from project.apps.accounts.models import AgentStatus, User, UserRole
from project.apps.files.models import FileAsset
from project.integrations.google_maps import RoutePreview, compute_driving_route_preview

from .models import AgentProfile, AgentType, CertificationApplication, CertificationStatus

EARTH_RADIUS_KM = 6371.0


def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Return distance in km between two lat/lon points."""
    lat1_r, lat2_r = math.radians(lat1), math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(lat1_r) * math.cos(lat2_r) * math.sin(dlon / 2) ** 2
    return EARTH_RADIUS_KM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def get_nearby_agents(
    *,
    lat: float,
    lon: float,
    radius_km: float = 10.0,
    min_amount: float | None = None,
    max_amount: float | None = None,
    sort_by: str = "distance",
) -> list[AgentProfile]:
    """
    Find available agents within radius_km of (lat, lon).

    Returns AgentProfile objects with an attached ``distance_km`` attribute.
    Uses a bounding-box pre-filter in SQL, then refines with Haversine in Python.
    """
    delta_lat = radius_km / 111.0
    delta_lon = radius_km / (111.0 * max(math.cos(math.radians(lat)), 0.01))

    qs = AgentProfile.objects.filter(
        is_available=True,
        latitude__isnull=False,
        longitude__isnull=False,
        latitude__gte=Decimal(str(lat - delta_lat)),
        latitude__lte=Decimal(str(lat + delta_lat)),
        longitude__gte=Decimal(str(lon - delta_lon)),
        longitude__lte=Decimal(str(lon + delta_lon)),
        user__role=UserRole.AGENT,
        user__agent_status=AgentStatus.APPROVED,
    ).select_related("user")

    if min_amount is not None:
        qs = qs.filter(max_amount__gte=Decimal(str(min_amount)))
    if max_amount is not None:
        qs = qs.filter(max_amount__lte=Decimal(str(max_amount)))

    results: list[AgentProfile] = []
    for profile in qs:
        dist = haversine(lat, lon, float(profile.latitude), float(profile.longitude))
        if dist <= radius_km:
            profile.distance_km = round(dist, 2)  # type: ignore[attr-defined]
            results.append(profile)

    if sort_by == "rating":
        results.sort(key=lambda p: (-float(p.rating), p.distance_km))
    else:
        results.sort(key=lambda p: p.distance_km)

    return results


def get_agent_profile(*, user: User) -> AgentProfile:
    """Get or create agent profile for an authenticated agent."""
    profile, _ = AgentProfile.objects.get_or_create(user=user)
    return profile


def update_agent_profile(*, user: User, **fields) -> AgentProfile:
    """Update agent profile fields with validation."""
    profile = get_agent_profile(user=user)

    lat = fields.get("latitude")
    lon = fields.get("longitude")
    if (lat is None) != (lon is None):
        raise ValueError("Both latitude and longitude must be provided together.")

    effective_min = fields.get("min_amount", profile.min_amount)
    effective_max = fields.get("max_amount", profile.max_amount)
    if effective_max is not None and effective_min is not None and effective_min > effective_max:
        raise ValueError("Minimum amount cannot exceed maximum amount.")

    # Once limits are set (both > 0), they cannot be cleared back to 0 or null.
    limits_already_set = (
        profile.min_amount is not None
        and profile.min_amount > 0
        and profile.max_amount is not None
        and profile.max_amount > 0
    )
    if limits_already_set:
        new_min = fields.get("min_amount")
        new_max = fields.get("max_amount")
        if new_min is not None and new_min <= 0:
            raise ValueError("Minimum amount cannot be set to zero once configured.")
        if new_max is not None and new_max <= 0:
            raise ValueError("Maximum amount cannot be set to zero once configured.")

    update_fields: list[str] = []
    for field, value in fields.items():
        if value is not None:
            setattr(profile, field, value)
            update_fields.append(field)

    if update_fields:
        update_fields.append("updated_at")
        profile.save(update_fields=update_fields)

    return profile


def toggle_availability(*, user: User) -> AgentProfile:
    """Toggle agent availability on/off."""
    profile = get_agent_profile(user=user)
    going_online = not profile.is_available

    if going_online:
        if not profile.min_amount or profile.min_amount <= 0 or not profile.max_amount or profile.max_amount <= 0:
            raise ValueError("Set your minimum and maximum transaction limits before going online.")

    profile.is_available = going_online
    profile.save(update_fields=["is_available", "updated_at"])
    return profile


def get_route_preview(
    *,
    origin_latitude: float,
    origin_longitude: float,
    destination_latitude: float,
    destination_longitude: float,
) -> RoutePreview:
    """Compute a driving route preview between the user and an agent."""
    return compute_driving_route_preview(
        origin_latitude=origin_latitude,
        origin_longitude=origin_longitude,
        destination_latitude=destination_latitude,
        destination_longitude=destination_longitude,
    )


# ---------------------------------------------------------------------------
# Certification
# ---------------------------------------------------------------------------


def apply_for_certification(
    *,
    user: User,
    agent_id_number: str,
    network: str = "mtn",
    agent_id_photo_id: str,
    business_location_photo_id: str,
    business_registration_number: str = "",
) -> CertificationApplication:
    """Submit a certification application for a self-enrolled agent."""
    profile = get_agent_profile(user=user)

    if profile.agent_type == AgentType.CERTIFIED:
        raise ValueError("You are already a certified agent.")

    if CertificationApplication.objects.filter(
        agent_profile=profile,
        status=CertificationStatus.PENDING,
    ).exists():
        raise ValueError("You already have a pending certification application.")

    agent_id_photo = FileAsset.objects.filter(pk=agent_id_photo_id, owner=user).first()
    if agent_id_photo is None:
        raise ValueError("Agent ID photo not found.")

    business_location_photo = FileAsset.objects.filter(pk=business_location_photo_id, owner=user).first()
    if business_location_photo is None:
        raise ValueError("Business location photo not found.")

    return CertificationApplication.objects.create(
        agent_profile=profile,
        agent_id_number=agent_id_number,
        network=network,
        agent_id_photo=agent_id_photo,
        business_location_photo=business_location_photo,
        business_registration_number=business_registration_number,
    )


@transaction.atomic
def approve_certification(*, application: CertificationApplication, reviewer: User) -> CertificationApplication:
    """Approve a certification application and upgrade the agent to certified."""
    if application.status != CertificationStatus.PENDING:
        raise ValueError("Only pending applications can be approved.")

    application.status = CertificationStatus.APPROVED
    application.reviewed_by = reviewer
    application.reviewed_at = timezone.now()
    application.save(update_fields=["status", "reviewed_by", "reviewed_at", "updated_at"])

    profile = application.agent_profile
    profile.agent_type = AgentType.CERTIFIED
    profile.save(update_fields=["agent_type", "updated_at"])

    return application


def reject_certification(
    *, application: CertificationApplication, reviewer: User, reason: str = ""
) -> CertificationApplication:
    """Reject a certification application."""
    if application.status != CertificationStatus.PENDING:
        raise ValueError("Only pending applications can be rejected.")

    application.status = CertificationStatus.REJECTED
    application.rejection_reason = reason
    application.reviewed_by = reviewer
    application.reviewed_at = timezone.now()
    application.save(update_fields=["status", "rejection_reason", "reviewed_by", "reviewed_at", "updated_at"])

    return application


def get_certification_status(*, user: User) -> CertificationApplication | None:
    """Get the most recent certification application for an agent."""
    profile = get_agent_profile(user=user)
    return CertificationApplication.objects.filter(agent_profile=profile).order_by("-created_at").first()
