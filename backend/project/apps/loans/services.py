from __future__ import annotations

import logging
import uuid
from datetime import timedelta
from decimal import ROUND_HALF_UP, Decimal

from django.db import transaction
from django.utils import timezone

from project.apps.accounts.models import User
from project.apps.agents.models import AgentProfile
from project.apps.wallets.models import Wallet
from project.integrations import paystack

from .models import Loan, LoanPayment, LoanStatus, PaymentStatus, PaymentType

logger = logging.getLogger(__name__)

DEFAULT_INTEREST_RATE = Decimal("10.00")  # 10%
PENALTY_RATE = Decimal("2.00")  # 2% per penalty cycle
PENALTY_INTERVAL_HOURS = 12
DEFAULT_DEADLINE_HOURS = 24
SATURDAY_DEADLINE_HOURS = 48
DEFAULT_DAYS = 7


def _generate_reference(prefix: str = "MP") -> str:
    return f"{prefix}_{uuid.uuid4().hex[:16]}"


def _pesewas(amount: Decimal) -> int:
    """Convert GHS decimal to pesewas integer."""
    return int((amount * 100).quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def _compute_deadline() -> tuple[timedelta, int]:
    """Return (deadline timedelta, hours) based on current day."""
    now = timezone.now()
    # Saturday = 5 in Python's weekday()
    hours = SATURDAY_DEADLINE_HOURS if now.weekday() == 5 else DEFAULT_DEADLINE_HOURS
    return timedelta(hours=hours), hours


# ── Loan Request ─────────────────────────────────────────────────────────────


@transaction.atomic
def request_loan(
    *,
    borrower: User,
    agent_profile_id: str,
    amount: Decimal,
    wallet_id: str,
    network: str,
) -> Loan:
    """User requests an emergency loan from an agent."""
    try:
        agent = AgentProfile.objects.select_related("user").get(pk=agent_profile_id)
    except AgentProfile.DoesNotExist:
        raise ValueError("Agent not found.")

    if not agent.is_available:
        raise ValueError("This agent is not currently available.")

    if agent.user_id == borrower.pk:
        raise ValueError("You cannot request a loan from yourself.")

    # Validate amount against agent limits
    if agent.min_amount and amount < agent.min_amount:
        raise ValueError(f"Minimum loan amount for this agent is GHS {agent.min_amount}.")
    if agent.max_amount and amount > agent.max_amount:
        raise ValueError(f"Maximum loan amount for this agent is GHS {agent.max_amount}.")

    try:
        wallet = Wallet.objects.get(pk=wallet_id, user=borrower)
    except Wallet.DoesNotExist:
        raise ValueError("Wallet not found.")

    if not wallet.is_verified:
        raise ValueError("Only verified wallets can receive loan disbursements.")

    if not wallet.paystack_subaccount_code:
        raise ValueError("This wallet is not yet set up for payments. Please re-verify.")

    # Check for existing pending/active loan with same agent
    if Loan.objects.filter(
        borrower=borrower,
        agent=agent,
        status__in=[LoanStatus.PENDING, LoanStatus.APPROVED, LoanStatus.DISBURSING, LoanStatus.ACTIVE],
    ).exists():
        raise ValueError("You already have an active loan with this agent.")

    interest = (amount * DEFAULT_INTEREST_RATE / 100).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    total = amount + interest

    return Loan.objects.create(
        borrower=borrower,
        agent=agent,
        amount=amount,
        interest_rate=DEFAULT_INTEREST_RATE,
        total_repayment=total,
        outstanding_balance=total,
        borrower_wallet=wallet,
        network=network,
        status=LoanStatus.PENDING,
    )


# ── Agent Actions ────────────────────────────────────────────────────────────


@transaction.atomic
def accept_loan(
    *,
    loan: Loan,
    agent_user: User,
    agent_wallet_id: str,
) -> Loan:
    """Agent accepts a loan request and selects their wallet for funding."""
    if loan.agent.user_id != agent_user.pk:
        raise ValueError("Only the assigned agent can accept this loan.")

    if loan.status != LoanStatus.PENDING:
        raise ValueError("Only pending loans can be accepted.")

    try:
        agent_wallet = Wallet.objects.get(pk=agent_wallet_id, user=agent_user)
    except Wallet.DoesNotExist:
        raise ValueError("Agent wallet not found.")

    if not agent_wallet.is_verified:
        raise ValueError("Agent wallet must be verified.")

    if not agent_wallet.paystack_subaccount_code:
        raise ValueError("Agent wallet is not set up for payments.")

    loan.agent_wallet = agent_wallet
    loan.status = LoanStatus.APPROVED
    loan.approved_at = timezone.now()
    loan.save(update_fields=["agent_wallet", "status", "approved_at", "updated_at"])
    return loan


@transaction.atomic
def reject_loan(
    *,
    loan: Loan,
    agent_user: User,
    reason: str = "",
) -> Loan:
    """Agent rejects a loan request."""
    if loan.agent.user_id != agent_user.pk:
        raise ValueError("Only the assigned agent can reject this loan.")

    if loan.status != LoanStatus.PENDING:
        raise ValueError("Only pending loans can be rejected.")

    loan.status = LoanStatus.REJECTED
    loan.rejection_reason = reason
    loan.save(update_fields=["status", "rejection_reason", "updated_at"])
    return loan


@transaction.atomic
def cancel_loan(
    *,
    loan: Loan,
    user: User,
    reason: str = "",
) -> Loan:
    """Cancel a loan (by borrower before disbursement, or by agent)."""
    if loan.status not in (LoanStatus.PENDING, LoanStatus.APPROVED):
        raise ValueError("This loan can no longer be cancelled.")

    is_borrower = loan.borrower_id == user.pk
    is_agent = loan.agent.user_id == user.pk
    if not is_borrower and not is_agent:
        raise ValueError("You are not a party to this loan.")

    loan.status = LoanStatus.CANCELLED
    loan.cancelled_by = user
    loan.rejection_reason = reason
    loan.save(update_fields=["status", "cancelled_by", "rejection_reason", "updated_at"])
    return loan


# ── Disbursement ─────────────────────────────────────────────────────────────


def initiate_disbursement(*, loan: Loan) -> LoanPayment:
    """Charge the agent's MoMo to disburse funds to the borrower's wallet.

    The agent's MoMo is charged, and the money is routed to the borrower's
    subaccount (their verified wallet).
    """
    if loan.status != LoanStatus.APPROVED:
        raise ValueError("Loan must be approved before disbursement.")

    if not loan.agent_wallet:
        raise ValueError("Agent wallet not set.")

    agent_wallet = loan.agent_wallet
    borrower_wallet = loan.borrower_wallet
    agent_user = loan.agent.user

    provider = paystack.NETWORK_TO_PROVIDER.get(agent_wallet.network, "mtn")
    reference = _generate_reference("DISB")

    # Create payment record and update loan status atomically
    with transaction.atomic():
        payment = LoanPayment.objects.create(
            loan=loan,
            payment_type=PaymentType.DISBURSEMENT,
            amount=loan.amount,
            reference=reference,
            payer_phone=agent_wallet.phone_number,
            payer_network=agent_wallet.network,
            recipient_subaccount=borrower_wallet.paystack_subaccount_code,
        )
        loan.status = LoanStatus.DISBURSING
        loan.save(update_fields=["status", "updated_at"])

    # Call Paystack outside the atomic block so failure handling persists
    try:
        resp = paystack.charge_mobile_money(
            email=agent_user.email,
            amount_pesewas=_pesewas(loan.amount),
            phone=agent_wallet.phone_number,
            provider=provider,
            reference=reference,
            subaccount_code=borrower_wallet.paystack_subaccount_code,
            metadata={
                "loan_id": str(loan.pk),
                "payment_type": "disbursement",
                "borrower_id": str(loan.borrower_id),
            },
        )
        payment.paystack_reference = resp.get("reference", "")
        payment.paystack_response = resp
        payment.save(update_fields=["paystack_reference", "paystack_response", "updated_at"])
    except paystack.PaystackError as exc:
        payment.status = PaymentStatus.FAILED
        payment.paystack_response = {"error": str(exc)}
        payment.save(update_fields=["status", "paystack_response", "updated_at"])
        loan.status = LoanStatus.FAILED
        loan.save(update_fields=["status", "updated_at"])
        raise ValueError(f"Disbursement failed: {exc}")

    return payment


# ── Repayment ────────────────────────────────────────────────────────────────


def initiate_repayment(*, loan: Loan, amount: Decimal | None = None) -> LoanPayment:
    """Charge the borrower's MoMo to repay the loan to the agent's subaccount."""
    if loan.status not in (LoanStatus.ACTIVE, LoanStatus.REPAYING):
        raise ValueError("Loan is not active.")

    if not loan.agent_wallet:
        raise ValueError("Agent wallet not configured for this loan.")

    repay_amount = amount or loan.outstanding_balance
    if repay_amount <= 0:
        raise ValueError("Nothing to repay.")
    if repay_amount > loan.outstanding_balance:
        raise ValueError(f"Amount exceeds outstanding balance of GHS {loan.outstanding_balance}.")

    borrower_wallet = loan.borrower_wallet
    agent_wallet = loan.agent_wallet
    provider = paystack.NETWORK_TO_PROVIDER.get(borrower_wallet.network, "mtn")
    reference = _generate_reference("REPAY")

    with transaction.atomic():
        payment = LoanPayment.objects.create(
            loan=loan,
            payment_type=PaymentType.REPAYMENT,
            amount=repay_amount,
            reference=reference,
            payer_phone=borrower_wallet.phone_number,
            payer_network=borrower_wallet.network,
            recipient_subaccount=agent_wallet.paystack_subaccount_code,
        )
        loan.status = LoanStatus.REPAYING
        loan.save(update_fields=["status", "updated_at"])

    try:
        resp = paystack.charge_mobile_money(
            email=loan.borrower.email,
            amount_pesewas=_pesewas(repay_amount),
            phone=borrower_wallet.phone_number,
            provider=provider,
            reference=reference,
            subaccount_code=agent_wallet.paystack_subaccount_code,
            metadata={
                "loan_id": str(loan.pk),
                "payment_type": "repayment",
                "agent_id": str(loan.agent_id),
            },
        )
        payment.paystack_reference = resp.get("reference", "")
        payment.paystack_response = resp
        payment.save(update_fields=["paystack_reference", "paystack_response", "updated_at"])
    except paystack.PaystackError as exc:
        payment.status = PaymentStatus.FAILED
        payment.paystack_response = {"error": str(exc)}
        payment.save(update_fields=["status", "paystack_response", "updated_at"])
        loan.status = LoanStatus.ACTIVE
        loan.save(update_fields=["status", "updated_at"])
        raise ValueError(f"Repayment initiation failed: {exc}")

    return payment


# ── Webhook Handlers ─────────────────────────────────────────────────────────


@transaction.atomic
def handle_charge_success(*, reference: str, paystack_data: dict) -> None:
    """Handle a successful charge (disbursement or repayment confirmed)."""
    try:
        payment = LoanPayment.objects.select_related("loan").get(reference=reference)
    except LoanPayment.DoesNotExist:
        logger.warning("Charge success webhook for unknown reference: %s", reference)
        return

    if payment.status == PaymentStatus.SUCCESS:
        logger.info("Payment %s already marked success, skipping.", reference)
        return

    payment.status = PaymentStatus.SUCCESS
    payment.paystack_response = paystack_data
    payment.completed_at = timezone.now()
    payment.save(update_fields=["status", "paystack_response", "completed_at", "updated_at"])

    loan = payment.loan

    if payment.payment_type == PaymentType.DISBURSEMENT:
        _handle_disbursement_success(loan)
    elif payment.payment_type == PaymentType.REPAYMENT:
        _handle_repayment_success(loan, payment)


def _handle_disbursement_success(loan: Loan) -> None:
    """Activate loan after successful disbursement."""
    deadline_delta, _ = _compute_deadline()
    now = timezone.now()

    loan.status = LoanStatus.ACTIVE
    loan.disbursed_at = now
    loan.deadline_at = now + deadline_delta
    loan.save(update_fields=["status", "disbursed_at", "deadline_at", "updated_at"])
    logger.info("Loan %s activated, deadline at %s", loan.pk, loan.deadline_at)


def _handle_repayment_success(loan: Loan, payment: LoanPayment) -> None:
    """Reduce outstanding balance and close loan if fully repaid."""
    loan.outstanding_balance -= payment.amount
    if loan.outstanding_balance <= 0:
        loan.outstanding_balance = Decimal("0.00")
        loan.status = LoanStatus.COMPLETED
        loan.completed_at = timezone.now()
        logger.info("Loan %s fully repaid and closed.", loan.pk)
    else:
        loan.status = LoanStatus.ACTIVE
        logger.info("Loan %s partial repayment, remaining: %s", loan.pk, loan.outstanding_balance)

    loan.save(update_fields=["outstanding_balance", "status", "completed_at", "updated_at"])


@transaction.atomic
def handle_charge_failed(*, reference: str, paystack_data: dict) -> None:
    """Handle a failed charge."""
    try:
        payment = LoanPayment.objects.select_related("loan").get(reference=reference)
    except LoanPayment.DoesNotExist:
        logger.warning("Charge failed webhook for unknown reference: %s", reference)
        return

    payment.status = PaymentStatus.FAILED
    payment.paystack_response = paystack_data
    payment.save(update_fields=["status", "paystack_response", "updated_at"])

    loan = payment.loan

    if payment.payment_type == PaymentType.DISBURSEMENT:
        loan.status = LoanStatus.FAILED
        loan.save(update_fields=["status", "updated_at"])
    elif payment.payment_type == PaymentType.REPAYMENT:
        loan.status = LoanStatus.ACTIVE
        loan.save(update_fields=["status", "updated_at"])


# ── Penalties & Defaults ─────────────────────────────────────────────────────


def apply_penalties() -> int:
    """Apply penalties to overdue active loans. Returns count of penalised loans."""
    now = timezone.now()
    overdue_loans = Loan.objects.filter(
        status=LoanStatus.ACTIVE,
        deadline_at__lt=now,
    )

    count = 0
    for loan in overdue_loans:
        # Check if enough time has passed since last penalty
        last = loan.last_penalty_at or loan.deadline_at
        if not last:
            continue
        hours_since = (now - last).total_seconds() / 3600
        if hours_since < PENALTY_INTERVAL_HOURS:
            continue

        penalty = (loan.amount * PENALTY_RATE / 100).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
        loan.penalty_amount += penalty
        loan.outstanding_balance += penalty
        loan.total_repayment += penalty
        loan.last_penalty_at = now
        loan.save(
            update_fields=[
                "penalty_amount",
                "outstanding_balance",
                "total_repayment",
                "last_penalty_at",
                "updated_at",
            ]
        )
        count += 1
        logger.info("Penalty of %s applied to loan %s", penalty, loan.pk)

    return count


def flag_defaulted_loans() -> int:
    """Flag loans as defaulted after 7 days past deadline."""
    now = timezone.now()
    threshold = now - timedelta(days=DEFAULT_DAYS)
    updated = Loan.objects.filter(
        status=LoanStatus.ACTIVE,
        deadline_at__lt=threshold,
    ).update(status=LoanStatus.DEFAULTED, defaulted_at=now, updated_at=now)
    if updated:
        logger.info("Flagged %d loans as defaulted.", updated)
    return updated


# ── Query Helpers ────────────────────────────────────────────────────────────


def get_borrower_loans(*, user: User, status: str | None = None) -> list[Loan]:
    qs = Loan.objects.filter(borrower=user).select_related("agent__user", "borrower_wallet", "agent_wallet")
    if status:
        qs = qs.filter(status=status)
    return list(qs)


def get_agent_loans(*, user: User, status: str | None = None) -> list[Loan]:
    qs = Loan.objects.filter(agent__user=user).select_related(
        "borrower", "borrower_wallet", "agent_wallet", "agent__user"
    )
    if status:
        qs = qs.filter(status=status)
    return list(qs)


def get_loan_detail(*, loan_id: str, user: User) -> Loan:
    try:
        loan = Loan.objects.select_related("borrower", "agent__user", "borrower_wallet", "agent_wallet").get(
            pk=loan_id
        )
    except Loan.DoesNotExist:
        raise ValueError("Loan not found.")

    if loan.borrower_id != user.pk and loan.agent.user_id != user.pk:
        raise ValueError("Loan not found.")

    return loan
