import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/domain/models/app_user.dart';
import '../../../../core/ui/theme/app_theme.dart';
import '../../../../core/ui/widgets/profile_avatar.dart';
import '../../../../core/ui/widgets/sign_out_sheet.dart';
import '../../../auth/presentation/auth_view_model.dart';

class UserMoreScreen extends StatelessWidget {
  const UserMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final appUser = authVm.appUser;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(backgroundColor: AppColors.primary, toolbarHeight: 12),
      body: appUser == null
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: 100,
              ),
              children: [
                _ProfileHeader(appUser: appUser),
                const SizedBox(height: 20),
                _SectionCard(
                  children: [
                    _MoreTile(
                      icon: Icons.person_outline,
                      title: 'Profile',
                      subtitle: 'Personal information',
                      onTap: () => context.push('/profile'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _AgentApplicationSection(appUser: appUser, authVm: authVm),
                const SizedBox(height: 20),
                _SectionHeader(title: 'Activity'),
                const SizedBox(height: 8),
                _SectionCard(
                  children: [
                    _MoreTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Wallet',
                      subtitle: 'Manage your wallet',
                      onTap: () => context.push('/wallet'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _MoreTile(
                      icon: Icons.receipt_long_outlined,
                      title: 'Activity',
                      subtitle: 'View all your activity',
                      onTap: () => context.go('/user/activity'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionHeader(title: 'Account'),
                const SizedBox(height: 8),
                _SectionCard(
                  children: [
                    _MoreTile(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'App preferences',
                      onTap: () => context.push('/settings'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _MoreTile(
                      icon: Icons.help_outline,
                      title: 'Support',
                      subtitle: 'Get help',
                      onTap: () => context.push('/support'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await showSignOutDialog(
                        context,
                        onConfirm: authVm.signOut,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      backgroundColor: AppColors.error.withValues(alpha: 0.06),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final AppUser appUser;
  const _ProfileHeader({required this.appUser});

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final displayName = appUser.fullName.isNotEmpty
        ? appUser.fullName
        : appUser.email.split('@').first;

    return Column(
      children: [
        ProfileAvatar(
          imageUrl: authVm.selfieUrl,
          fallbackLetter: displayName[0],
          radius: 36,
        ),
        const SizedBox(height: 12),
        Text(
          displayName,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          appUser.email,
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      ],
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
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.hourglass_top_rounded,
                color: Colors.orange.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Become an Agent',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Application pending review',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isRejected = appUser.agentStatus == AgentStatus.rejected;

    return GestureDetector(
      onTap: authVm.isLoading
          ? null
          : () => context.read<AuthViewModel>().requestAgent(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.badge_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRejected ? 'Re-apply as Agent' : 'Become an Agent',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isRejected
                        ? 'Your previous application was rejected'
                        : 'Start earning by helping others',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            authVm.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: AppColors.textSecondary)
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
    );
  }
}
