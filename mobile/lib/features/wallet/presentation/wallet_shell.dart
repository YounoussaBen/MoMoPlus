import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/data/services/backend_api_service.dart';
import 'wallet_view_model.dart';

/// Provides a shared [WalletViewModel] to all wallet sub-routes.
class WalletShell extends StatelessWidget {
  final Widget child;
  const WalletShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => WalletViewModel(ctx.read<BackendApiService>()),
      child: child,
    );
  }
}
