import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/data/repositories/auth_repository.dart';
import 'core/data/services/backend_api_service.dart';
import 'core/data/services/file_upload_service.dart';
import 'core/data/services/supabase_auth_service.dart';
import 'core/routing/router.dart';
import 'core/ui/theme/app_theme.dart';
import 'features/auth/presentation/auth_view_model.dart';
import 'features/transactions/presentation/transaction_view_model.dart';

class MomoPlusApp extends StatefulWidget {
  const MomoPlusApp({super.key});

  @override
  State<MomoPlusApp> createState() => _MomoPlusAppState();
}

class _MomoPlusAppState extends State<MomoPlusApp> {
  late final SupabaseClient _supabaseClient;
  late final BackendApiService _backendService;
  late final FileUploadService _fileUploadService;
  late final AuthRepository _authRepository;
  late final AuthViewModel _authViewModel;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
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
    _router = AppRouter.create(_authViewModel);
  }

  @override
  void dispose() {
    _router.dispose();
    _authViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<BackendApiService>.value(value: _backendService),
        Provider<FileUploadService>.value(value: _fileUploadService),
        Provider<AuthRepository>.value(value: _authRepository),
        ChangeNotifierProvider<AuthViewModel>.value(value: _authViewModel),
        ChangeNotifierProvider<TransactionViewModel>(
          create: (_) => TransactionViewModel(_backendService),
        ),
      ],
      child: MaterialApp.router(
        title: 'MoMo Plus',
        theme: AppTheme.light,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
