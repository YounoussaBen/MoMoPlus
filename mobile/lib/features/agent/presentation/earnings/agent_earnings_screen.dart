import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/data/services/backend_api_service.dart';
import '../../../../core/ui/theme/app_theme.dart';
import '../../domain/agent_earnings.dart';
import 'agent_earnings_view_model.dart';

const List<String> _monthAbbreviations = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatShortDate(DateTime value) {
  return '${_monthAbbreviations[value.month - 1]} ${value.day}, ${value.year}';
}

String _formatDateRange(DateTimeRange range) {
  return '${_formatShortDate(range.start)} - ${_formatShortDate(range.end)}';
}

class AgentEarningsScreen extends StatelessWidget {
  const AgentEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          AgentEarningsViewModel(ctx.read<BackendApiService>())..loadEarnings(),
      child: const _AgentEarningsBody(),
    );
  }
}

class _AgentEarningsBody extends StatefulWidget {
  const _AgentEarningsBody();

  @override
  State<_AgentEarningsBody> createState() => _AgentEarningsBodyState();
}

class _AgentEarningsBodyState extends State<_AgentEarningsBody>
    with WidgetsBindingObserver {
  Future<void> _pickCustomRange(AgentEarningsViewModel vm) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialRange =
        vm.customRange ??
        DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
      initialDateRange: initialRange,
      helpText: 'Custom Earnings Range',
      saveText: 'Apply',
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
          ),
          child: child!,
        );
      },
    );

    if (!mounted || range == null) return;
    await vm.selectCustomRange(range);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AgentEarningsViewModel>().loadEarnings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AgentEarningsViewModel>();
    final showLoader = vm.isLoading && vm.earnings == null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(backgroundColor: AppColors.primary, toolbarHeight: 12),
      body: showLoader
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            )
          : vm.earnings == null
          ? _EmptyState()
          : _EarningsContent(
              earnings: vm.earnings!,
              selectedPeriod: vm.selectedPeriod,
              customRange: vm.customRange,
              isRefreshing: vm.isRefreshing,
              errorMessage: vm.errorMessage,
              onPeriodTap: vm.togglePeriod,
              onCustomRangeTap: () => _pickCustomRange(vm),
              onClearFilter: () => vm.clearFilter(),
            ),
    );
  }
}

// ── Hero Card ───────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final AgentEarnings earnings;

  const _HeroCard({required this.earnings});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5BB030), Color(0xFF3D8B1C)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Earnings',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'GHS ${earnings.totalEarned.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${earnings.totalLoansCompleted} loan${earnings.totalLoansCompleted == 1 ? '' : 's'} completed',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Period Stat Cards ───────────────────────────────────────────────────────

class _PeriodStats extends StatelessWidget {
  final AgentEarnings earnings;
  final AgentEarningsPeriod? selectedPeriod;
  final bool isRefreshing;
  final ValueChanged<AgentEarningsPeriod> onPeriodTap;

  const _PeriodStats({
    required this.earnings,
    required this.selectedPeriod,
    required this.isRefreshing,
    required this.onPeriodTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Today',
            amount: earnings.todayEarned,
            count: earnings.todayCount,
            isSelected: selectedPeriod == AgentEarningsPeriod.today,
            isEnabled: !isRefreshing,
            onTap: () => onPeriodTap(AgentEarningsPeriod.today),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'This Week',
            amount: earnings.thisWeekEarned,
            count: earnings.thisWeekCount,
            isSelected: selectedPeriod == AgentEarningsPeriod.week,
            isEnabled: !isRefreshing,
            onTap: () => onPeriodTap(AgentEarningsPeriod.week),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'This Month',
            amount: earnings.thisMonthEarned,
            count: earnings.thisMonthCount,
            isSelected: selectedPeriod == AgentEarningsPeriod.month,
            isEnabled: !isRefreshing,
            onTap: () => onPeriodTap(AgentEarningsPeriod.month),
          ),
        ),
      ],
    );
  }
}

class _CustomRangeFilter extends StatelessWidget {
  final DateTimeRange? customRange;
  final bool isSelected;
  final bool isRefreshing;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _CustomRangeFilter({
    required this.customRange,
    required this.isSelected,
    required this.isRefreshing,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSelected
        ? AppColors.primary.withValues(alpha: 0.08)
        : Colors.white;
    final borderColor = isSelected ? AppColors.primary : AppColors.divider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isRefreshing ? null : onTap,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.14)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_month_outlined,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Custom Range',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isSelected && customRange != null
                              ? _formatDateRange(customRange!)
                              : 'Choose specific dates for recent earnings',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isRefreshing && isSelected)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (isSelected)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isRefreshing ? null : onClear,
              child: const Text('Clear custom filter'),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double amount;
  final int count;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.amount,
    required this.count,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isSelected
        ? AppColors.primary.withValues(alpha: 0.12)
        : Colors.white;
    final borderColor = isSelected ? AppColors.primary : AppColors.divider;
    final textColor = isSelected ? AppColors.primary : AppColors.textPrimary;

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'GHS ${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count loan${count == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.85)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Recent Earnings List ────────────────────────────────────────────────────

class _RecentEarningTile extends StatelessWidget {
  final EarningItem item;

