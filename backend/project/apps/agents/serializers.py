from rest_framework import serializers

from project.apps.files.services import FileAssetAccessError, build_access_url

from .models import AgentProfile, CertificationApplication


class AgentProfileSerializer(serializers.ModelSerializer):
    """Full profile for the agent's own view."""

    full_name = serializers.SerializerMethodField()
    email = serializers.CharField(source="user.email", read_only=True)
    completed_services = serializers.SerializerMethodField()

    class Meta:
        model = AgentProfile
        fields = [
            "id",
            "full_name",
            "email",
            "latitude",
            "longitude",
            "is_available",
            "max_amount",
            "min_amount",
            "service_radius_km",
            "bio",
            "rating",
            "total_ratings",
            "completed_services",
            "agent_type",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "full_name",
            "email",
            "rating",
            "total_ratings",
            "agent_type",
            "completed_services",
            "created_at",
            "updated_at",
        ]

    def get_full_name(self, obj: AgentProfile) -> str:
        return f"{obj.user.first_name} {obj.user.last_name}".strip()

    def get_completed_services(self, obj: AgentProfile) -> int:
        annotated_count = getattr(obj, "completed_services_count", None)
        if annotated_count is not None:
            return annotated_count
        return obj.physical_transactions.filter(status="completed").count()


class UpdateAgentProfileSerializer(serializers.Serializer):
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6, required=False)
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6, required=False)
    is_available = serializers.BooleanField(required=False)
    max_amount = serializers.DecimalField(max_digits=10, decimal_places=2, required=False)
    min_amount = serializers.DecimalField(max_digits=10, decimal_places=2, required=False)
    service_radius_km = serializers.DecimalField(max_digits=5, decimal_places=2, required=False)
    bio = serializers.CharField(required=False, allow_blank=True)


class NearbyAgentSerializer(serializers.ModelSerializer):
    """Public-facing serializer for discovery results."""

    full_name = serializers.SerializerMethodField()
    distance_km = serializers.FloatField(read_only=True)
    selfie_url = serializers.SerializerMethodField()
    completed_services = serializers.SerializerMethodField()

    class Meta:
        model = AgentProfile
        fields = [
            "id",
            "full_name",
            "latitude",
            "longitude",
            "is_available",
            "max_amount",
            "min_amount",
            "rating",
            "total_ratings",
            "completed_services",
            "agent_type",
            "distance_km",
            "selfie_url",
        ]

    def get_full_name(self, obj: AgentProfile) -> str:
        return f"{obj.user.first_name} {obj.user.last_name}".strip()

    def get_completed_services(self, obj: AgentProfile) -> int:
        annotated_count = getattr(obj, "completed_services_count", None)
        if annotated_count is not None:
            return annotated_count
        return obj.physical_transactions.filter(status="completed").count()

    def get_selfie_url(self, obj: AgentProfile) -> str | None:
        kyc = getattr(obj.user, "kyc_submission", None)
        if kyc is None or kyc.selfie is None:
            return None
        request = self.context.get("request")
        if request is None:
            return None
        try:
            result = build_access_url(asset=kyc.selfie, request=request)
            return result.get("url")
        except FileAssetAccessError:
            return None


class NearbyQuerySerializer(serializers.Serializer):
    lat = serializers.FloatField()
    lon = serializers.FloatField()
    radius = serializers.FloatField(default=10.0, required=False)
    min_amount = serializers.FloatField(required=False)
    max_amount = serializers.FloatField(required=False)
    sort_by = serializers.ChoiceField(
        choices=["distance", "rating"],
        default="distance",
        required=False,
    )


class RoutePreviewRequestSerializer(serializers.Serializer):
    origin_latitude = serializers.FloatField()
    origin_longitude = serializers.FloatField()
    destination_latitude = serializers.FloatField()
    destination_longitude = serializers.FloatField()


class RoutePreviewSerializer(serializers.Serializer):
    distance_meters = serializers.IntegerField()
    duration_seconds = serializers.IntegerField()
    encoded_polyline = serializers.CharField()


# ---------------------------------------------------------------------------
# Certification
# ---------------------------------------------------------------------------


class CertificationApplicationSerializer(serializers.ModelSerializer):
    class Meta:
        model = CertificationApplication
        fields = [
            "id",
            "agent_id_number",
            "network",
            "agent_id_photo",
            "business_location_photo",
            "business_registration_number",
            "status",
            "rejection_reason",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "status",
            "rejection_reason",
            "created_at",
            "updated_at",
        ]


class ApplyCertificationSerializer(serializers.Serializer):
    agent_id_number = serializers.CharField(max_length=50)
    network = serializers.CharField(max_length=20, default="mtn")
    agent_id_photo_id = serializers.UUIDField()
    business_location_photo_id = serializers.UUIDField()
    business_registration_number = serializers.CharField(max_length=50, required=False, allow_blank=True, default="")


class CertificationRejectSerializer(serializers.Serializer):
    reason = serializers.CharField(required=False, allow_blank=True, default="")


class StaffCertificationListSerializer(serializers.ModelSerializer):
    agent_email = serializers.CharField(source="agent_profile.user.email", read_only=True)
    agent_phone = serializers.CharField(source="agent_profile.user.phone", read_only=True, allow_null=True)
    agent_name = serializers.SerializerMethodField()

    class Meta:
        model = CertificationApplication
        fields = [
            "id",
            "agent_email",
            "agent_phone",
            "agent_name",
            "agent_id_number",
            "network",
            "agent_id_photo",
            "business_location_photo",
            "business_registration_number",
            "status",
            "rejection_reason",
            "reviewed_at",
            "created_at",
        ]

    def get_agent_name(self, obj: CertificationApplication) -> str:
        u = obj.agent_profile.user
        return f"{u.first_name} {u.last_name}".strip()
