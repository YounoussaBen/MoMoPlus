import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/ui/theme/app_theme.dart';
import '../../../core/ui/widgets/network_logo.dart';
import '../domain/wallet.dart';
import 'wallet_view_model.dart';

class WalletListScreen extends StatelessWidget {
  const WalletListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sharedWalletVm = context.read<WalletViewModel>();
    return ChangeNotifierProvider(
      create: (ctx) => WalletViewModel(ctx.read<BackendApiService>()),
      child: _WalletListBody(sharedWalletVm: sharedWalletVm),
    );
  }
}

class _WalletListBody extends StatelessWidget {
  final WalletViewModel sharedWalletVm;

  const _WalletListBody({required this.sharedWalletVm});

  Future<void> _pushAndReload(
    BuildContext context,
    String path, {
    Object? extra,
  }) async {
    final shouldReload = await context.push<bool>(path, extra: extra);
    if (context.mounted && shouldReload == true) {
      await context.read<WalletViewModel>().loadWallets();
      await sharedWalletVm.loadWallets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WalletViewModel>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Wallets'),
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: vm.wallets.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.add, color: AppColors.primary),
                  onPressed: () => _pushAndReload(context, '/wallet/add'),
                ),
              ]
            : null,
      ),
      body: vm.isLoading && vm.wallets.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            )
          : RefreshIndicator(
              color: AppColors.primary,
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
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No wallets yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Add a mobile money number to get started',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _pushAndReload(context, '/wallet/add'),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Wallet'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(200, 48),
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
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (int i = 0; i < vm.wallets.length; i++) ...[
                                if (i > 0) const Divider(height: 1, indent: 72),
                                _WalletTile(
                                  wallet: vm.wallets[i],
                                  onPushAndReload: _pushAndReload,
                                  sharedWalletVm: sharedWalletVm,
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
  final WalletViewModel sharedWalletVm;

  const _WalletTile({
    required this.wallet,
    required this.onPushAndReload,
    required this.sharedWalletVm,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => _showActions(context),
      leading: NetworkLogo(network: wallet.network, size: 36),
      title: Text(
        wallet.phoneNumber,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Row(
        children: [
          Text(
            wallet.networkLabel,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (wallet.isDefault) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Default',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
          if (!wallet.isVerified) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Unverified',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
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
          if (!isLastVerified)
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
          if (ok) {
            await sharedWalletVm.loadWallets();
          }
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
          if (ok) {
            await sharedWalletVm.loadWallets();
          }
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
