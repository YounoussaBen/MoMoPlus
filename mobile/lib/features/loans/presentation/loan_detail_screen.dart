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
  late final LoanViewModel _loanVm;
  Loan? _loan;
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loanVm = context.read<LoanViewModel>();
    _loanVm.stopAutoRefresh();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _loadLoan());
    _loadLoan();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _loanVm.startAutoRefresh();
    super.dispose();
  }

  Future<void> _loadLoan() async {
    final loan = await _loanVm.getLoanDetail(widget.loanId);
    if (mounted) {
      setState(() {
        if (loan != null) _loan = loan;
        _isLoading = false;
      });
      if (loan != null && !loan.isOngoing) _timer?.cancel();
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
      final errorMessage = _loanVm.errorMessage;
      final hasError = errorMessage != null;
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasError
                      ? Icons.cloud_off_rounded
                      : Icons.account_balance_wallet_outlined,
                  size: 56,
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  hasError ? 'Could not load this loan' : 'Loan not found',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (hasError) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Try again',
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _loadLoan();
                    },
                  ),
                ],
              ],
            ),
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
          'Get Funds',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadLoan,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            _StatusHeader(loan: loan),
            const SizedBox(height: 20),
            _AmountCard(loan: loan, isAgent: isAgent),
            const SizedBox(height: 12),
            if (loan.isActive || loan.isRepaying) ...[
              _TimerCard(loan: loan),
              const SizedBox(height: 12),
            ],
            _DetailsCard(loan: loan, isAgent: isAgent),
            const SizedBox(height: 12),
            if (loan.payments.isNotEmpty) ...[
              _PaymentsCard(loan: loan, isAgent: isAgent),
              const SizedBox(height: 12),
            ],
            if (context.watch<LoanViewModel>().errorMessage != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(
                message: context.read<LoanViewModel>().errorMessage!,
              ),
            ],
            const SizedBox(height: 24),
            _ActionButtons(loan: loan, isAgent: isAgent, onRefresh: _loadLoan),
          ],
        ),
      ),
    );
  }
}

