import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/data/repositories/auth_repository.dart';
import 'core/data/services/backend_api_service.dart';
import 'core/data/services/file_upload_service.dart';
import 'core/data/services/supabase_auth_service.dart';
import 'core/routing/router.dart';
import 'core/ui/theme/app_motion.dart';
import 'core/ui/theme/app_theme.dart';
import 'core/ui/theme/app_theme_controller.dart';
import 'features/auth/presentation/auth_view_model.dart';
import 'features/agent_profile/presentation/agent_profile_view_model.dart';
import 'features/loans/presentation/loan_view_model.dart';
import 'features/transactions/presentation/transaction_view_model.dart';
import 'features/wallet/presentation/wallet_view_model.dart';

class MomoPlusApp extends StatefulWidget {
  const MomoPlusApp({super.key, required this.themeController});

  final AppThemeController themeController;

  @override
  State<MomoPlusApp> createState() => _MomoPlusAppState();
}

class _MomoPlusAppState extends State<MomoPlusApp> with WidgetsBindingObserver {
  late final SupabaseClient _supabaseClient;
  late final BackendApiService _backendService;
  late final FileUploadService _fileUploadService;
  late final AuthRepository _authRepository;
  late final AuthViewModel _authViewModel;
  late final TransactionViewModel _transactionViewModel;
  late final WalletViewModel _walletViewModel;
  late final LoanViewModel _loanViewModel;
  late final AgentProfileViewModel _agentProfileViewModel;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _supabaseClient = Supabase.instance.client;
    final authService = SupabaseAuthService(_supabaseClient);
    _backendService = BackendApiService(_supabaseClient);
    _fileUploadService = FileUploadService(_backendService);
    _authRepository = SupabaseAuthRepository(
      authService: authService,
      backendService: _backendService,
    );
    _authViewModel = AuthViewModel(_authRepository)
      ..setBackendApiService(_backendService);
    _transactionViewModel = TransactionViewModel(
      _backendService,
      autoStart: false,
    );
    _walletViewModel = WalletViewModel(
      _backendService,
      loadOnInit: false,
      autoStart: false,
    );
    _loanViewModel = LoanViewModel(_backendService, autoStart: false);
    _agentProfileViewModel = AgentProfileViewModel(
      _backendService,
      autoStart: false,
    );
    _authViewModel.addListener(_syncDataSession);
    _syncDataSession();
    _router = AppRouter.create(_authViewModel);
  }

  void _syncDataSession() {
    final sessionId = _authViewModel.isAuthenticated
        ? _authViewModel.currentUser?.id
        : null;
    _transactionViewModel.setSession(sessionId);
    _walletViewModel.setSession(sessionId);
    _loanViewModel.setSession(sessionId);
    _agentProfileViewModel.setSession(
      _authViewModel.appUser?.isAgent == true ? sessionId : null,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _authViewModel.isAuthenticated) {
      _transactionViewModel.startAutoRefresh();
      _loanViewModel.startAutoRefresh();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _transactionViewModel.stopAutoRefresh();
      _loanViewModel.stopAutoRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authViewModel.removeListener(_syncDataSession);
    _router.dispose();
    _transactionViewModel.dispose();
    _walletViewModel.dispose();
    _loanViewModel.dispose();
    _agentProfileViewModel.dispose();
    _authViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppThemeController>.value(
          value: widget.themeController,
        ),
        Provider<BackendApiService>.value(value: _backendService),
        Provider<FileUploadService>.value(value: _fileUploadService),
        Provider<AuthRepository>.value(value: _authRepository),
        ChangeNotifierProvider<AuthViewModel>.value(value: _authViewModel),
        ChangeNotifierProvider<TransactionViewModel>.value(
          value: _transactionViewModel,
        ),
        ChangeNotifierProvider<WalletViewModel>.value(value: _walletViewModel),
        ChangeNotifierProvider<LoanViewModel>.value(value: _loanViewModel),
        ChangeNotifierProvider<AgentProfileViewModel>.value(
          value: _agentProfileViewModel,
        ),
      ],
      child: Consumer<AppThemeController>(
        builder: (context, themeController, _) => MaterialApp.router(
          title: 'MoMo Plus',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.themeMode,
          themeAnimationDuration: AppMotion.themeChange,
          themeAnimationCurve: AppMotion.shared,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
