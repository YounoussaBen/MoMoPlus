import socket
import time

from celery import shared_task
from django.conf import settings
from django.core.mail import send_mail
from django.utils import timezone


@shared_task
def send_welcome_email(user_email, user_name):
    """Send welcome email to new users"""
    subject = "Welcome to Project API!"
    message = f"Hello {user_name},\n\nWelcome to Project API! We're excited to have you on board."

    send_mail(
        subject,
        message,
        settings.DEFAULT_FROM_EMAIL,
        [user_email],
        fail_silently=False,
    )
    return f"Welcome email sent to {user_email}"


@shared_task
def example_long_task(seconds):
    """Example long-running task"""
    time.sleep(seconds)
    return f"Task completed after {seconds} seconds"


@shared_task
def cleanup_old_data():
    """Example periodic task"""
    # Add your cleanup logic here
    return "Cleanup completed"


@shared_task
def health_check_task():
    """Task to verify Celery is working"""
    return {"status": "healthy", "timestamp": timezone.now().isoformat(), "worker": socket.gethostname()}
