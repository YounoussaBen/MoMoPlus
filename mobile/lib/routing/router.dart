import 'package:go_router/go_router.dart';
import '../ui/auth/auth_view_model.dart';
import '../ui/splash/splash_screen.dart';
import '../ui/onboarding/onboarding_screen.dart';
import '../ui/auth/sign_in_screen.dart';
import '../ui/auth/sign_up_screen.dart';
import '../ui/home/home_screen.dart';

class AppRouter {
  static GoRouter create(AuthViewModel authViewModel) {
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: authViewModel,
      redirect: (context, state) {
        final isAuthenticated = authViewModel.isAuthenticated;
        final path = state.uri.path;

        // Splash and onboarding are always accessible.
        if (path == '/splash' || path == '/onboarding') return null;

        final isAuthRoute = path.startsWith('/auth');

        // Authenticated user visiting an auth screen → send home.
        if (isAuthenticated && isAuthRoute) return '/home';

        // Unauthenticated user visiting a protected screen → send to sign-in.
        if (!isAuthenticated && !isAuthRoute) return '/auth/sign-in';

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
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      ],
    );
  }
}
