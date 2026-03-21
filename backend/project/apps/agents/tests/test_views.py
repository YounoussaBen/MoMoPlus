import uuid

import pytest
from rest_framework import status

from project.apps.accounts.models import AgentStatus, UserRole
from project.apps.agents.models import AgentProfile
from project.apps.files.models import FileAsset
from project.integrations.google_maps import GoogleMapsConfigurationError, GoogleMapsRequestError, RoutePreview


@pytest.fixture
def agent_claims():
    return {
        "sub": str(uuid.uuid4()),
        "email": "agent@example.com",
        "user_metadata": {
            "first_name": "Agent",
            "last_name": "Smith",
        },
    }


@pytest.fixture
def agent_client(auth_client_factory, agent_claims):
    """Authenticated client that syncs and then becomes an approved agent."""
    client = auth_client_factory(agent_claims)
    # Sync the user into Django
    client.post("/api/auth/sync/")
    # Manually upgrade to agent (simulating admin approval)
    from django.contrib.auth import get_user_model

    User = get_user_model()
    user = User.objects.get(email="agent@example.com")
    user.role = UserRole.AGENT
    user.agent_status = AgentStatus.APPROVED
    user.save(update_fields=["role", "agent_status"])
    AgentProfile.objects.get_or_create(
        user=user,
        defaults={"latitude": 5.6037, "longitude": -0.1870, "max_amount": 500, "is_available": True},
    )
    return client


@pytest.fixture
def regular_client(authenticated_client):
    """Regular (non-agent) authenticated user."""
    authenticated_client.post("/api/auth/sync/")
    return authenticated_client


@pytest.mark.django_db
class TestNearbyAgentsView:
    def test_returns_nearby_agents(self, regular_client, agent_client):
        response = regular_client.get("/api/agents/nearby/", {"lat": 5.6037, "lon": -0.1870, "radius": 10})

        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) == 1
        assert response.data[0]["full_name"] == "Agent Smith"

    def test_returns_empty_when_none_nearby(self, regular_client):
        response = regular_client.get("/api/agents/nearby/", {"lat": 5.6037, "lon": -0.1870, "radius": 10})

        assert response.status_code == status.HTTP_200_OK
        assert response.data == []

    def test_requires_lat_lon(self, regular_client):
        response = regular_client.get("/api/agents/nearby/")

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_unauthenticated_returns_401(self, api_client):
        response = api_client.get("/api/agents/nearby/", {"lat": 5.6037, "lon": -0.1870})

        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    def test_filters_by_min_amount(self, regular_client, agent_client):
        # Agent has max_amount=500
        response = regular_client.get(
            "/api/agents/nearby/",
            {"lat": 5.6037, "lon": -0.1870, "radius": 10, "min_amount": 1000},
        )

        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) == 0


