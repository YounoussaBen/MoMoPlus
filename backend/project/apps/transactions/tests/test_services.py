from decimal import Decimal

import pytest

from project.apps.accounts.models import AgentStatus, UserRole
from project.apps.agents.models import AgentProfile, AgentType
from project.apps.notifications.models import Notification, NotificationKind
from project.apps.transactions.models import CashServiceRating, TransactionStatus
from project.apps.transactions.services import (
    accept_transaction,
    cancel_transaction,
    confirm_transaction,
    create_physical_transaction,
    get_agent_transactions,
    get_transaction_detail,
    get_user_transactions,
    rate_cash_service,
    reject_transaction,
)
from project.apps.wallets.models import Wallet


@pytest.fixture
def agent_user(user_factory):
    return user_factory(
        username="agent1",
        email="agent@example.com",
        role=UserRole.AGENT,
        agent_status=AgentStatus.APPROVED,
    )


@pytest.fixture
def agent_profile(agent_user):
    return AgentProfile.objects.create(
        user=agent_user,
        latitude=Decimal("5.6037"),
        longitude=Decimal("-0.1870"),
        is_available=True,
        min_amount=Decimal("10.00"),
        max_amount=Decimal("500.00"),
        agent_type=AgentType.CERTIFIED,
    )


@pytest.fixture
def borrower(user_factory):
    return user_factory(
        username="borrower1",
        email="borrower@example.com",
        role=UserRole.USER,
    )


@pytest.fixture
def verified_wallet(borrower):
    return Wallet.objects.create(
        user=borrower,
        phone_number="0241234567",
        network="mtn",
        is_verified=True,
        is_default=True,
    )


@pytest.fixture
def pending_txn(borrower, agent_profile, verified_wallet):
    return create_physical_transaction(
        user=borrower,
        agent_profile_id=str(agent_profile.pk),
        transaction_type="cash_out",
        amount=Decimal("100.00"),
        network="mtn",
        wallet_id=str(verified_wallet.pk),
    )


@pytest.mark.django_db
class TestCreatePhysicalTransaction:
    def test_success(self, borrower, agent_profile, verified_wallet):
        txn = create_physical_transaction(
            user=borrower,
            agent_profile_id=str(agent_profile.pk),
            transaction_type="cash_out",
            amount=Decimal("100.00"),
            network="mtn",
            wallet_id=str(verified_wallet.pk),
        )
        assert txn.status == TransactionStatus.PENDING
        assert txn.amount == Decimal("100.00")
        assert txn.transaction_type == "cash_out"
        assert len(txn.verification_code) == 6
        assert txn.expires_at is not None
        assert Notification.objects.filter(
            user=agent_profile.user,
            kind=NotificationKind.TRANSACTION_REQUEST,
            resource_id=str(txn.pk),
        ).exists()

    def test_certified_agent_with_zero_get_funds_limit_can_provide_cash_service(
        self, borrower, agent_profile, verified_wallet
    ):
        agent_profile.max_amount = Decimal("0.00")
        agent_profile.save(update_fields=["max_amount"])

        txn = create_physical_transaction(
            user=borrower,
            agent_profile_id=str(agent_profile.pk),
            transaction_type="cash_out",
            amount=Decimal("100.00"),
            network="mtn",
            wallet_id=str(verified_wallet.pk),
        )

        assert txn.status == TransactionStatus.PENDING

    def test_deposit_type(self, borrower, agent_profile, verified_wallet):
        txn = create_physical_transaction(
            user=borrower,
            agent_profile_id=str(agent_profile.pk),
            transaction_type="deposit",
            amount=Decimal("50.00"),
            network="mtn",
            wallet_id=str(verified_wallet.pk),
        )
        assert txn.transaction_type == "deposit"

    def test_agent_not_found(self, borrower, verified_wallet):
        with pytest.raises(ValueError, match="Agent not found"):
            create_physical_transaction(
                user=borrower,
                agent_profile_id="00000000-0000-0000-0000-000000000000",
                transaction_type="cash_out",
                amount=Decimal("100.00"),
                network="mtn",
                wallet_id=str(verified_wallet.pk),
            )

    def test_agent_unavailable(self, borrower, agent_profile, verified_wallet):
        agent_profile.is_available = False
        agent_profile.save(update_fields=["is_available"])

        with pytest.raises(ValueError, match="no longer available"):
            create_physical_transaction(
                user=borrower,
                agent_profile_id=str(agent_profile.pk),
                transaction_type="cash_out",
                amount=Decimal("100.00"),
                network="mtn",
                wallet_id=str(verified_wallet.pk),
            )

    def test_self_transaction(self, agent_user, agent_profile):
        wallet = Wallet.objects.create(
            user=agent_user,
            phone_number="0241111111",
            network="mtn",
            is_verified=True,
        )
        with pytest.raises(ValueError, match="yourself"):
            create_physical_transaction(
                user=agent_user,
                agent_profile_id=str(agent_profile.pk),
                transaction_type="cash_out",
                amount=Decimal("100.00"),
                network="mtn",
                wallet_id=str(wallet.pk),
            )

    def test_self_enrolled_agent_rejected(self, borrower, verified_wallet, user_factory):
        se_user = user_factory(
            username="se_agent",
            email="se@example.com",
            role=UserRole.AGENT,
            agent_status=AgentStatus.APPROVED,
        )
        se_profile = AgentProfile.objects.create(
            user=se_user,
            latitude=Decimal("5.6037"),
            longitude=Decimal("-0.1870"),
            is_available=True,
            agent_type=AgentType.SELF_ENROLLED,
        )
        with pytest.raises(ValueError, match="certified agents"):
            create_physical_transaction(
                user=borrower,
                agent_profile_id=str(se_profile.pk),
                transaction_type="cash_out",
                amount=Decimal("100.00"),
                network="mtn",
                wallet_id=str(verified_wallet.pk),
            )

    def test_unverified_wallet(self, borrower, agent_profile):
        wallet = Wallet.objects.create(
            user=borrower,
            phone_number="0249999999",
            network="mtn",
            is_verified=False,
        )
        with pytest.raises(ValueError, match="verified"):
            create_physical_transaction(
                user=borrower,
                agent_profile_id=str(agent_profile.pk),
                transaction_type="cash_out",
                amount=Decimal("100.00"),
                network="mtn",
                wallet_id=str(wallet.pk),
            )

    def test_duplicate_pending(self, borrower, agent_profile, verified_wallet, pending_txn):
        with pytest.raises(ValueError, match="already have a pending"):
            create_physical_transaction(
                user=borrower,
                agent_profile_id=str(agent_profile.pk),
                transaction_type="cash_out",
                amount=Decimal("100.00"),
                network="mtn",
                wallet_id=str(verified_wallet.pk),
            )

    def test_invalid_type(self, borrower, agent_profile, verified_wallet):
        with pytest.raises(ValueError, match="Invalid transaction type"):
            create_physical_transaction(
                user=borrower,
                agent_profile_id=str(agent_profile.pk),
                transaction_type="invalid",
                amount=Decimal("100.00"),
                network="mtn",
                wallet_id=str(verified_wallet.pk),
            )


