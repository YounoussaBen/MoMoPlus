import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/theme/app_theme.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/ui/widgets/network_logo.dart';
import '../../../core/ui/widgets/top_in_app_notification.dart';
import '../../auth/presentation/auth_view_model.dart';
import '../../wallet/domain/wallet.dart';
import '../../wallet/presentation/wallet_view_model.dart';
import '../domain/loan.dart';
import 'loan_view_model.dart';

class LoanDetailScreen extends StatefulWidget {
  final String loanId;
  const LoanDetailScreen({super.key, required this.loanId});

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  Loan? _loan;
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadLoan();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _loadLoan());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadLoan() async {
    final loanVm = context.read<LoanViewModel>();
    final loan = await loanVm.getLoanDetail(widget.loanId);
    if (mounted) {
      setState(() {
        _loan = loan;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_loan == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'Not found.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final loan = _loan!;
    final isAgent = context.read<AuthViewModel>().appUser?.isAgent == true;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _StatusBanner(loan: loan),
          const SizedBox(height: 20),
          if (loan.isActive || loan.isRepaying) ...[
            _TimerCard(loan: loan),
            const SizedBox(height: 16),
          ],
          _AmountCard(loan: loan),
          const SizedBox(height: 16),
          _DetailsCard(loan: loan, isAgent: isAgent),
          const SizedBox(height: 16),
          if (loan.payments.isNotEmpty) ...[
            _PaymentsCard(loan: loan),
            const SizedBox(height: 16),
          ],
          _ActionButtons(loan: loan, isAgent: isAgent, onRefresh: _loadLoan),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final Loan loan;
  const _StatusBanner({required this.loan});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (loan.status) {
      'pending' => (Colors.orange, Icons.hourglass_top_rounded),
      'approved' => (AppColors.primary, Icons.check_circle_outline),
      'disbursing' => (Colors.blue, Icons.sync_rounded),
      'active' => (AppColors.primary, Icons.account_balance_wallet_rounded),
      'repaying' => (Colors.blue, Icons.sync_rounded),
      'completed' => (AppColors.primary, Icons.check_circle_rounded),
      'defaulted' => (AppColors.error, Icons.warning_amber_rounded),
      'rejected' => (AppColors.error, Icons.block_rounded),
      'cancelled' => (AppColors.textSecondary, Icons.cancel_outlined),
      'failed' => (AppColors.error, Icons.error_outline_rounded),
      _ => (AppColors.textSecondary, Icons.info_outline),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loan.statusLabel,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (loan.rejectionReason.isNotEmpty)
                  Text(
                    loan.rejectionReason,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerCard extends StatefulWidget {
  final Loan loan;
  const _TimerCard({required this.loan});

  @override
  State<_TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends State<_TimerCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.loan.timeRemaining;
    final isOverdue = widget.loan.isOverdue;

    String timeText;
    if (remaining == null) {
      timeText = '--:--:--';
    } else if (remaining == Duration.zero) {
      timeText = 'OVERDUE';
    } else {
      final h = remaining.inHours;
      final m = remaining.inMinutes.remainder(60);
      final s = remaining.inSeconds.remainder(60);
      timeText =
          '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isOverdue
            ? AppColors.error.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isOverdue
            ? Border.all(color: AppColors.error.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        children: [
          Text(
            isOverdue ? 'Overdue' : 'Time Remaining',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isOverdue ? AppColors.error : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            timeText,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isOverdue ? AppColors.error : AppColors.textPrimary,
            ),
          ),
          if (widget.loan.penaltyAmount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Penalties: GHS ${widget.loan.penaltyAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  final Loan loan;
  const _AmountCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _row('Amount', 'GHS ${loan.amount.toStringAsFixed(2)}'),
          _row(
            'Interest (${loan.interestRate.toStringAsFixed(0)}%)',
            'GHS ${(loan.totalRepayment - loan.amount - loan.penaltyAmount).toStringAsFixed(2)}',
          ),
          if (loan.penaltyAmount > 0)
            _row(
              'Penalties',
              'GHS ${loan.penaltyAmount.toStringAsFixed(2)}',
              valueColor: AppColors.error,
            ),
          const Divider(height: 20),
          _row(
            'Total Repayment',
            'GHS ${loan.totalRepayment.toStringAsFixed(2)}',
            bold: true,
          ),
          if (loan.isActive || loan.isRepaying || loan.isDefaulted)
            _row(
              'Outstanding',
              'GHS ${loan.outstandingBalance.toStringAsFixed(2)}',
              bold: true,
              valueColor: AppColors.primary,
            ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final Loan loan;
  final bool isAgent;
  const _DetailsCard({required this.loan, required this.isAgent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Details',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _detailRow(
            isAgent ? 'Borrower' : 'Agent',
            isAgent ? loan.borrowerName : loan.agentName,
          ),
          _detailRow('Network', loan.networkLabel),
          _detailRow('Borrower Wallet', loan.borrowerWalletPhone),
          if (loan.agentWalletPhone.isNotEmpty)
            _detailRow('Agent Wallet', loan.agentWalletPhone),
          if (loan.approvedAt != null)
            _detailRow('Approved', _formatDate(loan.approvedAt!)),
          if (loan.disbursedAt != null)
            _detailRow('Funds Sent', _formatDate(loan.disbursedAt!)),
          if (loan.deadlineAt != null)
            _detailRow('Deadline', _formatDate(loan.deadlineAt!)),
          if (loan.completedAt != null)
            _detailRow('Completed', _formatDate(loan.completedAt!)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _PaymentsCard extends StatelessWidget {
  final Loan loan;
  const _PaymentsCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment History',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...loan.payments.map((p) {
            final (icon, color) = switch (p.status) {
              'success' => (Icons.check_circle, AppColors.primary),
              'failed' => (Icons.cancel, AppColors.error),
              _ => (Icons.hourglass_top, Colors.orange),
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.isDisbursement ? 'Funds Received' : 'Repayment',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          p.reference,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'GHS ${p.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final Loan loan;
  final bool isAgent;
  final VoidCallback onRefresh;

  const _ActionButtons({
    required this.loan,
    required this.isAgent,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final loanVm = context.watch<LoanViewModel>();

    return Column(
      children: [
        // Agent: Accept pending loan
        if (isAgent && loan.isPending) ...[
          AppButton(
            label: 'Accept',
            onPressed: loanVm.isSubmitting
                ? null
                : () => _showAcceptDialog(context),
            isLoading: loanVm.isSubmitting,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Reject',
            onPressed: loanVm.isSubmitting
                ? null
                : () => _showRejectDialog(context),
            variant: AppButtonVariant.secondary,
          ),
        ],

        // Agent: Disburse approved loan
        if (isAgent && loan.isApproved) ...[
          AppButton(
            label: 'Send Funds',
            onPressed: loanVm.isSubmitting ? null : () => _disburse(context),
            isLoading: loanVm.isSubmitting,
          ),
        ],

        // Borrower: Repay active loan
        if (!isAgent && (loan.isActive || loan.isDefaulted)) ...[
          AppButton(
            label: 'Repay GHS ${loan.outstandingBalance.toStringAsFixed(2)}',
            onPressed: loanVm.isSubmitting ? null : () => _repay(context),
            isLoading: loanVm.isSubmitting,
          ),
        ],

        // Cancel button (pending/approved only)
        if (loan.isPending || loan.isApproved) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: loanVm.isSubmitting ? null : () => _cancel(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],

        // Waiting states
        if (loan.isDisbursing || loan.isRepaying)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    loan.isDisbursing
                        ? 'Waiting for payment confirmation. Please approve the prompt on your phone.'
                        : 'Processing repayment. Please approve the prompt on your phone.',
                    style: const TextStyle(fontSize: 13, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),

        if (loanVm.errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            loanVm.errorMessage!,
            style: const TextStyle(fontSize: 13, color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  void _showAcceptDialog(BuildContext context) {
    final walletVm = context.read<WalletViewModel>();
    final verifiedWallets = walletVm.wallets
        .where((w) => w.isVerified)
        .toList();

    if (verifiedWallets.isEmpty) {
      showTopInAppNotification(
        context,
        title: 'No Wallet',
        message: 'Add and verify a wallet first.',
        type: AppNotificationType.info,
      );
      return;
    }

    Wallet selectedWallet = verifiedWallets.firstWhere(
      (w) => w.isDefault,
      orElse: () => verifiedWallets.first,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Your Wallet',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'This wallet will be charged to send funds and will receive repayment.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...verifiedWallets.map(
                    (w) => GestureDetector(
                      onTap: () => setSheetState(() => selectedWallet = w),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: selectedWallet.id == w.id
                              ? Border.all(color: AppColors.primary, width: 2)
                              : null,
                        ),
                        child: Row(
                          children: [
                            NetworkLogo(network: w.network, size: 24),
                            const SizedBox(width: 10),
                            Text(
                              w.phoneNumber,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            if (selectedWallet.id == w.id)
                              const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Accept & Fund',
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _accept(context, selectedWallet.id);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRejectDialog(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reject',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Reason (optional)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Reject',
                variant: AppButtonVariant.secondary,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _reject(context, controller.text);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _accept(BuildContext context, String walletId) async {
    final loanVm = context.read<LoanViewModel>();
    final ok = await loanVm.acceptLoan(loan.id, agentWalletId: walletId);
    if (ok) onRefresh();
  }

  Future<void> _reject(BuildContext context, String reason) async {
    final loanVm = context.read<LoanViewModel>();
    final ok = await loanVm.rejectLoan(loan.id, reason: reason);
    if (ok) onRefresh();
  }

  Future<void> _disburse(BuildContext context) async {
    final loanVm = context.read<LoanViewModel>();
    final ok = await loanVm.disburseLoan(loan.id);
    if (ok) onRefresh();
  }

  Future<void> _repay(BuildContext context) async {
    final loanVm = context.read<LoanViewModel>();
    final ok = await loanVm.repayLoan(loan.id);
    if (ok) onRefresh();
  }

  Future<void> _cancel(BuildContext context) async {
    final loanVm = context.read<LoanViewModel>();
    final ok = await loanVm.cancelLoan(loan.id);
    if (ok) onRefresh();
  }
}
