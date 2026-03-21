import pytest

from project.apps.accounts.models import AgentStatus, UserRole
from project.apps.agents.models import AgentProfile, AgentType
from project.apps.agents.services import (
    apply_for_certification,
    approve_certification,
    get_agent_profile,
    get_certification_status,
    get_nearby_agents,
    haversine,
    reject_certification,
    toggle_availability,
    update_agent_profile,
)
from project.apps.files.models import FileAsset


@pytest.mark.django_db
class TestHaversine:
    def test_same_point_returns_zero(self):
        assert haversine(5.6037, -0.1870, 5.6037, -0.1870) == 0.0

    def test_accra_to_tema(self):
        # Accra (5.6037, -0.1870) to Tema (5.6698, -0.0166) ≈ ~20 km
        dist = haversine(5.6037, -0.1870, 5.6698, -0.0166)
        assert 18 < dist < 22

    def test_accra_to_kumasi(self):
        # Accra (5.6037, -0.1870) to Kumasi (6.6885, -1.6244) ≈ ~190 km
        dist = haversine(5.6037, -0.1870, 6.6885, -1.6244)
        assert 180 < dist < 200


@pytest.mark.django_db
class TestGetNearbyAgents:
    def _make_agent(self, user_factory, *, lat, lon, max_amount=100, is_available=True, **kwargs):
        user = user_factory(
            role=UserRole.AGENT,
            agent_status=AgentStatus.APPROVED,
            **kwargs,
        )
        return AgentProfile.objects.create(
            user=user,
            latitude=lat,
            longitude=lon,
            max_amount=max_amount,
            is_available=is_available,
        )

    def test_finds_agents_within_radius(self, user_factory):
        self._make_agent(
            user_factory,
            lat=5.6037,
            lon=-0.1870,
            email="nearby@test.com",
            username="nearby",
        )
        self._make_agent(
            user_factory,
            lat=6.6885,
            lon=-1.6244,  # Kumasi, ~190km away
            email="far@test.com",
            username="far",
        )

        results = get_nearby_agents(lat=5.6037, lon=-0.1870, radius_km=30)

        assert len(results) == 1
        assert results[0].user.email == "nearby@test.com"

    def test_excludes_unavailable_agents(self, user_factory):
        self._make_agent(
            user_factory,
            lat=5.6037,
            lon=-0.1870,
            is_available=False,
            email="offline@test.com",
            username="offline",
        )

        results = get_nearby_agents(lat=5.6037, lon=-0.1870, radius_km=30)

        assert len(results) == 0

    def test_filters_by_min_amount(self, user_factory):
        self._make_agent(
            user_factory,
            lat=5.6037,
            lon=-0.1870,
            max_amount=50,
            email="small@test.com",
            username="small",
        )
        self._make_agent(
            user_factory,
            lat=5.6040,
            lon=-0.1870,
            max_amount=200,
            email="big@test.com",
            username="big",
        )

        results = get_nearby_agents(lat=5.6037, lon=-0.1870, radius_km=30, min_amount=100)

        assert len(results) == 1
        assert results[0].user.email == "big@test.com"

    def test_sorts_by_distance_by_default(self, user_factory):
        self._make_agent(
            user_factory,
            lat=5.6100,
            lon=-0.1870,
            email="further@test.com",
            username="further",
        )
        self._make_agent(
            user_factory,
            lat=5.6038,
            lon=-0.1870,
            email="closer@test.com",
            username="closer",
        )

        results = get_nearby_agents(lat=5.6037, lon=-0.1870, radius_km=30)

        assert results[0].user.email == "closer@test.com"
        assert results[1].user.email == "further@test.com"

    def test_sorts_by_rating(self, user_factory):
        p1 = self._make_agent(
            user_factory,
            lat=5.6038,
            lon=-0.1870,
            email="low@test.com",
            username="low",
        )
        p1.rating = 3.0
        p1.save(update_fields=["rating"])

        p2 = self._make_agent(
            user_factory,
            lat=5.6100,
            lon=-0.1870,
            email="high@test.com",
            username="high",
        )
        p2.rating = 5.0
        p2.save(update_fields=["rating"])

        results = get_nearby_agents(lat=5.6037, lon=-0.1870, radius_km=30, sort_by="rating")

        assert results[0].user.email == "high@test.com"

    def test_attaches_distance_km(self, user_factory):
        self._make_agent(
            user_factory,
            lat=5.6037,
            lon=-0.1870,
            email="agent@test.com",
            username="agent",
        )

        results = get_nearby_agents(lat=5.6037, lon=-0.1870, radius_km=30)

        assert hasattr(results[0], "distance_km")
        assert results[0].distance_km == 0.0


