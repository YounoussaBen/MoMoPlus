import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/data/repositories/auth_repository.dart';
import '../../../../core/domain/models/app_user.dart';
import '../../../../core/ui/theme/app_theme.dart';
import '../../../../core/ui/widgets/profile_avatar.dart';
import '../../../../core/ui/widgets/sign_out_sheet.dart';
import '../../../auth/presentation/auth_view_model.dart';

class AgentMoreScreen extends StatelessWidget {
  const AgentMoreScreen({super.key});

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
                _SectionHeader(title: 'Activity'),
                const SizedBox(height: 8),
                _SectionCard(
                  children: [
                    _MoreTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Wallet',
                      subtitle: 'Manage your wallet',
                      onTap: () {},
                    ),
                    const Divider(height: 1, indent: 56),
                    _MoreTile(
                      icon: Icons.tune_outlined,
                      title: 'Limits',
                      subtitle: 'Max amount and service area',
                      onTap: () {},
                    ),
                    const Divider(height: 1, indent: 56),
                    _MoreTile(
                      icon: Icons.location_on_outlined,
                      title: 'Service Area',
                      subtitle: 'Manage your location',
                      onTap: () {},
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
                      final confirmed = await showSignOutDialog(context);
                      if (confirmed == true && context.mounted) {
                        context.read<AuthRepository>().signOut();
                      }
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
