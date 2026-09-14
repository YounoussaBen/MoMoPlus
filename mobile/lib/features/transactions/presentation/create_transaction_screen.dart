import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/services/backend_api_service.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/network_logo.dart';
import '../../../core/ui/widgets/profile_avatar.dart';
import '../../wallet/domain/wallet.dart';
import 'transaction_view_model.dart';

class CreateTransactionScreen extends StatefulWidget {
  final String agentId;
  final String agentName;
  final String? agentSelfieUrl;

  const CreateTransactionScreen({
    super.key,
    required this.agentId,
    required this.agentName,
    this.agentSelfieUrl,
  });

  @override
  State<CreateTransactionScreen> createState() =>
      _CreateTransactionScreenState();
}

class _CreateTransactionScreenState extends State<CreateTransactionScreen> {
  final _amountController = TextEditingController();
  String _transactionType = 'cash_out';
  Wallet? _selectedWallet;
  bool _hasAmount = false;
  String? _agentSelfieUrl;

  @override
  void initState() {
    super.initState();
    _agentSelfieUrl = _readImageUrl(widget.agentSelfieUrl);
    _amountController.addListener(_onAmountChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TransactionViewModel>().loadWallets();
      if (_agentSelfieUrl == null) _loadAgentPhoto();
    });
  }

  void _onAmountChanged() {
    final hasText = _amountController.text.trim().isNotEmpty;
    if (hasText != _hasAmount) {
      setState(() => _hasAmount = hasText);
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final vm = context.watch<TransactionViewModel>();

    // Auto-select default wallet
    if (_selectedWallet == null && vm.verifiedWallets.isNotEmpty) {
      _selectedWallet = vm.verifiedWallets.firstWhere(
        (w) => w.isDefault,
        orElse: () => vm.verifiedWallets.first,
      );
    }

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: const Text('Cash Services'),
        backgroundColor: colors.canvas,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Agent info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceSection,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.surfaceSubtle),
              ),
              child: Row(
                children: [
                  ProfileAvatar(
                    imageUrl: _agentSelfieUrl,
                    fallbackLetter: widget.agentName.isNotEmpty
                        ? widget.agentName[0]
                        : '?',
                    radius: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.agentName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Transaction type
            Text(
              'Service Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TypeCard(
                    icon: Icons.money_off_outlined,
                    label: 'Cash Out',
                    subtitle: 'Wallet → Cash',
                    selected: _transactionType == 'cash_out',
                    onTap: () => setState(() => _transactionType = 'cash_out'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Deposit',
                    subtitle: 'Cash → Wallet',
                    selected: _transactionType == 'deposit',
                    onTap: () => setState(() => _transactionType = 'deposit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Amount
            Text(
              'Amount (GHS)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: 'Enter amount',
                prefix: Text(
                  'GHS ',
                  style: TextStyle(color: colors.textPrimary),
                ),
                filled: true,
                fillColor: colors.surfaceInteractive,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.surfaceSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.surfaceSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.brandStrong, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Wallet selection
            Text(
              'Select Wallet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (vm.isLoadingWallets)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    color: colors.brandStrong,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (vm.verifiedWallets.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceSection,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.surfaceSubtle),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: colors.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No verified wallets. Add and verify a wallet first.',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _handleAddWallet(vm),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Wallet'),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...vm.verifiedWallets.map(
                (wallet) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _WalletOption(
                    wallet: wallet,
                    selected: _selectedWallet?.id == wallet.id,
                    onTap: () => setState(() => _selectedWallet = wallet),
                  ),
                ),
              ),
            const SizedBox(height: 32),

            // Error message
            if (vm.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vm.errorMessage!,
                        style: TextStyle(fontSize: 14, color: colors.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed:
                    vm.isSubmitting || _selectedWallet == null || !_hasAmount
                    ? null
                    : () => _submit(vm),
                child: vm.isSubmitting
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onBrandAccent,
                        ),
                      )
                    : const Text(
                        'Submit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(TransactionViewModel vm) async {
    final txn = await vm.createTransaction(
      agentId: widget.agentId,
      transactionType: _transactionType,
      amount: _amountController.text.trim(),
      network: _selectedWallet!.network,
      walletId: _selectedWallet!.id,
    );
    if (txn != null && mounted) {
      context.replace('/transactions/${txn.id}');
    }
  }

  Future<void> _handleAddWallet(TransactionViewModel vm) async {
    final shouldReload = await context.push<bool>('/wallet/add');
    if (!mounted || shouldReload != true) return;

    setState(() {
      _selectedWallet = null;
    });
    await vm.loadWallets();
  }

  Future<void> _loadAgentPhoto() async {
    try {
      final payload = await context.read<BackendApiService>().getAgentDetail(
        widget.agentId,
      );
      final imageUrl = _readImageUrl(payload?['selfie_url']);
      if (!mounted || imageUrl == null) return;
      setState(() => _agentSelfieUrl = imageUrl);
    } catch (_) {
      // Keep the initials placeholder when the optional photo is unavailable.
    }
  }

  static String? _readImageUrl(dynamic value) {
    if (value is String) {
      final url = value.trim();
      return url.isEmpty ? null : url;
    }
    if (value is Map) {
      return _readImageUrl(value['url'] ?? value['signed_url']);
    }
    return null;
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? colors.brandSoft : colors.surfaceSection,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? colors.brandStrong : colors.surfaceSubtle,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: selected ? colors.brandStrong : colors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? colors.brandStrong : colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletOption extends StatelessWidget {
  final Wallet wallet;
  final bool selected;
  final VoidCallback onTap;

  const _WalletOption({
    required this.wallet,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? colors.brandSoft : colors.surfaceSection,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.brandStrong : colors.surfaceSubtle,
          ),
        ),
        child: Row(
          children: [
            NetworkLogo(network: wallet.network, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.phoneNumber,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected ? colors.brandStrong : colors.textPrimary,
                    ),
                  ),
                  Text(
                    wallet.networkLabel,
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: colors.brandStrong, size: 22)
            else
              Icon(
                Icons.radio_button_unchecked,
                color: colors.textSecondary.withValues(alpha: 0.4),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
