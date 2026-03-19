import 'package:go_router/go_router.dart';
import '../../features/agent/presentation/transactions/agent_transactions_screen.dart';
import '../../features/agent/presentation/home/agent_home_screen.dart';
import '../../features/agent/presentation/more/agent_more_screen.dart';
import '../../features/agent/presentation/requests/agent_requests_screen.dart';
import '../../features/agent/presentation/shell/agent_shell.dart';
import '../../features/auth/presentation/auth_view_model.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/kyc/presentation/kyc_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/user/presentation/agents/user_agents_screen.dart';
import '../../features/user/presentation/home/user_home_screen.dart';
import '../../features/user/presentation/requests/user_requests_screen.dart';
import '../../features/user/presentation/more/user_more_screen.dart';
import '../../features/user/presentation/shell/user_shell.dart';

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

        final isKycApproved = authViewModel.isKycApproved;
        final shouldShowApprovedKycScreen =
            authViewModel.shouldShowApprovedKycScreen;

        // Authenticated user on an auth route → KYC gate or role home.
        if (isAuthRoute) {
          if (!isKycApproved || shouldShowApprovedKycScreen) return '/kyc';
          return appUser?.isAgent == true ? '/agent/home' : '/user/home';
        }

        // KYC gate: not yet approved → hold on /kyc.
        if ((!isKycApproved || shouldShowApprovedKycScreen) && !isKycRoute) {
          return '/kyc';
        }

        // KYC approved and already acknowledged → skip /kyc.
        if (isKycApproved && !shouldShowApprovedKycScreen && isKycRoute) {
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

        // ── User shell (5 tabs) ──
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              UserShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/user/home',
                  builder: (context, state) => const UserHomeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/user/agents',
                  builder: (context, state) => const UserAgentsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/user/requests',
                  builder: (context, state) => const UserRequestsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/user/more',
                  builder: (context, state) => const UserMoreScreen(),
                ),
              ],
            ),
          ],
        ),

        // ── Agent shell (5 tabs) ──
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AgentShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/agent/home',
                  builder: (context, state) => const AgentHomeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/agent/requests',
                  builder: (context, state) => const AgentRequestsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/agent/transactions',
                  builder: (context, state) => const AgentTransactionsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/agent/more',
                  builder: (context, state) => const AgentMoreScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
