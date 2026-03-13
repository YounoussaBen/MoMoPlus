import json
import platform
import re
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any

import redis
from celery import current_app
from django.conf import settings
from django.db import connection
from django.http import JsonResponse
from django.shortcuts import render
from django.utils import timezone
from django.views.decorators.csrf import requires_csrf_token
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny


def home(request):
    """API Landing Page"""
    return render(request, "core/home.html")


def status_page(request):
    """Human-friendly status dashboard."""
    status_data, _ = build_status_payload(request)
    context = {
        "headline": (
            "All Systems Operational" if status_data["overall_status"] == "healthy" else "Some Systems Need Attention"
        ),
        "summary_status": humanize_status(status_data["overall_status"]),
        "summary_tone": normalize_status(status_data["overall_status"]),
        "overview_items": build_overview_items(status_data),
        "service_sections": build_service_sections(status_data),
        "status_json_url": "/api/status/",
    }
    return render(request, "core/status.html", context)


def build_status_payload(request) -> tuple[dict[str, Any], int]:
    """Collect backend health checks for API and HTML status views."""
    status_data = {
        "status": "online",
        "timestamp": timezone.now().isoformat(),
        "version": "1.0.0",
        "environment": settings.PROJECT_ENVIRONMENT,
        "services": {},
        "docs": request.build_absolute_uri("/api/docs/"),
    }

    overall_healthy = True

    # Database Health Check
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        status_data["services"]["database"] = {"status": "healthy", "type": "postgresql", "response_time": "< 1ms"}
    except Exception as exc:
        status_data["services"]["database"] = {"status": "unhealthy", "error": str(exc)}
        overall_healthy = False

    # Redis Health Check
    try:
        redis_client = redis.from_url(settings.CELERY_BROKER_URL)
        redis_client.ping()
        info = redis_client.info()
        status_data["services"]["redis"] = {
            "status": "healthy",
            "connected_clients": info.get("connected_clients", 0),
            "used_memory_human": info.get("used_memory_human", "unknown"),
            "uptime_in_seconds": info.get("uptime_in_seconds", 0),
        }
    except Exception as exc:
        status_data["services"]["redis"] = {"status": "unhealthy", "error": str(exc)}
        overall_healthy = False

    # Celery Health Check
    try:
        inspect = current_app.control.inspect()
        stats = inspect.stats()
        active = inspect.active()
        scheduled = inspect.scheduled()

        if stats:
            worker_count = len(stats)
            total_active = sum(len(tasks) for tasks in active.values()) if active else 0
            total_scheduled = sum(len(tasks) for tasks in scheduled.values()) if scheduled else 0

            status_data["services"]["celery"] = {
                "status": "healthy",
                "workers": worker_count,
                "active_tasks": total_active,
                "scheduled_tasks": total_scheduled,
                "workers_detail": stats,
            }
        else:
            status_data["services"]["celery"] = {"status": "unhealthy", "error": "No workers available"}
            overall_healthy = False
    except Exception as exc:
        status_data["services"]["celery"] = {"status": "unhealthy", "error": str(exc)}
        overall_healthy = False

    status_data["system"] = collect_system_status()
    status_data["overall_status"] = "healthy" if overall_healthy else "unhealthy"
    status_code = 200 if overall_healthy else 503

    return status_data, status_code


@extend_schema(
    tags=["Monitoring"],
    request=None,
    responses={
        200: OpenApiTypes.OBJECT,
        503: OpenApiTypes.OBJECT,
    },
)
@api_view(["GET"])
@permission_classes([AllowAny])
def api_status(request):
    """Enhanced API Status endpoint with comprehensive health checks"""
    status_data, status_code = build_status_payload(request)
    return JsonResponse(status_data, status=status_code)


@extend_schema(
    tags=["Monitoring"],
    request=None,
    responses={
        200: OpenApiTypes.OBJECT,
        500: OpenApiTypes.OBJECT,
    },
)
@api_view(["GET"])
@permission_classes([AllowAny])
def celery_status(request):
    """Detailed Celery monitoring endpoint"""
    try:
        inspect = current_app.control.inspect()

        # Get comprehensive Celery information
        stats = inspect.stats()
        active_tasks = inspect.active()
        scheduled_tasks = inspect.scheduled()
        reserved_tasks = inspect.reserved()
        registered_tasks = inspect.registered()

        return JsonResponse(
            {
                "workers": stats,
                "active_tasks": active_tasks,
                "scheduled_tasks": scheduled_tasks,
                "reserved_tasks": reserved_tasks,
                "registered_tasks": registered_tasks,
                "timestamp": timezone.now().isoformat(),
            }
        )
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=500)


@extend_schema(
    tags=["Monitoring"],
    request=None,
    parameters=[
        OpenApiParameter(
            name="task_id",
            type=str,
            location=OpenApiParameter.PATH,
            description="Celery task identifier.",
        )
    ],
    responses={
        200: OpenApiTypes.OBJECT,
    },
)
@api_view(["GET"])
@permission_classes([AllowAny])
def task_status(request, task_id):
    """Get status of a specific task"""
    result = current_app.AsyncResult(task_id)

    if result.state == "PENDING":
        response = {"state": result.state, "status": "Task is waiting to be processed"}
    elif result.state != "FAILURE":
        response = {
            "state": result.state,
            "result": result.result,
        }
        if result.state == "PROGRESS":
            response.update(
                {
                    "current": result.info.get("current", 0),
                    "total": result.info.get("total", 1),
                }
            )
    else:
        response = {
            "state": result.state,
            "error": str(result.info),
        }

    return JsonResponse(response)


