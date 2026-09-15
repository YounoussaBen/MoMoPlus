from __future__ import annotations

import secrets
from datetime import timedelta
from decimal import ROUND_HALF_UP, Decimal

from django.db import transaction
from django.utils import timezone

from project.apps.accounts.models import User
from project.apps.agents.models import AgentProfile, AgentType
from project.apps.notifications.models import NotificationKind
from project.apps.notifications.services import create_notification
from project.apps.wallets.models import Wallet

from .models import PhysicalTransaction, TransactionStatus, TransactionType

TRANSACTION_EXPIRY_MINUTES = 60


def _generate_verification_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _normalize_coordinate(value: Decimal | float | str) -> Decimal:
    return Decimal(str(value)).quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP)


def _display_user_name(user: User) -> str:
    name = f"{user.first_name} {user.last_name}".strip()
    return name or user.email or "A user"


def _amount_label(amount: Decimal) -> str:
    return f"GHS {amount:,.2f}"


def _transaction_label(transaction_type: str) -> str:
    return "Cash Out" if transaction_type == TransactionType.CASH_OUT else "Cash Deposit"


def _notify_transaction(
    *,
    txn: PhysicalTransaction,
    user: User,
    kind: str,
    title: str,
    message: str,
    event: str,
) -> None:
    create_notification(
        user=user,
        kind=kind,
        title=title,
        message=message,
        resource_type="transaction",
        resource_id=str(txn.pk),
        metadata={"status": txn.status},
        dedupe_key=f"transaction:{txn.pk}:{event}",
    )


def _notify_transaction_parties(
    *,
    txn: PhysicalTransaction,
    event: str,
    title: str,
    user_message: str,
    agent_message: str,
) -> None:
    _notify_transaction(
        txn=txn,
        user=txn.user,
        kind=NotificationKind.TRANSACTION_STATUS,
        title=title,
        message=user_message,
        event=f"{event}:user",
    )
    _notify_transaction(
        txn=txn,
        user=txn.agent.user,
        kind=NotificationKind.TRANSACTION_STATUS,
        title=title,
        message=agent_message,
        event=f"{event}:agent",
    )


@transaction.atomic
def create_physical_transaction(
    *,
    user: User,
    agent_profile_id: str,
    transaction_type: str,
    amount: Decimal,
    network: str,
    wallet_id: str,
) -> PhysicalTransaction:
    """Create a physical transaction request from a user to an agent."""
    if transaction_type not in TransactionType.values:
        raise ValueError("Invalid transaction type. Must be 'cash_out' or 'deposit'.")

    try:
        agent = AgentProfile.objects.select_related("user").get(pk=agent_profile_id)
    except AgentProfile.DoesNotExist:
        raise ValueError("Agent not found.")

    if not agent.is_available:
        raise ValueError("This agent is no longer available.")

    if agent.agent_type != AgentType.CERTIFIED:
        raise ValueError("Physical transactions are only available with certified agents.")

    if agent.user_id == user.pk:
        raise ValueError("You cannot create a transaction with yourself.")

    try:
        wallet = Wallet.objects.get(pk=wallet_id, user=user)
    except Wallet.DoesNotExist:
        raise ValueError("Wallet not found.")

    if not wallet.is_verified:
        raise ValueError("Only verified wallets can be used for transactions.")

    # Check for existing pending transaction with same agent
    if PhysicalTransaction.objects.filter(
        user=user,
        agent=agent,
        status=TransactionStatus.PENDING,
    ).exists():
        raise ValueError("You already have a pending transaction with this agent.")

    txn = PhysicalTransaction.objects.create(
        user=user,
        agent=agent,
        transaction_type=transaction_type,
        amount=amount,
        network=network,
        wallet=wallet,
        status=TransactionStatus.PENDING,
        verification_code=_generate_verification_code(),
        expires_at=timezone.now() + timedelta(minutes=TRANSACTION_EXPIRY_MINUTES),
    )
    label = _transaction_label(transaction_type)
    _notify_transaction(
        txn=txn,
        user=agent.user,
        kind=NotificationKind.TRANSACTION_REQUEST,
        title="New Cash Service request",
        message=f"{_display_user_name(user)} requested {label} for {_amount_label(amount)}.",
        event="request",
    )
    return txn


def get_user_transactions(*, user: User, status: str | None = None) -> list[PhysicalTransaction]:
    """List physical transactions for a user."""
    qs = PhysicalTransaction.objects.filter(user=user).select_related("agent__user", "wallet")
    if status:
        qs = qs.filter(status=status)
    return list(qs)


def get_agent_transactions(*, user: User, status: str | None = None) -> list[PhysicalTransaction]:
    """List physical transactions for an agent."""
    qs = PhysicalTransaction.objects.filter(agent__user=user).select_related("user", "agent__user", "wallet")
    if status:
        qs = qs.filter(status=status)
    return list(qs)


def get_transaction_detail(*, transaction_id: str, user: User) -> PhysicalTransaction:
    """Get a single transaction, validating the user is a party to it."""
    try:
        txn = PhysicalTransaction.objects.select_related("user", "agent__user", "wallet").get(pk=transaction_id)
    except PhysicalTransaction.DoesNotExist:
        raise ValueError("Transaction not found.")

    if txn.user_id != user.pk and txn.agent.user_id != user.pk:
        raise ValueError("Transaction not found.")

    return txn


