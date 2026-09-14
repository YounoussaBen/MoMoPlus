import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/theme/app_spacing.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/ui/widgets/app_section.dart';
import '../../../core/ui/widgets/app_status.dart';
import '../../../core/ui/widgets/network_logo.dart';
import '../domain/wallet.dart';
import 'wallet_view_model.dart';

class WalletListScreen extends StatelessWidget {
  const WalletListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _WalletListBody();
  }
}

class _WalletListBody extends StatelessWidget {
  const _WalletListBody();

  Future<void> _pushAndReload(
    BuildContext context,
    String path, {
    Object? extra,
  }) async {
    final shouldReload = await context.push<bool>(path, extra: extra);
    if (context.mounted && shouldReload == true) {
      await context.read<WalletViewModel>().loadWallets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WalletViewModel>();

    return Scaffold(
      backgroundColor: context.appColors.canvas,
      appBar: AppBar(
        title: const Text('Wallets'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: vm.wallets.isNotEmpty
            ? [
                IconButton(
                  tooltip: 'Add wallet',
                  icon: Icon(Icons.add, color: context.appColors.brandStrong),
                  onPressed: () => _pushAndReload(context, '/wallet/add'),
                ),
              ]
            : null,
      ),
      body: vm.isLoading && vm.wallets.isEmpty
          ? Center(
              child: CircularProgressIndicator(
                color: context.appColors.brandAccent,
                strokeWidth: 2,
              ),
            )
          : RefreshIndicator(
              color: context.appColors.brandAccent,
              onRefresh: vm.loadWallets,
              child: vm.wallets.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 64,
                                  color: context.appColors.textMuted.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No wallets yet',
                                  style: context.appTextTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Add a mobile money number to get started',
                                  textAlign: TextAlign.center,
                                  style: context.appTextTheme.bodyMedium
                                      ?.copyWith(
                                        color: context.appColors.textSecondary,
                                      ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: 220,
                                  child: AppButton(
                                    label: 'Add wallet',
                                    onPressed: () =>
                                        _pushAndReload(context, '/wallet/add'),
                                    icon: const Icon(Icons.add_rounded),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                      children: [
                        AppSection(
                          padding: const EdgeInsets.all(AppSpacing.space2),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (int i = 0; i < vm.wallets.length; i++) ...[
                                if (i > 0)
                                  const SizedBox(height: AppSpacing.space2),
                                _WalletTile(
                                  wallet: vm.wallets[i],
                                  onPushAndReload: _pushAndReload,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}

class _WalletTile extends StatelessWidget {
  final Wallet wallet;
  final Future<void> Function(BuildContext, String, {Object? extra})
  onPushAndReload;
  const _WalletTile({required this.wallet, required this.onPushAndReload});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surfaceInteractive,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: () => _showActions(context),
        leading: NetworkLogo(network: wallet.network, size: 36),
        title: Text(wallet.phoneNumber, style: context.appTextTheme.titleSmall),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                wallet.networkLabel,
                style: context.appTextTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
              if (wallet.isDefault)
                const AppStatusBadge(
                  label: 'Default',
                  tone: AppStatusTone.brand,
                ),
              if (!wallet.isVerified)
                const AppStatusBadge(
                  label: 'Unverified',
                  tone: AppStatusTone.warning,
                ),
            ],
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: context.appColors.textMuted,
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    final vm = context.read<WalletViewModel>();
    final isLastVerified =
        wallet.isVerified && vm.wallets.where((w) => w.isVerified).length == 1;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(wallet.phoneNumber),
        message: Text(wallet.networkLabel),
        actions: [
          if (wallet.isVerified && !wallet.isDefault)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                Future<void>.microtask(() {
                  if (context.mounted) {
                    _showSetDefaultDialog(context, vm);
                  }
                });
              },
              child: const Text('Set as Default'),
            ),
          if (!wallet.isVerified)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                onPushAndReload(
                  context,
                  '/wallet/verify',
                  extra: {
                    'walletId': wallet.id,
                    'phoneNumber': wallet.phoneNumber,
                    'network': wallet.network,
                  },
                );
              },
              child: const Text('Verify'),
            ),
          if (!wallet.isSignupWallet && !isLastVerified)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                Future<void>.microtask(() {
                  if (context.mounted) {
                    _confirmDelete(context, vm);
                  }
                });
              },
              child: const Text('Delete'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _showSetDefaultDialog(BuildContext context, WalletViewModel vm) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (_) => _WalletActionDialog(
        title: 'Set Default Wallet',
        message: 'Use ${wallet.phoneNumber} as your default wallet?',
        confirmLabel: 'Set Default',
        onConfirm: () async {
          final ok = await vm.setDefault(wallet.id);
          return ok
              ? null
              : (vm.errorMessage ??
                    'We could not update your default wallet right now.');
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WalletViewModel vm) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (_) => _WalletActionDialog(
        title: 'Delete Wallet',
        message: 'Remove ${wallet.phoneNumber} from your wallets?',
        confirmLabel: 'Delete',
        isDestructive: true,
        onConfirm: () async {
          final ok = await vm.deleteWallet(wallet.id);
          return ok
              ? null
              : (vm.errorMessage ??
                    'We could not delete this wallet right now.');
        },
      ),
    );
  }
}

class _WalletActionDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool isDestructive;
  final Future<String?> Function() onConfirm;

  const _WalletActionDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
    this.isDestructive = false,
  });

  @override
  State<_WalletActionDialog> createState() => _WalletActionDialogState();
}

class _WalletActionDialogState extends State<_WalletActionDialog> {
  bool _isSubmitting = false;
  String? _errorText;

  Future<void> _handleConfirm() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final error = await widget.onConfirm();
    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSubmitting = false;
      _errorText = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message),
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: const TextStyle(
                fontSize: 13,
                color: CupertinoColors.systemRed,
              ),
            ),
          ],
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: widget.isDestructive,
          onPressed: _isSubmitting ? null : _handleConfirm,
          child: _isSubmitting
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CupertinoActivityIndicator(),
                    const SizedBox(width: 8),
                    Text(widget.confirmLabel),
                  ],
                )
              : Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
