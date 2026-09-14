from django.contrib import admin

from .models import GhanaCardRecord, KycSubmission


@admin.register(KycSubmission)
class KycSubmissionAdmin(admin.ModelAdmin):
    list_display = [
        "id",
        "user",
        "status",
        "ghana_card_number",
        "verification_method",
        "reviewed_by",
        "reviewed_at",
        "created_at",
    ]
    list_filter = ["status", "verification_method"]
    search_fields = ["ghana_card_number", "user__email", "user__first_name", "user__last_name"]
    raw_id_fields = ["user", "reviewed_by", "id_front", "id_back", "selfie", "proof_of_address"]
    readonly_fields = ["created_at", "updated_at"]


@admin.register(GhanaCardRecord)
class GhanaCardRecordAdmin(admin.ModelAdmin):
    list_display = ["card_number", "first_names", "surname", "date_of_birth", "is_active", "created_at"]
    list_filter = ["is_active", "sex"]
    search_fields = ["card_number", "first_names", "surname"]
    raw_id_fields = ["card_front", "card_back", "created_by"]
    readonly_fields = ["created_at", "updated_at"]
