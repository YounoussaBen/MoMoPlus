from django.contrib import admin

from .models import CashServiceRating, PhysicalTransaction

admin.site.register(PhysicalTransaction)
admin.site.register(CashServiceRating)
