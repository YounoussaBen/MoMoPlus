import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../features/activity/presentation/activity_screen.dart';
import '../../features/agent/presentation/earnings/agent_earnings_screen.dart';
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
import '../../features/settings/presentation/design_system_preview_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/support/presentation/support_screen.dart';
import '../../features/agent_profile/presentation/agent_limits_screen.dart';
import '../../features/agent_profile/presentation/agent_service_area_screen.dart';
import '../../features/agent_profile/presentation/certification_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/guarantors/presentation/guarantors_onboarding_screen.dart';
import '../../features/guarantors/presentation/guarantors_screen.dart';
import '../../features/wallet/presentation/add_wallet_screen.dart';
import '../../features/wallet/presentation/verify_wallet_screen.dart';
import '../../features/wallet/presentation/wallet_list_screen.dart';
import '../../features/loans/presentation/loan_detail_screen.dart';
import '../../features/loans/presentation/loan_request_screen.dart';
import '../../features/transactions/presentation/create_transaction_screen.dart';
import '../../features/transactions/presentation/transaction_detail_screen.dart';
import '../../features/user/presentation/home/user_home_screen.dart';
import '../../features/user/presentation/more/user_more_screen.dart';
import '../../features/user/presentation/shell/user_shell.dart';

int _activityTabIndex(String? tab) {
  if (tab == 'cashServices' || tab == 'cash' || tab == '1') return 1;
  return 0; // default: getFunds
}

typedef _WalletVerificationPayload = ({
  String walletId,
  String phoneNumber,
  String network,
});
typedef _AgentActionPayload = ({
  String agentId,
  String agentName,
  String? agentSelfieUrl,
});

String? _extraString(Object? extra, String key) {
  if (extra is! Map<Object?, Object?>) return null;
  final value = extra[key];
  if (value is! String || value.trim().isEmpty) return null;
  return value;
}

_WalletVerificationPayload? _walletVerificationPayload(Object? extra) {
  final walletId = _extraString(extra, 'walletId');
  final phoneNumber = _extraString(extra, 'phoneNumber');
  if (walletId == null || phoneNumber == null) return null;

  return (
    walletId: walletId,
    phoneNumber: phoneNumber,
    network: _extraString(extra, 'network') ?? 'mtn',
  );
}

_AgentActionPayload? _agentActionPayload(Object? extra) {
  final agentId = _extraString(extra, 'agentId');
  final agentName = _extraString(extra, 'agentName');
  if (agentId == null || agentName == null) return null;

  return (
    agentId: agentId,
    agentName: agentName,
    agentSelfieUrl: _extraString(extra, 'agentSelfieUrl'),
  );
}

String _roleHome(AuthViewModel authViewModel) =>
    authViewModel.appUser?.isAgent == true ? '/agent/home' : '/user/home';

String _missingAgentPayloadLocation(AuthViewModel authViewModel) =>
    authViewModel.appUser?.isAgent == true ? '/agent/home' : '/user/discover';

