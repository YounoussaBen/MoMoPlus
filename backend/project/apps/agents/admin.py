from django.contrib import admin

from .models import AgentProfile, CertificationApplication


@admin.register(AgentProfile)
class AgentProfileAdmin(admin.ModelAdmin):
    list_display = ("user", "agent_type", "is_available", "max_amount", "rating", "created_at")
    list_filter = ("agent_type", "is_available")
    search_fields = ("user__email", "user__first_name", "user__last_name")
    readonly_fields = ("id", "created_at", "updated_at")


@admin.register(CertificationApplication)
class CertificationApplicationAdmin(admin.ModelAdmin):
    list_display = ("agent_profile", "agent_id_number", "network", "status", "created_at")
    list_filter = ("status", "network")
    search_fields = ("agent_id_number", "agent_profile__user__email")
    readonly_fields = ("id", "created_at", "updated_at")
