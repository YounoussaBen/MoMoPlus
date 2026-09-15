import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/data/services/backend_api_service.dart';
import 'package:momoplus/features/discover/presentation/discover_view_model.dart';
import 'package:momoplus/features/agent_profile/presentation/agent_profile_view_model.dart';
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

  test('AgentProfileViewModel ignores an old account response', () async {
    final api = _ControlledFinancialApi();
    final viewModel = AgentProfileViewModel(api, autoStart: false);
    addTearDown(viewModel.dispose);

    viewModel.setSession('agent-a');
    viewModel.setSession('agent-b');

    api.agentProfileRequests[1].complete(_agentProfileJson('agent-b'));
    await pumpEventQueue();
    expect(viewModel.profile?.id, 'agent-b');

    api.agentProfileRequests[0].complete(_agentProfileJson('agent-a'));
    await pumpEventQueue();
    expect(viewModel.profile?.id, 'agent-b');
  });

  test('saved limits update availability eligibility immediately', () async {
    final api = _ControlledFinancialApi();
    api.wallets = const [
      {'is_verified': true},
    ];
    final viewModel = AgentProfileViewModel(api, autoStart: false);
    addTearDown(viewModel.dispose);

    viewModel.setSession('agent-a');
    api.agentProfileRequests.single.complete(
      _agentProfileJson('agent-a', minAmount: 0, maxAmount: null),
    );
    await pumpEventQueue();
    expect(viewModel.hasLimitsSet, isFalse);
    expect(
      (await viewModel.validateAvailabilityChange(true))?.failure,
      AvailabilityGuardFailure.limitsRequired,
    );

    api.updatedAgentProfile = _agentProfileJson(
      'agent-a',
      minAmount: 50,
      maxAmount: 500,
    );
    expect(
      await viewModel.updateProfile(const {
        'min_amount': '50.00',
        'max_amount': '500.00',
      }),
      isTrue,
    );

    expect(viewModel.hasLimitsSet, isTrue);
    expect(await viewModel.validateAvailabilityChange(true), isNull);
  });

  test(
    'certified agents can stay eligible for cash service with zero limits',
    () async {
      final api = _ControlledFinancialApi();
      api.wallets = const [
        {'is_verified': true},
      ];
      final viewModel = AgentProfileViewModel(api, autoStart: false);
      addTearDown(viewModel.dispose);

      viewModel.setSession('agent-a');
      api.agentProfileRequests.single.complete(
        _agentProfileJson(
          'agent-a',
          minAmount: 0,
          maxAmount: 0,
          agentType: 'certified',
        ),
      );
      await pumpEventQueue();

      expect(viewModel.hasLimitsSet, isTrue);
      expect(await viewModel.validateAvailabilityChange(true), isNull);
    },
  );
}

class _ControlledFinancialApi extends BackendApiService {
  _ControlledFinancialApi()
    : super(SupabaseClient('https://example.supabase.co', 'test-anon-key'));

  final List<Completer<List<dynamic>>> loanRequests = [];
  final List<Completer<List<dynamic>>> transactionRequests = [];
  final List<Completer<Map<String, dynamic>?>> agentProfileRequests = [];
  Map<String, dynamic>? updatedAgentProfile;
  List<dynamic> wallets = const [];

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

  @override
  Future<Map<String, dynamic>?> getAgentProfile() {
    final request = Completer<Map<String, dynamic>?>();
    agentProfileRequests.add(request);
    return request.future;
  }

  @override
  Future<Map<String, dynamic>?> getCertificationStatus() async => null;

  @override
  Future<List<dynamic>> getWallets() async => wallets;

  @override
  Future<Map<String, dynamic>> updateAgentProfile(
    Map<String, dynamic> fields,
  ) async => updatedAgentProfile!;
}

Map<String, dynamic> _agentProfileJson(
  String id, {
  double minAmount = 50,
  double? maxAmount = 500,
  String agentType = 'self_enrolled',
}) => {
  'id': id,
  'full_name': 'Ama Mensah',
  'email': 'ama@example.com',
  'is_available': false,
  'min_amount': minAmount,
  'max_amount': maxAmount,
  'service_radius_km': 10,
  'bio': '',
  'rating': 0,
  'total_ratings': 0,
  'agent_type': agentType,
};

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
