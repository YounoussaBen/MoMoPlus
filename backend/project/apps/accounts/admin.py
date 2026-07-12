from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.utils.translation import gettext_lazy as _

from .models import LoanGuarantor, User


@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display = (
        "email",
        "phone",
        "username",
        "supabase_user_id",
        "first_name",
        "last_name",
        "is_staff",
        "created_at",
    )
    list_filter = ("is_staff", "is_superuser", "is_active", "created_at")
    search_fields = ("email", "phone", "username", "supabase_user_id", "first_name", "last_name")
    ordering = ("-created_at",)

    fieldsets = (
        (None, {"fields": ("username", "password")}),
        (_("Personal info"), {"fields": ("first_name", "last_name", "email", "phone", "supabase_user_id")}),
        (_("Permissions"), {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")}),
        (_("Important dates"), {"fields": ("last_login", "created_at", "updated_at")}),
    )

    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": ("username", "email", "password1", "password2"),
            },
        ),
    )

    readonly_fields = ("created_at", "updated_at", "supabase_user_id")

    def get_readonly_fields(self, request, obj=None):
        return list(self.readonly_fields)


@admin.register(LoanGuarantor)
class LoanGuarantorAdmin(admin.ModelAdmin):
    list_display = ("name", "phone_number", "user_email", "created_at")
    list_filter = ("created_at",)
    search_fields = ("name", "phone_number", "user__email")
    ordering = ("-created_at",)
    readonly_fields = ("id", "created_at", "updated_at")

    @admin.display(description="User Email")
    def user_email(self, obj: LoanGuarantor) -> str:
        return obj.user.email
