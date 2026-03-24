from django.contrib import admin

from .models import Loan, LoanPayment

admin.site.register(Loan)
admin.site.register(LoanPayment)
