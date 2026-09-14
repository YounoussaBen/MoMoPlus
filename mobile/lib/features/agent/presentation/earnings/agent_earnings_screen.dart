import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/services/backend_api_service.dart';
import '../../../../core/ui/theme/app_spacing.dart';
import '../../../../core/ui/theme/app_theme_extension.dart';
import '../../../../core/ui/widgets/app_button.dart';
import '../../../../core/ui/widgets/app_icon_button.dart';
import '../../../../core/ui/widgets/app_list_row.dart';
import '../../../../core/ui/widgets/app_section.dart';
import '../../domain/agent_earnings.dart';
import 'agent_earnings_view_model.dart';

const _monthAbbreviations = <String>[
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

String _formatShortDate(DateTime value) =>
    '${_monthAbbreviations[value.month - 1]} ${value.day}, ${value.year}';

String _formatDateRange(DateTimeRange range) =>
    '${_formatShortDate(range.start)} – ${_formatShortDate(range.end)}';

class AgentEarningsScreen extends StatelessWidget {
  const AgentEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          AgentEarningsViewModel(context.read<BackendApiService>())
            ..loadEarnings(),
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

  Future<void> _pickCustomRange(AgentEarningsViewModel vm) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
      initialDateRange:
          vm.customRange ??
          DateTimeRange(
            start: today.subtract(const Duration(days: 6)),
            end: today,
          ),
      helpText: 'Custom earnings range',
      saveText: 'Apply',
    );
    if (!mounted || range == null) return;
    await vm.selectCustomRange(range);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AgentEarningsViewModel>();

    return Scaffold(
      backgroundColor: context.appColors.canvas,
      body: SafeArea(
        bottom: false,
        child: vm.isLoading && vm.earnings == null
            ? Center(
                child: CircularProgressIndicator(
                  color: context.appColors.brandAccent,
                  strokeWidth: 2,
                ),
              )
            : vm.earnings == null
            ? _EmptyState(onRetry: vm.loadEarnings, message: vm.errorMessage)
            : RefreshIndicator(
                color: context.appColors.brandAccent,
                onRefresh: vm.loadEarnings,
                child: _EarningsContent(
                  earnings: vm.earnings!,
                  selectedPeriod: vm.selectedPeriod,
                  customRange: vm.customRange,
                  isRefreshing: vm.isRefreshing,
                  errorMessage: vm.errorMessage,
                  onPeriodTap: vm.togglePeriod,
                  onCustomRangeTap: () => _pickCustomRange(vm),
                  onClearFilter: vm.clearFilter,
                ),
              ),
      ),
    );
  }
}

class _EarningsContent extends StatelessWidget {
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

