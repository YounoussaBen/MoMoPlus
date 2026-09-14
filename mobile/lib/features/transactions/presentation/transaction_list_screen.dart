import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/network_logo.dart';
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
    final colors = context.appColors;
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        backgroundColor: colors.canvas,
        appBar: AppBar(
          backgroundColor: colors.brandAccent,
          toolbarHeight: 12,
          bottom: TabBar(
            labelColor: colors.onBrandAccent,
            unselectedLabelColor: colors.onBrandAccent.withValues(alpha: 0.72),
            indicatorColor: colors.onBrandAccent,
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: Consumer<TransactionViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading && vm.transactions.isEmpty) {
              return Center(
                child: CircularProgressIndicator(
                  color: colors.brandStrong,
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
    final colors = context.appColors;
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
                color: colors.textSecondary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
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
    final colors = context.appColors;
    final (statusColor, statusIcon) = switch (txn.status) {
      'pending' => (colors.warning, Icons.hourglass_top_rounded),
      'accepted' => (colors.brandStrong, Icons.handshake_outlined),
      'completed' => (colors.brandStrong, Icons.check_circle_outlined),
      'cancelled' => (colors.error, Icons.cancel_outlined),
      'rejected' => (colors.error, Icons.block_outlined),
      _ => (colors.textSecondary, Icons.info_outline),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceSection,
          borderRadius: BorderRadius.circular(16),
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
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
                  Row(
                    children: [
                      Text(
                        'GHS ${txn.amount.toStringAsFixed(2)} · ',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                      NetworkLogo(network: txn.network, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        txn.networkLabel,
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
            Icon(
              Icons.chevron_right,
              color: colors.textSecondary.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
