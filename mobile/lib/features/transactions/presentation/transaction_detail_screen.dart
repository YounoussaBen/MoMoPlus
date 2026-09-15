import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/services/native_map_launcher.dart';
import '../../../core/services/transaction_safety_service.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/network_logo.dart';
import '../../auth/presentation/auth_view_model.dart';
import '../domain/physical_transaction.dart';
import 'meeting_point_picker.dart';
import 'transaction_view_model.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late final TransactionViewModel _vm;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _vm = context.read<TransactionViewModel>();
      _vm.loadTransactionDetail(widget.transactionId);
      _vm.startPolling(widget.transactionId);
    }
  }

  @override
  void dispose() {
    _vm.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final txn = _vm.currentTransaction;
        final isAgent = context.read<AuthViewModel>().appUser?.isAgent == true;
        final colors = context.appColors;

        return Scaffold(
          backgroundColor: colors.canvas,
          appBar: AppBar(
            title: const Text('Cash Service'),
            actions: [
              if (txn?.isActive == true)
                IconButton(
                  tooltip: 'Emergency and safety',
                  onPressed: () =>
                      _showSafetySheet(context, txn!, isAgent: isAgent),
                  icon: const Icon(Icons.shield_outlined),
                ),
            ],
          ),
          body: _vm.isLoading && txn == null
              ? Center(
                  child: CircularProgressIndicator(
                    color: colors.brandStrong,
                    strokeWidth: 2,
                  ),
                )
              : txn == null
              ? _buildError(context)
              : RefreshIndicator(
                  onRefresh: () =>
                      _vm.loadTransactionDetail(widget.transactionId),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    child: Column(
                      children: [
                        _StatusHeader(txn: txn),
                        const SizedBox(height: 20),
                        _AmountCard(txn: txn),
                        const SizedBox(height: 12),
                        _WorkflowCard(txn: txn, isAgent: isAgent),
                        const SizedBox(height: 12),
                        _DetailsCard(txn: txn, isAgent: isAgent),
                        if (txn.isAccepted &&
                            !isAgent &&
                            txn.verificationCode != null &&
                            txn.verificationCode!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _VerificationCodeCard(txn: txn),
                        ],
                        if (txn.meetingLatitude != null &&
                            txn.meetingLongitude != null) ...[
                          const SizedBox(height: 12),
                          _MeetingCard(txn: txn),
                        ],
                        if (txn.isCompleted && !isAgent) ...[
                          const SizedBox(height: 12),
                          _AgentRatingCard(
                            agentName: txn.agentName,
                            rating: txn.myRating,
                            onRate: () =>
                                _showCashServiceRatingSheet(context, _vm, txn),
                          ),
                        ],
                        if (txn.isActive) ...[
                          const SizedBox(height: 12),
                          _SafetyCard(
                            onTap: () => _showSafetySheet(
                              context,
                              txn,
                              isAgent: isAgent,
                            ),
                          ),
                        ],
                        if (_vm.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          _ErrorBanner(message: _vm.errorMessage!),
                        ],
                        const SizedBox(height: 24),
                        _ActionButtons(txn: txn, isAgent: isAgent, vm: _vm),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildError(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: colors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _vm.errorMessage ?? 'Transaction not found',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showCashServiceRatingSheet(
  BuildContext context,
  TransactionViewModel vm,
  PhysicalTransaction txn,
) async {
  var selectedRating = txn.myRating ?? 0;
  final rating = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) {
        final colors = context.appColors;
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            decoration: BoxDecoration(
              color: colors.surfaceSection,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.surfaceInteractive,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Icon(
                  Icons.star_rounded,
                  size: 32,
                  color: Colors.amber.shade600,
                ),
                const SizedBox(height: 8),
                Text(
                  'Rate ${txn.agentName}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'How was your cash service experience?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var value = 1; value <= 5; value++)
                      IconButton(
                        tooltip: '$value star${value == 1 ? '' : 's'}',
                        onPressed: () => setState(() {
                          selectedRating = value;
                        }),
                        icon: Icon(
                          value <= selectedRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 38,
                          color: Colors.amber.shade600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedRating == 0
                        ? null
                        : () => Navigator.pop(sheetContext, selectedRating),
                    child: Text(
                      txn.myRating == null ? 'Submit rating' : 'Update rating',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (rating == null || !context.mounted) return;
  final saved = await vm.rateTransaction(txn.id, rating);
  if (!saved || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Your rating was saved.'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ─── In-person workflow ─────────────────────────────────────────────────────

class _WorkflowCard extends StatelessWidget {
  final PhysicalTransaction txn;
  final bool isAgent;

  const _WorkflowCard({required this.txn, required this.isAgent});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final activeStep = txn.isPending
        ? 0
        : txn.isAccepted && !txn.agentConfirmed
        ? 1
        : txn.isAccepted
        ? 2
        : 3;
    final steps = [
      isAgent ? 'Accept request' : 'Agent accepts',
      isAgent ? 'Enter code' : 'Share code',
      txn.isCashOut ? 'Exchange cash' : 'Hand over deposit',
      'Completed',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSection,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.surfaceSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Safe handoff',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The code must be verified before any cash changes hands.',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(steps.length, (index) {
              final complete = index < activeStep || txn.isCompleted;
              final current = index == activeStep && !txn.isCompleted;
              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (index > 0)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: complete
                                  ? colors.brandStrong
                                  : colors.surfaceSubtle,
                            ),
                          ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: complete
                                ? colors.brandStrong
                                : current
                                ? colors.brandSoft
                                : colors.surfaceInteractive,
                            border: current
                                ? Border.all(
                                    color: colors.brandStrong,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: complete
                              ? Icon(
                                  Icons.check,
                                  size: 14,
                                  color: colors.onBrandAccent,
                                )
                              : null,
                        ),
                        if (index < steps.length - 1)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: index < activeStep
                                  ? colors.brandStrong
                                  : colors.surfaceSubtle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      steps[index],
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: current || complete
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: current || complete
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Status header ───────────────────────────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  final PhysicalTransaction txn;
  const _StatusHeader({required this.txn});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final (color, icon, subtitle) = switch (txn.status) {
      'pending' => (
        colors.warning,
        Icons.hourglass_top_rounded,
        'Waiting for agent to accept',
      ),
      'accepted' => (
        colors.brandStrong,
        Icons.handshake_outlined,
        txn.agentConfirmed
            ? 'Code verified — complete the cash service'
            : 'Meet in person and verify the code',
      ),
      'completed' => (
        colors.brandStrong,
        Icons.check_circle_outlined,
        'Transaction completed successfully',
      ),
      'cancelled' => (
        colors.error,
        Icons.cancel_outlined,
        'This transaction was cancelled',
      ),
      'rejected' => (
        colors.error,
        Icons.block_outlined,
        'Agent declined this request',
      ),
      'expired' => (
        colors.textSecondary,
        Icons.timer_off_outlined,
        'This transaction has expired',
      ),
      _ => (colors.textSecondary, Icons.info_outline, ''),
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
          txn.statusLabel,
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
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          txn.typeLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

// ─── Amount card ─────────────────────────────────────────────────────────────

class _AmountCard extends StatelessWidget {
  final PhysicalTransaction txn;
  const _AmountCard({required this.txn});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: colors.surfaceSection,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.surfaceSubtle),
      ),
      child: Column(
        children: [
          Text(
            'Amount',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'GHS ${txn.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.surfaceInteractive,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NetworkLogo(network: txn.network, size: 18),
                const SizedBox(width: 6),
                Text(
                  txn.networkLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
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

// ─── Details card ────────────────────────────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  final PhysicalTransaction txn;
  final bool isAgent;
  const _DetailsCard({required this.txn, required this.isAgent});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSection,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.surfaceSubtle),
      ),
      child: Column(
        children: [
          _DetailRow(
            label: isAgent ? 'Requested by' : 'Agent',
            value: isAgent ? txn.userName : txn.agentName,
          ),
          _detailDivider(context),
          _DetailRow(label: 'Wallet', value: txn.walletPhoneNumber),
          if (txn.userConfirmed || txn.agentConfirmed) ...[
            _detailDivider(context),
            _ConfirmationRow(txn: txn),
          ],
          if (txn.cancellationReason != null &&
              txn.cancellationReason!.isNotEmpty) ...[
            _detailDivider(context),
            _DetailRow(label: 'Reason', value: txn.cancellationReason!),
          ],
        ],
      ),
    );
  }

  Widget _detailDivider(BuildContext context) {
    return Divider(height: 24, color: context.appColors.surfaceSubtle);
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
          style: TextStyle(
            fontSize: 14,
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.appColors.textPrimary,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _ConfirmationRow extends StatelessWidget {
  final PhysicalTransaction txn;
  const _ConfirmationRow({required this.txn});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Confirmations',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        Row(
          children: [
            _confirmChip(context, 'User', txn.userConfirmed),
            const SizedBox(width: 8),
            _confirmChip(context, 'Agent', txn.agentConfirmed),
          ],
        ),
      ],
    );
  }

  Widget _confirmChip(BuildContext context, String label, bool confirmed) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: confirmed ? colors.brandSoft : colors.surfaceInteractive,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            confirmed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: confirmed ? colors.brandStrong : colors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: confirmed ? colors.brandStrong : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Verification code ───────────────────────────────────────────────────────

class _VerificationCodeCard extends StatelessWidget {
  final PhysicalTransaction txn;
  const _VerificationCodeCard({required this.txn});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surfaceSection,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.surfaceSubtle),
      ),
      child: Column(
        children: [
          Text(
            'YOUR CODE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: colors.brandSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              txn.verificationCode!,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: colors.brandStrong,
                letterSpacing: 10,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            txn.agentConfirmed
                ? 'Code verified. Complete the cash service, then confirm below.'
                : 'Only show this code to the agent after you meet and verify their identity.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Meeting location ────────────────────────────────────────────────────────

class _MeetingCard extends StatelessWidget {
  final PhysicalTransaction txn;
  const _MeetingCard({required this.txn});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSection,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.surfaceSubtle),
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
                  color: colors.brandSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: colors.brandStrong,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Meeting Point',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          if (txn.meetingDescription != null &&
              txn.meetingDescription!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              txn.meetingDescription!,
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                NativeMapLauncher.openDirections(
                  latitude: txn.meetingLatitude!,
                  longitude: txn.meetingLongitude!,
                  label: txn.meetingDescription ?? 'Meeting Point',
                );
              },
              icon: const Icon(Icons.navigation_outlined, size: 18),
              label: const Text('Open in Maps'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Safety ─────────────────────────────────────────────────────────────────

class _SafetyCard extends StatelessWidget {
  final VoidCallback onTap;

  const _SafetyCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: colors.error, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency & safety',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Call 112, share your location, or review the meeting point.',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

void _showSafetySheet(
  BuildContext context,
  PhysicalTransaction txn, {
  required bool isAgent,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    builder: (_) => _SafetySheet(txn: txn, isAgent: isAgent),
  );
}

class _SafetySheet extends StatelessWidget {
  final PhysicalTransaction txn;
  final bool isAgent;

  const _SafetySheet({required this.txn, required this.isAgent});

  String get _otherPartyName => isAgent ? txn.userName : txn.agentName;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: colors.surfaceSection,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.shield_outlined, color: colors.error, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Emergency & safety',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'If you feel unsafe, leave the area. Do not exchange cash and contact emergency services.',
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _runAction(
                  context,
                  TransactionSafetyService.callEmergencyServices,
                ),
                style: ElevatedButton.styleFrom(backgroundColor: colors.error),
                icon: const Icon(Icons.call_outlined),
                label: const Text('Call emergency services · 112'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _runAction(
                  context,
                  () => TransactionSafetyService.shareCurrentLocation(
                    transactionId: txn.id,
                    otherPartyName: _otherPartyName,
                  ),
                ),
                icon: const Icon(Icons.share_location_outlined),
                label: const Text('Share my current location'),
              ),
            ),
            if (txn.meetingLatitude != null &&
                txn.meetingLongitude != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _runAction(
                    context,
                    () => NativeMapLauncher.openDirections(
                      latitude: txn.meetingLatitude!,
                      longitude: txn.meetingLongitude!,
                      label: txn.meetingDescription ?? 'Meeting Point',
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Open meeting point'),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceInteractive,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Meet in a visible public place, verify the code in person, and count cash before confirming completion.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ─── Error banner ────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 14, color: colors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action buttons ──────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final PhysicalTransaction txn;
  final bool isAgent;
  final TransactionViewModel vm;

  const _ActionButtons({
    required this.txn,
    required this.isAgent,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (txn.isCompleted || txn.isCancelled || txn.isRejected) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Agent: accept/reject pending requests
        if (isAgent && txn.isPending) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: vm.isSubmitting
                  ? null
                  : () => _openMeetingPointPicker(context),
              icon: vm.isSubmitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onBrandAccent,
                      ),
                    )
                  : const Icon(Icons.location_on_outlined),
              label: const Text('Accept'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: vm.isSubmitting
                  ? null
                  : () => _showRejectDialog(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error),
                backgroundColor: colors.errorContainer,
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

        // The agent verifies the in-person code before cash changes hands.
        if (txn.isAccepted) ...[
          if (isAgent && !txn.agentConfirmed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: vm.isSubmitting
                    ? null
                    : () => _showCodeSheet(context),
                icon: const Icon(Icons.password_rounded),
                label: Text(vm.isSubmitting ? 'Verifying...' : 'Enter code'),
              ),
            )
          else if (isAgent && txn.agentConfirmed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.brandSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: colors.brandStrong,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Code verified. You may now complete the cash service.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.brandStrong,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (!isAgent && !txn.agentConfirmed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.warningContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_clock_outlined,
                    color: colors.warning,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Show your code in person. Do not exchange cash until the app says it is verified.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (!isAgent && !txn.userConfirmed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: vm.isSubmitting
                    ? null
                    : () => _confirmUserCompletion(context),
                icon: const Icon(Icons.task_alt_rounded),
                label: Text(
                  vm.isSubmitting
                      ? 'Confirming...'
                      : txn.isCashOut
                      ? 'Confirm cash received'
                      : 'Confirm deposit handed over',
                ),
              ),
            ),
          const SizedBox(height: 10),
        ],

        if (txn.isActive)
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: vm.isSubmitting
                  ? null
                  : () => _showCancelDialog(context),
              child: Text(
                'Cancel transaction',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showCodeSheet(BuildContext context) async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => const _CodeSheet(),
    );
    if (code == null || !context.mounted) return;
    final ok = await vm.confirmTransaction(txn.id, verificationCode: code);
    if (!ok || !context.mounted) return;
    await _refreshSharedTransactions(context);
  }

  Future<void> _confirmUserCompletion(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(txn.isCashOut ? 'Cash received?' : 'Deposit handed over?'),
        content: Text(
          txn.isCashOut
              ? 'Only confirm after you have counted and received the full cash amount.'
              : 'Only confirm after the agent has received and counted your full deposit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes, complete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await vm.confirmTransaction(txn.id);
    if (!ok || !context.mounted) return;
    await _refreshSharedTransactions(context);
    if (!context.mounted) return;
    final completedTxn = vm.currentTransaction;
    if (completedTxn?.isCompleted == true && completedTxn?.myRating == null) {
      await _showCashServiceRatingSheet(context, vm, completedTxn!);
    }
  }

  Future<void> _openMeetingPointPicker(BuildContext context) async {
    final result = await Navigator.push<MeetingPointResult>(
      context,
      MaterialPageRoute(builder: (_) => const MeetingPointPicker()),
    );
    if (result == null) return;
    final ok = await vm.acceptTransaction(
      txn.id,
      meetingLatitude: result.latitude.toString(),
      meetingLongitude: result.longitude.toString(),
      meetingDescription: result.description,
    );
    if (!ok || !context.mounted) return;
    await _refreshSharedTransactions(context);
  }

  void _showRejectDialog(BuildContext context) {
    _showReasonPicker(
      context: context,
      title: 'Reject',
      subtitle: 'The user will be notified that you declined their request.',
      icon: Icons.block_outlined,
      iconColor: context.appColors.error,
      confirmLabel: 'Reject',
      confirmColor: context.appColors.error,
      reasons: const [
        'I am currently unavailable',
        'Amount is too large',
        'Amount is too small',
        'Location is too far',
        'I don\'t serve this network',
      ],
      onConfirm: (reason) async {
        final ok = await vm.rejectTransaction(txn.id, reason: reason);
        if (!ok || !context.mounted) return;
        await _refreshSharedTransactions(context);
      },
    );
  }

  void _showCancelDialog(BuildContext context) {
    _showReasonPicker(
      context: context,
      title: 'Cancel',
      subtitle: isAgent
          ? 'The user will be notified. This action cannot be undone.'
          : 'The agent will be notified. This action cannot be undone.',
      icon: Icons.cancel_outlined,
      iconColor: context.appColors.error,
      confirmLabel: 'Continue',
      confirmColor: context.appColors.error,
      reasons: isAgent
          ? const [
              'I feel unsafe',
              'User did not arrive',
              'User details do not match',
              'Unable to complete the service',
              'Code could not be verified',
            ]
          : const [
              'I feel unsafe',
              'Agent is taking too long',
              'Found another agent',
              'Entered wrong details',
              'No longer need this transaction',
            ],
      onConfirm: (reason) async {
        final ok = await vm.cancelTransaction(txn.id, reason: reason);
        if (!ok || !context.mounted) return;
        await _refreshSharedTransactions(context);
      },
    );
  }

  Future<void> _refreshSharedTransactions(BuildContext context) {
    return context.read<TransactionViewModel>().loadTransactions();
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

class _CodeSheet extends StatefulWidget {
  const _CodeSheet();

  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: colors.surfaceSection,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.brandSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.password_rounded, color: colors.brandStrong),
              ),
              const SizedBox(height: 14),
              Text(
                'Enter code',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ask the user to show you their 6-digit code in person. Never start the cash service before it is verified.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 10,
                ),
                decoration: const InputDecoration(
                  hintText: '000000',
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (value) {
                  if (value.length == 6) Navigator.pop(context, value);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _controller.text.length == 6
                      ? () => Navigator.pop(context, _controller.text)
                      : null,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Verify before service'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentRatingCard extends StatelessWidget {
  final String agentName;
  final int? rating;
  final VoidCallback onRate;

  const _AgentRatingCard({
    required this.agentName,
    required this.rating,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasRating = rating != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSection,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.surfaceSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasRating ? 'Your rating' : 'Rate your cash service',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasRating
                ? 'You rated $agentName after this completed service.'
                : 'Help other users choose a trusted certified agent.',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (hasRating)
                Row(
                  children: [
                    for (var value = 1; value <= 5; value++)
                      Icon(
                        value <= rating!
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 22,
                        color: Colors.amber.shade600,
                      ),
                  ],
                )
              else
                Icon(Icons.star_outline_rounded, color: colors.brandStrong),
              const Spacer(),
              TextButton(
                onPressed: onRate,
                child: Text(hasRating ? 'Change' : 'Rate agent'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
    final colors = context.appColors;
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
          decoration: BoxDecoration(
            color: colors.surfaceSection,
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
                        color: colors.textSecondary.withValues(alpha: 0.3),
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
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Select a reason',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
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
                                : colors.surfaceInteractive,
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
                                      : colors.surfaceSection,
                                  border: Border.all(
                                    color: selected
                                        ? widget.iconColor
                                        : colors.textSecondary.withValues(
                                            alpha: 0.3,
                                          ),
                                    width: selected ? 0 : 1.5,
                                  ),
                                ),
                                child: selected
                                    ? Icon(
                                        Icons.check,
                                        size: 14,
                                        color: colors.onBrandAccent,
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
                                    color: colors.textPrimary,
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
                              : colors.surfaceInteractive,
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
                                    : colors.surfaceSection,
                                border: Border.all(
                                  color: _isOther
                                      ? widget.iconColor
                                      : colors.textSecondary.withValues(
                                          alpha: 0.3,
                                        ),
                                  width: _isOther ? 0 : 1.5,
                                ),
                              ),
                              child: _isOther
                                  ? Icon(
                                      Icons.check,
                                      size: 14,
                                      color: colors.onBrandAccent,
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
                                color: colors.textPrimary,
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
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
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