@transaction.atomic
def accept_transaction(
    *,
    txn: PhysicalTransaction,
    user: User,
    meeting_latitude: Decimal | float | str,
    meeting_longitude: Decimal | float | str,
    meeting_description: str = "",
) -> PhysicalTransaction:
    """Agent accepts a transaction and sets the meeting point."""
    if txn.agent.user_id != user.pk:
        raise ValueError("Only the assigned agent can accept this transaction.")

    if txn.status != TransactionStatus.PENDING:
        raise ValueError("Only pending transactions can be accepted.")

    txn.status = TransactionStatus.ACCEPTED
    txn.meeting_latitude = _normalize_coordinate(meeting_latitude)
    txn.meeting_longitude = _normalize_coordinate(meeting_longitude)
    txn.meeting_description = meeting_description
    txn.save(
        update_fields=[
            "status",
            "meeting_latitude",
            "meeting_longitude",
            "meeting_description",
            "updated_at",
        ]
    )
    label = _transaction_label(txn.transaction_type)
    _notify_transaction(
        txn=txn,
        user=txn.user,
        kind=NotificationKind.TRANSACTION_STATUS,
        title="Cash Service request accepted",
        message=f"Your {label} request for {_amount_label(txn.amount)} was accepted.",
        event="accepted",
    )
    return txn


@transaction.atomic
def reject_transaction(
    *,
    txn: PhysicalTransaction,
    user: User,
    reason: str = "",
) -> PhysicalTransaction:
    """Agent rejects a transaction."""
    if txn.agent.user_id != user.pk:
        raise ValueError("Only the assigned agent can reject this transaction.")

    if txn.status != TransactionStatus.PENDING:
        raise ValueError("Only pending transactions can be rejected.")

    txn.status = TransactionStatus.REJECTED
    txn.cancellation_reason = reason
    txn.save(update_fields=["status", "cancellation_reason", "updated_at"])
    label = _transaction_label(txn.transaction_type)
    reason_text = f" Reason: {reason}" if reason else ""
    _notify_transaction(
        txn=txn,
        user=txn.user,
        kind=NotificationKind.TRANSACTION_STATUS,
        title="Cash Service request declined",
        message=f"Your {label} request for {_amount_label(txn.amount)} was declined.{reason_text}",
        event="rejected",
    )
    return txn


def confirm_transaction(
    *,
    txn: PhysicalTransaction,
    user: User,
    verification_code: str = "",
) -> PhysicalTransaction:
    """Verify the in-person handoff, then let the user confirm completion."""
    verification_error = ""
    with transaction.atomic():
        txn = (
            PhysicalTransaction.objects.select_for_update()
            .select_related("user", "agent__user", "wallet")
            .get(pk=txn.pk)
        )
        if txn.status != TransactionStatus.ACCEPTED:
            raise ValueError("Transaction must be accepted before confirmation.")

        is_user = txn.user_id == user.pk
        is_agent = txn.agent.user_id == user.pk

        if not is_user and not is_agent:
            raise ValueError("You are not a party to this transaction.")

        update_fields = ["updated_at"]

        if is_user:
            if txn.user_confirmed:
                raise ValueError("You have already confirmed this transaction.")
            if not txn.agent_confirmed:
                raise ValueError("The agent must verify your code before you can confirm completion.")
            txn.user_confirmed = True
            update_fields.append("user_confirmed")

        if is_agent:
            if txn.agent_confirmed:
                raise ValueError("You have already verified the code.")
            if txn.verification_attempts >= 5:
                raise ValueError("Code verification is locked. Cancel this transaction and create a new request.")
            if not verification_code or not secrets.compare_digest(verification_code, txn.verification_code):
                txn.verification_attempts += 1
                update_fields.append("verification_attempts")
                attempts_left = 5 - txn.verification_attempts
                verification_error = (
                    "The code is incorrect. " f"{attempts_left} attempt{'s' if attempts_left != 1 else ''} remaining."
                )
            else:
                txn.agent_confirmed = True
                update_fields.append("agent_confirmed")

        if txn.user_confirmed and txn.agent_confirmed:
            txn.status = TransactionStatus.COMPLETED
            txn.completed_at = timezone.now()
            update_fields.extend(["status", "completed_at"])

        txn.save(update_fields=update_fields)

    if verification_error:
        raise ValueError(verification_error)
    if txn.status == TransactionStatus.COMPLETED:
        label = _transaction_label(txn.transaction_type)
        _notify_transaction_parties(
            txn=txn,
            event="completed",
            title="Cash Service completed",
            user_message=f"Your {label} for {_amount_label(txn.amount)} is complete.",
            agent_message=f"The {label} for {_amount_label(txn.amount)} is complete.",
        )
    return txn


@transaction.atomic
def cancel_transaction(
    *,
    txn: PhysicalTransaction,
    user: User,
    reason: str = "",
) -> PhysicalTransaction:
    """Cancel a transaction. Either party can cancel if not yet completed."""
    if txn.status not in (TransactionStatus.PENDING, TransactionStatus.ACCEPTED):
        raise ValueError("This transaction can no longer be cancelled.")

    is_user = txn.user_id == user.pk
    is_agent = txn.agent.user_id == user.pk

    if not is_user and not is_agent:
        raise ValueError("You are not a party to this transaction.")

    txn.status = TransactionStatus.CANCELLED
    txn.cancelled_by = user
    txn.cancellation_reason = reason
    txn.save(update_fields=["status", "cancelled_by", "cancellation_reason", "updated_at"])
    label = _transaction_label(txn.transaction_type)
    actor_name = _display_user_name(user)
    _notify_transaction_parties(
        txn=txn,
        event="cancelled",
        title="Cash Service cancelled",
        user_message=(
            f"You cancelled the {label} request for {_amount_label(txn.amount)}."
            if is_user
            else f"{actor_name} cancelled the {label} request for {_amount_label(txn.amount)}."
        ),
        agent_message=(
            f"You cancelled the {label} request for {_amount_label(txn.amount)}."
            if is_agent
            else f"{actor_name} cancelled the {label} request for {_amount_label(txn.amount)}."
        ),
    )
    return txn