@pytest.mark.django_db
class TestAcceptTransaction:
    def test_success(self, pending_txn, agent_user):
        txn = accept_transaction(
            txn=pending_txn,
            user=agent_user,
            meeting_latitude=Decimal("5.6100"),
            meeting_longitude=Decimal("-0.1900"),
            meeting_description="By the market entrance",
        )
        assert txn.status == TransactionStatus.ACCEPTED
        assert txn.meeting_latitude == Decimal("5.6100")
        assert txn.meeting_description == "By the market entrance"

    def test_rounds_high_precision_coordinates(self, pending_txn, agent_user):
        txn = accept_transaction(
            txn=pending_txn,
            user=agent_user,
            meeting_latitude="5.610012345678",
            meeting_longitude="-0.190098765432",
        )
        assert txn.status == TransactionStatus.ACCEPTED
        assert txn.meeting_latitude == Decimal("5.610012")
        assert txn.meeting_longitude == Decimal("-0.190099")

    def test_non_agent_cannot_accept(self, pending_txn, borrower):
        with pytest.raises(ValueError, match="Only the assigned agent"):
            accept_transaction(
                txn=pending_txn,
                user=borrower,
                meeting_latitude=Decimal("5.6100"),
                meeting_longitude=Decimal("-0.1900"),
            )

    def test_cannot_accept_non_pending(self, pending_txn, agent_user):
        pending_txn.status = TransactionStatus.REJECTED
        pending_txn.save(update_fields=["status"])

        with pytest.raises(ValueError, match="Only pending"):
            accept_transaction(
                txn=pending_txn,
                user=agent_user,
                meeting_latitude=Decimal("5.6100"),
                meeting_longitude=Decimal("-0.1900"),
            )


@pytest.mark.django_db
class TestRejectTransaction:
    def test_success(self, pending_txn, agent_user):
        txn = reject_transaction(txn=pending_txn, user=agent_user, reason="Too busy")
        assert txn.status == TransactionStatus.REJECTED
        assert txn.cancellation_reason == "Too busy"

    def test_non_agent_cannot_reject(self, pending_txn, borrower):
        with pytest.raises(ValueError, match="Only the assigned agent"):
            reject_transaction(txn=pending_txn, user=borrower)