  const _RecentEarningTile({required this.item});

  String _timeAgo() {
    if (item.completedAt == null) return '';
    final diff = DateTime.now().difference(item.completedAt!);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${item.completedAt!.day}/${item.completedAt!.month}/${item.completedAt!.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              size: 22,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.borrowerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Loan: GHS ${item.loanAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+GHS ${item.earned.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _timeAgo(),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Full Content ────────────────────────────────────────────────────────────

class _EarningsContent extends StatelessWidget {
  final AgentEarnings earnings;
  final AgentEarningsPeriod? selectedPeriod;
  final DateTimeRange? customRange;
  final bool isRefreshing;
  final String? errorMessage;
  final ValueChanged<AgentEarningsPeriod> onPeriodTap;
  final VoidCallback onCustomRangeTap;
  final VoidCallback onClearFilter;

  const _EarningsContent({
    required this.earnings,
    required this.selectedPeriod,
    required this.customRange,
    required this.isRefreshing,
    required this.errorMessage,
    required this.onPeriodTap,
    required this.onCustomRangeTap,
    required this.onClearFilter,
  });

  String _periodSummaryLabel() {
    switch (selectedPeriod) {
      case AgentEarningsPeriod.today:
        return 'Showing today only. Tap the card again to clear.';
      case AgentEarningsPeriod.week:
        return 'Showing this week only. Tap the card again to clear.';
      case AgentEarningsPeriod.month:
        return 'Showing this month only. Tap the card again to clear.';
      case AgentEarningsPeriod.custom:
        if (customRange == null) {
          return 'Showing a custom date range.';
        }
        return 'Showing ${_formatDateRange(customRange!)}.';
      case null:
        return 'Latest completed loans across all periods.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
      children: [
        Text('Your Earnings', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 6),
        Text(
          'Commission from completed loans',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        _HeroCard(earnings: earnings),
        const SizedBox(height: 16),
        _PeriodStats(
          earnings: earnings,
          selectedPeriod: selectedPeriod,
          isRefreshing: isRefreshing,
          onPeriodTap: onPeriodTap,
        ),
        const SizedBox(height: 12),
        _CustomRangeFilter(
          customRange: customRange,
          isSelected: selectedPeriod == AgentEarningsPeriod.custom,
          isRefreshing: isRefreshing,
          onTap: onCustomRangeTap,
          onClear: onClearFilter,
        ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Earnings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _periodSummaryLabel(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isRefreshing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
          ],
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: errorMessage!),
        ],
        const SizedBox(height: 14),
        if (earnings.recentEarnings.isNotEmpty) ...[
          ...earnings.recentEarnings.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecentEarningTile(item: item),
            ),
          ),
        ] else
          _NoEarningsYet(
            hasAnyEarnings: earnings.totalLoansCompleted > 0,
            selectedPeriod: selectedPeriod,
          ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.18)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.error,
        ),
      ),
    );
  }
}

// ── Empty / No-Data States ──────────────────────────────────────────────────

class _NoEarningsYet extends StatelessWidget {
  final bool hasAnyEarnings;
  final AgentEarningsPeriod? selectedPeriod;

  const _NoEarningsYet({
    required this.hasAnyEarnings,
    required this.selectedPeriod,
  });

  String get _title {
    if (!hasAnyEarnings) return 'No earnings yet';
    switch (selectedPeriod) {
      case AgentEarningsPeriod.today:
        return 'No earnings today';
      case AgentEarningsPeriod.week:
        return 'No earnings this week';
      case AgentEarningsPeriod.month:
        return 'No earnings this month';
      case AgentEarningsPeriod.custom:
        return 'No earnings in this range';
      case null:
        return 'No recent earnings';
    }
  }

  String get _subtitle {
    if (!hasAnyEarnings) {
      return 'Your commission from completed loans\nwill appear here.';
    }
    if (selectedPeriod == null) {
      return 'Completed loan commissions will appear here.';
    }
    if (selectedPeriod == AgentEarningsPeriod.custom) {
      return 'Choose different dates or clear the filter.';
    }
    return 'Try another period to see more completed loans.';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 56,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text('Earnings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Completed transactions,\nearnings breakdown, and metrics.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
