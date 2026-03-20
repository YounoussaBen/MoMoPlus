from django.contrib import admin

from .models import Wallet, WalletOtp


@admin.register(Wallet)
class WalletAdmin(admin.ModelAdmin):
    list_display = ("phone_number", "network", "user", "is_verified", "is_default", "created_at")
    list_filter = ("network", "is_verified", "is_default")
    search_fields = ("phone_number", "user__email")
    readonly_fields = ("id", "created_at", "updated_at")


@admin.register(WalletOtp)
class WalletOtpAdmin(admin.ModelAdmin):
    list_display = ("wallet", "code", "used", "expires_at", "created_at")
    list_filter = ("used",)
    readonly_fields = ("id", "created_at", "updated_at")
