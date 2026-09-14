import pytest
from rest_framework import status

from project.apps.accounts.models import AgentStatus, KycStatus, LoanGuarantor, UserRole
from project.apps.kyc.models import KycSubmission

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _staff_client(api_client, user_factory):
    """Return an APIClient authenticated as a staff user via the staff login endpoint."""
    staff = user_factory(
        email="admin@example.com",
        username="admin",
        password="adminpass123",
        is_staff=True,
        is_superuser=True,
        supabase_user_id=None,
    )
    response = api_client.post(
        "/api/auth/staff/login/",
        {"email": staff.email, "password": "adminpass123"},
        format="json",
    )
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {response.data['access']}")
    return api_client, staff


# ---------------------------------------------------------------------------
# User List  GET /api/staff/users/
# ---------------------------------------------------------------------------


class TestStaffUserList:
    @pytest.mark.django_db
    def test_staff_can_list_users(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        user_factory(email="alice@example.com", username="alice")
        user_factory(email="bob@example.com", username="bob")

        response = client.get("/api/staff/users/")

        assert response.status_code == status.HTTP_200_OK
        emails = [u["email"] for u in response.data["results"]]
        assert "alice@example.com" in emails
        assert "bob@example.com" in emails

    @pytest.mark.django_db
    def test_non_staff_is_forbidden(self, api_client, authenticated_client):
        response = authenticated_client.get("/api/staff/users/")
        assert response.status_code == status.HTTP_403_FORBIDDEN

    @pytest.mark.django_db
    def test_unauthenticated_is_rejected(self, api_client):
        response = api_client.get("/api/staff/users/")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    @pytest.mark.django_db
    def test_filter_by_role_user(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        user_factory(email="normaluser@example.com", username="normaluser", role=UserRole.USER)
        user_factory(email="agentuser@example.com", username="agentuser", role=UserRole.AGENT)

        response = client.get("/api/staff/users/?role=user")

        assert response.status_code == status.HTTP_200_OK
        roles = [u["role"] for u in response.data["results"]]
        assert all(r == UserRole.USER for r in roles)

    @pytest.mark.django_db
    def test_filter_by_role_agent(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        user_factory(email="normaluser@example.com", username="normaluser", role=UserRole.USER)
        user_factory(email="agentuser@example.com", username="agentuser", role=UserRole.AGENT)

        response = client.get("/api/staff/users/?role=agent")

        assert response.status_code == status.HTTP_200_OK
        roles = [u["role"] for u in response.data["results"]]
        assert all(r == UserRole.AGENT for r in roles)
        assert len(roles) >= 1

    @pytest.mark.django_db
    def test_filter_by_agent_status_pending(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        user_factory(email="pending@example.com", username="pending", agent_status=AgentStatus.PENDING)
        user_factory(email="approved@example.com", username="approved", agent_status=AgentStatus.APPROVED)

        response = client.get("/api/staff/users/?agent_status=pending")

        assert response.status_code == status.HTTP_200_OK
        statuses = [u["agent_status"] for u in response.data["results"]]
        assert all(s == AgentStatus.PENDING for s in statuses)

    @pytest.mark.django_db
    def test_filter_by_is_active_false(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        user_factory(email="active@example.com", username="active", is_active=True)
        user_factory(email="inactive@example.com", username="inactive", is_active=False)

        response = client.get("/api/staff/users/?is_active=false")

        assert response.status_code == status.HTTP_200_OK
        assert all(not u["is_active"] for u in response.data["results"])

    @pytest.mark.django_db
    def test_filter_by_kyc_status_and_ghana_card_type(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        card_user = user_factory(
            email="card@example.com",
            username="card",
            kyc_status=KycStatus.PENDING,
        )
        KycSubmission.objects.create(
            user=card_user,
            id_type=KycSubmission.IdType.NATIONAL_ID,
        )

        response = client.get("/api/staff/users/?kyc_status=pending&id_type=national_id")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] == 1
        result = response.data["results"][0]
        assert result["id"] == str(card_user.id)
        assert result["kyc_status"] == KycStatus.PENDING
        assert result["kyc_submission"]["id_type"] == KycSubmission.IdType.NATIONAL_ID

    @pytest.mark.django_db
    def test_search_by_phone(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        user_factory(email="findme@example.com", username="findme", phone="+233241234567")
        user_factory(email="other@example.com", username="other", phone="+233551234567")

        response = client.get("/api/staff/users/?search=241234567")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] == 1
        assert response.data["results"][0]["phone"] == "+233241234567"

    @pytest.mark.django_db
    def test_search_by_first_name(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        user_factory(email="kwame@example.com", username="kwame", first_name="Kwame")
        user_factory(email="ama@example.com", username="ama", first_name="Ama")

        response = client.get("/api/staff/users/?search=Kwame")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] == 1
        assert response.data["results"][0]["first_name"] == "Kwame"

    @pytest.mark.django_db
    def test_ordering_by_phone(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        user_factory(email="zzz@example.com", username="zzz", phone="+233551234567")
        user_factory(email="aaa@example.com", username="aaa", phone="+233241234567")

        response = client.get("/api/staff/users/?ordering=phone")

        assert response.status_code == status.HTTP_200_OK
        phones = [u["phone"] for u in response.data["results"] if u["phone"]]
        assert phones == sorted(phones)

    @pytest.mark.django_db
    def test_response_includes_role_and_agent_status(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        user_factory(email="check@example.com", username="check")

        response = client.get("/api/staff/users/")

        assert response.status_code == status.HTTP_200_OK
        first = response.data["results"][0]
        assert "role" in first
        assert "agent_status" in first

    @pytest.mark.django_db
    def test_response_includes_kyc_summary(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        target = user_factory(
            email="kyc-summary@example.com",
            username="kyc-summary",
            phone="+233241112222",
            kyc_status=KycStatus.PENDING,
        )
        submission = KycSubmission.objects.create(
            user=target,
            id_type=KycSubmission.IdType.NATIONAL_ID,
        )

        response = client.get("/api/staff/users/?search=241112222")

        assert response.status_code == status.HTTP_200_OK
        summary = response.data["results"][0]["kyc_submission"]
        assert summary["id"] == str(submission.id)
        assert summary["status"] == KycSubmission.Status.PENDING
        assert summary["id_type"] == KycSubmission.IdType.NATIONAL_ID

    @pytest.mark.django_db
    def test_superusers_excluded_from_list(self, api_client, user_factory):
        client, staff = _staff_client(api_client, user_factory)

        response = client.get("/api/staff/users/")

        assert response.status_code == status.HTTP_200_OK
        ids = [u["id"] for u in response.data["results"]]
        assert str(staff.id) not in ids


# ---------------------------------------------------------------------------
# User Detail  GET /api/staff/users/{id}/
# ---------------------------------------------------------------------------


class TestStaffUserDetail:
    @pytest.mark.django_db
    def test_staff_can_get_user_detail(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        target = user_factory(email="detail@example.com", username="detail")

        response = client.get(f"/api/staff/users/{target.id}/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["email"] == target.email
        assert "supabase_user_id" in response.data

    @pytest.mark.django_db
    def test_returns_404_for_missing_user(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)

        response = client.get("/api/staff/users/00000000-0000-0000-0000-000000000000/")

        assert response.status_code == status.HTTP_404_NOT_FOUND

    @pytest.mark.django_db
    def test_non_staff_is_forbidden(self, api_client, user_factory, authenticated_client):
        target = user_factory(email="target@example.com", username="target")

        response = authenticated_client.get(f"/api/staff/users/{target.id}/")

        assert response.status_code == status.HTTP_403_FORBIDDEN


# ---------------------------------------------------------------------------
# Approve Agent  POST /api/staff/users/{id}/approve-agent/
# ---------------------------------------------------------------------------


class TestApproveAgent:
    @pytest.mark.django_db
    def test_approves_pending_application(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        applicant = user_factory(
            email="applicant@example.com",
            username="applicant",
            agent_status=AgentStatus.PENDING,
        )

        response = client.post(f"/api/staff/users/{applicant.id}/approve-agent/")

        assert response.status_code == status.HTTP_200_OK
        applicant.refresh_from_db()
        assert applicant.role == UserRole.AGENT
        assert applicant.agent_status == AgentStatus.APPROVED

    @pytest.mark.django_db
    def test_response_reflects_updated_role(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        applicant = user_factory(
            email="applicant2@example.com",
            username="applicant2",
            agent_status=AgentStatus.PENDING,
        )

        response = client.post(f"/api/staff/users/{applicant.id}/approve-agent/")

        assert response.data["role"] == UserRole.AGENT
        assert response.data["agent_status"] == AgentStatus.APPROVED

    @pytest.mark.django_db
    def test_returns_400_if_already_agent(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        agent = user_factory(
            email="alreadyagent@example.com",
            username="alreadyagent",
            role=UserRole.AGENT,
            agent_status=AgentStatus.APPROVED,
        )

        response = client.post(f"/api/staff/users/{agent.id}/approve-agent/")

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    @pytest.mark.django_db
    def test_returns_400_if_not_pending(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        user = user_factory(
            email="nopending@example.com",
            username="nopending",
            agent_status=AgentStatus.NONE,
        )

        response = client.post(f"/api/staff/users/{user.id}/approve-agent/")

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    @pytest.mark.django_db
    def test_returns_404_for_missing_user(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)

        response = client.post("/api/staff/users/00000000-0000-0000-0000-000000000000/approve-agent/")

        assert response.status_code == status.HTTP_404_NOT_FOUND

    @pytest.mark.django_db
    def test_non_staff_is_forbidden(self, api_client, user_factory, authenticated_client):
        applicant = user_factory(
            email="forbidden@example.com",
            username="forbidden",
            agent_status=AgentStatus.PENDING,
        )

        response = authenticated_client.post(f"/api/staff/users/{applicant.id}/approve-agent/")

        assert response.status_code == status.HTTP_403_FORBIDDEN


# ---------------------------------------------------------------------------
# Reject Agent  POST /api/staff/users/{id}/reject-agent/
# ---------------------------------------------------------------------------


class TestRejectAgent:
    @pytest.mark.django_db
    def test_rejects_pending_application(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        applicant = user_factory(
            email="toreject@example.com",
            username="toreject",
            agent_status=AgentStatus.PENDING,
        )

        response = client.post(f"/api/staff/users/{applicant.id}/reject-agent/")

        assert response.status_code == status.HTTP_200_OK
        applicant.refresh_from_db()
        assert applicant.role == UserRole.USER
        assert applicant.agent_status == AgentStatus.REJECTED

    @pytest.mark.django_db
    def test_response_reflects_rejected_status(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        applicant = user_factory(
            email="toreject2@example.com",
            username="toreject2",
            agent_status=AgentStatus.PENDING,
        )

        response = client.post(f"/api/staff/users/{applicant.id}/reject-agent/")

        assert response.data["agent_status"] == AgentStatus.REJECTED
        assert response.data["role"] == UserRole.USER

    @pytest.mark.django_db
    def test_accepts_optional_reason(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        applicant = user_factory(
            email="withreason@example.com",
            username="withreason",
            agent_status=AgentStatus.PENDING,
        )

        response = client.post(
            f"/api/staff/users/{applicant.id}/reject-agent/",
            {"reason": "Incomplete documentation."},
            format="json",
        )

        assert response.status_code == status.HTTP_200_OK

    @pytest.mark.django_db
    def test_returns_400_if_not_pending(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        user = user_factory(
            email="notpending@example.com",
            username="notpending",
            agent_status=AgentStatus.NONE,
        )

        response = client.post(f"/api/staff/users/{user.id}/reject-agent/")

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    @pytest.mark.django_db
    def test_returns_404_for_missing_user(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)

        response = client.post("/api/staff/users/00000000-0000-0000-0000-000000000000/reject-agent/")

        assert response.status_code == status.HTTP_404_NOT_FOUND

    @pytest.mark.django_db
    def test_non_staff_is_forbidden(self, api_client, user_factory, authenticated_client):
        applicant = user_factory(
            email="forbiddenreject@example.com",
            username="forbiddenreject",
            agent_status=AgentStatus.PENDING,
        )

        response = authenticated_client.post(f"/api/staff/users/{applicant.id}/reject-agent/")

        assert response.status_code == status.HTTP_403_FORBIDDEN


# ---------------------------------------------------------------------------
# Deactivate User  POST /api/staff/users/{id}/deactivate/
# ---------------------------------------------------------------------------


class TestDeactivateUser:
    @pytest.mark.django_db
    def test_deactivates_approved_user_with_reason(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        target = user_factory(
            email="approved-user@example.com",
            username="approved-user",
            kyc_status=KycStatus.APPROVED,
        )

        response = client.post(
            f"/api/staff/users/{target.id}/deactivate/",
            {"reason": "Identity risk identified during manual review."},
            format="json",
        )

        assert response.status_code == status.HTTP_200_OK
        target.refresh_from_db()
        assert target.is_active is False
        assert target.deactivation_reason == "Identity risk identified during manual review."
        assert target.deactivated_at is not None
        assert response.data["deactivation_reason"] == target.deactivation_reason

    @pytest.mark.django_db
    def test_requires_reason(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        target = user_factory(
            email="no-reason@example.com",
            username="no-reason",
            kyc_status=KycStatus.APPROVED,
        )

        response = client.post(
            f"/api/staff/users/{target.id}/deactivate/",
            {"reason": ""},
            format="json",
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        target.refresh_from_db()
        assert target.is_active is True

    @pytest.mark.django_db
    def test_rejects_user_without_approved_kyc(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        target = user_factory(
            email="pending-user@example.com",
            username="pending-user",
            kyc_status=KycStatus.PENDING,
        )

        response = client.post(
            f"/api/staff/users/{target.id}/deactivate/",
            {"reason": "Should not be accepted."},
            format="json",
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        target.refresh_from_db()
        assert target.is_active is True


# ---------------------------------------------------------------------------
# User Guarantors  GET /api/staff/users/{id}/guarantors/
# ---------------------------------------------------------------------------


class TestStaffUserGuarantors:
    @pytest.mark.django_db
    def test_returns_user_guarantors(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)
        target = user_factory(email="gtarget@example.com", username="gtarget")
        LoanGuarantor.objects.create(user=target, name="A", phone_number="024")
        LoanGuarantor.objects.create(user=target, name="B", phone_number="055")

        response = client.get(f"/api/staff/users/{target.id}/guarantors/")

        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) == 2
        names = {g["name"] for g in response.data}
        assert names == {"A", "B"}

    @pytest.mark.django_db
    def test_returns_404_for_invalid_user(self, api_client, user_factory):
        client, _ = _staff_client(api_client, user_factory)

        response = client.get("/api/staff/users/00000000-0000-0000-0000-000000000000/guarantors/")

        assert response.status_code == status.HTTP_404_NOT_FOUND

    @pytest.mark.django_db
    def test_unauthenticated_rejected(self, api_client, user_factory):
        target = user_factory(email="gtarget2@example.com", username="gtarget2")

        response = api_client.get(f"/api/staff/users/{target.id}/guarantors/")

        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    @pytest.mark.django_db
    def test_non_staff_rejected(self, api_client, user_factory, authenticated_client):
        target = user_factory(email="gtarget3@example.com", username="gtarget3")

        response = authenticated_client.get(f"/api/staff/users/{target.id}/guarantors/")

        assert response.status_code == status.HTTP_403_FORBIDDEN
