import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/data/repositories/auth_repository.dart';
import '../../../../core/ui/theme/app_theme.dart';
import '../../../../core/ui/widgets/app_logo.dart';
import '../../../auth/presentation/auth_view_model.dart';
import 'agent_home_view_model.dart';

class AgentHomeScreen extends StatelessWidget {
  const AgentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AgentHomeViewModel(ctx.read<AuthRepository>()),
      child: const _AgentHomeView(),
    );
  }
}

class _AgentHomeView extends StatelessWidget {
  const _AgentHomeView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AgentHomeViewModel>();
    final appUser = context.watch<AuthViewModel>().appUser;

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
              _RoleBadge(label: 'Agent', color: const Color(0xFF1A7A4A)),
              const Spacer(),
              Center(
                child: vm.isLoading
                    ? const CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      )
                    : TextButton(
                        onPressed: () =>
                            context.read<AgentHomeViewModel>().signOut(),
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
