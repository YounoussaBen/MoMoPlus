from __future__ import annotations

import logging
import uuid
from datetime import date, timedelta
from decimal import ROUND_HALF_UP, Decimal

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from project.apps.accounts.models import User
from project.apps.agents.models import AgentProfile
from project.apps.wallets.models import Wallet
from project.integrations import paystack

from .models import Loan, LoanPayment, LoanStatus, PaymentStatus, PaymentType

logger = logging.getLogger(__name__)

DEFAULT_INTEREST_RATE = Decimal("10.00")
DEFAULT_PAYSTACK_CHARGE_PERCENT = Decimal("1.95")
DEFAULT_PAYSTACK_CHARGE_FIXED = Decimal("0.00")
DEFAULT_PAYSTACK_TRANSFER_FEE = Decimal("1.00")
PENALTY_RATE = Decimal("2.00")  # 2% per penalty cycle
PENALTY_INTERVAL_HOURS = 12
DEFAULT_DEADLINE_HOURS = 24
SATURDAY_DEADLINE_HOURS = 48
DEFAULT_DAYS = 7
MONEY_QUANTUM = Decimal("0.01")
HUNDRED = Decimal("100")


def _generate_reference(prefix: str = "MP") -> str:
    return f"{prefix}_{uuid.uuid4().hex[:16]}"