@pytest.mark.django_db
class TestGetAgentProfile:
    def test_creates_profile_if_not_exists(self, user):
        profile = get_agent_profile(user=user)

        assert profile.user == user
        assert AgentProfile.objects.filter(user=user).exists()

    def test_returns_existing_profile(self, user):
        existing = AgentProfile.objects.create(user=user, max_amount=500)

        profile = get_agent_profile(user=user)

        assert profile.pk == existing.pk


@pytest.mark.django_db
class TestUpdateAgentProfile:
    def test_updates_location(self, user):
        profile = update_agent_profile(user=user, latitude=5.6037, longitude=-0.1870)

        assert float(profile.latitude) == 5.6037
        assert float(profile.longitude) == -0.187

    def test_rejects_latitude_without_longitude(self, user):
        with pytest.raises(ValueError, match="Both latitude and longitude"):
            update_agent_profile(user=user, latitude=5.6037)

    def test_rejects_min_greater_than_max(self, user):
        AgentProfile.objects.create(user=user, max_amount=100)

        with pytest.raises(ValueError, match="Minimum amount cannot exceed"):
            update_agent_profile(user=user, min_amount=200)

    def test_updates_multiple_fields(self, user):
        profile = update_agent_profile(
            user=user,
            max_amount=500,
            min_amount=10,
            bio="I am a trusted agent",
            is_available=True,
        )

        assert float(profile.max_amount) == 500
        assert float(profile.min_amount) == 10
        assert profile.bio == "I am a trusted agent"
        assert profile.is_available is True


@pytest.mark.django_db
class TestToggleAvailability:
    def test_toggles_off_to_on(self, user):
        AgentProfile.objects.create(user=user, is_available=False)

        profile = toggle_availability(user=user)

        assert profile.is_available is True

    def test_toggles_on_to_off(self, user):
        AgentProfile.objects.create(user=user, is_available=True)

        profile = toggle_availability(user=user)

        assert profile.is_available is False


# ---------------------------------------------------------------------------
# Certification
# ---------------------------------------------------------------------------


@pytest.fixture
def agent_user(user_factory):
    return user_factory(
        email="agent@test.com",
        username="agentuser",
        role=UserRole.AGENT,
        agent_status=AgentStatus.APPROVED,
    )


@pytest.fixture
def agent_with_profile(agent_user):
    profile = AgentProfile.objects.create(user=agent_user)
    return agent_user, profile


@pytest.fixture
def file_assets(agent_user):
    photo = FileAsset.objects.create(owner=agent_user, kind="document")
    location = FileAsset.objects.create(owner=agent_user, kind="document")
    return photo, location


