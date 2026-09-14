import pytest

from project.apps.accounts.models import KycStatus
from project.apps.kyc.models import KycSubmission
from project.apps.kyc.services import approve_kyc, reject_kyc, submit_kyc

from .conftest import make_ghana_card_record, make_submission_asset_ids

DEFAULT_CARD_NUMBER = "GHA-728430143-4"


class TestSubmitKyc:
    @pytest.mark.django_db
    def test_creates_pending_submission(self, user_factory, media_root):
        user = user_factory()
        submission = submit_kyc(
            user=user,
            ghana_card_number=DEFAULT_CARD_NUMBER,
            **make_submission_asset_ids(user),
        )

        assert submission.status == KycSubmission.Status.PENDING
        assert submission.id_type == KycSubmission.IdType.NATIONAL_ID
        assert submission.ghana_card_number == DEFAULT_CARD_NUMBER
        assert submission.user == user

    @pytest.mark.django_db
    def test_sets_user_kyc_status_pending(self, user_factory, media_root):
        user = user_factory()
        submit_kyc(
            user=user,
            ghana_card_number=DEFAULT_CARD_NUMBER,
            **make_submission_asset_ids(user),
        )

        user.refresh_from_db()
        assert user.kyc_status == KycStatus.PENDING

    @pytest.mark.django_db
    def test_all_four_file_assets_created(self, user_factory, media_root):
        user = user_factory()
        submission = submit_kyc(
            user=user,
            ghana_card_number=DEFAULT_CARD_NUMBER,
            **make_submission_asset_ids(user),
        )

        assert submission.id_front_id is not None
        assert submission.id_back_id is not None
        assert submission.selfie_id is not None
        assert submission.proof_of_address_id is not None

    @pytest.mark.django_db
    def test_raises_if_already_pending(self, user_factory, kyc_submission_factory):
        user = user_factory(email="pending@example.com", username="pending")
        kyc_submission_factory(user)

        with pytest.raises(ValueError, match="already pending"):
            submit_kyc(
                user=user,
                ghana_card_number=DEFAULT_CARD_NUMBER,
                **make_submission_asset_ids(user),
            )

    @pytest.mark.django_db
    def test_raises_if_already_approved(self, user_factory, kyc_submission_factory):
        user = user_factory(email="approved@example.com", username="approved")
        submission = kyc_submission_factory(user)
        approve_kyc(submission=submission, reviewer=user)

        with pytest.raises(ValueError, match="already approved"):
            submit_kyc(
                user=user,
                ghana_card_number=DEFAULT_CARD_NUMBER,
                **make_submission_asset_ids(user),
            )

    @pytest.mark.django_db
    def test_resubmission_replaces_rejected_submission(self, user_factory, kyc_submission_factory):
        user = user_factory(email="resubmit@example.com", username="resubmit")
        submission = kyc_submission_factory(user)
        reject_kyc(submission=submission, reviewer=user, reason="Bad docs")

        new_submission = submit_kyc(
            user=user,
            ghana_card_number="GHA-728430143-5",
            **make_submission_asset_ids(user),
        )

        assert new_submission.pk == submission.pk
        assert new_submission.status == KycSubmission.Status.PENDING
        assert new_submission.id_type == KycSubmission.IdType.NATIONAL_ID
        assert new_submission.ghana_card_number == "GHA-728430143-5"
        assert new_submission.rejection_reason == ""

    @pytest.mark.django_db
    def test_resubmission_updates_user_kyc_status_to_pending(self, user_factory, kyc_submission_factory):
        user = user_factory(email="repending@example.com", username="repending")
        submission = kyc_submission_factory(user)
        reject_kyc(submission=submission, reviewer=user, reason="Bad docs")

        submit_kyc(
            user=user,
            ghana_card_number=DEFAULT_CARD_NUMBER,
            **make_submission_asset_ids(user),
        )

        user.refresh_from_db()
        assert user.kyc_status == KycStatus.PENDING

    @pytest.mark.django_db
    def test_auto_approves_when_card_is_in_registry(self, user_factory, media_root):
        registry_owner = user_factory(email="registry@example.com", username="registry")
        make_ghana_card_record(registry_owner)
        user = user_factory(email="matched@example.com", username="matched")

        submission = submit_kyc(
            user=user,
            ghana_card_number=DEFAULT_CARD_NUMBER,
            **make_submission_asset_ids(user),
        )

        assert submission.status == KycSubmission.Status.APPROVED
        assert submission.verification_method == KycSubmission.VerificationMethod.GHANA_CARD_REGISTRY
        user.refresh_from_db()
        assert user.kyc_status == KycStatus.APPROVED


class TestApproveKyc:
    @pytest.mark.django_db
    def test_approves_pending_submission(self, user_factory, kyc_submission_factory):
        user = user_factory(email="toapprove@example.com", username="toapprove")
        submission = kyc_submission_factory(user)

        approved = approve_kyc(submission=submission, reviewer=user)

        assert approved.status == KycSubmission.Status.APPROVED
        assert approved.reviewed_by == user
        assert approved.reviewed_at is not None

    @pytest.mark.django_db
    def test_sets_user_kyc_status_approved(self, user_factory, kyc_submission_factory):
        user = user_factory(email="approved2@example.com", username="approved2")
        submission = kyc_submission_factory(user)
        approve_kyc(submission=submission, reviewer=user)

        user.refresh_from_db()
        assert user.kyc_status == KycStatus.APPROVED

    @pytest.mark.django_db
    def test_raises_if_not_pending(self, user_factory, kyc_submission_factory):
        user = user_factory(email="alreadyapproved@example.com", username="alreadyapproved")
        submission = kyc_submission_factory(user)
        approve_kyc(submission=submission, reviewer=user)

        with pytest.raises(ValueError, match="pending"):
            approve_kyc(submission=submission, reviewer=user)


class TestRejectKyc:
    @pytest.mark.django_db
    def test_rejects_pending_submission(self, user_factory, kyc_submission_factory):
        user = user_factory(email="toreject@example.com", username="toreject")
        submission = kyc_submission_factory(user)

        rejected = reject_kyc(submission=submission, reviewer=user, reason="Image blurry")

        assert rejected.status == KycSubmission.Status.REJECTED
        assert rejected.rejection_reason == "Image blurry"
        assert rejected.reviewed_by == user
        assert rejected.reviewed_at is not None

    @pytest.mark.django_db
    def test_sets_user_kyc_status_rejected(self, user_factory, kyc_submission_factory):
        user = user_factory(email="rejected2@example.com", username="rejected2")
        submission = kyc_submission_factory(user)
        reject_kyc(submission=submission, reviewer=user, reason="Invalid ID")

        user.refresh_from_db()
        assert user.kyc_status == KycStatus.REJECTED

    @pytest.mark.django_db
    def test_raises_if_not_pending(self, user_factory, kyc_submission_factory):
        user = user_factory(email="notpending@example.com", username="notpending")
        submission = kyc_submission_factory(user)
        reject_kyc(submission=submission, reviewer=user, reason="Bad")

        with pytest.raises(ValueError, match="pending"):
            reject_kyc(submission=submission, reviewer=user, reason="Bad again")

    @pytest.mark.django_db
    def test_raises_without_reason(self, user_factory, kyc_submission_factory):
        user = user_factory(email="noreason@example.com", username="noreason")
        submission = kyc_submission_factory(user)

        with pytest.raises(ValueError, match="reason"):
            reject_kyc(submission=submission, reviewer=user, reason="")