def _pesewas(amount: Decimal) -> int:
    """Convert GHS decimal to pesewas integer."""
    return int((amount * 100).quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def _money(amount: Decimal, *, rounding: str = ROUND_HALF_UP) -> Decimal:
    return amount.quantize(MONEY_QUANTUM, rounding=rounding)


def _setting_decimal(name: str, default: str) -> Decimal:
    return Decimal(str(getattr(settings, name, default)))


def _interest_rate() -> Decimal:
    return _setting_decimal("LOAN_DEFAULT_INTEREST_RATE", str(DEFAULT_INTEREST_RATE))


def _agent_interest_rate() -> Decimal:
    return _setting_decimal("LOAN_AGENT_INTEREST_RATE", "5.00")


def _charge_fee_rate() -> Decimal:
    return DEFAULT_PAYSTACK_CHARGE_PERCENT


def _charge_fixed_fee() -> Decimal:
    return _money(DEFAULT_PAYSTACK_CHARGE_FIXED)


def _transfer_fee() -> Decimal:
    return _money(DEFAULT_PAYSTACK_TRANSFER_FEE)


def _percentage_of(amount: Decimal, rate: Decimal) -> Decimal:
    return _money(amount * rate / HUNDRED)


def _charge_fee_for(amount: Decimal) -> Decimal:
    percentage_fee = _percentage_of(amount, _charge_fee_rate())
    return _money(percentage_fee + _charge_fixed_fee())


def _loan_pricing(amount: Decimal) -> dict[str, Decimal]:
    interest_rate = _interest_rate()
    total_interest = _percentage_of(amount, interest_rate)
    agent_interest_amount = _percentage_of(amount, _agent_interest_rate())
    if agent_interest_amount > total_interest:
        raise ValueError("Loan pricing configuration is invalid.")
    platform_interest_amount = _money(total_interest - agent_interest_amount)
    total_repayment = amount + agent_interest_amount + platform_interest_amount
    agent_receivable_balance = amount + agent_interest_amount
    return {
        "interest_rate": interest_rate,
        "origination_fee": Decimal("0.00"),
        "agent_interest_amount": agent_interest_amount,
        "platform_interest_amount": platform_interest_amount,
        "total_repayment": _money(total_repayment),
        "agent_receivable_balance": _money(agent_receivable_balance),
    }


def _transfer_fee_for(transfer_amount: Decimal) -> Decimal:
    return _transfer_fee() if transfer_amount > 0 else Decimal("0.00")


def _required_transfer_balance(transfer_amount: Decimal) -> Decimal:
    return _money(transfer_amount + _transfer_fee_for(transfer_amount))


def _disbursement_transfer_amount(charge_amount: Decimal) -> Decimal:
    net_amount = _money(charge_amount - _charge_fee_for(charge_amount) - _transfer_fee())
    if net_amount <= 0:
        raise ValueError("Loan amount is too small after Paystack fees.")
    return net_amount


def _balance_from_subunit(value: object) -> Decimal:
    return _money(Decimal(str(value)) / HUNDRED)


def _get_available_balance(currency: str = "GHS") -> Decimal | None:
    balances = paystack.get_balances()
    for entry in balances:
        if str(entry.get("currency", "")).upper() != currency.upper():
            continue
        if "available_balance" in entry:
            return _balance_from_subunit(entry["available_balance"])
        if "balance" in entry:
            return _balance_from_subunit(entry["balance"])
    return None


def _repayment_breakdown(*, loan: Loan) -> tuple[Decimal, Decimal]:
    agent_receivable_balance = loan.agent_receivable_balance or loan.outstanding_balance
    return _money(agent_receivable_balance), _money(loan.outstanding_balance - agent_receivable_balance)


def _merge_paystack_response(existing: dict | None, *, stage: str, data: dict) -> dict:
    payload = existing.copy() if isinstance(existing, dict) else {}
    payload[stage] = data
    return payload


def _paystack_error_payload(exc: paystack.PaystackError) -> dict:
    payload: dict = {"error": str(exc)}
    if exc.response:
        payload["response"] = exc.response
    return payload


def _recipient_details(payment: LoanPayment) -> tuple[str, str, str]:
    loan = payment.loan
    if payment.payment_type == PaymentType.DISBURSEMENT:
        recipient_code = loan.borrower_wallet.paystack_recipient_code
        return recipient_code, str(LoanStatus.FAILED), f"Loan disbursement {loan.pk}"

    recipient_code = loan.agent_wallet.paystack_recipient_code if loan.agent_wallet else ""
    return recipient_code, str(LoanStatus.REPAYING), f"Loan repayment {loan.pk}"


def _complete_payment_success(payment: LoanPayment, *, paystack_data: dict) -> None:
    payment.status = PaymentStatus.SUCCESS
    payment.paystack_response = _merge_paystack_response(
        payment.paystack_response, stage="transfer", data=paystack_data
    )
    payment.completed_at = timezone.now()
    payment.save(update_fields=["status", "paystack_response", "completed_at", "updated_at"])

    if payment.payment_type == PaymentType.DISBURSEMENT:
        _handle_disbursement_success(payment.loan)
    elif payment.payment_type == PaymentType.REPAYMENT:
        _handle_repayment_success(payment.loan, payment)


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

    if not wallet.paystack_recipient_code:
        raise ValueError("This wallet is not yet set up for payments. Please re-verify.")

    # Check for existing pending/active loan with same agent
    if Loan.objects.filter(
        borrower=borrower,
        agent=agent,
        status__in=[LoanStatus.PENDING, LoanStatus.APPROVED, LoanStatus.DISBURSING, LoanStatus.ACTIVE],
    ).exists():
        raise ValueError("You already have an active loan with this agent.")

    pricing = _loan_pricing(amount)

    return Loan.objects.create(
        borrower=borrower,
        agent=agent,
        amount=amount,
        interest_rate=pricing["interest_rate"],
        origination_fee=pricing["origination_fee"],
        agent_interest_amount=pricing["agent_interest_amount"],
        platform_interest_amount=pricing["platform_interest_amount"],
        total_repayment=pricing["total_repayment"],
        outstanding_balance=pricing["total_repayment"],
        agent_receivable_balance=pricing["agent_receivable_balance"],
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

    if not agent_wallet.paystack_recipient_code:
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
    """Charge the agent's MoMo, then disburse from the business balance."""
    if loan.status != LoanStatus.APPROVED:
        raise ValueError("Loan must be approved before disbursement.")

    if not loan.agent_wallet:
        raise ValueError("Agent wallet not set.")

    agent_wallet = loan.agent_wallet
    borrower_wallet = loan.borrower_wallet

    if not borrower_wallet.paystack_recipient_code:
        raise ValueError("Borrower wallet is not set up to receive transfers. Please re-verify it.")

    paystack_wallet = paystack.mobile_money_details(
        phone=agent_wallet.phone_number,
        network=agent_wallet.network,
    )
    reference = _generate_reference("DISB")
    charge_amount = _money(loan.amount)
    transfer_amount = _disbursement_transfer_amount(charge_amount)
    platform_amount = Decimal("0.00")

    # Create payment record and update loan status atomically
    with transaction.atomic():
        payment = LoanPayment.objects.create(
            loan=loan,
            payment_type=PaymentType.DISBURSEMENT,
            amount=loan.amount,
            charge_amount=charge_amount,
            transfer_amount=transfer_amount,
            platform_amount=platform_amount,
            reference=reference,
            payer_phone=agent_wallet.phone_number,
            payer_network=agent_wallet.network,
            # Keep the payout target on the existing audit field until the model is expanded.
            recipient_code=borrower_wallet.paystack_recipient_code,
        )
        loan.status = LoanStatus.DISBURSING
        loan.save(update_fields=["status", "updated_at"])

    # Call Paystack outside the atomic block so failure handling persists
    try:
        resp = paystack.charge_mobile_money(
            amount_pesewas=_pesewas(payment.charge_amount),
            phone=paystack_wallet.phone,
            provider=paystack_wallet.provider,
            reference=reference,
            metadata={
                "loan_id": str(loan.pk),
                "payment_type": "disbursement",
                "borrower_id": str(loan.borrower_id),
                "payer_phone": payment.payer_phone,
                "payer_network": payment.payer_network,
                "principal_amount": str(payment.amount),
                "charge_amount": str(payment.charge_amount),
                "transfer_amount": str(payment.transfer_amount),
                "platform_amount": str(payment.platform_amount),
            },
        )
        payment.paystack_reference = resp.get("reference", "")
        payment.paystack_response = _merge_paystack_response(payment.paystack_response, stage="charge_init", data=resp)
        payment.save(update_fields=["paystack_reference", "paystack_response", "updated_at"])
    except paystack.PaystackError as exc:
        payment.status = PaymentStatus.FAILED
        payment.paystack_response = _paystack_error_payload(exc)
        payment.save(update_fields=["status", "paystack_response", "updated_at"])
        loan.status = LoanStatus.FAILED
        loan.save(update_fields=["status", "updated_at"])
        raise ValueError(f"Disbursement failed: {exc}")

    return payment


# ── Repayment ────────────────────────────────────────────────────────────────


def initiate_repayment(*, loan: Loan, amount: Decimal | None = None) -> LoanPayment:
    """Charge the borrower's MoMo, then transfer the repayment to the agent."""
    if loan.status != LoanStatus.ACTIVE:
        raise ValueError("Loan is not ready for repayment.")

    if not loan.agent_wallet:
        raise ValueError("Agent wallet not configured for this loan.")

    if amount is not None and _money(amount) != loan.outstanding_balance:
        raise ValueError("Partial repayment is not supported. The borrower must repay the full outstanding balance.")

    repay_amount = _money(loan.outstanding_balance)
    if repay_amount <= 0:
        raise ValueError("Nothing to repay.")
    if repay_amount > loan.outstanding_balance:
        raise ValueError(f"Amount exceeds outstanding balance of GHS {loan.outstanding_balance}.")

    borrower_wallet = loan.borrower_wallet
    agent_wallet = loan.agent_wallet
    if not agent_wallet.paystack_recipient_code:
        raise ValueError("Agent wallet is not set up to receive transfers. Please re-verify it.")

    paystack_wallet = paystack.mobile_money_details(
        phone=borrower_wallet.phone_number,
        network=borrower_wallet.network,
    )
    reference = _generate_reference("REPAY")
    transfer_amount, platform_amount = _repayment_breakdown(loan=loan)
    charge_amount = repay_amount

    with transaction.atomic():
        payment = LoanPayment.objects.create(
            loan=loan,
            payment_type=PaymentType.REPAYMENT,
            amount=repay_amount,
            charge_amount=charge_amount,
            transfer_amount=transfer_amount,
            platform_amount=platform_amount,
            reference=reference,
            payer_phone=borrower_wallet.phone_number,
            payer_network=borrower_wallet.network,
            # Keep the payout target on the existing audit field until the model is expanded.
            recipient_code=agent_wallet.paystack_recipient_code,
        )
        loan.status = LoanStatus.REPAYING
        loan.save(update_fields=["status", "updated_at"])

    try:
        resp = paystack.charge_mobile_money(
            amount_pesewas=_pesewas(payment.charge_amount),
            phone=paystack_wallet.phone,
            provider=paystack_wallet.provider,
            reference=reference,
            metadata={
                "loan_id": str(loan.pk),
                "payment_type": "repayment",
                "agent_id": str(loan.agent_id),
                "payer_phone": payment.payer_phone,
                "payer_network": payment.payer_network,
                "repayment_amount": str(payment.amount),
                "charge_amount": str(payment.charge_amount),
                "transfer_amount": str(payment.transfer_amount),
                "platform_amount": str(payment.platform_amount),
            },
        )
        payment.paystack_reference = resp.get("reference", "")
        payment.paystack_response = _merge_paystack_response(payment.paystack_response, stage="charge_init", data=resp)
        payment.save(update_fields=["paystack_reference", "paystack_response", "updated_at"])
    except paystack.PaystackError as exc:
        payment.status = PaymentStatus.FAILED
        payment.paystack_response = _paystack_error_payload(exc)
        payment.save(update_fields=["status", "paystack_response", "updated_at"])
        loan.status = LoanStatus.ACTIVE
        loan.save(update_fields=["status", "updated_at"])
        raise ValueError(f"Repayment initiation failed: {exc}")

    return payment


# ── Webhook Handlers ─────────────────────────────────────────────────────────


@transaction.atomic
def handle_charge_success(*, reference: str, paystack_data: dict) -> None:
    """Handle a successful charge webhook."""
    try:
        payment = LoanPayment.objects.select_related(
            "loan",
            "loan__borrower_wallet",
            "loan__agent_wallet",
        ).get(reference=reference)
    except LoanPayment.DoesNotExist:
        logger.warning("Charge success webhook for unknown reference: %s", reference)
        return

    payment.paystack_response = _merge_paystack_response(payment.paystack_response, stage="charge", data=paystack_data)

    if payment.payment_type in (PaymentType.DISBURSEMENT, PaymentType.REPAYMENT):
        if payment.status == PaymentStatus.SUCCESS:
            logger.info("Payment %s already completed, skipping duplicate charge.success.", reference)
            return

        if payment.paystack_reference and payment.paystack_reference != reference:
            payment.save(update_fields=["paystack_response", "updated_at"])
            logger.info("Transfer already initiated for payment %s, skipping duplicate charge.success.", reference)
            return

        loan = payment.loan
        recipient_code, failure_status, reason = _recipient_details(payment)
        if not recipient_code:
            payment.status = PaymentStatus.FAILED
            payment.paystack_response = _merge_paystack_response(
                payment.paystack_response,
                stage="transfer_error",
                data={"error": "Payment recipient has no Paystack transfer recipient code."},
            )
            payment.save(update_fields=["status", "paystack_response", "updated_at"])
            loan.status = failure_status
            loan.save(update_fields=["status", "updated_at"])
            logger.error("Payment %s cannot continue: recipient wallet has no transfer recipient code.", reference)
            return

        try:
            available_balance = _get_available_balance()
        except paystack.PaystackError as exc:
            logger.warning("Unable to fetch Paystack balance before transfer for %s: %s", reference, exc)
            available_balance = None

        required_balance = _required_transfer_balance(payment.transfer_amount)
        if available_balance is not None and available_balance < required_balance:
            error_payload = {
                "error": (
                    f"Paystack balance is too low for transfer. "
                    f"Need GHS {required_balance}, available GHS {available_balance}."
                )
            }
            payment.status = PaymentStatus.FAILED
            payment.paystack_response = _merge_paystack_response(
                payment.paystack_response,
                stage="transfer_error",
                data=error_payload,
            )
            payment.save(update_fields=["status", "paystack_response", "updated_at"])
            loan.status = failure_status
            loan.save(update_fields=["status", "updated_at"])
            logger.error("Transfer for payment %s blocked by insufficient Paystack balance.", reference)
            return

        transfer_reference = _generate_reference("TRF")
        try:
            transfer_resp = paystack.initiate_transfer(
                amount_pesewas=_pesewas(payment.transfer_amount),
                recipient_code=recipient_code,
                reference=transfer_reference,
                reason=reason,
            )
        except paystack.PaystackError as exc:
            payment.status = PaymentStatus.FAILED
            payment.paystack_response = _merge_paystack_response(
                payment.paystack_response,
                stage="transfer_error",
                data=_paystack_error_payload(exc),
            )
            payment.save(update_fields=["status", "paystack_response", "updated_at"])
            loan.status = failure_status
            loan.save(update_fields=["status", "updated_at"])
            logger.exception("Transfer initiation failed for payment %s", reference)
            return

        payment.paystack_reference = transfer_resp.get("reference", transfer_reference)
        payment.paystack_response = _merge_paystack_response(
            payment.paystack_response,
            stage="transfer_init",
            data=transfer_resp,
        )
        payment.save(update_fields=["paystack_reference", "paystack_response", "updated_at"])
        logger.info("Transfer initiated for payment %s with reference %s", reference, payment.paystack_reference)
        return

    if payment.status == PaymentStatus.SUCCESS:
        logger.info("Payment %s already marked success, skipping.", reference)
        return

    payment.status = PaymentStatus.SUCCESS
    payment.completed_at = timezone.now()
    payment.save(update_fields=["status", "paystack_response", "completed_at", "updated_at"])


@transaction.atomic
def handle_transfer_success(*, reference: str, paystack_data: dict) -> None:
    """Handle a successful transfer webhook for a payment."""
    try:
        payment = LoanPayment.objects.select_related("loan").get(
            paystack_reference=reference,
        )
    except LoanPayment.DoesNotExist:
        logger.warning("Transfer success webhook for unknown reference: %s", reference)
        return

    if payment.status == PaymentStatus.SUCCESS:
        logger.info("Transfer %s already marked success, skipping.", reference)
        return

    _complete_payment_success(payment, paystack_data=paystack_data)


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
    loan.outstanding_balance = _money(loan.outstanding_balance - payment.amount)
    loan.agent_receivable_balance = _money(loan.agent_receivable_balance - payment.transfer_amount)
    if loan.agent_receivable_balance < 0:
        loan.agent_receivable_balance = Decimal("0.00")
    if loan.outstanding_balance <= 0:
        loan.outstanding_balance = Decimal("0.00")
        loan.agent_receivable_balance = Decimal("0.00")
        loan.status = LoanStatus.COMPLETED
        loan.completed_at = timezone.now()
        logger.info("Loan %s fully repaid and closed.", loan.pk)
    else:
        loan.status = LoanStatus.ACTIVE
        logger.info("Loan %s partial repayment, remaining: %s", loan.pk, loan.outstanding_balance)

    loan.save(
        update_fields=["outstanding_balance", "agent_receivable_balance", "status", "completed_at", "updated_at"]
    )


@transaction.atomic
def handle_charge_failed(*, reference: str, paystack_data: dict) -> None:
    """Handle a failed charge."""
    try:
        payment = LoanPayment.objects.select_related("loan").get(reference=reference)
    except LoanPayment.DoesNotExist:
        logger.warning("Charge failed webhook for unknown reference: %s", reference)
        return

    payment.status = PaymentStatus.FAILED
    payment.paystack_response = _merge_paystack_response(
        payment.paystack_response, stage="charge_failed", data=paystack_data
    )
    payment.save(update_fields=["status", "paystack_response", "updated_at"])

    loan = payment.loan

    if payment.payment_type == PaymentType.DISBURSEMENT:
        loan.status = LoanStatus.FAILED
        loan.save(update_fields=["status", "updated_at"])
    elif payment.payment_type == PaymentType.REPAYMENT:
        loan.status = LoanStatus.ACTIVE
        loan.save(update_fields=["status", "updated_at"])


@transaction.atomic
def handle_transfer_failed(*, reference: str, paystack_data: dict) -> None:
    """Handle a failed transfer webhook for a payment."""
    try:
        payment = LoanPayment.objects.select_related("loan").get(
            paystack_reference=reference,
        )
    except LoanPayment.DoesNotExist:
        logger.warning("Transfer failed webhook for unknown reference: %s", reference)
        return

    payment.status = PaymentStatus.FAILED
    payment.paystack_response = _merge_paystack_response(
        payment.paystack_response, stage="transfer_failed", data=paystack_data
    )
    payment.save(update_fields=["status", "paystack_response", "updated_at"])

    loan = payment.loan
    if payment.payment_type == PaymentType.DISBURSEMENT:
        loan.status = LoanStatus.FAILED
    elif payment.payment_type == PaymentType.REPAYMENT:
        # Borrower was already charged, so keep the loan in repayment for manual resolution.
        loan.status = LoanStatus.REPAYING
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
        loan.agent_receivable_balance += penalty
        loan.total_repayment += penalty
        loan.last_penalty_at = now
        loan.save(
            update_fields=[
                "penalty_amount",
                "outstanding_balance",
                "agent_receivable_balance",
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


# ── Earnings ────────────────────────────────────────────────────────────────


def get_agent_earnings(
    *,
    user: User,
    period: str | None = None,
    start_date: date | None = None,
    end_date: date | None = None,
) -> dict:
    """Aggregate earnings for an agent from completed loans.

    ``period`` may be ``"today"``, ``"week"``, ``"month"``, or ``"custom"``
    to restrict the recent-earnings list. When ``period == "custom"``,
    ``start_date`` and ``end_date`` bound the inclusive date window.
    Aggregates are always returned for all periods regardless of the filter.
    """
    from django.db.models import Count, DecimalField, Q, Sum
    from django.db.models.functions import Coalesce

    now = timezone.now()
    today = now.date()
    # ISO week: Monday is start of week
    start_of_week = today - timedelta(days=today.weekday())

    zero = Decimal("0.00")
    decimal_field = DecimalField(max_digits=10, decimal_places=2)

    qs = Loan.objects.filter(agent__user=user, status=LoanStatus.COMPLETED)

    agg = qs.aggregate(
        total_earned=Coalesce(Sum("agent_interest_amount"), zero, output_field=decimal_field),
        total_loans_completed=Count("id"),
        today_earned=Coalesce(
            Sum("agent_interest_amount", filter=Q(completed_at__date=today)),
            zero,
            output_field=decimal_field,
        ),
        today_count=Count("id", filter=Q(completed_at__date=today)),
        this_week_earned=Coalesce(
            Sum("agent_interest_amount", filter=Q(completed_at__date__gte=start_of_week)),
            zero,
            output_field=decimal_field,
        ),
        this_week_count=Count("id", filter=Q(completed_at__date__gte=start_of_week)),
        this_month_earned=Coalesce(
            Sum(
                "agent_interest_amount",
                filter=Q(completed_at__year=now.year, completed_at__month=now.month),
            ),
            zero,
            output_field=decimal_field,
        ),
        this_month_count=Count(
            "id",
            filter=Q(completed_at__year=now.year, completed_at__month=now.month),
        ),
    )

    recent_qs = qs.select_related("borrower")
    if period == "today":
        recent_qs = recent_qs.filter(completed_at__date=today)
    elif period == "week":
        recent_qs = recent_qs.filter(completed_at__date__gte=start_of_week)
    elif period == "month":
        recent_qs = recent_qs.filter(completed_at__year=now.year, completed_at__month=now.month)
    elif period == "custom" and start_date is not None and end_date is not None:
        recent_qs = recent_qs.filter(completed_at__date__range=(start_date, end_date))

    recent = recent_qs.order_by("-completed_at")[:20].values_list(
        "id", "borrower__first_name", "borrower__last_name", "amount", "agent_interest_amount", "completed_at"
    )

    recent_earnings = [
        {
            "id": str(row[0]),
            "borrower_name": f"{row[1]} {row[2]}".strip(),
            "loan_amount": str(row[3]),
            "earned": str(row[4]),
            "completed_at": row[5].isoformat() if row[5] else None,
        }
        for row in recent
    ]

    return {**agg, "recent_earnings": recent_earnings}


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
