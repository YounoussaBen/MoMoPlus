import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/data/repositories/auth_repository.dart';
import '../../../../core/domain/models/app_user.dart';
import '../../../../core/ui/theme/app_theme.dart';
import '../../../../core/ui/widgets/app_logo.dart';
import '../../../auth/presentation/auth_view_model.dart';
import 'user_home_view_model.dart';

class UserHomeScreen extends StatelessWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => UserHomeViewModel(ctx.read<AuthRepository>()),
      child: const _UserHomeView(),
    );
  }
}

class _UserHomeView extends StatelessWidget {
  const _UserHomeView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UserHomeViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final appUser = authVm.appUser;

    if (appUser == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final displayName = appUser.firstName.isNotEmpty
        ? appUser.firstName
        : appUser.email.split('@').first;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const AppLogo(size: 120),
              const Spacer(),
              Text(
                'Hello, $displayName 👋',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 8),
              Text(
                appUser.email,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              _RoleBadge(label: 'User', color: AppColors.primary),
              const SizedBox(height: 24),
              _AgentApplicationSection(appUser: appUser, authVm: authVm),
              if (authVm.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  authVm.errorMessage!,
                  style: GoogleFonts.inter(
                    color: AppColors.error,
                    fontSize: 14,
                  ),
                ),
              ],
              const Spacer(),
              Center(
                child: vm.isLoading
                    ? const CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      )
                    : TextButton(
                        onPressed: () =>
                            context.read<UserHomeViewModel>().signOut(),
                        child: Text(
                          'Sign Out',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.error,
                          ),
                        ),
                      ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _RoleBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _AgentApplicationSection extends StatelessWidget {
  final AppUser appUser;
  final AuthViewModel authVm;
  const _AgentApplicationSection({required this.appUser, required this.authVm});

  @override
  Widget build(BuildContext context) {
    if (appUser.agentStatus == AgentStatus.pending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              size: 16,
              color: Colors.orange.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              'Agent application pending review',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (appUser.agentStatus == AgentStatus.rejected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your agent application was rejected.',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.error),
          ),
          const SizedBox(height: 8),
          _BecomeAgentButton(
            authVm: authVm,
            label: 'Re-apply to become an Agent',
          ),
        ],
      );
    }

    return _BecomeAgentButton(authVm: authVm, label: 'Become an Agent');
  }
}

class _BecomeAgentButton extends StatelessWidget {
  final AuthViewModel authVm;
  final String label;
  const _BecomeAgentButton({required this.authVm, required this.label});

  @override
  Widget build(BuildContext context) {
    return authVm.isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          )
        : OutlinedButton(
            onPressed: () => context.read<AuthViewModel>().requestAgent(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
  }
}
