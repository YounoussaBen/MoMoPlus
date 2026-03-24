"""Celery periodic tasks for loan lifecycle management."""

import logging

from celery import shared_task

logger = logging.getLogger(__name__)


@shared_task(name="loans.apply_penalties")
def apply_penalties_task() -> str:
    from .services import apply_penalties

    count = apply_penalties()
    return f"Applied penalties to {count} loans."


@shared_task(name="loans.flag_defaulted_loans")
def flag_defaulted_loans_task() -> str:
    from .services import flag_defaulted_loans

    count = flag_defaulted_loans()
    return f"Flagged {count} loans as defaulted."