@pytest.mark.django_db
class TestApplyForCertification:
    def test_creates_pending_application(self, agent_with_profile, file_assets):
        user, _ = agent_with_profile
        photo, location = file_assets

        app = apply_for_certification(
            user=user,
            agent_id_number="MTN-AGT-12345",
            agent_id_photo_id=str(photo.pk),
            business_location_photo_id=str(location.pk),
        )

        assert app.agent_id_number == "MTN-AGT-12345"
        assert app.status == "pending"
        assert app.network == "mtn"

    def test_rejects_already_certified(self, agent_with_profile, file_assets):
        user, profile = agent_with_profile
        profile.agent_type = AgentType.CERTIFIED
        profile.save(update_fields=["agent_type"])
        photo, location = file_assets

        with pytest.raises(ValueError, match="already a certified"):
            apply_for_certification(
                user=user,
                agent_id_number="MTN-AGT-12345",
                agent_id_photo_id=str(photo.pk),
                business_location_photo_id=str(location.pk),
            )

    def test_rejects_duplicate_pending(self, agent_with_profile, file_assets):
        user, _ = agent_with_profile
        photo, location = file_assets

        apply_for_certification(
            user=user,
            agent_id_number="MTN-AGT-12345",
            agent_id_photo_id=str(photo.pk),
            business_location_photo_id=str(location.pk),
        )

        with pytest.raises(ValueError, match="pending certification"):
            apply_for_certification(
                user=user,
                agent_id_number="MTN-AGT-99999",
                agent_id_photo_id=str(photo.pk),
                business_location_photo_id=str(location.pk),
            )

    def test_rejects_missing_photo(self, agent_with_profile, file_assets):
        user, _ = agent_with_profile
        _, location = file_assets

        with pytest.raises(ValueError, match="Agent ID photo not found"):
            apply_for_certification(
                user=user,
                agent_id_number="MTN-AGT-12345",
                agent_id_photo_id="00000000-0000-0000-0000-000000000000",
                business_location_photo_id=str(location.pk),
            )


@pytest.mark.django_db
class TestApproveCertification:
    def test_upgrades_to_certified(self, agent_with_profile, file_assets, user_factory):
        user, _ = agent_with_profile
        photo, location = file_assets
        reviewer = user_factory(email="admin@test.com", username="admin", is_staff=True)

        app = apply_for_certification(
            user=user,
            agent_id_number="MTN-AGT-12345",
            agent_id_photo_id=str(photo.pk),
            business_location_photo_id=str(location.pk),
        )

        result = approve_certification(application=app, reviewer=reviewer)

        assert result.status == "approved"
        assert result.reviewed_by == reviewer
        assert result.reviewed_at is not None

        profile = AgentProfile.objects.get(user=user)
        assert profile.agent_type == AgentType.CERTIFIED

    def test_rejects_non_pending(self, agent_with_profile, file_assets, user_factory):
        user, _ = agent_with_profile
        photo, location = file_assets
        reviewer = user_factory(email="admin@test.com", username="admin", is_staff=True)

        app = apply_for_certification(
            user=user,
            agent_id_number="MTN-AGT-12345",
            agent_id_photo_id=str(photo.pk),
            business_location_photo_id=str(location.pk),
        )
        approve_certification(application=app, reviewer=reviewer)

        with pytest.raises(ValueError, match="Only pending"):
            approve_certification(application=app, reviewer=reviewer)


@pytest.mark.django_db
class TestRejectCertification:
    def test_rejects_with_reason(self, agent_with_profile, file_assets, user_factory):
        user, _ = agent_with_profile
        photo, location = file_assets
        reviewer = user_factory(email="admin@test.com", username="admin", is_staff=True)

        app = apply_for_certification(
            user=user,
            agent_id_number="MTN-AGT-12345",
            agent_id_photo_id=str(photo.pk),
            business_location_photo_id=str(location.pk),
        )

        result = reject_certification(application=app, reviewer=reviewer, reason="Blurry photo")

        assert result.status == "rejected"
        assert result.rejection_reason == "Blurry photo"

        profile = AgentProfile.objects.get(user=user)
        assert profile.agent_type == AgentType.SELF_ENROLLED


@pytest.mark.django_db
class TestGetCertificationStatus:
    def test_returns_latest_application(self, agent_with_profile, file_assets):
        user, _ = agent_with_profile
        photo, location = file_assets

        apply_for_certification(
            user=user,
            agent_id_number="MTN-AGT-12345",
            agent_id_photo_id=str(photo.pk),
            business_location_photo_id=str(location.pk),
        )

        result = get_certification_status(user=user)

        assert result is not None
        assert result.agent_id_number == "MTN-AGT-12345"

    def test_returns_none_when_no_application(self, agent_with_profile):
        user, _ = agent_with_profile

        result = get_certification_status(user=user)

        assert result is None