  final AgentEarnings earnings;
  final AgentEarningsPeriod? selectedPeriod;
  final DateTimeRange? customRange;
  final bool isRefreshing;
  final String? errorMessage;
  final ValueChanged<AgentEarningsPeriod> onPeriodTap;
  final VoidCallback onCustomRangeTap;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 112),
      children: [
        Text('Earnings', style: context.appTextTheme.displayLarge),
        const SizedBox(height: AppSpacing.space1),
        Text(
          'Commission from your completed loans.',
          style: context.appTextTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.space6),
        _EarningsHero(earnings: earnings),
        const SizedBox(height: AppSpacing.space6),
        const AppSectionHeader(title: 'Earnings period'),
        const SizedBox(height: AppSpacing.space2),
        AppSection(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _PeriodCard(
                      label: 'Today',
                      amount: earnings.todayEarned,
                      count: earnings.todayCount,
                      isSelected: selectedPeriod == AgentEarningsPeriod.today,
                      onTap: isRefreshing
                          ? null
                          : () => onPeriodTap(AgentEarningsPeriod.today),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: _PeriodCard(
                      label: 'This week',
                      amount: earnings.thisWeekEarned,
                      count: earnings.thisWeekCount,
                      isSelected: selectedPeriod == AgentEarningsPeriod.week,
                      onTap: isRefreshing
                          ? null
                          : () => onPeriodTap(AgentEarningsPeriod.week),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: _PeriodCard(
                      label: 'This month',
                      amount: earnings.thisMonthEarned,
                      count: earnings.thisMonthCount,
                      isSelected: selectedPeriod == AgentEarningsPeriod.month,
                      onTap: isRefreshing
                          ? null
                          : () => onPeriodTap(AgentEarningsPeriod.month),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space3),
              _CustomRangeRow(
                range: customRange,
                isSelected: selectedPeriod == AgentEarningsPeriod.custom,
                isRefreshing: isRefreshing,
                onTap: onCustomRangeTap,
                onClear: onClearFilter,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space6),
        Row(
          children: [
            const Expanded(child: AppSectionHeader(title: 'Recent earnings')),
            if (isRefreshing)
              SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  color: context.appColors.brandStrong,
                  strokeWidth: 2,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.space1),
        Text(
          _periodSummary(),
          style: context.appTextTheme.bodySmall?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: AppSpacing.space3),
          _ErrorBanner(message: errorMessage!),
        ],
        const SizedBox(height: AppSpacing.space2),
        AppSection(
          padding: const EdgeInsets.all(AppSpacing.space2),
          child: earnings.recentEarnings.isEmpty
              ? _NoEarningsYet(
                  hasAnyEarnings: earnings.totalLoansCompleted > 0,
                  selectedPeriod: selectedPeriod,
                )
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < earnings.recentEarnings.length;
                      index++
                    ) ...[
                      _RecentEarningRow(item: earnings.recentEarnings[index]),
                      if (index < earnings.recentEarnings.length - 1)
                        const SizedBox(height: AppSpacing.space2),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  String _periodSummary() => switch (selectedPeriod) {
    AgentEarningsPeriod.today => 'Showing today only.',
    AgentEarningsPeriod.week => 'Showing this week only.',
    AgentEarningsPeriod.month => 'Showing this month only.',
    AgentEarningsPeriod.custom when customRange != null =>
      'Showing ${_formatDateRange(customRange!)}.',
    AgentEarningsPeriod.custom => 'Showing a custom date range.',
    null => 'Latest completed loans across all periods.',
  };
}

class _EarningsHero extends StatelessWidget {
  const _EarningsHero({required this.earnings});

  final AgentEarnings earnings;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space6),
      decoration: const BoxDecoration(
        gradient: AppGradients.forestHero,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total earnings',
            style: context.appTextTheme.labelLarge?.copyWith(
              color: colors.onBrandAccent.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'GHS ${earnings.totalEarned.toStringAsFixed(2)}',
            style: context.appTextTheme.displayLarge?.copyWith(
              color: colors.onBrandAccent,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            '${earnings.totalLoansCompleted} completed loan${earnings.totalLoansCompleted == 1 ? '' : 's'}',
            style: context.appTextTheme.bodyMedium?.copyWith(
              color: colors.onBrandAccent.withValues(alpha: 0.74),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.label,
    required this.amount,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final double amount;
  final int count;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected
        ? context.appColors.brandStrong
        : context.appColors.textPrimary;

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected
            ? context.appColors.brandSoft
            : context.appColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextTheme.labelSmall?.copyWith(
                    color: isSelected
                        ? context.appColors.brandStrong
                        : context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'GHS ${amount.toStringAsFixed(2)}',
                    style: context.appTextTheme.titleSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  '$count loan${count == 1 ? '' : 's'}',
                  style: context.appTextTheme.labelSmall?.copyWith(
                    color: context.appColors.textSecondary,
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

class _CustomRangeRow extends StatelessWidget {
  const _CustomRangeRow({
    required this.range,
    required this.isSelected,
    required this.isRefreshing,
    required this.onTap,
    required this.onClear,
  });

  final DateTimeRange? range;
  final bool isSelected;
  final bool isRefreshing;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      title: 'Custom range',
      subtitle: isSelected && range != null
          ? _formatDateRange(range!)
          : 'Choose specific dates',
      leading: AppIconTile(
        icon: Icons.calendar_month_outlined,
        backgroundColor: isSelected ? context.appColors.brandSoft : null,
        foregroundColor: isSelected ? context.appColors.brandStrong : null,
      ),
      trailing: isRefreshing && isSelected
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                color: context.appColors.brandStrong,
                strokeWidth: 2,
              ),
            )
          : isSelected
          ? IconButton(
              tooltip: 'Clear custom range',
              onPressed: isRefreshing ? null : onClear,
              icon: const Icon(Icons.close_rounded),
            )
          : Icon(
              Icons.chevron_right_rounded,
              color: context.appColors.textMuted,
            ),
      onTap: isRefreshing ? null : onTap,
    );
  }
}

class _RecentEarningRow extends StatelessWidget {
  const _RecentEarningRow({required this.item});

  final EarningItem item;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      title: item.borrowerName,
      subtitle:
          'Loan GHS ${item.loanAmount.toStringAsFixed(2)}  •  ${_timeAgo()}',
      leading: AppIconTile(
        icon: Icons.trending_up_rounded,
        backgroundColor: context.appColors.successContainer,
        foregroundColor: context.appColors.success,
      ),
      trailing: Text(
        '+GHS ${item.earned.toStringAsFixed(2)}',
        style: context.appTextTheme.titleSmall?.copyWith(
          color: context.appColors.success,
        ),
      ),
    );
  }

  String _timeAgo() {
    final completedAt = item.completedAt;
    if (completedAt == null) return '';
    final difference = DateTime.now().difference(completedAt);
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${completedAt.day}/${completedAt.month}/${completedAt.year}';
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        color: context.appColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: context.appTextTheme.bodySmall?.copyWith(
          color: context.appColors.error,
        ),
      ),
    );
  }
}

class _NoEarningsYet extends StatelessWidget {
  const _NoEarningsYet({
    required this.hasAnyEarnings,
    required this.selectedPeriod,
  });

  final bool hasAnyEarnings;
  final AgentEarningsPeriod? selectedPeriod;

  @override
  Widget build(BuildContext context) {
    final title = !hasAnyEarnings
        ? 'No earnings yet'
        : selectedPeriod == null
        ? 'No recent earnings'
        : 'No earnings for this period';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space6),
      child: Column(
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 40,
            color: context.appColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(title, style: context.appTextTheme.titleSmall),
          const SizedBox(height: AppSpacing.space1),
          Text(
            'Completed-loan commissions will appear here.',
            textAlign: TextAlign.center,
            style: context.appTextTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: 52,
              color: context.appColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(
              'Earnings unavailable',
              style: context.appTextTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              message ?? 'We could not load your earnings right now.',
              textAlign: TextAlign.center,
              style: context.appTextTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            AppButton(
              label: 'Try again',
              variant: AppButtonVariant.secondary,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
