import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/ui/theme/app_theme.dart';
import '../../../core/ui/widgets/network_logo.dart';
import '../../auth/presentation/auth_view_model.dart';
import 'wallet_view_model.dart';

class VerifyWalletScreen extends StatelessWidget {
  final String walletId;
  final String phoneNumber;
  final String network;

  const VerifyWalletScreen({
    super.key,
    required this.walletId,
    required this.phoneNumber,
    required this.network,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          WalletViewModel(ctx.read<BackendApiService>(), loadOnInit: false)
            ..setPendingWallet(
              walletId: walletId,
              phoneNumber: phoneNumber,
              network: network,
            ),
      child: const _VerifyWalletScreenBody(),
    );
  }
}

class _VerifyWalletScreenBody extends StatefulWidget {
  const _VerifyWalletScreenBody();

  @override
  State<_VerifyWalletScreenBody> createState() =>
      _VerifyWalletScreenBodyState();
}

class _VerifyWalletScreenBodyState extends State<_VerifyWalletScreenBody> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isRedirectingToWallets = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();
  bool get _isComplete => _code.length == 6;

  void _onChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  void _onKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WalletViewModel>();
    final wallet = vm.pendingWallet;

    if (wallet == null) {
      if (_isRedirectingToWallets) {
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
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: const Center(child: Text('No wallet to verify')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Verify Wallet'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sms_outlined,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Enter verification code',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a 6-digit code to\n${wallet.phoneNumber}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NetworkLogo(network: wallet.network, size: 20),
              const SizedBox(width: 6),
              Text(
                wallet.networkLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              return Container(
                width: 48,
                margin: EdgeInsets.only(left: i > 0 ? 8 : 0),
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) => _onKeyDown(i, event),
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) => _onChanged(i, v),
                  ),
                ),
              );
            }),
          ),
          if (vm.errorMessage != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
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
                        fontSize: 13,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isComplete && !vm.isVerifying
                ? () async {
                    setState(() => _isRedirectingToWallets = true);
                    vm.clearError();
                    final success = await vm.verifyOtp(_code);
                    if (!context.mounted) return;
                    if (success) {
                      if (context.canPop()) {
                        context.pop(true);
                        return;
                      }
                      final appUser = context.read<AuthViewModel>().appUser;
                      context.go(
                        appUser?.isAgent == true ? '/agent/home' : '/user/home',
                      );
                      return;
                    }
                    setState(() => _isRedirectingToWallets = false);
                  }
                : null,
            child: vm.isVerifying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Verify'),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: vm.isResending
                  ? null
                  : () {
                      vm.resendOtp();
                      for (final c in _controllers) {
                        c.clear();
                      }
                      setState(() {});
                    },
              child: vm.isResending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Text('Resend Code'),
            ),
          ),
        ],
      ),
    );
  }
}
