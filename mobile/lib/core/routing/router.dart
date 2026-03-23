import 'package:go_router/go_router.dart';
import '../../features/agent/presentation/home/agent_home_screen.dart';
import '../../features/agent/presentation/more/agent_more_screen.dart';
import '../../features/agent/presentation/shell/agent_shell.dart';
import '../../features/auth/presentation/auth_view_model.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/connection_error/presentation/connection_error_screen.dart';
import '../../features/kyc/presentation/kyc_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/support/presentation/support_screen.dart';
import '../../features/agent_profile/presentation/agent_limits_screen.dart';
import '../../features/agent_profile/presentation/agent_service_area_screen.dart';
import '../../features/agent_profile/presentation/certification_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/wallet/presentation/add_wallet_screen.dart';
import '../../features/wallet/presentation/verify_wallet_screen.dart';
import '../../features/wallet/presentation/wallet_list_screen.dart';
import '../../features/user/presentation/home/user_home_screen.dart';
import '../../features/user/presentation/more/user_more_screen.dart';
import '../../features/user/presentation/shell/user_shell.dart';
import '../../features/transactions/presentation/create_transaction_screen.dart';
import '../../features/transactions/presentation/transaction_detail_screen.dart';
import '../../features/transactions/presentation/transaction_list_screen.dart';

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

        final hasConnectionError = authViewModel.hasConnectionError;

        // Connection error → show error screen (unless already there).
        if (isAuthenticated && hasConnectionError) {
          return path == '/connection-error' ? null : '/connection-error';
        }

        // Leaving connection error after recovery → continue to normal flow.
        if (path == '/connection-error' && !hasConnectionError) {
          return isAuthenticated ? null : '/auth/sign-in';
        }

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
          path: '/connection-error',
          builder: (context, state) => const ConnectionErrorScreen(),
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
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/support',
          builder: (context, state) => const SupportScreen(),
        ),

        GoRoute(
          path: '/wallet',
          builder: (context, state) => const WalletListScreen(),
        ),
        GoRoute(
          path: '/wallet/add',
          builder: (context, state) => const AddWalletScreen(),
        ),
        GoRoute(
          path: '/wallet/verify',
          builder: (context, state) {
            final extra = state.extra as Map<String, String>;
            return VerifyWalletScreen(
              walletId: extra['walletId']!,
              phoneNumber: extra['phoneNumber']!,
            );
          },
        ),

        // ── Transactions (shared by both roles) ──
        GoRoute(
          path: '/transactions/create',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            return CreateTransactionScreen(
              agentId: extra['agentId'] as String,
              agentName: extra['agentName'] as String,
              agentSelfieUrl: extra['agentSelfieUrl'] as String?,
            );
          },
        ),
        GoRoute(
          path: '/transactions/:id',
          builder: (context, state) {
            return TransactionDetailScreen(
              transactionId: state.pathParameters['id']!,
            );
          },
        ),

        // ── User shell (4 tabs) ──
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
                  builder: (context, state) => const DiscoverScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/user/requests',
                  builder: (context, state) => TransactionListScreen(
                    isAgent: false,
                    initialTabIndex:
                        state.uri.queryParameters['tab'] == 'history' ? 1 : 0,
                  ),
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

        // ── Agent settings ──
        GoRoute(
          path: '/agent/limits',
          builder: (context, state) => const AgentLimitsScreen(),
        ),
        GoRoute(
          path: '/agent/service-area',
          builder: (context, state) => const AgentServiceAreaScreen(),
        ),
        GoRoute(
          path: '/agent/certification',
          builder: (context, state) => const CertificationScreen(),
        ),

        GoRoute(
          path: '/agent/requests',
          redirect: (context, state) => '/agent/transactions?tab=active',
        ),

        // ── Agent shell (3 tabs) ──
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
                  path: '/agent/transactions',
                  builder: (context, state) => TransactionListScreen(
                    isAgent: true,
                    initialTabIndex:
                        state.uri.queryParameters['tab'] == 'history' ? 1 : 0,
                  ),
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
