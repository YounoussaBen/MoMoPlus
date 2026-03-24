"""Paystack webhook handler.

Paystack sends POST requests to this endpoint for payment events.
The payload is verified using HMAC-SHA512 with the secret key.
"""

from __future__ import annotations

import json
import logging

from django.http import HttpRequest, HttpResponse, JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from project.integrations.paystack import verify_webhook_signature

from .services import (
    handle_charge_failed,
    handle_charge_success,
    handle_transfer_failed,
    handle_transfer_success,
)

logger = logging.getLogger(__name__)


@csrf_exempt
@require_POST
def paystack_webhook(request: HttpRequest) -> HttpResponse:
    """Receive and process Paystack webhook events."""
    signature = request.headers.get("X-Paystack-Signature", "")
    if not signature:
        return HttpResponse(status=400)

    if not verify_webhook_signature(payload=request.body, signature=signature):
        logger.warning("Invalid Paystack webhook signature.")
        return HttpResponse(status=400)

    try:
        payload = json.loads(request.body)
    except json.JSONDecodeError:
        return HttpResponse(status=400)

    event = payload.get("event", "")
    data = payload.get("data", {})
    reference = data.get("reference", "")

    logger.info("Paystack webhook event: %s, reference: %s", event, reference)

    if event == "charge.success":
        handle_charge_success(reference=reference, paystack_data=data)
    elif event == "charge.failed":
        handle_charge_failed(reference=reference, paystack_data=data)
    elif event == "transfer.success":
        handle_transfer_success(reference=reference, paystack_data=data)
    elif event == "transfer.failed":
        handle_transfer_failed(reference=reference, paystack_data=data)
    else:
        logger.info("Unhandled Paystack event: %s", event)

    return JsonResponse({"status": "ok"})
