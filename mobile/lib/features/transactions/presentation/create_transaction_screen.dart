import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TransactionViewModel>().loadWallets();
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
    final vm = context.watch<TransactionViewModel>();

    // Auto-select default wallet
    if (_selectedWallet == null && vm.verifiedWallets.isNotEmpty) {
      _selectedWallet = vm.verifiedWallets.firstWhere(
        (w) => w.isDefault,
        orElse: () => vm.verifiedWallets.first,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Cash Services'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  ProfileAvatar(
                    imageUrl: widget.agentSelfieUrl,
                    fallbackLetter: widget.agentName.isNotEmpty
                        ? widget.agentName[0]
                        : '?',
                    radius: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.agentName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Transaction type
            const Text(
              'Service Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
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
            const Text(
              'Amount (GHS)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
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
                prefixText: 'GHS ',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Wallet selection
            const Text(
              'Select Wallet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (vm.isLoadingWallets)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (vm.verifiedWallets.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.error.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'No verified wallets. Add and verify a wallet first.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
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
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vm.errorMessage!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.error,
                        ),
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
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.divider,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.divider,
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
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    wallet.networkLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 22)
            else
              Icon(
                Icons.radio_button_unchecked,
                color: AppColors.textSecondary.withValues(alpha: 0.4),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
