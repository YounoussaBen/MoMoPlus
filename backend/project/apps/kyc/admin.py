from django.contrib import admin

from .models import KycSubmission


@admin.register(KycSubmission)
class KycSubmissionAdmin(admin.ModelAdmin):
    list_display = ["id", "user", "status", "id_type", "reviewed_by", "reviewed_at", "created_at"]
    list_filter = ["status", "id_type"]
    search_fields = ["user__email", "user__first_name", "user__last_name"]
    raw_id_fields = ["user", "reviewed_by", "id_front", "id_back", "selfie", "proof_of_address"]
    readonly_fields = ["created_at", "updated_at"]
