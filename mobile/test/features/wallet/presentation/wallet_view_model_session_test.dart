import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/data/services/backend_api_service.dart';
import 'package:momoplus/features/wallet/presentation/wallet_view_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'BACKEND_URL=http://localhost:8000');
  });

  group('WalletViewModel session isolation', () {
    test(
      'ignores a previous session response after an account switch',
      () async {
        final api = _ControlledWalletApi();
        final viewModel = WalletViewModel(api, autoStart: false);
        addTearDown(viewModel.dispose);

        viewModel.setSession('user-a');
        viewModel.setSession('user-b');

        expect(api.requests, hasLength(2));
        api.requests[1].complete([_walletJson('wallet-b')]);
        await pumpEventQueue();
        expect(viewModel.wallets.single.id, 'wallet-b');

        api.requests[0].complete([_walletJson('wallet-a')]);
        await pumpEventQueue();

        expect(viewModel.wallets.single.id, 'wallet-b');
        expect(viewModel.errorMessage, isNull);
      },
    );

    test(
      'clearSession invalidates failures and removes sensitive state',
      () async {
        final api = _ControlledWalletApi();
        final viewModel = WalletViewModel(api, autoStart: false);
        addTearDown(viewModel.dispose);

        viewModel.setSession('user-a');
        viewModel.setPendingWallet(
          walletId: 'pending-wallet',
          phoneNumber: '0240000000',
        );

        viewModel.clearSession();
        api.requests.single.completeError(Exception('old account failed'));
        await pumpEventQueue();

        expect(viewModel.isSessionActive, isFalse);
        expect(viewModel.wallets, isEmpty);
        expect(viewModel.pendingWallet, isNull);
        expect(viewModel.errorMessage, isNull);
        expect(viewModel.isLoading, isFalse);
      },
    );
  });
}

class _ControlledWalletApi extends BackendApiService {
  _ControlledWalletApi()
    : super(SupabaseClient('https://example.supabase.co', 'test-anon-key'));

  final List<Completer<List<dynamic>>> requests = [];

  @override
  Future<List<dynamic>> getWallets() {
    final request = Completer<List<dynamic>>();
    requests.add(request);
    return request.future;
  }
}

Map<String, dynamic> _walletJson(String id) => {
  'id': id,
  'phone_number': '0240000000',
  'network': 'mtn',
  'is_verified': true,
  'is_default': true,
  'created_at': '2026-07-11T00:00:00Z',
};