@pytest.mark.django_db
class TestConfirmTransaction:
    def test_user_confirms_after_agent_verifies(self, pending_txn, agent_user, borrower):
        accept_transaction(
            txn=pending_txn,
            user=agent_user,
            meeting_latitude=Decimal("5.6100"),
            meeting_longitude=Decimal("-0.1900"),
        )
        confirm_transaction(
            txn=pending_txn,
            user=agent_user,
            verification_code=pending_txn.verification_code,
        )
        txn = confirm_transaction(txn=pending_txn, user=borrower)
        assert txn.user_confirmed is True
        assert txn.agent_confirmed is True
        assert txn.status == TransactionStatus.COMPLETED

    def test_agent_verifies_correct_code(self, pending_txn, agent_user):
        accept_transaction(
            txn=pending_txn,
            user=agent_user,
            meeting_latitude=Decimal("5.6100"),
            meeting_longitude=Decimal("-0.1900"),
        )
        txn = confirm_transaction(
            txn=pending_txn,
            user=agent_user,
            verification_code=pending_txn.verification_code,
        )
        assert txn.agent_confirmed is True
        assert txn.user_confirmed is False
        assert txn.status == TransactionStatus.ACCEPTED

    def test_both_confirm_completes(self, pending_txn, agent_user, borrower):
        accept_transaction(
            txn=pending_txn,
            user=agent_user,
            meeting_latitude=Decimal("5.6100"),
            meeting_longitude=Decimal("-0.1900"),
        )
        confirm_transaction(
            txn=pending_txn,
            user=agent_user,
            verification_code=pending_txn.verification_code,
        )
        txn = confirm_transaction(txn=pending_txn, user=borrower)
        assert txn.status == TransactionStatus.COMPLETED
        assert txn.completed_at is not None

    def test_agent_wrong_code_rejected(self, pending_txn, agent_user):
        accept_transaction(
            txn=pending_txn,
            user=agent_user,
            meeting_latitude=Decimal("5.6100"),
            meeting_longitude=Decimal("-0.1900"),
        )
        wrong_code = "000001" if pending_txn.verification_code == "000000" else "000000"
        with pytest.raises(ValueError, match="code is incorrect"):
            confirm_transaction(
                txn=pending_txn,
                user=agent_user,
                verification_code=wrong_code,
            )
        pending_txn.refresh_from_db()
        assert pending_txn.agent_confirmed is False
        assert pending_txn.verification_attempts == 1

    def test_agent_is_locked_after_five_wrong_codes(self, pending_txn, agent_user):
        accept_transaction(
            txn=pending_txn,
            user=agent_user,
            meeting_latitude=Decimal("5.6100"),
            meeting_longitude=Decimal("-0.1900"),
        )
        wrong_code = "000001" if pending_txn.verification_code == "000000" else "000000"
        for _ in range(5):
            with pytest.raises(ValueError, match="code is incorrect"):
                confirm_transaction(
                    txn=pending_txn,
                    user=agent_user,
                    verification_code=wrong_code,
                )

        with pytest.raises(ValueError, match="verification is locked"):
            confirm_transaction(
                txn=pending_txn,
                user=agent_user,
                verification_code=pending_txn.verification_code,
            )

    def test_user_cannot_confirm_before_code_is_verified(self, pending_txn, agent_user, borrower):
        accept_transaction(
            txn=pending_txn,
            user=agent_user,
            meeting_latitude=Decimal("5.6100"),
            meeting_longitude=Decimal("-0.1900"),
        )
        with pytest.raises(ValueError, match="must verify your code"):
            confirm_transaction(txn=pending_txn, user=borrower)

    def test_cannot_confirm_pending(self, pending_txn, borrower):
        with pytest.raises(ValueError, match="must be accepted"):
            confirm_transaction(txn=pending_txn, user=borrower)

    def test_completed_transaction_cannot_be_confirmed_again(self, pending_txn, agent_user, borrower):
        accept_transaction(
            txn=pending_txn,
            user=agent_user,
            meeting_latitude=Decimal("5.6100"),
            meeting_longitude=Decimal("-0.1900"),
        )
        confirm_transaction(
            txn=pending_txn,
            user=agent_user,
            verification_code=pending_txn.verification_code,
        )
        confirm_transaction(txn=pending_txn, user=borrower)
        with pytest.raises(ValueError, match="must be accepted"):
            confirm_transaction(txn=pending_txn, user=borrower)


