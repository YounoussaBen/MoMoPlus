import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/theme/app_theme.dart';
import '../../../core/ui/widgets/profile_avatar.dart';
import '../../auth/presentation/auth_view_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final appUser = authVm.appUser;

    if (appUser == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: AppColors.background,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final displayName = appUser.fullName.isNotEmpty
        ? appUser.fullName
        : appUser.contactLabel;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          Center(
            child: ProfileAvatar(
              imageUrl: authVm.selfieUrl,
              fallbackLetter: displayName[0],
              radius: 52,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              displayName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                appUser.isAgent ? 'Agent' : 'User',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _InfoCard(
            children: [
              _InfoRow(
                icon: Icons.person_outline,
                label: 'First Name',
                value: appUser.firstName.isNotEmpty ? appUser.firstName : '—',
              ),
              const Divider(height: 1, indent: 56),
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Last Name',
                value: appUser.lastName.isNotEmpty ? appUser.lastName : '—',
              ),
              const Divider(height: 1, indent: 56),
              _InfoRow(
                icon: appUser.phone.isNotEmpty
                    ? Icons.phone_outlined
                    : Icons.email_outlined,
                label: appUser.phone.isNotEmpty ? 'Phone' : 'Email',
                value: appUser.contactLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
