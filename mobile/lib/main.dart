import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'data/repositories/auth_repository.dart';
import 'data/services/supabase_auth_service.dart';
import 'data/services/backend_api_service.dart';
import 'ui/auth/auth_view_model.dart';
import 'ui/core/themes/app_theme.dart';
import 'routing/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const MomoPlusApp());
}

class MomoPlusApp extends StatefulWidget {
  const MomoPlusApp({super.key});

  @override
  State<MomoPlusApp> createState() => _MomoPlusAppState();
}

class _MomoPlusAppState extends State<MomoPlusApp> {
  late final SupabaseClient _supabaseClient;
  late final AuthRepository _authRepository;
  late final AuthViewModel _authViewModel;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _supabaseClient = Supabase.instance.client;
    final authService = SupabaseAuthService(_supabaseClient);
    final backendService = BackendApiService(_supabaseClient);
    _authRepository = SupabaseAuthRepository(
      authService: authService,
      backendService: backendService,
    );
    _authViewModel = AuthViewModel(_authRepository);
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
        Provider<AuthRepository>.value(value: _authRepository),
        ChangeNotifierProvider<AuthViewModel>.value(value: _authViewModel),
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