@pytest.mark.django_db
class TestCancelTransaction:
    def test_user_cancels_pending(self, pending_txn, borrower):
        txn = cancel_transaction(txn=pending_txn, user=borrower, reason="Changed mind")
        assert txn.status == TransactionStatus.CANCELLED
        assert txn.cancelled_by == borrower
        assert txn.cancellation_reason == "Changed mind"

    def test_agent_cancels_accepted(self, pending_txn, agent_user):
        accept_transaction(
            txn=pending_txn,
            user=agent_user,
            meeting_latitude=Decimal("5.6100"),
            meeting_longitude=Decimal("-0.1900"),
        )
        txn = cancel_transaction(txn=pending_txn, user=agent_user)
        assert txn.status == TransactionStatus.CANCELLED

    def test_cannot_cancel_completed(self, pending_txn, agent_user, borrower):
        accept_transaction(
            txn=pending_txn,
            user=agent_user,
            meeting_latitude=Decimal("5.6100"),
            meeting_longitude=Decimal("-0.1900"),
        )
        pending_txn = confirm_transaction(
            txn=pending_txn,
            user=agent_user,
            verification_code=pending_txn.verification_code,
        )
        pending_txn = confirm_transaction(txn=pending_txn, user=borrower)

        with pytest.raises(ValueError, match="can no longer be cancelled"):
            cancel_transaction(txn=pending_txn, user=borrower)


@pytest.mark.django_db
class TestListTransactions:
    def test_user_list(self, pending_txn, borrower):
        txns = get_user_transactions(user=borrower)
        assert len(txns) == 1
        assert txns[0].pk == pending_txn.pk

    def test_agent_list(self, pending_txn, agent_user):
        txns = get_agent_transactions(user=agent_user)
        assert len(txns) == 1
        assert txns[0].pk == pending_txn.pk

    def test_filter_by_status(self, pending_txn, borrower):
        txns = get_user_transactions(user=borrower, status="pending")
        assert len(txns) == 1

        txns = get_user_transactions(user=borrower, status="completed")
        assert len(txns) == 0


@pytest.mark.django_db
class TestGetTransactionDetail:
    def test_user_can_view(self, pending_txn, borrower):
        txn = get_transaction_detail(transaction_id=str(pending_txn.pk), user=borrower)
        assert txn.pk == pending_txn.pk

    def test_agent_can_view(self, pending_txn, agent_user):
        txn = get_transaction_detail(transaction_id=str(pending_txn.pk), user=agent_user)
        assert txn.pk == pending_txn.pk

    def test_stranger_cannot_view(self, pending_txn, user_factory):
        stranger = user_factory(username="stranger", email="stranger@example.com")
        with pytest.raises(ValueError, match="not found"):
            get_transaction_detail(transaction_id=str(pending_txn.pk), user=stranger)


@pytest.mark.django_db
class TestRateCashService:
    def _complete(self, pending_txn, agent_user, borrower):
        accept_transaction(
            txn=pending_txn,
            user=agent_user,
            meeting_latitude=Decimal("5.6100"),
            meeting_longitude=Decimal("-0.1900"),
        )
        confirm_transaction(
            txn=pending_txn,
            user=agent_user,
            verification_code=pending_txn.verification_code,
        )
        return confirm_transaction(txn=pending_txn, user=borrower)

    def test_user_can_rate_completed_cash_service(self, pending_txn, agent_user, borrower, agent_profile):
        completed = self._complete(pending_txn, agent_user, borrower)

        rated = rate_cash_service(txn=completed, user=borrower, rating=5)

        assert rated.agent_rating.rating == 5
        agent_profile.refresh_from_db()
        assert agent_profile.rating == Decimal("5.00")
        assert agent_profile.total_ratings == 1
        assert CashServiceRating.objects.filter(transaction=completed, user=borrower).count() == 1

    def test_updating_rating_does_not_inflate_count(self, pending_txn, agent_user, borrower, agent_profile):
        completed = self._complete(pending_txn, agent_user, borrower)

        rate_cash_service(txn=completed, user=borrower, rating=5)
        rate_cash_service(txn=completed, user=borrower, rating=3)

        agent_profile.refresh_from_db()
        assert agent_profile.rating == Decimal("3.00")
        assert agent_profile.total_ratings == 1
        assert CashServiceRating.objects.filter(agent=agent_profile).count() == 1

    def test_only_participating_user_can_rate(self, pending_txn, agent_user, borrower):
        completed = self._complete(pending_txn, agent_user, borrower)

        with pytest.raises(ValueError, match="Only the user"):
            rate_cash_service(txn=completed, user=agent_user, rating=5)

    def test_rating_requires_completed_transaction(self, pending_txn, borrower):
        with pytest.raises(ValueError, match="only after it is completed"):
            rate_cash_service(txn=pending_txn, user=borrower, rating=5)
