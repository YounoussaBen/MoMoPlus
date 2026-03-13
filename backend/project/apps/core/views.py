import redis
from celery import current_app
from django.conf import settings
from django.db import connection
from django.http import JsonResponse
from django.shortcuts import render
from django.utils import timezone
from django.views.decorators.csrf import requires_csrf_token
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny


def home(request):
    """API Landing Page"""
    return render(request, "core/home.html")


@api_view(["GET"])
@permission_classes([AllowAny])
def api_status(request):
    """Enhanced API Status endpoint with comprehensive health checks"""
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
    except Exception as e:
        status_data["services"]["database"] = {"status": "unhealthy", "error": str(e)}
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
    except Exception as e:
        status_data["services"]["redis"] = {"status": "unhealthy", "error": str(e)}
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
    except Exception as e:
        status_data["services"]["celery"] = {"status": "unhealthy", "error": str(e)}
        overall_healthy = False

    # System Resources
    try:
        # Get disk usage
        import shutil

        disk_usage = shutil.disk_usage("/")
        disk_free_gb = disk_usage.free // (1024**3)
        disk_total_gb = disk_usage.total // (1024**3)

        # Get memory info (Linux)
        with open("/proc/meminfo") as f:
            meminfo = f.read()
        mem_total = int([line for line in meminfo.split("\n") if "MemTotal" in line][0].split()[1]) // 1024
        mem_available = int([line for line in meminfo.split("\n") if "MemAvailable" in line][0].split()[1]) // 1024

        status_data["system"] = {
            "disk_free_gb": disk_free_gb,
            "disk_total_gb": disk_total_gb,
            "memory_total_mb": mem_total,
            "memory_available_mb": mem_available,
            "memory_usage_percent": round((1 - mem_available / mem_total) * 100, 2),
        }
    except Exception as e:
        status_data["system"] = {"error": str(e)}

    status_data["overall_status"] = "healthy" if overall_healthy else "unhealthy"
    status_code = 200 if overall_healthy else 503

    return JsonResponse(status_data, status=status_code)


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


@requires_csrf_token
def csrf_failure(request, reason=""):
    """Handle CSRF failures"""
    return JsonResponse(
        {"error": "CSRF verification failed", "reason": reason, "message": "Request blocked for security reasons"},
        status=403,
    )
