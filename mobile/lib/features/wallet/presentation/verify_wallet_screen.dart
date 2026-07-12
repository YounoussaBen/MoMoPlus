import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/ui/theme/app_spacing.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/ui/widgets/app_screen.dart';
import '../../../core/ui/widgets/app_section.dart';
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
  final List<FocusNode> _keyboardFocusNodes = List.generate(
    6,
    (_) => FocusNode(),
  );
  bool _isRedirectingToWallets = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    for (final f in _keyboardFocusNodes) {
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
        return Scaffold(
          backgroundColor: context.appColors.canvas,
          body: Center(
            child: CircularProgressIndicator(
              color: context.appColors.brandAccent,
              strokeWidth: 2,
            ),
          ),
        );
      }
      return AppScreen(
        title: 'Verify wallet',
        body: Center(
          child: Text(
            'No wallet to verify',
            style: context.appTextTheme.bodyLarge,
          ),
        ),
      );
    }

    return AppScreen(
      title: 'Verify wallet',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.appColors.brandSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sms_outlined,
                size: 30,
                color: context.appColors.brandStrong,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Enter verification code',
            textAlign: TextAlign.center,
            style: context.appTextTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a 6-digit code to\n${wallet.phoneNumber}',
            textAlign: TextAlign.center,
            style: context.appTextTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
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
                style: context.appTextTheme.bodyMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          AppSection(
            padding: const EdgeInsets.all(AppSpacing.space4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fieldWidth = ((constraints.maxWidth - 40) / 6)
                    .clamp(36.0, 48.0)
                    .toDouble();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    return SizedBox(
                      width: fieldWidth,
                      child: Padding(
                        padding: EdgeInsets.only(left: i > 0 ? 8 : 0),
                        child: KeyboardListener(
                          focusNode: _keyboardFocusNodes[i],
                          onKeyEvent: (event) => _onKeyDown(i, event),
                          child: TextField(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            style: context.appTextTheme.titleLarge,
                            decoration: InputDecoration(
                              counterText: '',
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              filled: true,
                              fillColor: context.appColors.surfaceInteractive,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: context.appColors.brandStrong,
                                  width: 2,
                                ),
                              ),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (v) => _onChanged(i, v),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          if (vm.errorMessage != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appColors.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: context.appColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      vm.errorMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          AppButton(
            label: 'Verify',
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
            isLoading: vm.isVerifying,
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
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.appColors.brandStrong,
                      ),
                    )
                  : const Text('Resend code'),
            ),
          ),
        ],
      ),
    );
  }
}