def collect_system_status() -> dict[str, Any]:
    """Collect host-level system metrics."""
    disk_usage = shutil.disk_usage("/")
    system_status: dict[str, Any] = {
        "platform": platform.system(),
        "disk_free_gb": disk_usage.free // (1024**3),
        "disk_total_gb": disk_usage.total // (1024**3),
    }

    try:
        system_status.update(collect_memory_status())
    except Exception as exc:
        system_status["error"] = str(exc)

    return system_status


def collect_memory_status() -> dict[str, Any]:
    """Collect memory metrics for Linux and macOS."""
    proc_meminfo = Path("/proc/meminfo")
    if proc_meminfo.exists():
        return collect_linux_memory_status(proc_meminfo)

    if platform.system() == "Darwin":
        return collect_macos_memory_status()

    raise FileNotFoundError("Memory metrics are not available on this platform")


def collect_linux_memory_status(meminfo_path: Path) -> dict[str, Any]:
    meminfo = meminfo_path.read_text()
    mem_total = int([line for line in meminfo.split("\n") if "MemTotal" in line][0].split()[1]) // 1024
    mem_available = int([line for line in meminfo.split("\n") if "MemAvailable" in line][0].split()[1]) // 1024
    return {
        "memory_total_mb": mem_total,
        "memory_available_mb": mem_available,
        "memory_usage_percent": round((1 - mem_available / mem_total) * 100, 2),
    }


def collect_macos_memory_status() -> dict[str, Any]:
    mem_total_bytes = int(subprocess.check_output(["sysctl", "-n", "hw.memsize"], text=True).strip())
    vm_stat_output = subprocess.check_output(["vm_stat"], text=True)

    page_size_match = re.search(r"page size of (\d+) bytes", vm_stat_output)
    if not page_size_match:
        raise ValueError("Unable to determine macOS memory page size")

    page_size = int(page_size_match.group(1))
    page_counts: dict[str, int] = {}

    for line in vm_stat_output.splitlines():
        if ":" not in line:
            continue

        name, raw_value = line.split(":", 1)
        numeric_value = re.sub(r"[^\d]", "", raw_value)
        if numeric_value:
            page_counts[name.strip()] = int(numeric_value)

    available_pages = sum(
        page_counts.get(page_name, 0)
        for page_name in (
            "Pages free",
            "Pages inactive",
            "Pages speculative",
        )
    )
    mem_total = mem_total_bytes // (1024**2)
    mem_available = (available_pages * page_size) // (1024**2)
    usage_percent = round((1 - mem_available / mem_total) * 100, 2)
    usage_percent = max(0.0, min(100.0, usage_percent))

    return {
        "memory_total_mb": mem_total,
        "memory_available_mb": mem_available,
        "memory_usage_percent": usage_percent,
    }


def build_overview_items(status_data: dict[str, Any]) -> list[dict[str, str]]:
    return [
        {"label": "Overall", "value": humanize_status(status_data["overall_status"])},
        {"label": "Last Updated", "value": format_timestamp(status_data["timestamp"])},
        {"label": "Environment", "value": str(status_data["environment"]).title()},
        {"label": "Version", "value": status_data["version"]},
        {"label": "Docs", "value": "Open Swagger", "url": status_data["docs"]},
        {"label": "JSON", "value": "View Raw Status", "url": "/api/status/"},
    ]


def build_service_sections(status_data: dict[str, Any]) -> list[dict[str, Any]]:
    sections = [build_status_section(name, payload) for name, payload in status_data["services"].items()]
    sections.append(build_status_section("system", status_data["system"]))
    return sections


def build_status_section(name: str, payload: dict[str, Any]) -> dict[str, Any]:
    section_status = payload.get("status")
    if section_status is None:
        section_status = "healthy" if not payload.get("error") else "unhealthy"

    normalized_status = normalize_status(section_status, payload.get("error"))
    details = [build_detail_item(key, value) for key, value in payload.items() if key not in {"status", "error"}]

    return {
        "title": humanize_key(name),
        "status": humanize_status(normalized_status),
        "tone": normalized_status,
        "error": payload.get("error"),
        "details": details,
    }


def build_detail_item(key: str, value: Any) -> dict[str, Any]:
    if isinstance(value, dict | list):
        return {
            "label": humanize_key(key),
            "value": json.dumps(value, indent=2, sort_keys=True),
            "is_code": True,
        }

    return {
        "label": humanize_key(key),
        "value": str(value),
        "is_code": False,
    }


def normalize_status(status: Any, error: str | None = None) -> str:
    if status in {"healthy", "online"}:
        return "healthy"
    if status in {"unhealthy", "offline"} or error:
        return "unhealthy"
    return "unknown"


def humanize_status(status: Any) -> str:
    normalized = normalize_status(status)
    if normalized == "healthy":
        return "Healthy"
    if normalized == "unhealthy":
        return "Unhealthy"
    return "Unknown"


def humanize_key(value: str) -> str:
    return value.replace("_", " ").title()


def format_timestamp(value: str) -> str:
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        return value

    return timezone.localtime(parsed).strftime("%b %d, %Y at %H:%M %Z")


@requires_csrf_token
def csrf_failure(request, reason=""):
    """Handle CSRF failures"""
    return JsonResponse(
        {"error": "CSRF verification failed", "reason": reason, "message": "Request blocked for security reasons"},
        status=403,
    )
