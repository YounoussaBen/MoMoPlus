import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
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
  String? _agentSelfieUrl;

  @override
  void initState() {
    super.initState();
    _agentSelfieUrl = _readImageUrl(widget.agentSelfieUrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallets = context.read<WalletViewModel>().wallets;
      final verified = wallets.where((w) => w.isVerified).toList();
      if (verified.isNotEmpty && _selectedWallet == null && mounted) {
        setState(() {
          _selectedWallet = verified.firstWhere(
            (w) => w.isDefault,
            orElse: () => verified.first,
          );
        });
      }
      if (_agentSelfieUrl == null) _loadAgentPhoto();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
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
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Get Funds'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
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
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: colors.textMuted.withValues(alpha: 0.55),
              ),
              prefix: Text(
                'GHS ',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              filled: true,
              fillColor: colors.surfaceInteractive,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.surfaceSubtle, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.surfaceSubtle, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.brandStrong, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Select wallet
          Text(
            'Receive to Wallet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (walletVm.isLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                  color: colors.brandStrong,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (verifiedWallets.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceSection,
                borderRadius: BorderRadius.circular(14),
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
                    color: colors.surfaceSection,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedWallet?.id == w.id
                          ? colors.brandStrong
                          : colors.surfaceSubtle,
                      width: _selectedWallet?.id == w.id ? 2 : 1,
                    ),
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
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              w.networkLabel,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedWallet?.id == w.id)
                        Icon(
                          Icons.check_circle,
                          color: colors.brandStrong,
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
              color: colors.surfaceInteractive,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Terms',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                _infoRow(context, 'Interest Rate', '10%'),
                _infoRow(context, 'Repayment Period', '24 hours'),
                _infoRow(context, 'Late Penalty', '2% every 12 hours'),
                _infoRow(context, 'Default', 'After 7 days'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (loanVm.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                loanVm.errorMessage!,
                style: TextStyle(fontSize: 13, color: colors.error),
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

  Widget _infoRow(BuildContext context, String label, String value) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
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
      context.pushReplacement('/loans/${loan.id}');
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

  Future<void> _loadAgentPhoto() async {
    try {
      final payload = await context.read<BackendApiService>().getAgentDetail(
        widget.agentId,
      );
      final imageUrl = _readImageUrl(payload?['selfie_url']);
      if (!mounted || imageUrl == null) return;
      setState(() => _agentSelfieUrl = imageUrl);
    } catch (_) {
      // The avatar placeholder remains visible if the optional photo cannot load.
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
