import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/ui/theme/app_theme.dart';
import '../domain/wallet.dart';
import 'wallet_view_model.dart';

class WalletListScreen extends StatelessWidget {
  const WalletListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => WalletViewModel(ctx.read<BackendApiService>()),
      child: const _WalletListBody(),
    );
  }
}

class _WalletListBody extends StatelessWidget {
  const _WalletListBody();

  Future<void> _pushAndReload(
    BuildContext context,
    String path, {
    Object? extra,
  }) async {
    await context.push(path, extra: extra);
    if (context.mounted) {
      context.read<WalletViewModel>().loadWallets();
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => _showActions(context),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _networkColor(wallet.network).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            wallet.networkLabel[0],
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _networkColor(wallet.network),
            ),
          ),
        ),
      ),
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
                vm.setDefault(wallet.id);
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
                  },
                );
              },
              child: const Text('Verify'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDelete(context, vm);
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

  void _confirmDelete(BuildContext context, WalletViewModel vm) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Wallet'),
        content: Text('Remove ${wallet.phoneNumber} from your wallets?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              vm.deleteWallet(wallet.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _networkColor(String network) => switch (network) {
    'mtn' => const Color(0xFFFFCC00),
    'vodafone' => const Color(0xFFE60000),
    'airteltigo' => const Color(0xFF0066B3),
    _ => AppColors.primary,
  };
}