String? _safeLocalReturnLocation(Uri uri) {
  final path = uri.path;
  if (uri.hasScheme ||
      uri.hasAuthority ||
      !path.startsWith('/') ||
      path.startsWith('//') ||
      path.contains(r'\') ||
      uri.pathSegments.contains('..')) {
    return null;
  }

  if (path == '/wallet/verify') return '/wallet';
  if (path == '/transactions/create' || path == '/loans/request') {
    return '/user/discover';
  }

  if (path == '/splash' ||
      path == '/onboarding' ||
      path == '/connection-error' ||
      path.startsWith('/auth') ||
      path.startsWith('/kyc') ||
      path == '/guarantors') {
    return null;
  }

  return uri.replace(fragment: '').toString();
}

String _signInLocation(GoRouterState state) {
  final returnLocation = _safeLocalReturnLocation(state.uri);
  if (returnLocation == null) return '/auth/sign-in';

  return Uri(
    path: '/auth/sign-in',
    queryParameters: {'returnTo': returnLocation},
  ).toString();
}

String? _intendedReturnLocation(
  GoRouterState state,
  AuthViewModel authViewModel,
) {
  final rawLocation = state.uri.queryParameters['returnTo'];
  if (rawLocation == null || rawLocation.length > 2048) return null;

  final uri = Uri.tryParse(rawLocation);
  if (uri == null) return null;
  final returnLocation = _safeLocalReturnLocation(uri);
  if (returnLocation == null) return null;

  final path = Uri.parse(returnLocation).path;
  final isAgent = authViewModel.appUser?.isAgent == true;
  if ((isAgent && path.startsWith('/user')) ||
      (!isAgent && path.startsWith('/agent'))) {
    return null;
  }
  return returnLocation;
}

String _authenticatedDestination(
  AuthViewModel authViewModel, {
  String? returnLocation,
}) {
  final needsKyc =
      !authViewModel.isKycApproved || authViewModel.shouldShowApprovedKycScreen;
  if (needsKyc) {
    // Support is intentionally available from pending/error KYC states.
    if (returnLocation != null &&
        Uri.parse(returnLocation).path == '/support') {
      return returnLocation;
    }
    return '/kyc';
  }
  if (!(authViewModel.appUser?.hasGuarantors ?? false)) {
    return '/guarantors';
  }
  return returnLocation ?? _roleHome(authViewModel);
}

class AppRouter {
  static GoRouter create(AuthViewModel authViewModel) {
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: authViewModel,
      redirect: (context, state) {
        final isAuthenticated = authViewModel.isAuthenticated;
        final appUser = authViewModel.appUser;
        final path = state.uri.path;

        // Splash owns the launch animation and awaits this same bootstrap.
        if (path == '/splash') return null;

        final hasConnectionError = authViewModel.hasConnectionError;

        // Connection error → show error screen (unless already there).
        if (isAuthenticated && hasConnectionError) {
          return path == '/connection-error' ? null : '/connection-error';
        }

        // Never make KYC, guarantor, or role decisions from a partial profile.
        // Returning null keeps the current location stable until hydration
        // notifies the router again.
        if (isAuthenticated && authViewModel.isProfileLoading) {
          if (path == '/onboarding') return '/splash';
          return null;
        }

        // Leaving connection error after recovery → continue to normal flow.
        if (path == '/connection-error' && !hasConnectionError) {
          if (!isAuthenticated) return '/auth/sign-in';
          return _authenticatedDestination(authViewModel);
        }

        final isAuthRoute = path.startsWith('/auth');
        final isKycRoute = path.startsWith('/kyc');

        // Onboarding is only available before authentication.
        if (path == '/onboarding') {
          return isAuthenticated
              ? _authenticatedDestination(authViewModel)
              : null;
        }

        // Not authenticated → send to sign-in (unless already on an auth route).
        if (!isAuthenticated) {
          return isAuthRoute ? null : _signInLocation(state);
        }

        final isKycApproved = authViewModel.isKycApproved;
        final shouldShowApprovedKycScreen =
            authViewModel.shouldShowApprovedKycScreen;

        // Authenticated user on an auth route → KYC gate or role home.
        if (isAuthRoute) {
          return _authenticatedDestination(
            authViewModel,
            returnLocation: _intendedReturnLocation(state, authViewModel),
          );
        }

        // KYC gate: not yet approved → hold on /kyc.
        final isKycSupportRoute = path == '/support';
        if ((!isKycApproved || shouldShowApprovedKycScreen) &&
            !isKycRoute &&
            !isKycSupportRoute) {
          return '/kyc';
        }

        // KYC approved and already acknowledged → skip /kyc.
        if (isKycApproved && !shouldShowApprovedKycScreen && isKycRoute) {
          return _authenticatedDestination(authViewModel);
        }

        // Guarantors gate: require at least 2 guarantors after KYC.
        final isGuarantorsRoute = path == '/guarantors';
        if (isKycApproved && !shouldShowApprovedKycScreen) {
          final hasGuarantors = appUser?.hasGuarantors ?? false;
          if (!hasGuarantors && !isGuarantorsRoute && !isKycRoute) {
            return '/guarantors';
          }
          if (hasGuarantors && isGuarantorsRoute) {
            return _roleHome(authViewModel);
          }
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
          path: '/guarantors',
          builder: (context, state) => const GuarantorsOnboardingScreen(),
        ),
        GoRoute(
          path: '/guarantors/manage',
          builder: (context, state) => const GuarantorsScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/design-system',
          redirect: (context, state) => kDebugMode ? null : '/settings',
          builder: (context, state) => const DesignSystemPreviewScreen(),
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
          redirect: (context, state) =>
              _walletVerificationPayload(state.extra) == null
              ? '/wallet'
              : null,
          builder: (context, state) {
            final payload = _walletVerificationPayload(state.extra);
            if (payload == null) return const WalletListScreen();
            return VerifyWalletScreen(
              walletId: payload.walletId,
              phoneNumber: payload.phoneNumber,
              network: payload.network,
            );
          },
        ),

        // ── Transactions (shared by both roles) ──
        GoRoute(
          path: '/transactions/create',
          redirect: (context, state) => _agentActionPayload(state.extra) == null
              ? _missingAgentPayloadLocation(authViewModel)
              : null,
          builder: (context, state) {
            final payload = _agentActionPayload(state.extra);
            if (payload == null) {
              return authViewModel.appUser?.isAgent == true
                  ? const AgentHomeScreen()
                  : const DiscoverScreen();
            }
            return CreateTransactionScreen(
              agentId: payload.agentId,
              agentName: payload.agentName,
              agentSelfieUrl: payload.agentSelfieUrl,
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

        // ── Get Funds (loans) ──
        GoRoute(
          path: '/loans/request',
          redirect: (context, state) => _agentActionPayload(state.extra) == null
              ? _missingAgentPayloadLocation(authViewModel)
              : null,
          builder: (context, state) {
            final payload = _agentActionPayload(state.extra);
            if (payload == null) {
              return authViewModel.appUser?.isAgent == true
                  ? const AgentHomeScreen()
                  : const DiscoverScreen();
            }
            return LoanRequestScreen(
              agentId: payload.agentId,
              agentName: payload.agentName,
              agentSelfieUrl: payload.agentSelfieUrl,
            );
          },
        ),
        GoRoute(
          path: '/loans/:id',
          builder: (context, state) {
            return LoanDetailScreen(loanId: state.pathParameters['id']!);
          },
        ),

        // ── Legacy redirects ──
        GoRoute(
          path: '/user/requests',
          redirect: (context, state) => '/user/activity?tab=cashServices',
        ),
        GoRoute(
          path: '/user/loans',
          redirect: (context, state) => '/user/activity?tab=getFunds',
        ),
        GoRoute(
          path: '/user/agents',
          redirect: (context, state) => '/user/discover',
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
                  path: '/user/discover',
                  builder: (context, state) => const DiscoverScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/user/activity',
                  builder: (context, state) => ActivityScreen(
                    isAgent: false,
                    initialTabIndex: _activityTabIndex(
                      state.uri.queryParameters['tab'],
                    ),
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

        // ── Agent legacy redirects ──
        GoRoute(
          path: '/agent/requests',
          redirect: (context, state) => '/agent/activity?tab=cashServices',
        ),
        GoRoute(
          path: '/agent/transactions',
          redirect: (context, state) => '/agent/activity?tab=cashServices',
        ),
        GoRoute(
          path: '/agent/loans',
          redirect: (context, state) => '/agent/activity?tab=getFunds',
        ),

        // ── Agent shell (4 tabs) ──
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
                  path: '/agent/earnings',
                  builder: (context, state) => const AgentEarningsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/agent/activity',
                  builder: (context, state) => ActivityScreen(
                    isAgent: true,
                    initialTabIndex: _activityTabIndex(
                      state.uri.queryParameters['tab'],
                    ),
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
