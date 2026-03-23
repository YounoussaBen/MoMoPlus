import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/theme/app_theme.dart';
import '../domain/physical_transaction.dart';
import 'transaction_view_model.dart';

class TransactionListScreen extends StatelessWidget {
  final bool isAgent;
  final int initialTabIndex;

  const TransactionListScreen({
    super.key,
    this.isAgent = false,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return _TransactionListBody(
      key: ValueKey('${isAgent ? 'agent' : 'user'}-$initialTabIndex'),
      isAgent: isAgent,
      initialTabIndex: initialTabIndex,
    );
  }
}

class _TransactionListBody extends StatefulWidget {
  final bool isAgent;
  final int initialTabIndex;

  const _TransactionListBody({
    super.key,
    required this.isAgent,
    required this.initialTabIndex,
  });

  @override
  State<_TransactionListBody> createState() => _TransactionListBodyState();
}

class _TransactionListBodyState extends State<_TransactionListBody>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TransactionViewModel>().loadTransactions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<TransactionViewModel>().loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          toolbarHeight: 12,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: Consumer<TransactionViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading && vm.transactions.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              );
            }

            return TabBarView(
              children: [
                _TransactionTab(
                  transactions: vm.activeTransactions,
                  emptyIcon: Icons.swap_horiz_rounded,
                  emptyTitle: widget.isAgent
                      ? 'No active transactions'
                      : 'No active requests',
                  emptySubtitle: widget.isAgent
                      ? 'Active transactions will appear here.'
                      : 'Your active requests will appear here.',
                  onRefresh: vm.loadTransactions,
                  onTapTransaction: (txn) => _openDetail(vm, txn),
                ),
                _TransactionTab(
                  transactions: vm.completedTransactions,
                  emptyIcon: Icons.history_rounded,
                  emptyTitle: widget.isAgent
                      ? 'No transaction history'
                      : 'No request history',
                  emptySubtitle: widget.isAgent
                      ? 'Your transactions will appear here.'
                      : 'Your requests will appear here.',
                  onRefresh: vm.loadTransactions,
                  onTapTransaction: (txn) => _openDetail(vm, txn),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openDetail(
    TransactionViewModel vm,
    PhysicalTransaction txn,
  ) async {
    await context.push('/transactions/${txn.id}');
    if (mounted) {
      vm.loadTransactions();
    }
  }
}

class _TransactionTab extends StatelessWidget {
  final List<PhysicalTransaction> transactions;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<void> Function() onRefresh;
  final void Function(PhysicalTransaction txn) onTapTransaction;

  const _TransactionTab({
    required this.transactions,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onRefresh,
    required this.onTapTransaction,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                emptyIcon,
                size: 56,
                color: AppColors.textSecondary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _TransactionCard(
          txn: transactions[index],
          onTap: () => onTapTransaction(transactions[index]),
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final PhysicalTransaction txn;
  final VoidCallback onTap;
  const _TransactionCard({required this.txn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusIcon) = switch (txn.status) {
      'pending' => (Colors.orange, Icons.hourglass_top_rounded),
      'accepted' => (AppColors.primary, Icons.handshake_outlined),
      'completed' => (AppColors.primary, Icons.check_circle_outlined),
      'cancelled' => (AppColors.error, Icons.cancel_outlined),
      'rejected' => (AppColors.error, Icons.block_outlined),
      _ => (AppColors.textSecondary, Icons.info_outline),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
              child: Icon(statusIcon, color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        txn.typeLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          txn.statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'GHS ${txn.amount.toStringAsFixed(2)} · ${txn.networkLabel}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