// ─── Status header ───────────────────────────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  final Loan loan;
  const _StatusHeader({required this.loan});

  @override
  Widget build(BuildContext context) {
    final (color, icon, subtitle) = switch (loan.status) {
      'pending' => (
        Colors.orange,
        Icons.hourglass_top_rounded,
        'Waiting for agent to accept',
      ),
      'approved' => (
        AppColors.primary,
        Icons.check_circle_outline,
        'Agent accepted, awaiting fund disbursement',
      ),
      'disbursing' => (
        Colors.blue,
        Icons.sync_rounded,
        'Sending funds to your wallet',
      ),
      'active' => (
        AppColors.primary,
        Icons.account_balance_wallet_rounded,
        'Loan is active, repay before the deadline',
      ),
      'repaying' => (
        Colors.blue,
        Icons.sync_rounded,
        'Processing your repayment',
      ),
      'completed' => (
        AppColors.primary,
        Icons.check_circle_rounded,
        'Loan has been fully repaid',
      ),
      'defaulted' => (
        AppColors.error,
        Icons.warning_amber_rounded,
        'This loan has defaulted',
      ),
      'rejected' => (
        AppColors.error,
        Icons.block_rounded,
        'Agent declined this request',
      ),
      'cancelled' => (
        AppColors.textSecondary,
        Icons.cancel_outlined,
        'This loan was cancelled',
      ),
      'failed' => (
        AppColors.error,
        Icons.error_outline_rounded,
        'Transaction failed',
      ),
      _ => (AppColors.textSecondary, Icons.info_outline, ''),
    };

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 32, color: color),
        ),
        const SizedBox(height: 16),
        Text(
          loan.statusLabel,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        if (loan.rejectionReason.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            loan.rejectionReason,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Amount card ─────────────────────────────────────────────────────────────

class _AmountCard extends StatelessWidget {
  final Loan loan;
  final bool isAgent;
  const _AmountCard({required this.loan, required this.isAgent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Amount',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'GHS ${loan.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NetworkLogo(network: loan.network, size: 18),
                const SizedBox(width: 6),
                Text(
                  loan.networkLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                if (isAgent) ...[
                  _amountRow(
                    'Your Commission (${(loan.agentInterestAmount / loan.amount * 100).toStringAsFixed(0)}%)',
                    'GHS ${loan.agentInterestAmount.toStringAsFixed(2)}',
                  ),
                  if (loan.penaltyAmount > 0)
                    _amountRow(
                      'Penalties',
                      'GHS ${loan.penaltyAmount.toStringAsFixed(2)}',
                      valueColor: AppColors.error,
                    ),
                  Divider(height: 20, color: AppColors.divider),
                  _amountRow(
                    loan.isCompleted
                        ? 'Repayment Received'
                        : 'Repayment to You',
                    'GHS ${loan.totalAgentReceipt.toStringAsFixed(2)}',
                    bold: true,
                  ),
                  if (loan.isActive || loan.isRepaying || loan.isDefaulted)
                    _amountRow(
                      'Outstanding to You',
                      'GHS ${loan.agentReceivableBalance.toStringAsFixed(2)}',
                      bold: true,
                      valueColor: AppColors.primary,
                    ),
                ] else ...[
                  _amountRow(
                    'Interest (${loan.interestRate.toStringAsFixed(0)}%)',
                    'GHS ${loan.totalInterestAmount.toStringAsFixed(2)}',
                  ),
                  if (loan.penaltyAmount > 0)
                    _amountRow(
                      'Penalties',
                      'GHS ${loan.penaltyAmount.toStringAsFixed(2)}',
                      valueColor: AppColors.error,
                    ),
                  Divider(height: 20, color: AppColors.divider),
                  _amountRow(
                    'Total Repayment',
                    'GHS ${loan.totalRepayment.toStringAsFixed(2)}',
                    bold: true,
                  ),
                  if (loan.isActive || loan.isRepaying || loan.isDefaulted)
                    _amountRow(
                      'Outstanding',
                      'GHS ${loan.outstandingBalance.toStringAsFixed(2)}',
                      bold: true,
                      valueColor: AppColors.primary,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(
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

// ─── Timer card ──────────────────────────────────────────────────────────────

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
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isOverdue
            ? AppColors.error.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
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

// ─── Details card ────────────────────────────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  final Loan loan;
  final bool isAgent;
  const _DetailsCard({required this.loan, required this.isAgent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _DetailRow(
            label: isAgent ? 'Borrower' : 'Agent',
            value: isAgent ? loan.borrowerName : loan.agentName,
          ),
          _detailDivider(),
          _DetailRow(label: 'Network', value: loan.networkLabel),
          _detailDivider(),
          _DetailRow(label: 'Borrower Wallet', value: loan.borrowerWalletPhone),
          if (loan.agentWalletPhone.isNotEmpty) ...[
            _detailDivider(),
            _DetailRow(label: 'Agent Wallet', value: loan.agentWalletPhone),
          ],
          if (loan.approvedAt != null) ...[
            _detailDivider(),
            _DetailRow(label: 'Approved', value: _formatDate(loan.approvedAt!)),
          ],
          if (loan.disbursedAt != null) ...[
            _detailDivider(),
            _DetailRow(
              label: 'Funds Sent',
              value: _formatDate(loan.disbursedAt!),
            ),
          ],
          if (loan.deadlineAt != null) ...[
            _detailDivider(),
            _DetailRow(label: 'Deadline', value: _formatDate(loan.deadlineAt!)),
          ],
          if (loan.completedAt != null) ...[
            _detailDivider(),
            _DetailRow(
              label: 'Completed',
              value: _formatDate(loan.completedAt!),
            ),
          ],
          if (loan.rejectionReason.isNotEmpty &&
              (loan.isRejected || loan.isCancelled)) ...[
            _detailDivider(),
            _DetailRow(label: 'Reason', value: loan.rejectionReason),
          ],
        ],
      ),
    );
  }

  Widget _detailDivider() {
    return Divider(height: 24, color: AppColors.divider);
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// ─── Payments card ───────────────────────────────────────────────────────────

class _PaymentsCard extends StatelessWidget {
  final Loan loan;
  final bool isAgent;

  const _PaymentsCard({required this.loan, required this.isAgent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Payment History',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...loan.payments.map((p) {
            final (icon, color) = switch (p.status) {
              'success' => (Icons.check_circle, AppColors.primary),
              'failed' => (Icons.cancel, AppColors.error),
              _ => (Icons.hourglass_top, Colors.orange),
            };
            final title = p.title(isAgent: isAgent);
            final visibleAmount = p.visibleAmount(isAgent: isAgent);
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
                          title,
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
                    'GHS ${visibleAmount.toStringAsFixed(2)}',
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

// ─── Error banner ────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action buttons ──────────────────────────────────────────────────────────

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

    if (loan.isCompleted ||
        loan.isRejected ||
        loan.isCancelled ||
        loan.isFailed) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Agent: Accept and Reject pending loan
        if (isAgent && loan.isPending) ...[
          AppButton(
            label: 'Accept',
            onPressed: loanVm.isSubmitting
                ? null
                : () => _showAcceptDialog(context),
            isLoading: loanVm.isSubmitting,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: loanVm.isSubmitting
                  ? null
                  : () => _showRejectDialog(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                backgroundColor: AppColors.error.withValues(alpha: 0.06),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.block_outlined, size: 20),
              label: const Text('Reject'),
            ),
          ),
        ],

        // Agent: Disburse approved loan
        if (isAgent && loan.isApproved) ...[
          AppButton(
            label: 'Send Funds',
            onPressed: loanVm.isSubmitting ? null : () => _disburse(loanVm),
            isLoading: loanVm.isSubmitting,
          ),
        ],

        // Borrower: Repay active loan
        if (!isAgent && (loan.isActive || loan.isDefaulted)) ...[
          AppButton(
            label: 'Repay GHS ${loan.outstandingBalance.toStringAsFixed(2)}',
            onPressed: loanVm.isSubmitting ? null : () => _repay(loanVm),
            isLoading: loanVm.isSubmitting,
          ),
        ],

        // Waiting states
        if (loan.isDisbursing || loan.isRepaying)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
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
                        ? 'Waiting for payment confirmation.'
                        : 'Processing repayment. Please wait.',
                    style: const TextStyle(fontSize: 13, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),

        // Borrower only: Cancel pending or approved loans
        if (!isAgent && (loan.isPending || loan.isApproved)) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: loanVm.isSubmitting
                  ? null
                  : () => _showCancelDialog(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showAcceptDialog(BuildContext context) async {
    final walletVm = context.read<WalletViewModel>();
    await walletVm.loadWallets();
    if (!context.mounted) return;
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
                      final loanVm = context.read<LoanViewModel>();
                      Navigator.of(ctx).pop();
                      _accept(loanVm, selectedWallet.id);
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
    final loanVm = context.read<LoanViewModel>();
    final refresh = onRefresh;
    _showReasonPicker(
      context: context,
      title: 'Reject',
      subtitle:
          'The borrower will be notified that you declined their request.',
      icon: Icons.block_outlined,
      iconColor: AppColors.error,
      confirmLabel: 'Reject',
      confirmColor: AppColors.error,
      reasons: const [
        'I am currently unavailable',
        'Amount is too large',
        'Amount is too small',
        'Borrower has poor history',
        'I don\'t serve this network',
      ],
      onConfirm: (reason) async {
        final ok = await loanVm.rejectLoan(loan.id, reason: reason);
        if (ok) refresh();
      },
    );
  }

  void _showCancelDialog(BuildContext context) {
    final loanVm = context.read<LoanViewModel>();
    final refresh = onRefresh;
    _showReasonPicker(
      context: context,
      title: 'Cancel',
      subtitle: 'This action cannot be undone.',
      icon: Icons.cancel_outlined,
      iconColor: AppColors.error,
      confirmLabel: 'Continue',
      confirmColor: AppColors.error,
      reasons: const [
        'I changed my mind',
        'Agent is taking too long',
        'Found another agent',
        'Entered wrong details',
        'No longer need this loan',
      ],
      onConfirm: (reason) async {
        final ok = await loanVm.cancelLoan(loan.id, reason: reason);
        if (ok) refresh();
      },
    );
  }

  Future<void> _accept(LoanViewModel loanVm, String walletId) async {
    final ok = await loanVm.acceptLoan(loan.id, agentWalletId: walletId);
    if (ok) onRefresh();
  }

  Future<void> _disburse(LoanViewModel loanVm) async {
    final ok = await loanVm.disburseLoan(loan.id);
    if (ok) onRefresh();
  }

  Future<void> _repay(LoanViewModel loanVm) async {
    final ok = await loanVm.repayLoan(loan.id);
    if (ok) onRefresh();
  }

  void _showReasonPicker({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String confirmLabel,
    required Color confirmColor,
    required List<String> reasons,
    required void Function(String reason) onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => _ReasonPickerSheet(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: iconColor,
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
        reasons: reasons,
        onConfirm: (reason) {
          Navigator.pop(ctx);
          onConfirm(reason);
        },
      ),
    );
  }
}

// ─── Reason picker sheet ─────────────────────────────────────────────────────

class _ReasonPickerSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String confirmLabel;
  final Color confirmColor;
  final List<String> reasons;
  final void Function(String reason) onConfirm;

  const _ReasonPickerSheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.confirmLabel,
    required this.confirmColor,
    required this.reasons,
    required this.onConfirm,
  });

  @override
  State<_ReasonPickerSheet> createState() => _ReasonPickerSheetState();
}

class _ReasonPickerSheetState extends State<_ReasonPickerSheet> {
  int? _selectedIndex;
  bool _isOther = false;
  final _otherCtrl = TextEditingController();

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  String? get _selectedReason {
    if (_isOther) {
      final text = _otherCtrl.text.trim();
      return text.isEmpty ? null : text;
    }
    if (_selectedIndex != null) {
      return widget.reasons[_selectedIndex!];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomPadding = mediaQuery.viewPadding.bottom;
    final maxHeight =
        mediaQuery.size.height - mediaQuery.padding.top - bottomInset - 12;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: widget.iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          widget.icon,
                          size: 20,
                          color: widget.iconColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select a reason',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(widget.reasons.length, (i) {
                    final selected = !_isOther && _selectedIndex == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedIndex = i;
                          _isOther = false;
                        }),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? widget.iconColor.withValues(alpha: 0.06)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? widget.iconColor.withValues(alpha: 0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? widget.iconColor
                                      : Colors.white,
                                  border: Border.all(
                                    color: selected
                                        ? widget.iconColor
                                        : AppColors.textSecondary.withValues(
                                            alpha: 0.3,
                                          ),
                                    width: selected ? 0 : 1.5,
                                  ),
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.reasons[i],
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _isOther = true;
                        _selectedIndex = null;
                      }),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _isOther
                              ? widget.iconColor.withValues(alpha: 0.06)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isOther
                                ? widget.iconColor.withValues(alpha: 0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isOther
                                    ? widget.iconColor
                                    : Colors.white,
                                border: Border.all(
                                  color: _isOther
                                      ? widget.iconColor
                                      : AppColors.textSecondary.withValues(
                                          alpha: 0.3,
                                        ),
                                  width: _isOther ? 0 : 1.5,
                                ),
                              ),
                              child: _isOther
                                  ? const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Other',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: _isOther
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_isOther) ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: _otherCtrl,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Enter your reason...',
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _selectedReason != null
                              ? () => widget.onConfirm(_selectedReason!)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.confirmColor,
                          ),
                          child: Text(widget.confirmLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
