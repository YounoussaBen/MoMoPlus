from rest_framework import serializers


class DashboardSummarySerializer(serializers.Serializer):
    total_users = serializers.IntegerField()
    approved_agents = serializers.IntegerField()
    pending_kyc_reviews = serializers.IntegerField()
    pending_agent_reviews = serializers.IntegerField()
    open_get_funds_cases = serializers.IntegerField()
    overdue_get_funds_cases = serializers.IntegerField()
    open_cash_services = serializers.IntegerField()
    scheduled_cash_meetings = serializers.IntegerField()


class DashboardPeriodSerializer(serializers.Serializer):
    new_users = serializers.IntegerField()
    new_agents = serializers.IntegerField()
    new_kyc_submissions = serializers.IntegerField()
    new_get_funds_cases = serializers.IntegerField()
    new_cash_services = serializers.IntegerField()
    loan_disbursement_volume = serializers.DecimalField(max_digits=12, decimal_places=2)
    loan_repayment_volume = serializers.DecimalField(max_digits=12, decimal_places=2)
    cash_in_volume = serializers.DecimalField(max_digits=12, decimal_places=2)
    cash_out_volume = serializers.DecimalField(max_digits=12, decimal_places=2)


class DashboardActivityPointSerializer(serializers.Serializer):
    date = serializers.DateField()
    users = serializers.IntegerField()
    agents = serializers.IntegerField()
    kyc_submissions = serializers.IntegerField()
    get_funds_cases = serializers.IntegerField()
    cash_services = serializers.IntegerField()


class DashboardMoneyFlowPointSerializer(serializers.Serializer):
    date = serializers.DateField()
    loan_disbursements = serializers.DecimalField(max_digits=12, decimal_places=2)
    loan_repayments = serializers.DecimalField(max_digits=12, decimal_places=2)
    cash_in = serializers.DecimalField(max_digits=12, decimal_places=2)
    cash_out = serializers.DecimalField(max_digits=12, decimal_places=2)


class DashboardBreakdownPointSerializer(serializers.Serializer):
    key = serializers.CharField()
    label = serializers.CharField()
    value = serializers.IntegerField()


class DashboardChartsSerializer(serializers.Serializer):
    activity = DashboardActivityPointSerializer(many=True)
    money_flow = DashboardMoneyFlowPointSerializer(many=True)
    kyc_status_breakdown = DashboardBreakdownPointSerializer(many=True)
    loan_status_breakdown = DashboardBreakdownPointSerializer(many=True)
    cash_service_status_breakdown = DashboardBreakdownPointSerializer(many=True)
    network_breakdown = DashboardBreakdownPointSerializer(many=True)


class StaffDashboardOverviewSerializer(serializers.Serializer):
    generated_at = serializers.DateTimeField()
    range_days = serializers.IntegerField()
    summary = DashboardSummarySerializer()
    period = DashboardPeriodSerializer()
    charts = DashboardChartsSerializer()
