import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/data/services/backend_api_service.dart';
import 'package:momoplus/features/discover/presentation/discover_view_model.dart';
import 'package:momoplus/features/loans/presentation/loan_view_model.dart';
import 'package:momoplus/features/transactions/presentation/transaction_view_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'BACKEND_URL=http://localhost:8000');
  });

  test('LoanViewModel ignores an old account response', () async {
    final api = _ControlledFinancialApi();
    final viewModel = LoanViewModel(api, autoStart: false);
    addTearDown(viewModel.dispose);

    viewModel.setSession('user-a');
    viewModel.setSession('user-b');

    api.loanRequests[1].complete([_loanJson('loan-b')]);
    await pumpEventQueue();
    expect(viewModel.loans.single.id, 'loan-b');

    api.loanRequests[0].complete([_loanJson('loan-a')]);
    await pumpEventQueue();
    expect(viewModel.loans.single.id, 'loan-b');
  });

  test('TransactionViewModel ignores an old account response', () async {
    final api = _ControlledFinancialApi();
    final viewModel = TransactionViewModel(api, autoStart: false);
    addTearDown(viewModel.dispose);

    viewModel.setSession('user-a');
    viewModel.setSession('user-b');

    api.transactionRequests[1].complete([_transactionJson('transaction-b')]);
    await pumpEventQueue();
    expect(viewModel.transactions.single.id, 'transaction-b');

    api.transactionRequests[0].complete([_transactionJson('transaction-a')]);
    await pumpEventQueue();
    expect(viewModel.transactions.single.id, 'transaction-b');
  });

  test('DiscoverViewModel clears map and filter state with the session', () {
    final api = _ControlledFinancialApi();
    final viewModel = DiscoverViewModel(api, autoStart: false);
    addTearDown(viewModel.dispose);

    viewModel.setSession('user-a');
    viewModel.setRadius(25);
    expect(viewModel.isSessionActive, isTrue);
    expect(viewModel.radius, 25);

    viewModel.clearSession();

    expect(viewModel.isSessionActive, isFalse);
    expect(viewModel.agents, isEmpty);
    expect(viewModel.hasLocation, isFalse);
    expect(viewModel.radius, 10);
    expect(viewModel.errorMessage, isNull);
  });
}

class _ControlledFinancialApi extends BackendApiService {
  _ControlledFinancialApi()
    : super(SupabaseClient('https://example.supabase.co', 'test-anon-key'));

  final List<Completer<List<dynamic>>> loanRequests = [];
  final List<Completer<List<dynamic>>> transactionRequests = [];

  @override
  Future<List<dynamic>> getLoans({String? status}) {
    final request = Completer<List<dynamic>>();
    loanRequests.add(request);
    return request.future;
  }

  @override
  Future<List<dynamic>> getPhysicalTransactions({String? status}) {
    final request = Completer<List<dynamic>>();
    transactionRequests.add(request);
    return request.future;
  }
}

Map<String, dynamic> _loanJson(String id) => {
  'id': id,
  'amount': '100.00',
  'interest_rate': '10.00',
  'total_repayment': '110.00',
  'agent_interest_amount': '10.00',
  'agent_receivable_balance': '110.00',
  'penalty_amount': '0.00',
  'outstanding_balance': '110.00',
  'status': 'pending',
  'created_at': '2026-07-11T00:00:00Z',
};

Map<String, dynamic> _transactionJson(String id) => {
  'id': id,
  'transaction_type': 'cash_out',
  'amount': '100.00',
  'network': 'mtn',
  'status': 'pending',
  'user_confirmed': false,
  'agent_confirmed': false,
  'created_at': '2026-07-11T00:00:00Z',
  'expires_at': '2026-07-11T01:00:00Z',
};
