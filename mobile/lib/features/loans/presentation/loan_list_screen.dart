import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/network_logo.dart';
import '../domain/loan.dart';
import 'loan_view_model.dart';

class LoanListScreen extends StatefulWidget {
  final bool isAgent;
  final int initialTabIndex;

  const LoanListScreen({
    super.key,
    required this.isAgent,
    this.initialTabIndex = 0,
  });

  @override
  State<LoanListScreen> createState() => _LoanListScreenState();
}

class _LoanListScreenState extends State<LoanListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final loanVm = context.watch<LoanViewModel>();

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Loans',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.brandStrong,
          labelColor: colors.brandStrong,
          unselectedLabelColor: colors.textSecondary,
          tabs: [
            Tab(text: 'Active (${loanVm.ongoingLoans.length})'),
            Tab(text: 'History (${loanVm.historyLoans.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LoanTab(
            loans: loanVm.ongoingLoans,
            isLoading: loanVm.isLoading,
            emptyIcon: Icons.money_off_rounded,
            emptyText: 'No active loans',
            isAgent: widget.isAgent,
          ),
          _LoanTab(
            loans: loanVm.historyLoans,
            isLoading: loanVm.isLoading,
            emptyIcon: Icons.receipt_long_outlined,
            emptyText: 'No loan history',
            isAgent: widget.isAgent,
          ),
        ],
      ),
    );
  }
}

class _LoanTab extends StatelessWidget {
  final List<Loan> loans;
  final bool isLoading;
  final IconData emptyIcon;
  final String emptyText;
  final bool isAgent;

  const _LoanTab({
    required this.loans,
    required this.isLoading,
    required this.emptyIcon,
    required this.emptyText,
    required this.isAgent,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && loans.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: context.appColors.brandStrong,
          strokeWidth: 2,
        ),
      );
    }

    if (loans.isEmpty) {
      final colors = context.appColors;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              emptyIcon,
              size: 48,
              color: colors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              emptyText,
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<LoanViewModel>().loadLoans(),
      color: context.appColors.brandStrong,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: loans.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _LoanCard(loan: loans[index], isAgent: isAgent),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final Loan loan;
  final bool isAgent;
  const _LoanCard({required this.loan, required this.isAgent});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final (statusColor, statusIcon) = switch (loan.status) {
      'pending' => (colors.warning, Icons.hourglass_top_rounded),
      'approved' => (colors.brandStrong, Icons.check_circle_outline),
      'disbursing' => (colors.info, Icons.sync_rounded),
      'active' => (colors.brandStrong, Icons.account_balance_wallet_rounded),
      'repaying' => (colors.info, Icons.sync_rounded),
      'completed' => (colors.brandStrong, Icons.check_circle_rounded),
      'defaulted' => (colors.error, Icons.warning_amber_rounded),
      'rejected' => (colors.error, Icons.block_rounded),
      'cancelled' => (colors.textSecondary, Icons.cancel_outlined),
      'failed' => (colors.error, Icons.error_outline_rounded),
      _ => (colors.textSecondary, Icons.info_outline),
    };

    return GestureDetector(
      onTap: () => context.push('/loans/${loan.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceSection,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.surfaceSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, size: 22, color: statusColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAgent ? loan.borrowerName : loan.agentName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '${loan.statusLabel} · ',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                      NetworkLogo(network: loan.network, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        loan.networkLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'GHS ${loan.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                if (loan.isActive && loan.isOverdue)
                  Text(
                    'OVERDUE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.error,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
