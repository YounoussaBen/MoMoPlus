import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/theme/app_theme.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/ui/widgets/network_logo.dart';
import '../../../core/ui/widgets/profile_avatar.dart';
import '../../wallet/domain/wallet.dart';
import '../../wallet/presentation/wallet_view_model.dart';
import 'loan_view_model.dart';

class LoanRequestScreen extends StatefulWidget {
  final String agentId;
  final String agentName;
  final String? agentSelfieUrl;

  const LoanRequestScreen({
    super.key,
    required this.agentId,
    required this.agentName,
    this.agentSelfieUrl,
  });

  @override
  State<LoanRequestScreen> createState() => _LoanRequestScreenState();
}

class _LoanRequestScreenState extends State<LoanRequestScreen> {
  final _amountController = TextEditingController();
  Wallet? _selectedWallet;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallets = context.read<WalletViewModel>().wallets;
      final verified = wallets.where((w) => w.isVerified).toList();
      if (verified.isNotEmpty && _selectedWallet == null) {
        setState(() {
          _selectedWallet = verified.firstWhere(
            (w) => w.isDefault,
            orElse: () => verified.first,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletVm = context.watch<WalletViewModel>();
    final loanVm = context.watch<LoanViewModel>();
    final verifiedWallets = walletVm.wallets
        .where((w) => w.isVerified)
        .toList();

    if (_selectedWallet == null && verifiedWallets.isNotEmpty) {
      _selectedWallet = verifiedWallets.firstWhere(
        (w) => w.isDefault,
        orElse: () => verifiedWallets.first,
      );
    }

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
      body: ListView(
        padding: const EdgeInsets.all(20),
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary.withValues(alpha: 0.3),
              ),
              prefixText: 'GHS ',
              prefixStyle: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Select wallet
          const Text(
            'Receive to Wallet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (walletVm.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (verifiedWallets.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
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
                      onPressed: _handleAddWallet,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Wallet'),
                    ),
                  ),
                ],
              ),
            )
          else
            ...verifiedWallets.map(
              (w) => GestureDetector(
                onTap: () => setState(() => _selectedWallet = w),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: _selectedWallet?.id == w.id
                        ? Border.all(color: AppColors.primary, width: 2)
                        : null,
                  ),
                  child: Row(
                    children: [
                      NetworkLogo(network: w.network, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              w.phoneNumber,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              w.networkLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedWallet?.id == w.id)
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),

          // Interest info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Terms',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                _infoRow('Interest Rate', '10%'),
                _infoRow('Repayment Period', '24 hours'),
                _infoRow('Late Penalty', '2% every 12 hours'),
                _infoRow('Default', 'After 7 days'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (loanVm.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                loanVm.errorMessage!,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
            ),

          const SizedBox(height: 16),
          AppButton(
            label: 'Submit Request',
            onPressed: _canSubmit ? _submit : null,
            isLoading: loanVm.isSubmitting,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  bool get _canSubmit {
    final amount = double.tryParse(_amountController.text);
    return amount != null && amount > 0 && _selectedWallet != null;
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final loanVm = context.read<LoanViewModel>();
    final loan = await loanVm.requestLoan(
      agentId: widget.agentId,
      amount: _amountController.text.trim(),
      walletId: _selectedWallet!.id,
      network: _selectedWallet!.network,
    );
    if (loan != null && mounted) {
      context.go('/loans/${loan.id}');
    }
  }

  Future<void> _handleAddWallet() async {
    final shouldReload = await context.push<bool>('/wallet/add');
    if (!mounted || shouldReload != true) return;

    setState(() {
      _selectedWallet = null;
    });
    await context.read<WalletViewModel>().loadWallets();
  }
}
