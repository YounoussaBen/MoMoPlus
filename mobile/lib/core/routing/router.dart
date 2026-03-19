import 'package:go_router/go_router.dart';
import '../../features/agent/presentation/home/agent_home_screen.dart';
import '../../features/auth/presentation/auth_view_model.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/kyc/presentation/kyc_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/user/presentation/home/user_home_screen.dart';
import '../domain/models/app_user.dart';

class AppRouter {
  static GoRouter create(AuthViewModel authViewModel) {
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: authViewModel,
      redirect: (context, state) {
        final isAuthenticated = authViewModel.isAuthenticated;
        final appUser = authViewModel.appUser;
        final path = state.uri.path;

        // Always allow splash and onboarding.
        if (path == '/splash' || path == '/onboarding') return null;

        final isAuthRoute = path.startsWith('/auth');
        final isKycRoute = path.startsWith('/kyc');

        // Not authenticated → send to sign-in (unless already on an auth route).
        if (!isAuthenticated) {
          return isAuthRoute ? null : '/auth/sign-in';
        }

        final isKycApproved = appUser?.kycStatus == KycStatus.approved;

        // Authenticated user on an auth route → KYC gate or role home.
        if (isAuthRoute) {
          if (!isKycApproved) return '/kyc';
          return appUser?.isAgent == true ? '/agent/home' : '/user/home';
        }

        // KYC gate: not yet approved → hold on /kyc.
        if (!isKycApproved && !isKycRoute) return '/kyc';

        // KYC approved but still on /kyc → advance to role home.
        if (isKycApproved && isKycRoute) {
          return appUser?.isAgent == true ? '/agent/home' : '/user/home';
        }

        // Role enforcement: agents cannot visit user routes and vice versa.
        if (path.startsWith('/agent') && appUser?.isAgent != true) {
          return '/user/home';
        }
        if (path.startsWith('/user') && appUser?.isAgent == true) {
          return '/agent/home';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/auth/sign-in',
          builder: (context, state) => const SignInScreen(),
        ),
        GoRoute(
          path: '/auth/sign-up',
          builder: (context, state) => const SignUpScreen(),
        ),
        GoRoute(path: '/kyc', builder: (context, state) => const KycScreen()),
        GoRoute(
          path: '/user/home',
          builder: (context, state) => const UserHomeScreen(),
        ),
        GoRoute(
          path: '/agent/home',
          builder: (context, state) => const AgentHomeScreen(),
        ),
      ],
    );
  }
}