@pytest.mark.django_db
class TestAgentDetailView:
    def test_returns_agent_detail(self, regular_client, agent_client):
        profile = AgentProfile.objects.first()

        response = regular_client.get(f"/api/agents/{profile.pk}/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["full_name"] == "Agent Smith"

    def test_returns_404_for_nonexistent(self, regular_client):
        response = regular_client.get("/api/agents/00000000-0000-0000-0000-000000000000/")

        assert response.status_code == status.HTTP_404_NOT_FOUND


@pytest.mark.django_db
class TestRoutePreviewView:
    def test_returns_route_preview(self, regular_client, mocker):
        mocker.patch(
            "project.apps.agents.views.get_route_preview",
            return_value=RoutePreview(
                distance_meters=1820,
                duration_seconds=420,
                encoded_polyline="encoded",
            ),
        )

        response = regular_client.post(
            "/api/agents/route-preview/",
            {
                "origin_latitude": 5.6037,
                "origin_longitude": -0.1870,
                "destination_latitude": 5.6100,
                "destination_longitude": -0.1800,
            },
            format="json",
        )

        assert response.status_code == status.HTTP_200_OK
        assert response.data["distance_meters"] == 1820
        assert response.data["duration_seconds"] == 420
        assert response.data["encoded_polyline"] == "encoded"

    def test_returns_503_when_maps_not_configured(self, regular_client, mocker):
        mocker.patch(
            "project.apps.agents.views.get_route_preview",
            side_effect=GoogleMapsConfigurationError("GOOGLE_MAPS_SERVER_KEY must be configured."),
        )

        response = regular_client.post(
            "/api/agents/route-preview/",
            {
                "origin_latitude": 5.6037,
                "origin_longitude": -0.1870,
                "destination_latitude": 5.6100,
                "destination_longitude": -0.1800,
            },
            format="json",
        )

        assert response.status_code == status.HTTP_503_SERVICE_UNAVAILABLE

    def test_returns_502_when_maps_provider_fails(self, regular_client, mocker):
        mocker.patch(
            "project.apps.agents.views.get_route_preview",
            side_effect=GoogleMapsRequestError("Google Maps failed."),
        )

        response = regular_client.post(
            "/api/agents/route-preview/",
            {
                "origin_latitude": 5.6037,
                "origin_longitude": -0.1870,
                "destination_latitude": 5.6100,
                "destination_longitude": -0.1800,
            },
            format="json",
        )

        assert response.status_code == status.HTTP_502_BAD_GATEWAY

    def test_requires_authentication(self, api_client):
        response = api_client.post(
            "/api/agents/route-preview/",
            {
                "origin_latitude": 5.6037,
                "origin_longitude": -0.1870,
                "destination_latitude": 5.6100,
                "destination_longitude": -0.1800,
            },
            format="json",
        )

        assert response.status_code == status.HTTP_401_UNAUTHORIZED


@pytest.mark.django_db
class TestMyProfileView:
    def test_returns_agent_profile(self, agent_client):
        response = agent_client.get("/api/agents/profile/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["full_name"] == "Agent Smith"
        assert response.data["is_available"] is True

    def test_returns_403_for_non_agent(self, regular_client):
        response = regular_client.get("/api/agents/profile/")

        assert response.status_code == status.HTTP_403_FORBIDDEN


@pytest.mark.django_db
class TestUpdateProfileView:
    def test_updates_profile(self, agent_client):
        response = agent_client.put(
            "/api/agents/profile/update/",
            {"max_amount": "1000.00", "bio": "Trusted agent"},
            format="json",
        )

        assert response.status_code == status.HTTP_200_OK
        assert response.data["max_amount"] == "1000.00"
        assert response.data["bio"] == "Trusted agent"

    def test_updates_location(self, agent_client):
        response = agent_client.put(
            "/api/agents/profile/update/",
            {"latitude": "6.6885", "longitude": "-1.6244"},
            format="json",
        )

        assert response.status_code == status.HTTP_200_OK
        assert response.data["latitude"] == "6.688500"

    def test_rejects_partial_location(self, agent_client):
        response = agent_client.put(
            "/api/agents/profile/update/",
            {"latitude": "6.6885"},
            format="json",
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_returns_403_for_non_agent(self, regular_client):
        response = regular_client.put(
            "/api/agents/profile/update/",
            {"max_amount": "1000.00"},
            format="json",
        )

        assert response.status_code == status.HTTP_403_FORBIDDEN


@pytest.mark.django_db
class TestToggleAvailabilityView:
    def test_toggles_availability(self, agent_client):
        # Agent starts as available=True
        response = agent_client.post("/api/agents/profile/toggle-availability/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["is_available"] is False

        # Toggle again
        response = agent_client.post("/api/agents/profile/toggle-availability/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["is_available"] is True

    def test_returns_403_for_non_agent(self, regular_client):
        response = regular_client.post("/api/agents/profile/toggle-availability/")

        assert response.status_code == status.HTTP_403_FORBIDDEN


# ---------------------------------------------------------------------------
# Certification Views
# ---------------------------------------------------------------------------


@pytest.fixture
def agent_file_assets(agent_client):
    """Create file assets owned by the agent user."""
    from django.contrib.auth import get_user_model

    User = get_user_model()
    user = User.objects.get(email="agent@example.com")
    photo = FileAsset.objects.create(owner=user, kind="document")
    location = FileAsset.objects.create(owner=user, kind="document")
    return photo, location


@pytest.fixture
def staff_client(api_client, user_factory):
    """Django staff API client."""
    staff = user_factory(
        email="staff@example.com",
        username="staffuser",
        is_staff=True,
        is_superuser=True,
    )
    api_client.force_authenticate(user=staff)
    return api_client


@pytest.mark.django_db
class TestCertificationStatusView:
    def test_returns_204_when_no_application(self, agent_client):
        response = agent_client.get("/api/agents/certification/")

        assert response.status_code == status.HTTP_204_NO_CONTENT

    def test_returns_application(self, agent_client, agent_file_assets):
        photo, location = agent_file_assets

        agent_client.post(
            "/api/agents/certification/apply/",
            {
                "agent_id_number": "MTN-AGT-12345",
                "agent_id_photo_id": str(photo.pk),
                "business_location_photo_id": str(location.pk),
            },
            format="json",
        )

        response = agent_client.get("/api/agents/certification/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["agent_id_number"] == "MTN-AGT-12345"
        assert response.data["status"] == "pending"

    def test_returns_403_for_non_agent(self, regular_client):
        response = regular_client.get("/api/agents/certification/")

        assert response.status_code == status.HTTP_403_FORBIDDEN


@pytest.mark.django_db
class TestCertificationApplyView:
    def test_creates_application(self, agent_client, agent_file_assets):
        photo, location = agent_file_assets

        response = agent_client.post(
            "/api/agents/certification/apply/",
            {
                "agent_id_number": "MTN-AGT-12345",
                "agent_id_photo_id": str(photo.pk),
                "business_location_photo_id": str(location.pk),
            },
            format="json",
        )

        assert response.status_code == status.HTTP_201_CREATED
        assert response.data["agent_id_number"] == "MTN-AGT-12345"

    def test_rejects_duplicate_pending(self, agent_client, agent_file_assets):
        photo, location = agent_file_assets

        agent_client.post(
            "/api/agents/certification/apply/",
            {
                "agent_id_number": "MTN-AGT-12345",
                "agent_id_photo_id": str(photo.pk),
                "business_location_photo_id": str(location.pk),
            },
            format="json",
        )

        response = agent_client.post(
            "/api/agents/certification/apply/",
            {
                "agent_id_number": "MTN-AGT-99999",
                "agent_id_photo_id": str(photo.pk),
                "business_location_photo_id": str(location.pk),
            },
            format="json",
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_returns_403_for_non_agent(self, regular_client):
        response = regular_client.post(
            "/api/agents/certification/apply/",
            {"agent_id_number": "MTN-AGT-12345"},
            format="json",
        )

        assert response.status_code == status.HTTP_403_FORBIDDEN


@pytest.mark.django_db
class TestStaffCertificationListView:
    def test_lists_applications(self, staff_client, agent_client, agent_file_assets):
        photo, location = agent_file_assets

        agent_client.post(
            "/api/agents/certification/apply/",
            {
                "agent_id_number": "MTN-AGT-12345",
                "agent_id_photo_id": str(photo.pk),
                "business_location_photo_id": str(location.pk),
            },
            format="json",
        )

        response = staff_client.get("/api/staff/agents/certifications/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] == 1

    def test_filters_by_status(self, staff_client):
        response = staff_client.get("/api/staff/agents/certifications/", {"status": "pending"})

        assert response.status_code == status.HTTP_200_OK

    def test_unauthenticated_returns_401(self, api_client):
        response = api_client.get("/api/staff/agents/certifications/")

        assert response.status_code == status.HTTP_401_UNAUTHORIZED


@pytest.mark.django_db
class TestStaffCertificationApproveView:
    def test_approves_and_upgrades_to_certified(self, staff_client, agent_client, agent_file_assets):
        photo, location = agent_file_assets

        create_resp = agent_client.post(
            "/api/agents/certification/apply/",
            {
                "agent_id_number": "MTN-AGT-12345",
                "agent_id_photo_id": str(photo.pk),
                "business_location_photo_id": str(location.pk),
            },
            format="json",
        )
        app_id = create_resp.data["id"]

        response = staff_client.post(f"/api/staff/agents/certifications/{app_id}/approve/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["status"] == "approved"

        # Verify agent is now certified
        profile_resp = agent_client.get("/api/agents/profile/")
        assert profile_resp.data["agent_type"] == "certified"

    def test_returns_404_for_nonexistent(self, staff_client):
        response = staff_client.post("/api/staff/agents/certifications/00000000-0000-0000-0000-000000000000/approve/")

        assert response.status_code == status.HTTP_404_NOT_FOUND


@pytest.mark.django_db
class TestStaffCertificationRejectView:
    def test_rejects_with_reason(self, staff_client, agent_client, agent_file_assets):
        photo, location = agent_file_assets

        create_resp = agent_client.post(
            "/api/agents/certification/apply/",
            {
                "agent_id_number": "MTN-AGT-12345",
                "agent_id_photo_id": str(photo.pk),
                "business_location_photo_id": str(location.pk),
            },
            format="json",
        )
        app_id = create_resp.data["id"]

        response = staff_client.post(
            f"/api/staff/agents/certifications/{app_id}/reject/",
            {"reason": "Blurry photo"},
            format="json",
        )

        assert response.status_code == status.HTTP_200_OK
        assert response.data["status"] == "rejected"
        assert response.data["rejection_reason"] == "Blurry photo"

        # Agent should still be self-enrolled
        profile_resp = agent_client.get("/api/agents/profile/")
        assert profile_resp.data["agent_type"] == "self_enrolled"
